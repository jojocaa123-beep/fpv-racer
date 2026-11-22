extends RefCounted

static func torque_factor(rpm: float) -> float:
	return clampf(1.0 - pow((rpm - 4200.0) / 5700.0, 2), 0.15, 1.0)

static func ackermann(center: float) -> Vector2:
	if absf(center) < 0.0001:
		return Vector2.ZERO
	var radius: float = 2.4 / tan(absf(center))
	var inner: float = atan(2.4 / maxf(0.1, radius - 0.76)) * signf(center)
	var outer: float = atan(2.4 / (radius + 0.76)) * signf(center)
	return Vector2(outer, inner) if center > 0 else Vector2(inner, outer)

static func steer_limit(speed: float, grip: float) -> float:
	return minf(deg_to_rad(32), atan(2.4 * 9.81 * clampf(grip, 0.05, 2.0) * 1.1 / maxf(0.01, speed * speed)))

static func drive_slip(wheel: float, road: float, motor: float) -> float:
	return maxf(0.0, (wheel - road) * signf(motor) / maxf(2.0, absf(road)))

static func brake_slip(wheel: float, road: float) -> float:
	if absf(road) < 0.1:
		return 0.0
	return maxf(0.0, (absf(road) - wheel * signf(road)) / maxf(2.0, absf(road)))

static func tire_forces(slip: float, angle: float, normal_load: float, grip: float) -> Vector2:
	var supported_load: float = maxf(0.0, normal_load)
	var sensitivity: float = clampf(pow(maxf(0.1, supported_load / 2943.0), -0.12), 0.65, 1.15)
	var limit: float = supported_load * maxf(0.0, grip) * sensitivity
	var demand := Vector2(sin(1.5 * atan(10.0 * slip)), -sin(1.4 * atan(15.0 * angle)))
	return demand.limit_length(1.0) * limit
