select a.feed_index, route_id, direction_id, lead_stop_id, lead.stop_name lead_stop_name, lag_stop_id, lag.stop_name as lag_stop_name, round(spacing, 1) as spacing
from (
    select feed_index, route_id, direction_id, lead_stop_id, lag_stop_id, spacing, rank() OVER (space) AS rank
    from stat.stopdist
    where spacing > 30 and not (lag_stop_id in ('901473', '903233', '903169', '903232', '903209'))
    WINDOW space AS (PARTITION BY feed_index, route_id, direction_id ORDER BY spacing ASC)
  ) a
  left join gtfs.stops as lead on (lead.feed_index = a.feed_index and lead.stop_id = lead_stop_id)
  left join gtfs.stops as lag on (lag.feed_index = a.feed_index and lag.stop_id = lag_stop_id)
WHERE rank = 1;