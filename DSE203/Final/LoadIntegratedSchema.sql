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


CREATE VIEW SalesAggregate AS
SELECT s.nodeid,
  s.month,
  s.year,
  s.season,
  SUM(s.numunits) total_sales_volume,
  ROUND(AVG(CAST(s.numunits AS NUMERIC)),4) avg_sales_volume,
  SUM(CAST(s.totalprice AS NUMERIC)) total_sales_price,
  ROUND(AVG(CAST(s.totalprice AS NUMERIC)),2) avg_sales_price
FROM Sales s
GROUP BY s.nodeid,
  s.MONTH,
  s.YEAR,
  s.season
 ;

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