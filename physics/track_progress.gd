extends RefCounted

var points: PackedVector3Array
var distances := PackedFloat64Array()
var length: float = 0.0

func configure(route: PackedVector3Array) -> void:
	points = route
	distances = PackedFloat64Array([0.0])
	for i in points.size():
		distances.append(distances[-1]+points[i].distance_to(points[(i+1)%points.size()]))
	length = distances[-1]

func project(position: Vector3, expected_gate: int) -> float:
	# Restringe a busca ao trecho entre os checkpoints ja validados.
	# Uma curva proxima ou um retorno nao faz o delta saltar de trecho.
	var start: int = int(posmod(expected_gate-1, 8)*points.size()/8.0)
	var end: int = int((expected_gate if expected_gate > 0 else 8)*points.size()/8.0)
	var nearest: float = INF
	var result: float = distances[start]
	for i in range(start, end):
		var segment: Vector3 = points[(i+1)%points.size()]-points[i]
		var fraction: float = clampf((position-points[i]).dot(segment)/maxf(segment.length_squared(), 0.0001), 0, 1)
		var error: float = position.distance_squared_to(points[i]+segment*fraction)
		if error < nearest:
			nearest = error
			result = lerpf(distances[i], distances[i+1], fraction)
	return result
