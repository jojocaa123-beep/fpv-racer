extends RefCounted

static func sample() -> PackedVector3Array:
	var nodes := PackedVector3Array([
		Vector3(-65, 0, -85), Vector3(45, 0, -85), Vector3(90, 0, -55),
		Vector3(95, 0, 15), Vector3(65, 0, 75), Vector3(10, 0, 90),
		Vector3(-30, 0, 55), Vector3(-75, 0, 65), Vector3(-100, 0, 20), Vector3(-95, 0, -35)
	])
	var result := PackedVector3Array()
	for i in nodes.size():
		var a: Vector3 = nodes[posmod(i - 1, nodes.size())]
		var b: Vector3 = nodes[i]
		var c: Vector3 = nodes[(i + 1) % nodes.size()]
		var d: Vector3 = nodes[(i + 2) % nodes.size()]
		for s in 18:
			var t: float = s / 18.0
			result.append(0.5 * (2*b + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
	return result

static func tangent(points: PackedVector3Array, i: int) -> Vector3:
	return (points[(i + 1) % points.size()] - points[posmod(i - 1, points.size())]).normalized()
