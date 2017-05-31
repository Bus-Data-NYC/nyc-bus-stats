SELECT DISTINCT
    t.route_id,
    shape.shape_id,
    service_id, 
    ROUND(ST_Length(shape.Geometry, 1) / ST_Distance(StartPoint(shape.Geometry), EndPoint(shape.Geometry), 1), 2) crow_ratio, 
    ROUND(ST_Length(shape.Geometry, 1) / ST_Length(simp.Geometry, 1), 2) simple_ratio 
FROM OGRGeoJSON shape 
    LEFT JOIN '$(word 2,$(^D))'.trips t ON (t.shape_id = shape.id) 
SORT BY crow_ratio DESC
