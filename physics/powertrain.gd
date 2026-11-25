extends RefCounted

const Driving = preload("res://physics/driving_math.gd")
const RATIOS := [3.2, 2.1, 1.5, 1.15, 0.92]
var gear: int = 1
var rpm: float = 900.0
var reversing: bool = false
var limiter: bool = false
var shift_left: float = 0.0
var manual: bool = false
var overrev_block_left: float = 0.0

func reset() -> void:
	gear = 1
	rpm = 900.0
	reversing = false
	limiter = false
	shift_left = 0.1
	overrev_block_left = 0.0

func try_shift(direction: int, wheel_rpm: float, speed: float) -> bool:
	if not manual or reversing or shift_left > 0 or direction not in [-1, 1] or not is_finite(wheel_rpm) or not is_finite(speed):
		return false
	var target: int = clampi(gear+direction, 1, RATIOS.size())
	if target == gear: return false
	# A velocidade do chassi tambem protege reducoes com rodas travadas.
	var reference_rpm: float = maxf(absf(wheel_rpm), absf(speed)*60.0/(TAU*0.32))
	if direction < 0 and reference_rpm*RATIOS[target-1]*3.9 > 6700:
		overrev_block_left = 0.9
		return false
	gear = target
	shift_left = 0.22
	return true

func step(dt: float, throttle: float, reverse: bool, left_rpm: float, right_rpm: float, stable: bool, speed: float) -> float:
	if dt <= 0.0:
		return 0.0
	if reversing != reverse:
		reset()
		reversing = reverse
		shift_left = 0.15
	shift_left = maxf(0.0, shift_left - dt)
	overrev_block_left = maxf(0.0, overrev_block_left-dt)
	var wheel_rpm: float = (absf(left_rpm) + absf(right_rpm)) * 0.5
	if not manual and wheel_rpm < 10.0 and speed < 0.83:
		gear = 1
	var ratio: float = 3.1 if reverse else RATIOS[gear - 1]
	rpm = move_toward(rpm, clampf(wheel_rpm * ratio * 3.9, 900.0, 7200.0), dt * 20000.0)
	if not manual and not reverse and shift_left <= 0.0:
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
