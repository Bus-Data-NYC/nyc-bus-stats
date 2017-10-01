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
        EXTRACT(isodow FROM "datetime") > 5 OR h.holiday IS NOT NULL AS weekend,
        day_period_hour(hour) AS period,
        SUM(1),
        SUM(sh.pickups),
        COALESCE(SUM(a.observed), 0)
    FROM schedule_hours AS sh
        LEFT JOIN adherence AS a USING (date, route_id, direction_id, stop_id, hour)
        LEFT JOIN ref_holidays h USING (date)
        JOIN ref_rds USING (rds_index)
    WHERE sh.date >= "start"
        AND sh.date < "start" + "term"
        AND sh.pickups > 0
        AND NOT exception
    GROUP BY rds_index,
        weekend,
        period
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
