WITH min AS (SELECT 5 * 60 AS a, 15 * 60 as b, 30 * 60 as c)
SELECT
    route_id,
    direction_id,
    stop_id,
    period,
    weekend,
    SUM(CASE WHEN call_epoch - lag_epoch > min.a
        THEN min.a
        ELSE call_epoch - lag_epoch
    END) / day_period_length(period) wtp5,
    SUM(CASE WHEN call_epoch - lag_epoch > min.b
        THEN min.b
        ELSE call_epoch - lag_epoch
    END) / day_period_length(period) wtp15,
    SUM(CASE WHEN call_epoch - lag_epoch > min.c
        THEN min.c
        ELSE call_epoch - lag_epoch
    END) / day_period_length(period) wtp30
FROM (
    SELECT
        *,
        EXTRACT(EPOCH FROM call_time) call_epoch,
        day_period(call_time::time) period,
        EXTRACT(isodow FROM call_time) > 5 weekend,
        call_time::date AS date,
        EXTRACT(
            EPOCH FROM lag(call_time)
            OVER (PARTITION BY route_id, direction_id, stop_id ORDER BY call_time ASC)
        ) lag_epoch
    FROM calls
) x, min
GROUP BY 
    route_id,
    direction_id,
    stop_id,
    period,
    weekend;
