extends Node3D

const Shape = preload("res://visuals/cockpit.gd")
const Track = preload("res://physics/track.gd")
var samples: PackedVector3Array

func _ready() -> void:
	_rails()
	_landscape()
	_markers()
	_gantry()
	_edge_lines()
	_paddock()

static func surface(color: Color, grass: bool) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color.WHITE
	result.roughness = 1.0
	var noise := FastNoiseLite.new()
	noise.seed = 2244 if grass else 8637
	noise.frequency = 0.025 if grass else 0.65
	var grain := RandomNumberGenerator.new()
	grain.seed = 318 if grass else 639
	var picture := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var amount: float = noise.get_noise_2d(x, y)*(0.07 if grass else 0.025)+grain.randf_range(-0.018, 0.018)
			picture.set_pixel(x, y, Color(color.r+amount, color.g+amount, color.b+amount*0.65))
	picture.generate_mipmaps()
	result.albedo_texture = ImageTexture.create_from_image(picture)
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if grass:
		result.uv1_triplanar = true
		result.uv1_scale = Vector3.ONE*0.18
	return result

func _rails() -> void:
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var metal := Shape.material(Color(0.46, 0.5, 0.53), 0.6, 0.55)
	for i in range(0, samples.size(), 3):
		var j: int = (i+3)%samples.size()
		for side in [-1, 1]:
			var a: Vector3 = samples[i]+Track.tangent(samples, i).cross(Vector3.UP)*8.5*side
			var b: Vector3 = samples[j]+Track.tangent(samples, j).cross(Vector3.UP)*8.5*side
			var rail_basis := Basis.looking_at((b-a).normalized(), Vector3.UP)
			var length: float = a.distance_to(b)
			for level in [0.48, 0.79]:
				rails.append(Transform3D(rail_basis*Basis.from_scale(Vector3(1, 1, length+0.1)), (a+b)*0.5+Vector3.UP*level))
			posts.append(Transform3D(rail_basis, a+Vector3.UP*0.45))
			var barrier := StaticBody3D.new()
			barrier.transform = Transform3D(rail_basis, (a+b)*0.5+Vector3.UP*0.48)
			barrier.set_meta("grip", 0.4)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.14, 0.88, length+0.1)
			collision.shape = shape
			barrier.add_child(collision)
			add_child(barrier)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.12, 0.16, 1)
	_batch(rail_mesh, metal, rails)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.12, 0.9, 0.12)
	_batch(post_mesh, metal, posts)

func _landscape() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 56291
	var hill_surface := Shape.material(Color(0.21, 0.29, 0.18))
	for i in 14:
		var angle: float = i*TAU/14.0
		var hill := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = random.randf_range(45, 80)
		mesh.height = mesh.radius*1.2
		mesh.radial_segments = 40
		mesh.rings = 14
		hill.mesh = mesh
		hill.material_override = hill_surface
		hill.position = Vector3(sin(angle)*310, -12, cos(angle)*310)
		hill.scale = Vector3(1.9, 1.0, 1.5)
		add_child(hill)
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var foliage_colors := PackedColorArray()
	for i in range(0, samples.size(), 7):
		for side in [-1, 1]:
			var at: Vector3 = samples[i]+Track.tangent(samples, i).cross(Vector3.UP)*side*random.randf_range(22, 38)
			if _road_clearance(at) < 15.0:
				continue
			var scale_value: float = random.randf_range(0.75, 1.35)
			trunks.append(Transform3D(Basis.from_scale(Vector3.ONE*scale_value), at+Vector3.UP*1.8*scale_value))
			for layer in 3:
				var offset := Vector3(random.randf_range(-1.1, 1.1), 3.7+layer*0.8, random.randf_range(-0.9, 0.9))*scale_value
				crowns.append(Transform3D(Basis.from_scale(Vector3(1.0-layer*0.14, 1.0, 0.9)*scale_value), at+offset))
				foliage_colors.append(Color(0.16, 0.25, 0.11).lightened(random.randf_range(-0.15, 0.2)))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 3.6
	trunk_mesh.radial_segments = 6
	_batch(trunk_mesh, Shape.material(Color(0.21, 0.16, 0.11)), trunks)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.2
	crown_mesh.height = 3.6
	crown_mesh.radial_segments = 16
	crown_mesh.rings = 8
	var leaves := Shape.material(Color.WHITE)
	leaves.vertex_color_use_as_albedo = true
	_batch(crown_mesh, leaves, crowns, foliage_colors)

func _markers() -> void:
	var distance := PackedFloat32Array([0.0])
	for i in range(1, samples.size()):
		distance.append(distance[-1]+samples[i].distance_to(samples[i-1]))
	var total: float = distance[-1]+samples[-1].distance_to(samples[0])
	var white := Shape.material(Color(0.9, 0.91, 0.86))
	var black := Shape.material(Color(0.045, 0.055, 0.06))
	for corner in [18, 54, 90, 126, 162]:
		for before in [100, 50]:
			var target: float = fposmod(distance[corner]-before, total)
			var index: int = 0
			for i in distance.size():
				if absf(distance[i]-target) < absf(distance[index]-target): index = i
			var forward: Vector3 = Track.tangent(samples, index)
			var board := Node3D.new()
			board.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), samples[index]+forward.cross(Vector3.UP)*7.1)
			add_child(board)
			Shape.box(board, Vector3(0.07, 1.5, 0.07), Vector3(0, 0.75, 0), black)
			Shape.box(board, Vector3(1.1, 0.8, 0.08), Vector3(0, 1.5, 0), white)
			Shape.label(board, str(before), Vector3(0, 1.5, 0.048), 64, 0.007, Color(0.03, 0.045, 0.05))

func _gantry() -> void:
	var gate := Node3D.new()
	gate.transform = Transform3D(Basis.looking_at(Track.tangent(samples, 0), Vector3.UP), samples[0])
	add_child(gate)
	var steel := Shape.material(Color(0.3, 0.34, 0.37), 0.55, 0.6)
	var dark := Shape.material(Color(0.035, 0.07, 0.09))
	for side in [-1, 1]:
		Shape.box(gate, Vector3(0.18, 5, 0.18), Vector3(side*7.3, 2.5, 0), steel)
	Shape.box(gate, Vector3(14.8, 0.22, 0.22), Vector3(0, 5, 0), steel)
	Shape.box(gate, Vector3(13, 0.82, 0.10), Vector3(0, 4.6, 0), dark)
	Shape.label(gate, "FPV  /  CLUB CIRCUIT", Vector3(0, 4.6, 0.065), 72, 0.011, Color(0.92, 0.95, 0.9))

func _batch(mesh: Mesh, surface_material: Material, transforms: Array[Transform3D], colors: PackedColorArray = PackedColorArray()) -> void:
	var node := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
		if not colors.is_empty(): multi.set_instance_color(i, colors[i])
	node.multimesh = multi
	node.material_override = surface_material
	add_child(node)

func _road_clearance(at: Vector3) -> float:
	var nearest: float = INF
	for i in samples.size():
		var segment: Vector3 = samples[(i+1)%samples.size()]-samples[i]
		var fraction: float = clampf((at-samples[i]).dot(segment)/maxf(0.001, segment.length_squared()), 0, 1)
		nearest = minf(nearest, at.distance_to(samples[i]+segment*fraction))
	return nearest

func _edge_lines() -> void:
	var transforms: Array[Transform3D] = []
	for i in samples.size():
		var next: int = (i+1)%samples.size()
		var forward: Vector3 = samples[next]-samples[i]
		var right: Vector3 = Track.tangent(samples, i).cross(Vector3.UP)
		for side in [-1, 1]:
			transforms.append(Transform3D(Basis.looking_at(forward.normalized(), Vector3.UP)*Basis.from_scale(Vector3(1, 1, forward.length()+0.06)), (samples[i]+samples[next])*0.5+right*5.78*side+Vector3.UP*0.023))
	var paint := BoxMesh.new()
	paint.size = Vector3(0.10, 0.001, 1)
	_batch(paint, Shape.material(Color(0.72, 0.73, 0.67)), transforms)

func _paddock() -> void:
	var concrete := Shape.material(Color(0.40, 0.42, 0.40))
	var roof := Shape.material(Color(0.12, 0.17, 0.19), 0.3, 0.7)
	var glass := Shape.material(Color(0.12, 0.24, 0.29), 0.3, 0.22)
	for index in [8, 65, 150]:
		var forward: Vector3 = Track.tangent(samples, index)
		var position_on_grass: Vector3 = samples[index]+forward.cross(Vector3.UP)*32
		if _road_clearance(position_on_grass) < 24: continue
		var building := Node3D.new()
		building.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), position_on_grass)
		add_child(building)
		Shape.box(building, Vector3(12, 3.4, 6), Vector3(0, 1.7, 0), concrete)
		Shape.box(building, Vector3(12.6, 0.18, 6.6), Vector3(0, 3.5, 0), roof)
		for bay in 4:
			Shape.box(building, Vector3(2.3, 2.5, 0.06), Vector3(-4.5+bay*3, 1.3, 3.04), roof)
			Shape.box(building, Vector3(2.2, 0.42, 0.07), Vector3(-4.5+bay*3, 2.8, 3.08), glass)
