extends RefCounted

const DEAD_ZONE: float = deg_to_rad(1.5)
var roll: float = 0.0
var center: float = 0.0
var value: float = 0.0
var ready: bool = false
var pending_calibration: bool = true
var missing_time: float = 0.0
var gravity_direction := Vector3(0, -1, 0)

func calibrate() -> void:
	ready = false
	pending_calibration = true
	value = 0.0
	missing_time = 0.0

func step(dt: float, gravity: Vector3, gyro: Vector3, sensitivity: float) -> float:
	if dt <= 0.0 or not is_finite(dt):
		return value
	var h: float = minf(dt, 0.1)
	var has_reference: bool = gravity.is_finite() and gravity.length() > 4.0
	if has_reference:
		gravity_direction = gravity.normalized()
	# Projeta o giro no eixo de inclinacao lateral, mesmo com o celular deitado.
	var angular_speed: float = (gravity_direction.y*gyro.z-gravity_direction.z*gyro.y)/sqrt(maxf(0.04, 1.0-gravity_direction.x*gravity_direction.x)) if gyro.is_finite() else 0.0
	if has_reference:
		missing_time = 0.0
		var measured: float = asin(clampf(gravity_direction.x, -1.0, 1.0))
		if not ready:
			roll = measured
			ready = true
		else:
			# O giro responde imediatamente; a gravidade corrige a deriva.
			roll = lerp_angle(roll + angular_speed*h, measured, 1.0-exp(-4.0*h))
		if pending_calibration:
			center = roll
			pending_calibration = false
	else:
		missing_time += h
		if not ready or missing_time > 0.15:
			ready = false
			pending_calibration = true
			value = move_toward(value, 0.0, h*8.0)
			return value
		roll += angular_speed*h
	var angle: float = wrapf(roll-center, -PI, PI)
	var full_angle: float = deg_to_rad(32.0)*2.5/clampf(sensitivity, 1.5, 3.5)
	var target: float = signf(angle)*clampf((absf(angle)-DEAD_ZONE)/(full_angle-DEAD_ZONE), 0.0, 1.0)
	value = lerpf(value, target, 1.0-exp(-18.0*h))
	return value
