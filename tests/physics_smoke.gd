extends SceneTree

const Game = preload("res://main.tscn")
const Driving = preload("res://physics/driving_math.gd")
var game
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		print("FAIL ", label)

func step(frames: int) -> void:
	for i in frames:
		await physics_frame
	await process_frame

func reset() -> void:
	game.restart()
	await step(150)

func _run() -> void:
	game = Game.instantiate()
	root.add_child(game)
	game.controls.simulated = true
	await step(180)
	var car = game.car
	print("SETTLED y=", car.global_position.y, " wheels=", car.grounded_count, " offroad=", car.offroad_count, " speed=", car.linear_velocity.length(), " loads=", car.loads)
	check(car.grounded_count == 4, "Quatro rodas em contato com a pista")
	check(car.offroad_count == 0, "Contato inicial identificado como asfalto")
	check(car.linear_velocity.length() < 0.02, "Carro parado sem vibracao excessiva")
	check(car.global_basis.y.dot(Vector3.UP) > 0.98, "Chassi equilibrado em repouso")
	var start: Vector3 = car.global_position
	var forward: Vector3 = -car.global_basis.z
	game.controls.throttle = 1.0
	await step(180)
	var acceleration_speed: float = car.linear_velocity.length()
	print("ACCEL speed_kmh=", acceleration_speed*3.6, " distance=", (car.global_position-start).dot(forward), " rpm=", car.gearbox.rpm)
	check(acceleration_speed > 4.0, "Aceleracao supera 14 km/h em tres segundos")
	check((car.global_position-start).dot(forward) > 3, "Torque positivo move o carro para frente")
	game.controls.throttle = 0.0
	game.controls.brake = 1.0
	await step(180)
	print("BRAKE speed_kmh=", car.linear_velocity.length()*3.6)
	check(car.linear_velocity.length() < 0.83, "Freio imobiliza o carro")
	await reset()
	start = car.global_position
	forward = -car.global_basis.z
	game.controls.reverse = true
	game.controls.throttle = 0.6
	await step(120)
	print("REVERSE distance=", (car.global_position-start).dot(forward))
	check((car.global_position-start).dot(forward) < -1, "Re desloca o carro para tras")
	await reset()
	var initial_right: Vector3 = car.global_basis.x
	game.controls.steering = 0.35
	game.controls.throttle = 0.5
	await step(120)
	var turn: float = (-car.global_basis.z).dot(initial_right)
	print("STEER direction=", turn)
	check(turn > 0.01, "Direcao positiva produz curva para direita")
	await reset()
	car.global_position += car.global_basis.x*25.0
	await step(120)
	check(car.offroad_count == 4, "Quatro rodas reconhecem a grama")
	check(car.grips[0] < 0.9, "Grama tem aderencia inferior ao asfalto")
	game.controls.throttle = 1.0
	game.controls.brake = 0.0
	game.controls.set_paused(true)
	var paused_position: Vector3 = car.global_position
	for i in 5:
		await process_frame
	check(car.global_position.distance_to(paused_position) < 0.0001, "Pausa congela a simulacao")
	check(game.controls.throttle == 0 and game.controls.steering == 0, "Pausa libera os controles")
	game.controls.set_paused(false)
	game.restart()
	check(car.linear_velocity.length() < 0.0001, "Reinicio remove a velocidade")
	check(car.omega.all(func(value): return is_zero_approx(value)), "Reinicio remove rotacao das rodas")
	check(not game.laps.running, "Reinicio encerra tentativa de volta")
	for slip in [-2.0, -0.2, 0.0, 0.2, 2.0]:
		for angle in [-0.5, 0.0, 0.5]:
			var force: Vector2 = Driving.tire_forces(slip, angle, 2943.0, 1.0)
			check(force.x*slip >= -0.0001 and force.y*angle <= 0.0001 and force.length() <= 2943.01, "Pneu conserva limite e dissipa derrapagem %.1f/%.1f" % [slip, angle])
	print("RESULT checks=", checks, " failed=", failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
