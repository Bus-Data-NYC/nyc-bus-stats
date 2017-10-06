-- Counts of scheduled buses, observed buses, per route stop and direction

CREATE OR REPLACE FUNCTION get_service ("start" DATE, term INTERVAL)
    RETURNS TABLE(
        start date,
        term interval,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        hours int,
        scheduled int,
        observed int
    ) AS $$
    SELECT
        "start" AS start,
        term,
        route_id,
        direction_id,
        stop_id,
        (EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL)::int AS weekend,
        day_period_hour(hour) AS period,
        SUM(1),
        SUM(sh.pickups),
        COALESCE(SUM(a.observed), 0)
    FROM stat_headway_scheduled AS sh
        LEFT JOIN calls USING (date, trip_id, stop_id)
        LEFT JOIN adherence AS a USING 
        LEFT JOIN ref_holidays h USING (date)
        JOIN ref_rds USING (rds_index)
    WHERE sh.date >= "start"
        AND sh.date < ("start" + "term")::DATE
        AND calls.source = 'I'
    GROUP BY rds_index,
        EXTRACT(isodow FROM "datetime") > 5 OR h.holiday IS NOT NULL,
        day_period_hour(hour)
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_service ("start" DATE)
    RETURNS TABLE(
        month date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        hours int,
        scheduled int,
        observed int
    ) AS $$
    SELECT * FROM get_service("start", INTERVAL '1 MONTH')
    $$
LANGUAGE SQL STABLE;
