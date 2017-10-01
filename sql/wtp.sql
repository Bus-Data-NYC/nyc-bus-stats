-- Wait time probabilities
-- wtp_5, wtp_10, wtp_15, wtp_20, wtp_30: the percentage chance of waiting less than 5, 10, 15, 20, or 30 minutes when arriving at a bus stop at random during high frequency scheduled service
-- hours: the number of hours measured (during high frequency scheduled service)
-- Calculated with the observed headways. We calculate the fraction of a period less than x minutes before a call, then divide by the total number of minutes per period

CREATE OR REPLACE FUNCTION get_wtp ("start" DATE, term INTERVAL)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        calls int,
        wtp5 int,
        wtp10 int,
        wtp15 int,
        wtp20 int,
        wtp30 int
    ) AS $$
    SELECT
        "start" month,
        route_id,
        direction_id,
        stop_id,
        EXTRACT(isodow FROM "datetime") > 5 OR h.holiday IS NOT NULL AS weekend,
        day_period("datetime") AS period,
        COUNT(*)::int AS calls,
        SUM(LEAST(EXTRACT(epoch FROM headway),  5 * 60)) / day_period_length(day_period("datetime")) wtp5,
        SUM(LEAST(EXTRACT(epoch FROM headway), 10 * 60)) / day_period_length(day_period("datetime")) wtp10,
        SUM(LEAST(EXTRACT(epoch FROM headway), 15 * 60)) / day_period_length(day_period("datetime")) wtp15,
        SUM(LEAST(EXTRACT(epoch FROM headway), 20 * 60)) / day_period_length(day_period("datetime")) wtp20,
        SUM(LEAST(EXTRACT(epoch FROM headway), 30 * 60)) / day_period_length(day_period("datetime")) wtp30
    FROM stat_headway_observed
        LEFT JOIN gtfs_trips USING (trip_id)
        LEFT JOIN stat_holidays h USING ("date")
    WHERE "date" >= "start"
            "date" < ("start" + "term")::DATE
    GROUP BY 
        route_id,
        direction_id,
        stop_id,
        4,
        5
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_wtp ("start" DATE)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        hours int,
        wtp5 int,
        wtp15 int,
        wtp30 int
    ) AS $$
    SELECT * FROM get_wtp(start_date, INTERVAL '1 MONTH' - INTERVAL '1 DAY')
    $$
LANGUAGE SQL STABLE;
