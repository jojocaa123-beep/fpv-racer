extends RefCounted

var offset := Vector3.ZERO
var angles := Vector3.ZERO

func reset() -> void:
	offset = Vector3.ZERO
	angles = Vector3.ZERO

func step(dt: float, local_g: Vector3, yaw_rate: float, enabled: bool) -> void:
	if not enabled:
		reset()
		return
	if dt <= 0 or not is_finite(dt) or not local_g.is_finite() or not is_finite(yaw_rate):
		return
	var g: Vector3 = local_g.clamp(Vector3.ONE*-1.5, Vector3.ONE*1.5)
	var target_offset := Vector3(-g.x*0.025, -absf(g.z)*0.004, -g.z*0.025)
	var target_angles := Vector3(deg_to_rad(-g.z*1.2), clampf(yaw_rate*0.08, -0.07, 0.07), deg_to_rad(g.x))
	var weight: float = 1.0-exp(-6.0*minf(dt, 0.1))
	offset = offset.lerp(target_offset, weight)
	angles = angles.lerp(target_angles, weight)
