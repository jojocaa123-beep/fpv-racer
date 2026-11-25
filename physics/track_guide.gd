extends RefCounted

const Track = preload("res://physics/track.gd")
var length: float = 0.0
var corners: Array[Dictionary] = []
var map_route := PackedVector2Array()
var map_center := Vector2.ZERO
var map_span: float = 1.0

func configure(points: PackedVector3Array, distances: PackedFloat64Array) -> void:
	length = distances[-1]
	corners.clear()
	map_route.clear()
	var low := Vector2(points[0].x, points[0].z)
	var high := low
	var curvature := PackedFloat64Array()
	for i in points.size():
		low = low.min(Vector2(points[i].x, points[i].z))
		high = high.max(Vector2(points[i].x, points[i].z))
		var before: int = posmod(i-3, points.size())
		var after: int = (i+3)%points.size()
		var span: float = fposmod(distances[after]-distances[before], length)
		curvature.append(Track.tangent(points, before).signed_angle_to(Track.tangent(points, after), Vector3.UP)/maxf(span, 1.0))
	map_center = (low+high)*0.5
	map_span = maxf(1, maxf(high.x-low.x, high.y-low.y))
	for point in points: map_route.append(map_position(point))
	map_route.append(map_route[0])
	for i in points.size():
		var peak: bool = absf(curvature[i]) >= 0.0125
		for offset in range(-4, 5):
			if absf(curvature[posmod(i+offset, points.size())]) > absf(curvature[i])+0.000001: peak = false
		if not peak: continue
		if not corners.is_empty() and distances[i]-float(corners[-1].distance) < 30:
			if absf(curvature[i]) > float(corners[-1].strength)+0.000001: corners.remove_at(corners.size()-1)
			else: continue
		corners.append({"distance": distances[i], "side": 1 if curvature[i] < 0 else -1, "strength": absf(curvature[i])})
	if corners.size() > 1 and length-float(corners[-1].distance)+float(corners[0].distance) < 30:
		corners.remove_at(0 if float(corners[-1].strength) > float(corners[0].strength)+0.000001 else corners.size()-1)

func map_position(position: Vector3) -> Vector2:
	return (Vector2(position.x, position.z)-map_center)/map_span

func next_turn(distance: float) -> Dictionary:
	var remaining: float = INF
	var side: int = 0
	for corner in corners:
		var ahead: float = fposmod(float(corner.distance)+12.0-distance, length)
		if ahead < remaining:
			remaining = ahead
			side = int(corner.side)
	return {"side": side if remaining <= 162.0 else 0, "meters": maxf(0, remaining-12.0)}
