extends MultiMeshInstance3D

const CAPACITY: int = 512
var car
var anchors: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var drawing: Array[bool] = [false, false, false, false]
var next_segment: int = 0
var segment_count: int = 0

func _ready() -> void:
	process_physics_priority = 20
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var strip := BoxMesh.new()
	strip.size = Vector3(0.18, 0.001, 1)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = strip
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.025, 0.023, 0.02, 0.6)
	rubber.vertex_color_use_as_albedo = true
	rubber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rubber.roughness = 1.0
	material_override = rubber

func break_trails() -> void:
	drawing.fill(false)

func _physics_process(_dt: float) -> void:
	for i in 4:
		var slip: Vector2 = car.wheel_slips[i]
		var amount: float = clampf(maxf((absf(slip.x)-0.2)*2.0, (absf(slip.y)-0.1)*4.0), 0, 1)
		if not car.grounded[i] or car.grips[i] < 0.9 or car.loads[i] < 300 or car.linear_velocity.length() < 3 or amount < 0.08:
			drawing[i] = false
			continue
		var at: Vector3 = car.points[i]+car.normals[i]*0.004
		var length: float = at.distance_to(anchors[i])
		if drawing[i] and length < 0.14:
			continue
		if drawing[i] and length < 1.8:
			var direction: Vector3 = (at-anchors[i]).normalized()
			var frame := Basis.looking_at(direction, car.normals[i])
			multimesh.set_instance_transform(next_segment, Transform3D(frame*Basis.from_scale(Vector3(1, 1, length+0.025)), (at+anchors[i])*0.5))
			multimesh.set_instance_color(next_segment, Color(1, 1, 1, amount))
			next_segment = (next_segment+1)%CAPACITY
			segment_count = mini(CAPACITY, segment_count+1)
			multimesh.visible_instance_count = segment_count
		anchors[i] = at
		drawing[i] = true
