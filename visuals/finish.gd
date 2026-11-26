extends RefCounted

static func grained(color: Color, seed_value: int) -> StandardMaterial3D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for y in 128:
		for x in 128:
			var grain: float = random.randf_range(-0.009, 0.009)
			image.set_pixel(x, y, Color(color.r+grain, color.g+grain, color.b+grain))
	image.generate_mipmaps()
	var surface := StandardMaterial3D.new()
	surface.albedo_texture = ImageTexture.create_from_image(image)
	surface.roughness = 0.9
	surface.uv1_triplanar = true
	surface.uv1_scale = Vector3.ONE*5.0
	return surface

static func panel(parent: Node3D, size: Vector3, at: Vector3, radius: float, surface: Material) -> MeshInstance3D:
	var outline := PackedVector2Array()
	var r: float = minf(radius, minf(size.x, size.y)*0.49)
	for corner in 4:
		var angle: float = -PI/2+corner*PI/2
		var center := Vector2((size.x*0.5-r)*(1 if corner in [0, 1] else -1), (size.y*0.5-r)*(-1 if corner in [0, 3] else 1))
		for i in 7:
			var a: float = angle+i*PI/12
			outline.append(center+Vector2(cos(a), sin(a))*r)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		for point in [Vector3(0, 0, size.z*0.5), Vector3(b.x, b.y, size.z*0.5), Vector3(a.x, a.y, size.z*0.5), Vector3(0, 0, -size.z*0.5), Vector3(a.x, a.y, -size.z*0.5), Vector3(b.x, b.y, -size.z*0.5), Vector3(a.x, a.y, -size.z*0.5), Vector3(a.x, a.y, size.z*0.5), Vector3(b.x, b.y, size.z*0.5), Vector3(a.x, a.y, -size.z*0.5), Vector3(b.x, b.y, size.z*0.5), Vector3(b.x, b.y, -size.z*0.5)]:
			tool.add_vertex(point)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = surface
	node.position = at
	parent.add_child(node)
	return node
