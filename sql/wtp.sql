-- Wait time probabilities
-- wtp_5, wtp_10, wtp_15, wtp_20, wtp_30: the percentage chance of waiting less than 5, 10, 15, 20, or 30 minutes when arriving at a bus stop at random during high frequency scheduled service
-- hours: the number of hours measured (during high frequency scheduled service)
-- Calculated with the observed headways. We calculate the fraction of a period less than x minutes before a call, then divide by the total number of minutes per period

CREATE OR REPLACE FUNCTION get_wtp ("start" DATE, term INTERVAL)
    RETURNS TABLE(
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        calls int,
        wtp_5 numeric(4, 2),
        wtp_10 numeric(4, 2),
        wtp_15 numeric(4, 2),
        wtp_20 numeric(4, 2),
        wtp_30 numeric(4, 2)
    ) AS $$
    SELECT
        route_id,
        direction_id,
        stop_id,
        (EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL)::int AS weekend,
        period,
        COUNT(*)::int AS calls,
        (SUM(LEAST(EXTRACT(epoch FROM headway) / 60,  5)) / day_period_length(period) * 60)::numeric AS wtp_5,
        (SUM(LEAST(EXTRACT(epoch FROM headway) / 60, 10)) / day_period_length(period) * 60)::numeric AS wtp_10,
        (SUM(LEAST(EXTRACT(epoch FROM headway) / 60, 15)) / day_period_length(period) * 60)::numeric AS wtp_15,
        (SUM(LEAST(EXTRACT(epoch FROM headway) / 60, 20)) / day_period_length(period) * 60)::numeric AS wtp_20,
        (SUM(LEAST(EXTRACT(epoch FROM headway) / 60, 30)) / day_period_length(period) * 60)::numeric AS wtp_30
    FROM stat_headway_observed
        LEFT JOIN gtfs.trips USING (trip_id)
        LEFT JOIN stat_holidays h USING (date)
    WHERE date >= "start"
        AND date < ("start" + "term")::DATE
    GROUP BY 
        route_id,
        direction_id,
        stop_id,
        EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL,
        period
    $$
LANGUAGE SQL STABLE;
