extends Node3D

const Track = preload("res://physics/track.gd")
const Vehicle = preload("res://physics/car.gd")
const Controls = preload("res://ui/controls.gd")
const LapModel = preload("res://physics/laps.gd")
const Sound = preload("res://sound.gd")
const Ghost = preload("res://physics/ghost.gd")
const Navigation = preload("res://physics/track_guide.gd")
const Progress = preload("res://physics/track_progress.gd")
const GhostVisual = preload("res://visuals/ghost_car.gd")
const TireMarks = preload("res://visuals/tire_marks.gd")
const CircuitVisuals = preload("res://visuals/circuit.gd")
var ghost = Ghost.new()
var progress = Progress.new()
var navigation = Navigation.new()
var track_distance: float = 0.0
var ghost_visual: Node3D
var previous_car_pose := Transform3D.IDENTITY
var delta: float = 0.0
var delta_ready: bool = false
var ghost_saved_at: float = -100.0
var tire_marks: MultiMeshInstance3D
var sun: DirectionalLight3D
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
	progress.configure(samples)
	navigation.configure(samples, progress.distances)
	ghost.track_length = progress.length
	ghost.load_best("user://ghost-v1.json")
	var record := ConfigFile.new()
	if record.load("user://records.cfg") == OK:
		var best: float = float(record.get_value("practice", "layout1", 0.0))
		laps.best_time = best if is_finite(best) and best > 0 else 0.0
	if ghost.has_reference() and (laps.best_time <= 0 or ghost.best_time < laps.best_time):
		laps.best_time = ghost.best_time
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.15, 0.34, 0.58)
	sky_material.sky_horizon_color = Color(0.69, 0.79, 0.84)
	sky_material.ground_horizon_color = Color(0.64, 0.72, 0.72)
	sky_material.ground_bottom_color = Color(0.18, 0.23, 0.17)
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75, 0.8, 0.9)
	settings.ambient_light_energy = 0.6
	settings.fog_enabled = true
	settings.fog_light_color = Color(0.65, 0.74, 0.78)
	settings.fog_density = 0.0015
	env.environment = settings
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	var grass := CircuitVisuals.surface(Color(0.25, 0.34, 0.18), true)
	var road := CircuitVisuals.surface(Color(0.18, 0.19, 0.2), false)
	road.cull_mode = BaseMaterial3D.CULL_DISABLED
	var white := _material(Color(0.86, 0.87, 0.79))
	var red := _material(Color(0.64, 0.16, 0.11))
	_static_box("Grass", Vector3(1600, 0.2, 1600), Vector3(0, -0.1, 0), grass, 0.58)
	_make_road(road, white, red)
	var scenery := CircuitVisuals.new()
	scenery.samples = samples
	add_child(scenery)
	controls = Controls.new()
	controls.world = self
	add_child(controls)
	car = Vehicle.new()
	car.controls = controls
	var forward: Vector3 = Track.tangent(samples, 0)
	car.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), samples[0]-forward*10+Vector3.UP*0.22)
	add_child(car)
	tire_marks = TireMarks.new()
	tire_marks.car = car
	add_child(tire_marks)
	ghost_visual = GhostVisual.new()
	add_child(ghost_visual)
	previous_car_pose = car.global_transform
	controls.car = car
	var audio = Sound.new()
	audio.car = car
	audio.controls = controls
	add_child(audio)
	apply_graphics_quality()

func apply_graphics_quality() -> void:
	var quality: int = clampi(controls.graphics_quality, 0, 2)
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = [0.75, 0.85, 1.0][quality]
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	sun.shadow_enabled = quality > 0
	sun.directional_shadow_max_distance = 70.0 if quality == 1 else 110.0

func _physics_process(dt: float) -> void:
	if car == null:
		return
	clock += dt
	offroad_time = offroad_time + dt if car.offroad_count >= 3 else 0.0
	var invalid: String = "FORA DA PISTA" if offroad_time > 0.5 else ""
	if car.global_basis.y.dot(Vector3.UP) < 0.2:
		invalid = "CARRO CAPOTADO"
	var old_best: float = laps.best_time
	var old_completed: int = laps.completed
	laps.step(car.global_position, clock, invalid)
	track_distance = progress.project(car.global_position, laps.expected)
	if laps.crossing_gate == 0:
		var fraction: float = clampf((laps.crossing_time-(clock-dt))/dt, 0, 1)
		var crossing_pose: Transform3D = previous_car_pose.interpolate_with(car.global_transform, fraction)
		if laps.completed != old_completed and ghost.finish(laps.last_valid, laps.last_time, crossing_pose, laps.last_sectors):
			if ghost.save_best("user://ghost-v1.json") == OK: ghost_saved_at = clock
		ghost.begin(crossing_pose)
	if laps.running and laps.valid:
		ghost.sample(clock-laps.started_at, car.global_transform, track_distance)
	else:
		ghost.cancel_recording()
	delta_ready = laps.running and laps.valid and ghost.has_reference()
	delta = clock-laps.started_at-ghost.time_at_distance(track_distance) if delta_ready else 0.0
	ghost_visual.replay(ghost, clock-laps.started_at, car.global_position, controls.ghost_enabled and laps.running and laps.valid)
	previous_car_pose = car.global_transform
	if laps.best_time != old_best:
		var record := ConfigFile.new()
		record.set_value("practice", "layout1", laps.best_time)
		record.save("user://records.cfg")

func restart() -> void:
	car.reset_car()
	tire_marks.break_trails()
	laps.reset_attempt()
	ghost.cancel_recording()
	ghost_visual.visible = false
	delta_ready = false
	previous_car_pose = car.global_transform
	offroad_time = 0.0

func _make_road(material: Material, white: Material, red: Material) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var path_distance: float = 0.0
	var edges: Array[Transform3D] = []
	var colors: Array[int] = []
	for i in samples.size():
		if i > 0: path_distance += samples[i].distance_to(samples[i-1])
		var forward: Vector3 = Track.tangent(samples, i)
		var right: Vector3 = forward.cross(Vector3.UP)
		vertices.append(samples[i]-right*6+Vector3.UP*0.015)
		vertices.append(samples[i]+right*6+Vector3.UP*0.015)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0, path_distance/4.0))
		uvs.append(Vector2(3, path_distance/4.0))
		var j: int = ((i+1) % samples.size())*2
		indices.append_array(PackedInt32Array([i*2, j, i*2+1, i*2+1, j, j+1]))
		var next: int = (i+1)%samples.size()
		var segment: Vector3 = samples[next]-samples[i]
		for side in [-1, 1]:
			edges.append(Transform3D(Basis.looking_at(segment.normalized(), Vector3.UP)*Basis.from_scale(Vector3(1, 1, segment.length()+0.08)), (samples[i]+samples[next])*0.5+right*6.2*side+Vector3.UP*0.03))
			colors.append(i%2)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
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
		block.size = Vector3(0.65, 0.025, 1)
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
