/*
* Integrated schema design:
*
* - Calendar table is similar to current customer database calendar table,
*   with additional attributes to indicate season and holiday season
*
* - Reviews table summarizes key information from product reviews JSON file
*
* - Classification flattens the nested structure of ClassificationInfo JSON file
*
* - Sales table integrates information from current customer database tables
*   products, orders, orderlines, customers, campaigns, and classificationInfo
*
* - ReviewsTFIDF table contains TFIDF info for top 50 terms from review text corpus
*
* - TFIDFvocabulary maps TFIDF term numbers to actual terms
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
  o.customerid,
  c.householdid,
  c.gender,
  o.city,
  o.state,
  o.zipcode,
  ol.productid,
  p.asin,
  p.nodeid,
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
ON o.campaignid = cp.campaignid;


CREATE VIEW SalesAggregate AS
SELECT s.nodeid,
  c.month,
  c.year,
--  c.season,
  SUM(s.numunits) total_sales_volume,
  ROUND(AVG(CAST(s.numunits AS NUMERIC)),4) avg_sales_volume,
  SUM(CAST(s.totalprice AS NUMERIC)) total_sales_price,
  ROUND(AVG(CAST(s.totalprice AS NUMERIC)),2) avg_sales_price
FROM Sales s
INNER JOIN calendar c
ON s.orderdate = c.date
INNER JOIN
  (SELECT MAX(dom) tot_days_in_month,
    MONTH,
    YEAR
  FROM calendar
  GROUP BY MONTH,
    YEAR
  ) tdm
ON tdm.month = c.month
AND tdm.year = c.year
GROUP BY s.nodeid,
  c.MONTH,
  c.YEAR
 -- ,c.season
 ;

CREATE TABLE Classification
  (
    NodeId         INT PRIMARY KEY NOT NULL,
    Classification VARCHAR(50) NOT NULL,
    Level0         VARCHAR(50),
    Level1         VARCHAR(50),
    Level2         VARCHAR(50),
    Level3         VARCHAR(50),
    Level4         VARCHAR(50),
    Level5         VARCHAR(50)
  );

CREATE TABLE ReviewsAggregate
  (
    Asin            INT PRIMARY KEY NOT NULL,
    NumReviews      INT NOT NULL,
    AvgRating       DECIMAL NOT NULL,
    AvgReviewLength DECIMAL NOT NULL
  );

CREATE TABLE ReviewsTFIDF
  (
    ReviewId INT PRIMARY KEY NOT NULL,
    Asin     INT REFERENCES ReviewsAggregate (asin) NOT NULL,
    Term0    NUMERIC NOT NULL,
    Term1    NUMERIC NOT NULL,
    Term2    NUMERIC NOT NULL,
    Term3    NUMERIC NOT NULL,
    Term4    NUMERIC NOT NULL,
    Term5    NUMERIC NOT NULL,
    Term6    NUMERIC NOT NULL,
    Term7    NUMERIC NOT NULL,
    Term8    NUMERIC NOT NULL,
    Term9    NUMERIC NOT NULL,
    Term10   NUMERIC NOT NULL,
    Term11   NUMERIC NOT NULL,
    Term12   NUMERIC NOT NULL,
    Term13   NUMERIC NOT NULL,
    Term14   NUMERIC NOT NULL,
    Term15   NUMERIC NOT NULL,
    Term16   NUMERIC NOT NULL,
    Term17   NUMERIC NOT NULL,
    Term18   NUMERIC NOT NULL,
    Term19   NUMERIC NOT NULL,
    Term20   NUMERIC NOT NULL,
    Term21   NUMERIC NOT NULL,
    Term22   NUMERIC NOT NULL,
    Term23   NUMERIC NOT NULL,
    Term24   NUMERIC NOT NULL,
    Term25   NUMERIC NOT NULL,
    Term26   NUMERIC NOT NULL,
    Term27   NUMERIC NOT NULL,
    Term28   NUMERIC NOT NULL,
    Term29   NUMERIC NOT NULL,
    Term30   NUMERIC NOT NULL,
    Term31   NUMERIC NOT NULL,
    Term32   NUMERIC NOT NULL,
    Term33   NUMERIC NOT NULL,
    Term34   NUMERIC NOT NULL,
    Term35   NUMERIC NOT NULL,
    Term36   NUMERIC NOT NULL,
    Term37   NUMERIC NOT NULL,
    Term38   NUMERIC NOT NULL,
    Term39   NUMERIC NOT NULL,
    Term40   NUMERIC NOT NULL,
    Term41   NUMERIC NOT NULL,
    Term42   NUMERIC NOT NULL,
    Term43   NUMERIC NOT NULL,
    Term44   NUMERIC NOT NULL,
    Term45   NUMERIC NOT NULL,
    Term46   NUMERIC NOT NULL,
    Term47   NUMERIC NOT NULL,
    Term48   NUMERIC NOT NULL,
    Term49   NUMERIC NOT NULL
  );

CREATE TABLE TFIDFvocabulary
  (
    TermId INT PRIMARY KEY NOT NULL,
    Word   VARCHAR(50) NOT NULL
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