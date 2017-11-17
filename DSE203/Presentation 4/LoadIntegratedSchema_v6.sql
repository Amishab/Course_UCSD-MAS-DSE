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
 * - ReviewsTFIDF table contains TFIDF info for top 100 terms from review text corpus
 *
 * - TFIDFvocabulary maps TFIDF term numbers to actual terms
 *
 * - DemandPredictions allows storage of demand prediction from machine learning
 *   team at classification level
 */

DROP TABLE Calendar CASCADE;
DROP TABLE Classification CASCADE;
DROP TABLE Reviews CASCADE;
DROP TABLE ReviewsTFIDF CASCADE;
DROP TABLE Sales CASCADE;
DROP TABLE SalesAggregate CASCADE;
DROP TABLE TFIDFvocabulary CASCADE;
DROP TABLE DemandPredictions CASCADE;

CREATE TABLE Calendar (
	Date date NOT NULL PRIMARY KEY,
	Year smallint NOT NULL,
	Month smallint NOT NULL,
	Season varchar(10) NOT NULL,
	HolidaySeason varchar(25),
	ISO varchar(10) NOT NULL,
	datenum int NOT NULL,
	DOW char(3) NOT NULL,
	DOWint smallint NOT NULL,
	DOM smallint NOT NULL,
	MonthAbbr char(3) NOT NULL,
	DOY smallint NOT NULL,
	Mondays smallint NOT NULL,
	Tuesdays smallint NOT NULL,
	Wednesdays smallint NOT NULL,
	Thursdays smallint NOT NULL,
	Fridays smallint NOT NULL,
	Saturdays smallint NOT NULL,
	Sundays smallint NOT NULL,
	NumHolidays int NOT NULL,
	HolidayName varchar(255) NULL,
	HolidayType varchar(9) NULL,
	hol_National varchar(255) NULL,
	hol_Minor varchar(255) NULL,
	hol_Christian varchar(255) NULL,
	hol_Jewish varchar(255) NULL,
	hol_Muslim varchar(255) NULL,
	hol_Chinese varchar(255) NULL,
	hol_Other varchar(255) NULL
);

CREATE TABLE Classification (
	NodeId int PRIMARY KEY NOT NULL,
	Classification varchar(50) NOT NULL,
	Level0 varchar(50),
	Level1 varchar(50),
	Level2 varchar(50),
	Level3 varchar(50),
	Level4 varchar(50),
	Level5 varchar(50)
);

/* 
 * Or, the Classification table can be structured as below: 

CREATE TABLE Classification (
	NodeId int PRIMARY KEY NOT NULL
	Classification varchar(50) NOT NULL,
	CategoryName varchar(50) NOT NULL,
	CategoryLevel int NOT NULL,
	AvgProductPrice money
);
 */

CREATE TABLE ReviewsAggregate (
    Asin int PRIMARY KEY NOT NULL,
    NodeId int NOT NULL,
    Month int NOT NULL,
    Year int NOT NULL,
    Season varchar(10) NOT NULL,
    NumReviews int NOT NULL,
    AvgRating decimal NOT NULL,
    AvgSentiment decimal NOT NULL
);

CREATE TABLE ReviewsTFIDF (
    ReviewId int PRIMARY KEY NOT NULL,
    Asin int REFERENCES Reviews (asin) NOT NULL,
	Term0 numeric NOT NULL,
    Term1 numeric NOT NULL,
	Term48 numeric NOT NULL,
    Term49 numeric NOT NULL
);

CREATE TABLE TFIDFvocabulary (
	TermId int PRIMARY KEY NOT NULL,
	Word varchar(50) NOT NULL
);


CREATE TABLE Sales (
	SalesId int PRIMARY KEY NOT NULL,
	OrderDate date REFERENCES Calendar (date) NOT NULL,
	Month smallint NOT NULL,
	Year smallint NOT NULL,
	Season varchar(10) NOT NULL,
	HolidaySeason varchar(25),
	Asin int REFERENCES Reviews (asin) NOT NULL,
	NodeId int REFERENCES Classification (NodeId) NOT NULL,
	ProductId int NOT NULL,
	IsInStock char(1) NOT NULL,
	OrderId int NOT NULL,
	NumUnits int NOT NULL,
	FullPrice money NOT NULL,
	City varchar(50) NOT NULL,
	State varchar(50) NOT NULL,
	ZipCode varchar(50) NOT NULL,
	CampaignId int NOT NULL,
	CampaignChannel varchar(50),
	CampaignDiscount int NOT NULL,
	CampaignFreeShippingFlag char(1) NOT NULL,
	CustomerId int NOT NULL,
	CustomerHouseholdId int NOT NULL,
	CustomerGender varchar(50) NOT NULL
);

CREATE TABLE SalesAggregate (
	SalesAggId int PRIMARY KEY NOT NULL,
	NodeId int REFERENCES Classification (NodeId) NOT NULL,
    Month int NOT NULL,
    Year int NOT NULL,
    Season varchar(10) NOT NULL,
    TotalSalesVolume int NOT NULL,
    TotalSalesPrice money NOT NULL,
    AvgSalesPrice money NOT NULL
);

CREATE TABLE DemandPredictions (
	DemandId int PRIMARY KEY NOT NULL,
	NodeId int REFERENCES Classification (NodeId) NOT NULL,
	Month int NOT NULL,
	Year int NOT NULL,
	Season varchar(10) NOT NULL,
	PredictedSales int NOT NULL
);