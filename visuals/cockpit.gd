extends Node3D

const Finish = preload("res://visuals/finish.gd")
const HeadMotion = preload("res://visuals/head_motion.gd")
const EYE := Vector3(-0.34, 1.33, 0.28)
const VIEW_ANGLES := Vector3(deg_to_rad(-3), 0, 0)
var head_motion = HeadMotion.new()
var car
var steering_wheel: Node3D
var camera: Camera3D
var speed_needle: Node3D
var rpm_needle: Node3D
var gear_label: Label3D
var shift_lights: Array[MeshInstance3D] = []
var led_on: StandardMaterial3D
var led_off: StandardMaterial3D

func _ready() -> void:
	var paint := material(Color(0.11, 0.25, 0.32), 0.3, 0.45)
	var rubber := Finish.grained(Color(0.032, 0.038, 0.043), 118)
	var dashboard := Finish.grained(Color(0.075, 0.083, 0.09), 415)
	var trim := material(Color(0.24, 0.27, 0.29), 0.65, 0.35)
	var silver := material(Color(0.57, 0.61, 0.64), 0.75, 0.3)
	var black := material(Color(0.008, 0.012, 0.015))
	box(self, Vector3(1.7, 0.40, 3.8), Vector3(0, 0.62, 0), paint)
	box(self, Vector3(1.65, 0.07, 1.5), Vector3(0, 0.88, -1.17), paint)
	Finish.panel(self, Vector3(1.64, 0.14, 0.50), Vector3(0, 0.94, -0.62), 0.065, dashboard)
	Finish.panel(self, Vector3(0.61, 0.265, 0.14), Vector3(-0.34, 1.10, -0.61), 0.075, rubber)
	box(self, Vector3(1.65, 0.065, 1.75), Vector3(0, 1.73, 0.475), dashboard)
	for side in [-1, 1]:
		box(self, Vector3(0.07, 0.24, 1.85), Vector3(side*0.81, 0.88, 0.36), dashboard)
		box(self, Vector3(0.04, 0.022, 1.6), Vector3(side*0.76, 1.015, 0.4), trim)
		beam(self, Vector3(side*0.80, 0.98, -0.76), Vector3(side*0.82, 1.73, -0.40), 0.024, rubber)
		box(self, Vector3(0.055, 0.7, 0.055), Vector3(side*0.79, 1.36, 1.0), rubber)
	var seam := material(Color(0.18, 0.25, 0.28))
	for side in [-1, 1]:
		box(self, Vector3(0.016, 0.005, 1.1), Vector3(side*0.52, 0.924, -1.17), paint)
	box(self, Vector3(1.5, 0.008, 0.008), Vector3(0, 0.99, -0.36), seam)
	# Cluster orientado para o piloto, atras do volante.
	speed_needle = dial(Vector3(-0.47, 1.11, -0.515), 240, "km/h", false)
	rpm_needle = dial(Vector3(-0.21, 1.11, -0.515), 8, "x1000", true)
	gear_label = label(self, "1", Vector3(-0.34, 1.055, -0.495), 38, 0.0011, Color(0.4, 1.0, 0.65))
	led_on = material(Color(0.3, 0.9, 0.45))
	led_on.emission_enabled = true
	led_on.emission = Color(0.2, 0.7, 0.3)
	led_off = material(Color(0.06, 0.12, 0.08))
	for i in 7:
		var led := cylinder(self, 0.006, 0.006, Vector3(-0.43+i*0.03, 1.235, -0.515), led_off)
		shift_lights.append(led)
	# Console e saidas de ar.
	Finish.panel(self, Vector3(0.27, 0.16, 0.12), Vector3(0.14, 1.025, -0.55), 0.032, trim)
	box(self, Vector3(0.23, 0.13, 0.13), Vector3(0.14, 1.025, -0.535), black)
	for i in 6:
		box(self, Vector3(0.21, 0.007, 0.015), Vector3(0.14, 0.976+i*0.02, -0.455), dashboard)
	box(self, Vector3(0.18, 0.34, 0.1), Vector3(0.14, 0.77, -0.49), dashboard)
	for i in 3:
		cylinder(self, 0.026, 0.022, Vector3(0.14, 0.87-i*0.085, -0.42), silver)
	box(self, Vector3(0.25, 0.16, 0.9), Vector3(0.16, 0.75, 0.1), rubber)
	beam(self, Vector3(0.16, 0.80, 0.0), Vector3(0.16, 0.97, -0.04), 0.014, silver)
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.033
	sphere.height = 0.066
	knob.mesh = sphere
	knob.material_override = rubber
	knob.position = Vector3(0.16, 0.97, -0.04)
	add_child(knob)
	steering_wheel = Node3D.new()
	steering_wheel.position = Vector3(-0.34, 1.035, -0.25)
	add_child(steering_wheel)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.155
	torus.outer_radius = 0.178
	torus.rings = 40
	torus.ring_segments = 10
	rim.mesh = torus
	rim.material_override = rubber
	rim.rotation.x = PI/2
	steering_wheel.add_child(rim)
	for angle in [-PI/2, PI/2, PI]:
		var spoke := box(steering_wheel, Vector3(0.035, 0.13, 0.015), Vector3(0, 0.085, 0.008).rotated(Vector3.FORWARD, angle), trim)
		spoke.rotation.z = -angle
	for side in [-1, 1]:
		Finish.panel(steering_wheel, Vector3(0.031, 0.09, 0.028), Vector3(side*0.161, 0.0, 0.015), 0.013, dashboard)
	cylinder(steering_wheel, 0.052, 0.025, Vector3(0, 0, 0.025), black)
	label(steering_wheel, "FPV", Vector3(0, 0, 0.045), 32, 0.0010, Color(0.8, 0.84, 0.86))
	box(steering_wheel, Vector3(0.012, 0.022, 0.018), Vector3(0, 0.166, 0.012), material(Color(0.9, 0.67, 0.12)))
	camera = Camera3D.new()
	camera.position = EYE
	camera.rotation = VIEW_ANGLES
	camera.near = 0.035
	camera.far = 650
	camera.fov = 65
	add_child(camera)
	camera.current = true

func _process(dt: float) -> void:
	if car == null:
		return
	head_motion.step(dt, car.feedback.local_g, car.angular_velocity.y, car.controls.camera_motion)
	camera.position = EYE+head_motion.offset
	camera.rotation = VIEW_ANGLES+head_motion.angles
	var speed: float = car.linear_velocity.length()*3.6
	speed_needle.rotation.z = lerp_angle(speed_needle.rotation.z, deg_to_rad(130.0-260.0*clampf(speed/240.0, 0, 1)), 1.0-exp(-16.0*dt))
	rpm_needle.rotation.z = lerp_angle(rpm_needle.rotation.z, deg_to_rad(130.0-260.0*clampf(car.gearbox.rpm/8000.0, 0, 1)), 1.0-exp(-20.0*dt))
	gear_label.text = "R" if car.controls.reverse else str(car.gearbox.gear)
	for i in shift_lights.size():
		shift_lights[i].material_override = led_on if car.gearbox.rpm > 4300+i*300 else led_off

func reset_view() -> void:
	head_motion.reset()
	camera.position = EYE
	camera.rotation = VIEW_ANGLES

func dial(at: Vector3, maximum: int, caption: String, red_zone: bool) -> Node3D:
	var group := Node3D.new()
	group.position = at
	add_child(group)
	cylinder(group, 0.113, 0.008, Vector3.ZERO, material(Color(0.35, 0.39, 0.42), 0.65, 0.35))
	cylinder(group, 0.105, 0.011, Vector3(0, 0, 0.004), material(Color(0.009, 0.015, 0.022)))
	for i in 25:
		var angle: float = deg_to_rad(130.0-260.0*i/24.0)
		var tick := box(group, Vector3(0.002, 0.011 if i%3 == 0 else 0.006, 0.002), Vector3(0, 0.092, 0.015).rotated(Vector3.BACK, angle), material(Color(0.9, 0.25, 0.16) if red_zone and i >= 19 else Color(0.8, 0.85, 0.86)))
		tick.rotation.z = angle
	for i in 5:
		var angle: float = deg_to_rad(130.0-260.0*i/4.0)
		label(group, str(roundi(maximum*i/4.0)), Vector3(0, 0.071, 0.018).rotated(Vector3.BACK, angle), 24, 0.00075, Color(0.85, 0.9, 0.9))
	label(group, caption, Vector3(0, -0.033, 0.018), 24, 0.0007, Color(0.55, 0.7, 0.75))
	var needle := Node3D.new()
	needle.rotation.z = deg_to_rad(130)
	group.add_child(needle)
	var needle_material := material(Color(0.96, 0.25, 0.12))
	needle_material.emission_enabled = true
	needle_material.emission = Color(0.65, 0.1, 0.04)
	box(needle, Vector3(0.0035, 0.083, 0.003), Vector3(0, 0.032, 0.025), needle_material)
	cylinder(group, 0.008, 0.008, Vector3(0, 0, 0.028), material(Color(0.65, 0.7, 0.72)))
	for item in group.find_children("*", "MeshInstance3D", true, false):
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return needle

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

static func box(parent: Node3D, dimensions: Vector3, at: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = surface
	node.position = at
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, radius: float, depth: float, at: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 40
	node.mesh = mesh
	node.material_override = surface
	node.position = at
	node.rotation.x = PI/2
	parent.add_child(node)
	return node

static func beam(parent: Node3D, start: Vector3, end: Vector3, radius: float, surface: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = surface
	node.position = (start+end)*0.5
	node.basis = Basis(Quaternion(Vector3.UP, (end-start).normalized()))
	parent.add_child(node)

static func label(parent: Node3D, text: String, at: Vector3, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = at
	node.font_size = font_size
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	node.shaded = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
