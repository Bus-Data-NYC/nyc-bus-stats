/*
 * Create index to route / stop / direction, useful when route and stop are known
 * but not direction (e.g. in rt.vehicle_positions)
 * TODO: workaround for when pickup_type is always 0
*/
create materialized view stat.stop_direction as
select distinct
    route_id,
    stop_id,
    direction_id,
    count(*)
from gtfs.trips
    left join gtfs.stop_times using (feed_index, trip_id)
where pickup_type = 0
group by 1, 2, 3;

create unique index on stat.stop_direction ( route_id, stop_id );

