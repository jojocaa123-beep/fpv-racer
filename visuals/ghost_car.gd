extends Node3D

const Shape = preload("res://visuals/cockpit.gd")
var shell: StandardMaterial3D

func _ready() -> void:
	shell = Shape.material(Color(0.2, 0.82, 1.0, 0.3))
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var glass := shell.duplicate() as StandardMaterial3D
	glass.albedo_color = Color(0.05, 0.2, 0.3, 0.34)
	Shape.box(self, Vector3(1.72, 0.34, 3.8), Vector3(0, 0.62, 0), shell)
	Shape.box(self, Vector3(1.66, 0.12, 1.4), Vector3(0, 0.87, -1.15), shell)
	Shape.box(self, Vector3(1.48, 0.6, 1.7), Vector3(0, 1.16, 0.32), glass)
	Shape.box(self, Vector3(1.5, 0.06, 1.7), Vector3(0, 1.49, 0.32), shell)
	Shape.box(self, Vector3(1.58, 0.12, 0.65), Vector3(0, 0.9, 1.52), shell)
	for side in [-1, 1]:
		for axle in [-1, 1]:
			var wheel := Shape.cylinder(self, 0.32, 0.2, Vector3(side*0.78, 0.27, axle*1.2), glass)
			wheel.rotation = Vector3(0, 0, PI/2)
	for item in find_children("*", "MeshInstance3D", true, false):
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func replay(reference, elapsed: float, player_position: Vector3, enabled: bool) -> void:
	visible = enabled and reference.has_reference() and elapsed >= 0 and elapsed <= reference.best_time
	if not visible: return
	global_transform = reference.pose_at(elapsed)
	var distance: float = global_position.distance_to(player_position)
	# Some perto do piloto para nao tampar o para-brisa ou cruzar o cockpit.
	visible = distance > 4.0 and distance < 160.0
