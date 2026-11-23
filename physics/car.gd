extends RigidBody3D

const Driving = preload("res://physics/driving_math.gd")
const Gearbox = preload("res://physics/powertrain.gd")
const Feedback = preload("res://physics/feedback.gd")
const Cockpit = preload("res://visuals/cockpit.gd")
const RADIUS: float = 0.32
const REST: float = 0.38
const INERTIA: float = 1.1
const MOUNTS := [Vector3(-0.76, 0.60, -1.2), Vector3(0.76, 0.60, -1.2), Vector3(-0.76, 0.60, 1.2), Vector3(0.76, 0.60, 1.2)]
var controls
var gearbox = Gearbox.new()
var feedback = Feedback.new()
var wheel_slips: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var cockpit: Node3D
var grounded: Array[bool] = [false, false, false, false]
var omega: Array[float] = [0.0, 0.0, 0.0, 0.0]
var road_speed: Array[float] = [0.0, 0.0, 0.0, 0.0]
var compression: Array[float] = [0.0, 0.0, 0.0, 0.0]
var loads: Array[float] = [0.0, 0.0, 0.0, 0.0]
var grips: Array[float] = [1.0, 1.0, 1.0, 1.0]
var tc_scales: Array[float] = [1.0, 1.0, 1.0, 1.0]
var abs_scales: Array[float] = [1.0, 1.0, 1.0, 1.0]
var points: Array[Vector3] = []
var normals: Array[Vector3] = []
var rays: Array[PhysicsRayQueryParameters3D] = []
var wheels: Array[Node3D] = []
var wheel_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var grounded_count: int = 0
var offroad_count: int = 0
var tc_active: bool = false
var abs_active: bool = false
var max_slip: float = 0.0
var spawn_pose: Transform3D
var camera: Camera3D
var steering_wheel: Node3D

func _ready() -> void:
	mass = 1200.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.48, 0)
	linear_damp = 0.015
	angular_damp = 0.15
	continuous_cd = true
	can_sleep = false
	collision_layer = 2
	collision_mask = 1
	spawn_pose = global_transform
	_shape(Vector3(1.7, 0.45, 3.8), Vector3(0, 0.63, 0))
	_shape(Vector3(1.6, 0.8, 1.8), Vector3(0, 1.24, 0.35))
	cockpit = Cockpit.new()
	cockpit.car = self
	add_child(cockpit)
	steering_wheel = cockpit.steering_wheel
	camera = cockpit.camera
	var dark := _material(Color(0.025, 0.035, 0.045))
	for i in 4:
		points.append(Vector3.ZERO)
		normals.append(Vector3.UP)
		var ray := PhysicsRayQueryParameters3D.new()
		ray.collision_mask = 1
		ray.exclude = [get_rid()]
		rays.append(ray)
		var pivot := Node3D.new()
		add_child(pivot)
		var mesh := MeshInstance3D.new()
		var tire := CylinderMesh.new()
		tire.top_radius = RADIUS
		tire.bottom_radius = RADIUS
		tire.height = 0.21
		tire.radial_segments = 16
		mesh.mesh = tire
		mesh.material_override = dark
		mesh.rotation.z = PI / 2
		pivot.add_child(mesh)
		wheels.append(pivot)

func _physics_process(dt: float) -> void:
	if controls == null:
		return
	grounded_count = 0
	offroad_count = 0
	max_slip = 0.0
	tc_active = false
	abs_active = false
	var up: Vector3 = global_basis.y
	var com: Vector3 = global_transform * center_of_mass
	for i in 4:
		var mount: Vector3 = global_transform * MOUNTS[i]
		rays[i].from = mount
		rays[i].to = mount - up * (REST + RADIUS)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(rays[i])
		grounded[i] = not hit.is_empty()
		loads[i] = 0.0
		compression[i] = 0.0
		road_speed[i] = 0.0
		grips[i] = 1.0
		if grounded[i]:
			points[i] = hit.position
			normals[i] = hit.normal
			grounded[i] = normals[i].dot(Vector3.UP) > 0.3
		if grounded[i]:
			grounded_count += 1
			grips[i] = float(hit.collider.get_meta("grip", 0.58))
			if grips[i] < 0.9:
				offroad_count += 1
			compression[i] = clampf(REST - (mount.distance_to(points[i]) - RADIUS), 0.0, 0.22)
			var velocity: Vector3 = linear_velocity + angular_velocity.cross(points[i] - com)
			loads[i] = clampf(35000.0 * compression[i] - 3800.0 * velocity.dot(normals[i]), 0.0, 8829.0)
	var bar_front: float = (compression[0] - compression[1]) * 18000.0
	var bar_rear: float = (compression[2] - compression[3]) * 12000.0
	if grounded[0] and grounded[1]:
		loads[0] = maxf(0.0, loads[0] + bar_front)
		loads[1] = maxf(0.0, loads[1] - bar_front)
	if grounded[2] and grounded[3]:
		loads[2] = maxf(0.0, loads[2] + bar_rear)
		loads[3] = maxf(0.0, loads[3] - bar_rear)
	var planar_speed: float = Vector2(linear_velocity.x, linear_velocity.z).length()
	var average_grip: float = (grips[0] + grips[1] + grips[2] + grips[3]) / 4.0
	var limit: float = Driving.steer_limit(planar_speed, average_grip) if controls.steer_assist else deg_to_rad(32)
	var angles: Vector2 = Driving.ackermann(controls.steering * limit)
	for i in 4:
		var angle: float = angles[i] if i < 2 else 0.0
		var forward: Vector3 = (-global_basis.z).rotated(up, -angle).slide(normals[i]).normalized()
		var velocity: Vector3 = linear_velocity + angular_velocity.cross(points[i] - com)
		road_speed[i] = velocity.dot(forward)
	var stable: bool = grounded[2] and grounded[3] and absf(omega[2]*RADIUS-road_speed[2]) / maxf(2.0, absf(road_speed[2])) < 0.4 and absf(omega[3]*RADIUS-road_speed[3]) / maxf(2.0, absf(road_speed[3])) < 0.4
	var drive: float = gearbox.step(dt, controls.throttle, controls.reverse, omega[2]*60/TAU, omega[3]*60/TAU, stable, planar_speed)
	var coupling: float = clampf((omega[2]-omega[3])*60/TAU*0.6, -absf(drive)*0.25, absf(drive)*0.25)
	for i in 4:
		var motor: float = drive*0.5 + (-coupling if i == 2 else coupling) if i >= 2 else 0.0
		var brake: float = controls.brake * (1800.0 if i < 2 else 1000.0)
		var wheel_speed: float = omega[i] * RADIUS
		var traction: bool = controls.tc and i >= 2 and grounded[i] and absf(motor) > 0.01 and motor*wheel_speed >= 0.0
		var target_tc: float = clampf(1.0 - maxf(0.0, Driving.drive_slip(wheel_speed, road_speed[i], motor)-0.18)*2.0, 0.12, 1.0) if traction else 1.0
		tc_scales[i] = move_toward(tc_scales[i], target_tc, dt*(20.0 if target_tc < tc_scales[i] else 5.0)) if traction else 1.0
		var handbraking: bool = controls.handbrake and i >= 2
		var use_abs: bool = controls.abs_enabled and grounded[i] and brake > 0 and absf(road_speed[i]) > 2.2 and not handbraking
		var target_abs: float = clampf(1.0-maxf(0.0, Driving.brake_slip(wheel_speed, road_speed[i])-0.2)*2.3, 0.12, 1.0) if use_abs else 1.0
		abs_scales[i] = move_toward(abs_scales[i], target_abs, dt*(30.0 if target_abs < abs_scales[i] else 10.0)) if use_abs else 1.0
		tc_active = tc_active or (traction and tc_scales[i] < 0.95)
		abs_active = abs_active or (use_abs and abs_scales[i] < 0.95)
		motor *= tc_scales[i]
		brake = 2600.0 if handbraking else brake*abs_scales[i]
		var angle: float = angles[i] if i < 2 else 0.0
		var forward: Vector3 = (-global_basis.z).rotated(up, -angle).slide(normals[i]).normalized()
		var right: Vector3 = forward.cross(normals[i]).normalized()
		var velocity: Vector3 = linear_velocity + angular_velocity.cross(points[i] - com)
		var lateral_speed: float = velocity.dot(right)
		# Regularizacao lateral maior em baixa velocidade evita rigidez numerica
		# excessiva do contato no passo de 60 Hz, sem mudar o limite de aderencia.
		var slip_angle: float = atan(lateral_speed / maxf(4.0, absf(road_speed[i])))
		if grounded[i]:
			apply_force(normals[i] * loads[i], points[i] - global_position)
		var stiffness: float = loads[i]*grips[i]*15.0 / maxf(2.0, absf(road_speed[i])) * RADIUS*RADIUS / INERTIA
		var substeps: int = clampi(int(ceil(dt * stiffness / 0.6)), 4, 160)
		var h: float = dt / substeps
		var average := Vector2.ZERO
		for s in substeps:
			var slip: float = (omega[i]*RADIUS-road_speed[i]) / maxf(2.0, absf(road_speed[i]))
			var force: Vector2 = Driving.tire_forces(slip, slip_angle, loads[i], grips[i]) if grounded[i] else Vector2.ZERO
			omega[i] += (motor - force.x*RADIUS - omega[i]*0.06) / INERTIA * h
			omega[i] = move_toward(omega[i], 0.0, (brake + (8.0 if grounded[i] else 0.0)) / INERTIA * h)
			average += force / substeps
		wheel_slips[i] = Vector2((omega[i]*RADIUS-road_speed[i])/maxf(2.0, absf(road_speed[i])), slip_angle) if grounded[i] else Vector2.ZERO
		if grounded[i]:
			apply_force(forward*average.x + right*average.y, points[i] - global_position)
			max_slip = maxf(max_slip, maxf(absf(slip_angle), absf((omega[i]*RADIUS-road_speed[i])/maxf(2.0, absf(road_speed[i])))))
		wheel_angles[i] += omega[i] * dt
		wheels[i].position = MOUNTS[i] - Vector3.UP * (REST-compression[i])
		wheels[i].rotation = Vector3(wheel_angles[i], -angle, 0)
	feedback.step(dt, linear_velocity, global_basis)
	apply_central_force(-linear_velocity * linear_velocity.length() * 0.42)
	steering_wheel.rotation.z = -controls.steering * deg_to_rad(160)
	camera.fov = controls.fov

func reset_car() -> void:
	global_transform = spawn_pose
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	constant_force = Vector3.ZERO
	constant_torque = Vector3.ZERO
	gearbox.reset()
	feedback.reset()
	cockpit.reset_view()
	for i in 4:
		omega[i] = 0.0
		wheel_slips[i] = Vector2.ZERO
		tc_scales[i] = 1.0
		abs_scales[i] = 1.0
	controls.clear()

func _shape(size: Vector3, location: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = location
	add_child(shape)

static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _box(label: String, size: Vector3, location: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = location
	add_child(node)
