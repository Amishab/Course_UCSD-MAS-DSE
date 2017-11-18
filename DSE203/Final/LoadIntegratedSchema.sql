/*
* Integrated schema design:
*
*  - Reviews table summarizes key information from product reviews JSON file
*
* - Classification flattens the nested structure of ClassificationInfo JSON file
*
* - Sales table integrates information from current customer database tables
*   products, orders, orderlines, customers, campaigns,  classificationInfo, season, holidayseason
*
* - DemandPredictions allows storage of demand prediction from machine learning
*   team at classification level
*/
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

CREATE VIEW Sales AS
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
  cast(p.nodeid as bigint) nodeid,
  p.isinstock,
  p.fullprice,
  ol.unitprice,
  ol.numunits,
  ol.totalprice,
  o.campaignid,
  cp.channel campaignchannel,
  cp.discount campaigndiscount,
  cp.freeshppingflag campaignfreeshippingflag
FROM orders o
INNER JOIN orderlines ol
ON o.orderid = ol.orderid
INNER JOIN products p
ON ol.productid = p.productid
LEFT OUTER JOIN customers c
ON o.customerid = c.customerid
LEFT OUTER JOIN campaigns cp
ON o.campaignid = cp.campaignid
INNER JOIN calendar cl
ON o.orderdate = cl.date;


CREATE OR REPLACE VIEW salesaggregate AS
 SELECT COALESCE(curr.nodeid, prev.nodeid) AS nodeid,
    COALESCE(curr.month::double precision, prev.nm) AS mon,
    COALESCE(curr.year::double precision, prev.nmy) AS yr,
    COALESCE(curr.total_sales_volume, 0::bigint) AS total_sales_volume,
    COALESCE(curr.total_sales_price, 0::numeric) AS total_sales_price,
    COALESCE(prev.total_sales_volume, 0::bigint) AS pm_total_sales_volume,
    COALESCE(prev.total_sales_price, 0::numeric) AS pm_total_sales_price,
    COALESCE(( SELECT sum(s.numunits) AS total_sales_volume
           FROM sales s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= COALESCE(curr.l3myyyymm, prev.l3myyyymm) AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < COALESCE(curr.yyyymm, prev.nmyyyymm) AND s.nodeid = COALESCE(curr.nodeid, prev.nodeid)
          GROUP BY s.nodeid), 0::bigint) AS l3m_total_sales_volume,
    COALESCE(( SELECT sum(s.totalprice::numeric) AS total_sales_price
           FROM sales s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= COALESCE(curr.l3myyyymm, prev.l3myyyymm) AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < COALESCE(curr.yyyymm, prev.nmyyyymm) AND s.nodeid = COALESCE(curr.nodeid, prev.nodeid)
          GROUP BY s.nodeid), 0::numeric) AS l3m_total_sales_price,
    COALESCE(( SELECT sum(s.numunits) AS total_sales_volume
           FROM sales s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= COALESCE(curr.l12myyyymm, prev.l12myyyymm) AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < COALESCE(curr.yyyymm, prev.nmyyyymm) AND s.nodeid = COALESCE(curr.nodeid, prev.nodeid)
          GROUP BY s.nodeid), 0::bigint) AS l12m_total_sales_volume,
    COALESCE(( SELECT sum(s.totalprice::numeric) AS total_sales_price
           FROM sales s
          WHERE ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) >= COALESCE(curr.l12myyyymm, prev.l12myyyymm) AND ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer) < COALESCE(curr.yyyymm, prev.nmyyyymm) AND s.nodeid = COALESCE(curr.nodeid, prev.nodeid)
          GROUP BY s.nodeid), 0::numeric) AS l12m_total_sales_price,
    COALESCE(rev.avgrating, 0::numeric) AS avgrating_by_period,
    COALESCE(( SELECT round(avg(r.overall), 2) AS avgrating
           FROM reviews r
             LEFT JOIN products p ON p.asin = r.asin
          WHERE COALESCE(curr.nodeid, prev.nodeid) = COALESCE(p.nodeid::bigint, 0::bigint)
          GROUP BY (COALESCE(p.nodeid::bigint, 0::bigint))), 0::numeric) AS avgrating
   FROM ( SELECT s.nodeid,
            s.month,
        --    s.monthabbr,
            s.year,
            (s.year::text || lpad(s.month::text, 2, '0'::text))::integer AS yyyymm,
            s.season,
            s.holidayseason,
            date_part('month'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 mon'::interval)::date) AS pm,
            date_part('year'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 mon'::interval)::date) AS pmy,
            (date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '3 mons'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '3 mons'::interval)::text, 2, '0'::text))::integer AS l3myyyymm,
            (date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 year'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 year'::interval)::text, 2, '0'::text))::integer AS l12myyyymm,
            sum(s.fullprice * s.numunits) AS total_full_price,
            sum(s.numunits) AS total_sales_volume,
            sum(s.totalprice::numeric) AS total_sales_price
           FROM sales s
          GROUP BY s.nodeid, s.month, --s.monthabbr,
         s.year, ((s.year::text || lpad(s.month::text, 2, '0'::text))::integer), s.season, s.holidayseason, (date_part('month'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 mon'::interval)::date)), (date_part('year'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 mon'::interval)::date)), ((date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '3 mons'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '3 mons'::interval)::text, 2, '0'::text))::integer), ((date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 year'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '1 year'::interval)::text, 2, '0'::text))::integer)) curr
     FULL JOIN ( SELECT s.nodeid,
            s.month,
            s.year,
            date_part('month'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::date) AS nm,
            date_part('year'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::date) AS nmy,
            (date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::text, 2, '0'::text))::integer AS nmyyyymm,
            (date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '2 mons'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '2 mons'::interval)::text, 2, '0'::text))::integer AS l3myyyymm,
            (date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '11 mons'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '11 mons'::interval)::text, 2, '0'::text))::integer AS l12myyyymm,
            sum(s.numunits) AS total_sales_volume,
            sum(s.totalprice::numeric) AS total_sales_price
           FROM sales s
          GROUP BY s.nodeid, s.month, s.year, (date_part('month'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::date)), (date_part('year'::text, (date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::date)), ((date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) + '1 mon'::interval)::text, 2, '0'::text))::integer), ((date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '2 mons'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '2 mons'::interval)::text, 2, '0'::text))::integer), ((date_part('year'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '11 mons'::interval)::text || lpad(date_part('month'::text, date_trunc('month'::text, s.orderdate::timestamp with time zone) - '11 mons'::interval)::text, 2, '0'::text))::integer)) prev ON curr.nodeid = prev.nodeid AND curr.pm = prev.month::double precision AND curr.pmy = prev.year::double precision
     LEFT JOIN ( SELECT COALESCE(p.nodeid::bigint, 0::bigint) AS nodeid,
            c.month,
            c.year,
            round(avg(r.overall), 2) AS avgrating
           FROM reviews r
             LEFT JOIN products p ON p.asin = r.asin
             JOIN calendar c ON c.date = r.reviewtime
          GROUP BY (COALESCE(p.nodeid::bigint, 0::bigint)), c.month, c.year) rev ON COALESCE(curr.nodeid, prev.nodeid) = rev.nodeid AND COALESCE(curr.month::double precision, prev.nm) = rev.month::double precision AND COALESCE(curr.year::double precision, prev.nmy) = rev.year::double precision;


 CREATE OR REPLACE VIEW public.reviewsaggregate AS
 SELECT 
   r.asin,
   COALESCE(s.nodeid,0) nodeid,
    c.month,
    c.year,
    c.season,
    count(r.reviewid) AS numreviews,
    avg(r.overall) AS avgrating
   FROM reviews r
   left outer join sales s
   on s.asin = r.asin
   inner join calendar c
   on c.date = r.reviewtime
  GROUP BY r.asin,
   COALESCE(s.nodeid,0),
    c.month,
    c.year,
    c.season;


CREATE TABLE Classification
  (
    NodeId         BIGINT NOT NULL,
    Classification VARCHAR(100) NOT NULL,
    Level0         VARCHAR(100),
    Level1         VARCHAR(100),
    Level2         VARCHAR(100),
    Level3         VARCHAR(100),
    Level4         VARCHAR(100),
    Level5         VARCHAR(100)
  );


CREATE TABLE DemandPredictions
  (
    demandid       INTEGER PRIMARY KEY,
    nodeid         INTEGER,
    MONTH          INTEGER,
    YEAR           INTEGER,
    season         VARCHAR(10),
    predictedsales INTEGER
  );


ALTER TABLE public.orderlines
    ADD CONSTRAINT "Orders_FK" FOREIGN KEY (orderid)
    REFERENCES public.orders (orderid) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
CREATE INDEX "fki_Orders_FK"
    ON public.orderlines(orderid);

ALTER TABLE public.orderlines
    ADD CONSTRAINT product_fk FOREIGN KEY (productid)
    REFERENCES public.products (productid) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
CREATE INDEX fki_product_fk
    ON public.orderlines(productid);

--Adding zero id record in Customers to get all customers
insert into customers(customerid, householdid, gender, firstname)
values (0, 0,'NOT DEFINED', 'NOT DEFINED');

ALTER TABLE public.orders
    ADD CONSTRAINT customer_fk FOREIGN KEY (customerid)
    REFERENCES public.customers (customerid) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
CREATE INDEX fki_customer_fk
    ON public.orders(customerid);

ALTER TABLE public.orders
    ADD CONSTRAINT campaign_fk FOREIGN KEY (campaignid)
    REFERENCES public.campaigns (campaignid) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
CREATE INDEX fki_campaign_fk
    ON public.orders(campaignid);