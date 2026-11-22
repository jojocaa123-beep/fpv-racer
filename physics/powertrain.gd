extends RefCounted

const Driving = preload("res://physics/driving_math.gd")
const RATIOS := [3.2, 2.1, 1.5, 1.15, 0.92]
var gear: int = 1
var rpm: float = 900.0
var reversing: bool = false
var limiter: bool = false
var shift_left: float = 0.0

func reset() -> void:
	gear = 1
	rpm = 900.0
	reversing = false
	limiter = false
	shift_left = 0.1

func step(dt: float, throttle: float, reverse: bool, left_rpm: float, right_rpm: float, stable: bool, speed: float) -> float:
	if dt <= 0.0:
		return 0.0
	if reversing != reverse:
		reset()
		reversing = reverse
		shift_left = 0.15
	shift_left = maxf(0.0, shift_left - dt)
	var wheel_rpm: float = (absf(left_rpm) + absf(right_rpm)) * 0.5
	if wheel_rpm < 10.0 and speed < 0.83:
		gear = 1
	var ratio: float = 3.1 if reverse else RATIOS[gear - 1]
	rpm = move_toward(rpm, clampf(wheel_rpm * ratio * 3.9, 900.0, 7200.0), dt * 20000.0)
	if not reverse and shift_left <= 0.0:
		if rpm > 6200.0 and gear < 5 and stable:
			gear += 1
			shift_left = 0.22
		elif rpm < 2100.0 and gear > 1 and wheel_rpm * RATIOS[gear - 2] * 3.9 < 5500.0:
			gear -= 1
			shift_left = 0.22
	ratio = 3.1 if reverse else RATIOS[gear - 1]
	if rpm >= 6900.0:
		limiter = true
	elif rpm < 6500.0:
		limiter = false
	if shift_left > 0.0:
		return 0.0
	if throttle < 0.02:
		return -signf(left_rpm + right_rpm) * 12.0 * ratio * 3.9 if speed > 0.83 else 0.0
	if limiter:
		return 0.0
	return clampf(throttle, 0.0, 1.0) * 210.0 * Driving.torque_factor(rpm) * ratio * 3.9 * 0.88 * (-1.0 if reverse else 1.0)
