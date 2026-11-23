extends RefCounted

# Deriva a aceleracao no referencial do mundo antes de projetar no chassi.
# Assim, girar o carro nao cria aceleracao ficticia a velocidade constante.
var local_g := Vector3.ZERO
var previous_velocity := Vector3.ZERO
var initialized: bool = false

func reset(velocity: Vector3 = Vector3.ZERO) -> void:
	previous_velocity = velocity
	local_g = Vector3.ZERO
	initialized = false

func step(dt: float, velocity: Vector3, orientation: Basis) -> Vector3:
	if dt <= 0 or not is_finite(dt) or not velocity.is_finite():
		return local_g
	if not initialized:
		previous_velocity = velocity
		initialized = true
		return local_g
	var acceleration: Vector3 = orientation.inverse() * ((velocity-previous_velocity)/dt) / 9.81
	previous_velocity = velocity
	acceleration = acceleration.clamp(Vector3.ONE*-3.0, Vector3.ONE*3.0)
	local_g = local_g.lerp(acceleration, 1.0-exp(-8.0*minf(dt, 0.1)))
	return local_g
