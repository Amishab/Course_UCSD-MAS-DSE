DROP VIEW salesaggregate;

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

