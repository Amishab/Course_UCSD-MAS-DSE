/*
* Integrated schema design:
*
* - Sales view integrates information from current customer database tables
*   products, orders, orderlines, customers, campaigns,  classificationInfo, season, holidayseason
*
* - Salesaggregate view aggregates monthly sales by nodeid from Sales View
*
*- reviewsaggregate view summarizes key information from product reviews JSON file
*
* - reviews_agg_yrmn view to aggregate number of reviews and avgrating by nodeid
*
* - sales_agg_mn view aggregates and ranks sales by nodeid and month
*
* - sales_agg_yr view aggregates and ranks sales by nodeid and year
*
* - sales_agg_yrmn view aggregates and ranks sales by nodeid, year and month
*
* - ml_features view provides all features needed for Machine Learning to predict the demand
*
* - mv_ml_features view is materilized view based on ml_features view
* 
*/

--Add season info to Calendar
ALTER TABLE calendar ADD column season        VARCHAR(10) NULL;

ALTER TABLE calendar ADD column holidayseason VARCHAR(25) NULL;

UPDATE calendar
SET season =
  CASE
    WHEN MONTH IN (3,4,5)
    THEN 'Spring'
    WHEN MONTH IN (6,7,8)
    THEN 'Summer'
    WHEN MONTH IN (9,10,11)
    THEN 'Fall'
    WHEN MONTH IN (12,1,2)
    THEN 'Winter'
  END,
  holidayseason =
  CASE
    WHEN MONTH = 12
    THEN 'Christmas_season'
    ELSE NULL
  END;

--Sales View
CREATE OR REPLACE VIEW public.sales AS
 SELECT o.orderid,
    o.orderdate,
    cl.month,
    cl.year,
    cl.season,
    cl.holidayseason,
    o.customerid,
    c.householdid,
    c.gender,
    o.city,
    o.state,
    o.zipcode,
    ol.productid,
    p.asin,
    p.nodeid::bigint AS nodeid,
    p.isinstock,
    p.fullprice,
    ol.unitprice,
    ol.numunits,
    ol.totalprice,
    o.campaignid,
    cp.channel AS campaignchannel,
    cp.discount AS campaigndiscount,
    cp.freeshppingflag AS campaignfreeshippingflag
   FROM orders o
     JOIN orderlines ol ON o.orderid = ol.orderid
     JOIN products p ON ol.productid = p.productid
     LEFT JOIN customers c ON o.customerid = c.customerid
     LEFT JOIN campaigns cp ON o.campaignid = cp.campaignid
     JOIN calendar cl ON o.orderdate = cl.date;

-- SalesAggregate view
CREATE OR REPLACE VIEW public.salesaggregate AS
 SELECT s.nodeid,
    s.month,
    s.year,
    s.season,
    sum(s.numunits) AS total_sales_volume,
    round(avg(s.numunits::numeric), 4) AS avg_sales_volume,
    sum(s.totalprice::numeric) AS total_sales_price,
    round(avg(s.totalprice::numeric), 2) AS avg_sales_price
   FROM sales s
  GROUP BY s.nodeid, s.month, s.year, s.season;

-- reviewsaggregate view
CREATE OR REPLACE VIEW reviewsaggregate AS
SELECT r.asin,
    COALESCE(p.nodeid::bigint, 0::bigint) AS nodeid,
    c.month,
    c.year,
    c.season,
    count(r.reviewid) AS numreviews,
    round(avg(r.overall), 2) AS avgrating
   FROM reviews r
     LEFT JOIN products p ON p.asin = r.asin
     JOIN calendar c ON c.date = r.reviewtime
  GROUP BY r.asin, COALESCE(p.nodeid::bigint, 0::bigint), c.month, c.year, c.season;

-- View: public.reviews_agg_yrmn

CREATE OR REPLACE VIEW public.reviews_agg_yrmn AS
 SELECT p.nodeid::bigint AS nodeid,
    c.year AS yr,
    c.month AS mn,
    count(r.reviewid) AS numreviews,
    round(avg(r.overall), 2) AS avgrating
   FROM reviews r
     LEFT JOIN products p ON p.asin = r.asin
     JOIN calendar c ON c.date = r.reviewtime
  GROUP BY (p.nodeid::bigint), c.year, c.month;

-- View: public.sales_agg_mn

CREATE OR REPLACE VIEW public.sales_agg_mn AS
 SELECT s.nodeid,
    s.month AS mn,
    sum(s.totalprice::numeric) AS sales,
    sum(s.numunits) AS vol,
    round(avg(s.totalprice::numeric), 2) AS avgprice,
    dense_rank() OVER (PARTITION BY s.month ORDER BY (sum(s.totalprice::numeric)) DESC) AS rank_sales,
    dense_rank() OVER (PARTITION BY s.month ORDER BY (sum(s.numunits)) DESC) AS rank_vol
   FROM sales s
  GROUP BY s.nodeid, s.month;

-- View: public.sales_agg_yr

CREATE OR REPLACE VIEW public.sales_agg_yr AS
 SELECT s.nodeid,
    s.year AS yr,
    sum(s.totalprice::numeric) AS sales,
    sum(s.numunits) AS vol,
    round(avg(s.totalprice::numeric), 2) AS avgprice,
    dense_rank() OVER (PARTITION BY s.year ORDER BY (sum(s.totalprice::numeric)) DESC) AS rank_sales,
    dense_rank() OVER (PARTITION BY s.year ORDER BY (sum(s.numunits)) DESC) AS rank_vol
   FROM sales s
  GROUP BY s.nodeid, s.year;

-- View: public.sales_agg_yrmn

CREATE OR REPLACE VIEW public.sales_agg_yrmn AS
 SELECT s.nodeid,
    s.year AS yr,
    s.month AS mn,
    sum(s.totalprice::numeric) AS sales,
    sum(s.numunits) AS vol,
    round(avg(s.totalprice::numeric), 2) AS avgprice
   FROM sales s
  GROUP BY s.nodeid, s.year, s.month;

-- View: public.ml_features

CREATE OR REPLACE VIEW public.ml_features AS
 SELECT baseline.nodeid,
    baseline.year AS yr,
    baseline.month AS mn,
    COALESCE(curr.total_sales_price, 0::numeric) AS sales,
    COALESCE(curr.total_sales_volume, 0::bigint) AS vol,
    COALESCE(prev.total_sales_price, 0::numeric) AS pm_sales,
    COALESCE(prev.total_sales_volume, 0::bigint) AS pm_vol,
    COALESCE(( SELECT sum(s.total_sales_price) AS total_sales_price
           FROM salesaggregate s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= baseline.p3myyyymm AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < baseline.yyyymm AND s.nodeid = baseline.nodeid
          GROUP BY s.nodeid), 0::numeric) AS p3m_sales,
    COALESCE(( SELECT sum(s.total_sales_volume) AS total_sales_volume
           FROM salesaggregate s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= baseline.p3myyyymm AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < baseline.yyyymm AND s.nodeid = baseline.nodeid
          GROUP BY s.nodeid), 0::bigint::numeric) AS p3m_vol,
    COALESCE(( SELECT sum(s.total_sales_price) AS total_sales_price
           FROM salesaggregate s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= baseline.p12myyyymm AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < baseline.yyyymm AND s.nodeid = baseline.nodeid
          GROUP BY s.nodeid), 0::numeric) AS p12m_sales,
    COALESCE(( SELECT sum(s.total_sales_volume) AS total_sales_volume
           FROM salesaggregate s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= baseline.p12myyyymm AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < baseline.yyyymm AND s.nodeid = baseline.nodeid
          GROUP BY s.nodeid), 0::bigint::numeric) AS p12m_vol,
    COALESCE(rev.numreviews::numeric, 0::numeric) AS pm_numreviews,
    COALESCE(rev.avgrating, 0::numeric) AS pm_avgrating,
    COALESCE((( SELECT count(r.reviewid) AS numreviews
           FROM reviews r
             JOIN products p ON p.asin = r.asin
             JOIN calendar c ON c.date = r.reviewtime
          WHERE baseline.nodeid = COALESCE(p.nodeid::bigint, 0::bigint) AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) >= baseline.p3myyyymm AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) < baseline.yyyymm
          GROUP BY (COALESCE(p.nodeid::bigint, 0::bigint))))::numeric, 0::numeric) AS p3m_numreviews,
    COALESCE(( SELECT round(avg(r.overall), 2) AS avgrating
           FROM reviews r
             JOIN products p ON p.asin = r.asin
             JOIN calendar c ON c.date = r.reviewtime
          WHERE baseline.nodeid = COALESCE(p.nodeid::bigint, 0::bigint) AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) >= baseline.p3myyyymm AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) < baseline.yyyymm
          GROUP BY (COALESCE(p.nodeid::bigint, 0::bigint))), 0::numeric) AS p3m_avgrating,
    COALESCE((( SELECT count(r.reviewid) AS numreviews
           FROM reviews r
             JOIN products p ON p.asin = r.asin
             JOIN calendar c ON c.date = r.reviewtime
          WHERE baseline.nodeid = COALESCE(p.nodeid::bigint, 0::bigint) AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) >= baseline.p12myyyymm AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) < baseline.yyyymm
          GROUP BY (COALESCE(p.nodeid::bigint, 0::bigint))))::numeric, 0::numeric) AS p12m_numreviews,
    COALESCE(( SELECT round(avg(r.overall), 2) AS avgrating
           FROM reviews r
             JOIN products p ON p.asin = r.asin
             JOIN calendar c ON c.date = r.reviewtime
          WHERE baseline.nodeid = COALESCE(p.nodeid::bigint, 0::bigint) AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) >= baseline.p12myyyymm AND ((c.year::text || lpad(c.month::text, 2, '0'::text))::integer) < baseline.yyyymm
          GROUP BY (COALESCE(p.nodeid::bigint, 0::bigint))), 0::numeric) AS p12m_avgrating
   FROM ( SELECT DISTINCT products.nodeid::bigint AS nodeid,
            calendar.year,
            calendar.month,
            calendar.monthabbr,
            (calendar.year::text || lpad(calendar.month::text, 2, '0'::text))::integer AS yyyymm,
            calendar.season,
            calendar.holidayseason,
            date_part('month'::text, (date_trunc('month'::text, calendar.date::timestamp with time zone) - '1 mon'::interval)::date) AS pm,
            date_part('year'::text, (date_trunc('month'::text, calendar.date::timestamp with time zone) - '1 mon'::interval)::date) AS pmy,
            (date_part('year'::text, date_trunc('month'::text, calendar.date::timestamp with time zone) - '3 mons'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, calendar.date::timestamp with time zone) - '3 mons'::interval)::text, 2, '0'::text))::integer AS p3myyyymm,
            (date_part('year'::text, date_trunc('month'::text, calendar.date::timestamp with time zone) - '1 year'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, calendar.date::timestamp with time zone) - '1 year'::interval)::text, 2, '0'::text))::integer AS p12myyyymm
           FROM products
             CROSS JOIN calendar
          WHERE calendar.year >= 2009 AND calendar.year <= 2016) baseline
     LEFT JOIN ( SELECT s.nodeid,
            s.month,
            s.year,
            s.total_sales_volume,
            s.total_sales_price
           FROM salesaggregate s) curr ON baseline.nodeid = curr.nodeid AND baseline.month = curr.month AND baseline.year = curr.year
     LEFT JOIN ( SELECT s.nodeid,
            s.month,
            s.year,
            s.total_sales_volume,
            s.total_sales_price
           FROM salesaggregate s) prev ON baseline.nodeid = prev.nodeid AND baseline.pm = prev.month::double precision AND baseline.pmy = prev.year::double precision
     LEFT JOIN ( SELECT COALESCE(p.nodeid::bigint, 0::bigint) AS nodeid,
            c.month,
            c.year,
            count(r.reviewid) AS numreviews,
            round(avg(r.overall), 2) AS avgrating
           FROM reviews r
             LEFT JOIN products p ON p.asin = r.asin
             JOIN calendar c ON c.date = r.reviewtime
          GROUP BY (COALESCE(p.nodeid::bigint, 0::bigint)), c.month, c.year) rev ON baseline.nodeid = rev.nodeid AND baseline.pm = rev.month::double precision AND baseline.pmy = rev.year::double precision
  ORDER BY baseline.nodeid, baseline.year, baseline.month;

  -- View: public.mv_ml_features

CREATE MATERIALIZED VIEW public.mv_ml_features
TABLESPACE pg_default
AS
 SELECT ml_features.nodeid,
    ml_features.yr,
    ml_features.mn,
    ml_features.sales,
    ml_features.vol,
    ml_features.pm_sales,
    ml_features.pm_vol,
    ml_features.p3m_sales,
    ml_features.p3m_vol,
    ml_features.p12m_sales,
    ml_features.p12m_vol,
    ml_features.pm_numreviews,
    ml_features.pm_avgrating,
    ml_features.p3m_numreviews,
    ml_features.p3m_avgrating,
    ml_features.p12m_numreviews,
    ml_features.p12m_avgrating
   FROM ml_features
WITH DATA;

--Adding zero id record in Customers to get all customers
insert into customers(customerid, householdid, gender, firstname)
values (0, 0,'NOT DEFINED', 'NOT DEFINED');

-- Add Foreign keys
ALTER TABLE public.orders
    ADD CONSTRAINT campaign_fk FOREIGN KEY (campaignid)
    REFERENCES public.campaigns (campaignid);

ALTER TABLE public.orders
    ADD CONSTRAINT customer_fk FOREIGN KEY (customerid)
    REFERENCES public.customers (customerid);

ALTER TABLE public.orderlines
    ADD CONSTRAINT orders_fk FOREIGN KEY (orderid)
    REFERENCES public.orders (orderid);

ALTER TABLE public.orderlines
    ADD CONSTRAINT product_fk FOREIGN KEY (productid)
    REFERENCES public.products (productid);





--Add Indexes

CREATE INDEX idx_calendar_date
    ON public.calendar USING btree
    (date)
    TABLESPACE pg_default;

CREATE INDEX idx_calendar_year
    ON public.calendar USING btree
    (year)
    TABLESPACE pg_default;

CREATE INDEX pkcampaign
    ON public.campaigns USING btree
    (campaignid)
    TABLESPACE pg_default;

CREATE INDEX pkcustomerid
    ON public.customers USING btree
    (customerid)
    TABLESPACE pg_default;

CREATE INDEX fki_orders_fk
    ON public.orderlines USING btree
    (orderid)
    TABLESPACE pg_default;

CREATE INDEX fki_product_fk
    ON public.orderlines USING btree
    (productid)
    TABLESPACE pg_default;

CREATE INDEX fki_campaign_fk
    ON public.orders USING btree
    (campaignid)
    TABLESPACE pg_default;

CREATE INDEX fki_customer_fk
    ON public.orders USING btree
    (customerid)
    TABLESPACE pg_default;

CREATE INDEX idx_orders_orddt
    ON public.orders USING hash
    (orderdate)
    TABLESPACE pg_default;

CREATE INDEX pkorderid
    ON public.orders USING btree
    (orderid)
    TABLESPACE pg_default;

CREATE INDEX idx_products_asin
    ON public.products USING hash
    (asin COLLATE pg_catalog."default")
    TABLESPACE pg_default;

CREATE INDEX idx_products_nodeid
    ON public.products USING btree
    ((nodeid::bigint))
    TABLESPACE pg_default;

CREATE INDEX pkproduct
    ON public.products USING btree
    (productid)
    TABLESPACE pg_default;

CREATE INDEX idx_reviews_asin
    ON public.reviews USING btree
    (asin COLLATE pg_catalog."default")
    TABLESPACE pg_default;

CREATE INDEX idx_reviews_rvwtime
    ON public.reviews USING hash
    (reviewtime)
    TABLESPACE pg_default;



