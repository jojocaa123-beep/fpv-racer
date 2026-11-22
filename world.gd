extends Node3D

const Track = preload("res://physics/track.gd")
const Vehicle = preload("res://physics/car.gd")
const Controls = preload("res://ui/controls.gd")
const LapModel = preload("res://physics/laps.gd")
const Sound = preload("res://sound.gd")
var car
var controls
var laps = LapModel.new()
var samples: PackedVector3Array
var clock: float = 0.0
var offroad_time: float = 0.0

func _ready() -> void:
	process_physics_priority = 50
	Engine.max_fps = 60
	samples = Track.sample()
	laps.configure(samples)
	var record := ConfigFile.new()
	if record.load("user://records.cfg") == OK:
		var best: float = float(record.get_value("practice", "layout1", 0.0))
		laps.best_time = best if is_finite(best) and best > 0 else 0.0
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.55, 0.69, 0.78)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75, 0.8, 0.9)
	settings.ambient_light_energy = 0.65
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var grass := _material(Color(0.24, 0.34, 0.20))
	var road := _material(Color(0.14, 0.16, 0.18))
	road.cull_mode = BaseMaterial3D.CULL_DISABLED
	var white := _material(Color(0.86, 0.87, 0.79))
	var red := _material(Color(0.64, 0.16, 0.11))
	_static_box("Grass", Vector3(400, 0.2, 400), Vector3(0, -0.1, 0), grass, 0.58)
	_make_road(road, white, red)
	for i in 18:
		var a: float = i * TAU / 18.0
		_static_box("Reference marker", Vector3(2, 6, 2), Vector3(sin(a)*155, 3, cos(a)*145), white if i%2 == 0 else red, 0.58)
	controls = Controls.new()
	controls.world = self
	add_child(controls)
	car = Vehicle.new()
	car.controls = controls
	var forward: Vector3 = Track.tangent(samples, 0)
	car.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), samples[0]-forward*10+Vector3.UP*0.22)
	add_child(car)
	controls.car = car
	var audio = Sound.new()
	audio.car = car
	audio.controls = controls
	add_child(audio)

func _physics_process(dt: float) -> void:
	if car == null:
		return
	clock += dt
	offroad_time = offroad_time + dt if car.offroad_count >= 3 else 0.0
	var invalid: String = "FORA DA PISTA" if offroad_time > 0.5 else ""
	if car.global_basis.y.dot(Vector3.UP) < 0.2:
		invalid = "CARRO CAPOTADO"
	var old_best: float = laps.best_time
	laps.step(car.global_position, clock, invalid)
	if laps.best_time != old_best:
		var record := ConfigFile.new()
		record.set_value("practice", "layout1", laps.best_time)
		record.save("user://records.cfg")

func restart() -> void:
	car.reset_car()
	laps.reset_attempt()
	offroad_time = 0.0

func _make_road(material: Material, white: Material, red: Material) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var edges: Array[Transform3D] = []
	var colors: Array[int] = []
	for i in samples.size():
		var forward: Vector3 = Track.tangent(samples, i)
		var right: Vector3 = forward.cross(Vector3.UP)
		vertices.append(samples[i]-right*6+Vector3.UP*0.015)
		vertices.append(samples[i]+right*6+Vector3.UP*0.015)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		var j: int = ((i+1) % samples.size())*2
		indices.append_array(PackedInt32Array([i*2, j, i*2+1, i*2+1, j, j+1]))
		if i%2 == 0:
			for side in [-1, 1]:
				edges.append(Transform3D(Basis.looking_at(forward, Vector3.UP), samples[i]+right*5.85*side+Vector3.UP*0.025))
				colors.append(0 if i%4 == 0 else 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var asphalt := StaticBody3D.new()
	asphalt.name = "Asphalt"
	asphalt.set_meta("grip", 1.0)
	add_child(asphalt)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	asphalt.add_child(visual)
	var collider := CollisionShape3D.new()
	collider.shape = mesh.create_trimesh_shape()
	collider.shape.backface_collision = true
	asphalt.add_child(collider)
	for group in 2:
		var batch := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var block := BoxMesh.new()
		block.size = Vector3(0.22, 0.015, 1.7)
		multi.mesh = block
		multi.instance_count = colors.count(group)
		var index: int = 0
		for i in edges.size():
			if colors[i] == group:
				multi.set_instance_transform(index, edges[i])
				index += 1
		batch.multimesh = multi
		batch.material_override = white if group == 0 else red
		add_child(batch)
	var line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(11, 0.015, 0.5)
	line.mesh = line_mesh
	line.material_override = white
	line.transform = Transform3D(Basis.looking_at(Track.tangent(samples, 0), Vector3.UP), samples[0]+Vector3.UP*0.03)
	add_child(line)

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

func _static_box(label: String, size: Vector3, location: Vector3, material: Material, grip: float) -> void:
	var node := StaticBody3D.new()
	node.name = label
	node.position = location
	node.set_meta("grip", grip)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	node.add_child(collider)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	node.add_child(visual)
	add_child(node)
