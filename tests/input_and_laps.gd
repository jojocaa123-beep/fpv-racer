extends SceneTree

const Game = preload("res://main.tscn")
const LapModel = preload("res://physics/laps.gd")
const Track = preload("res://physics/track.gd")
var game
var checks: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func touch(id: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = game.controls.origin + at*game.controls.ui_scale
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func drag(id: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = game.controls.origin + at*game.controls.ui_scale
	root.push_input(event, true)

func _run() -> void:
	game = Game.instantiate()
	root.add_child(game)
	for i in 4:
		await physics_frame
	await process_frame
	var input = game.controls
	input._set_mode(input.SteeringMode.SLIDE, false)
	var gas: Vector2 = input._gas_rect().get_center()
	touch(0, Vector2(100, 600), true)
	touch(1, gas, true)
	drag(0, Vector2(260, 600))
	for i in 12:
		await physics_frame
	check(input.steering > 0.5 and input.throttle > 0.5, "Dois dedos controlam direcao e acelerador simultaneamente")
	check(input.brake == 0, "Acelerador nao aciona freio")
	drag(1, input._brake_rect().get_center())
	await process_frame
	check(input.brake == 0 and int(input.pointers.get(1, -1)) == 1, "Arrastar pedal nao troca sua funcao")
	touch(1, gas, false, true)
	await process_frame
	check(input.throttle == 0 and not input.pointers.has(1), "Cancelamento libera o pedal")
	touch(0, gas, true)
	await process_frame
	check(int(input.pointers.get(0, -1)) == 1 and input.steering_target == 0, "Novo toque pode reutilizar ID interrompido sem manter direcao")
	input._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check(input.paused and input.throttle == 0 and input.steering == 0, "Perda de foco pausa e libera os controles")
	input.set_paused(false)
	input.simulated = true
	touch(9, Vector2(input.width-74, 40), true)
	await process_frame
	check(not input.paused, "Automacao isolada ignora toque real durante teste de fisica")
	input.simulated = false
	touch(9, Vector2(input.width-74, 40), true)
	await process_frame
	check(input.paused, "Botao de pausa funciona por toque")
	touch(9, Vector2(input.width-74, 40), false)
	touch(10, input._menu_rect(0).get_center(), true)
	await process_frame
	check(not input.paused, "Menu retoma a simulacao por toque")
	touch(10, input._menu_rect(0).get_center(), false)
	input._set_mode(input.SteeringMode.ARROWS, false)
	var left: Vector2 = input._arrow_rect(false).get_center()
	var right: Vector2 = input._arrow_rect(true).get_center()
	touch(0, left, true)
	touch(1, gas, true)
	for i in 20: await physics_frame
	check(input.steering < -0.8 and input.throttle > 0.5, "Seta esquerda e acelerador funcionam com dois dedos")
	touch(2, right, true)
	for i in 20: await physics_frame
	check(absf(input.steering) < 0.01, "Duas setas pressionadas centralizam a direcao")
	touch(0, left, false)
	for i in 20: await physics_frame
	check(input.steering > 0.8, "Soltar esquerda preserva a seta direita pressionada")
	drag(2, right-Vector2(0, 200))
	for i in 20: await physics_frame
	check(absf(input.steering) < 0.01 and input.throttle > 0.5, "Sair da area da seta libera a direcao sem soltar acelerador")
	drag(2, right)
	for i in 20: await physics_frame
	check(input.steering > 0.8, "Retornar a seta com o mesmo dedo retoma a direcao")
	touch(2, right, false, true)
	touch(1, gas, false)
	for i in 20: await physics_frame
	check(absf(input.steering) < 0.01 and input.throttle == 0, "Cancelar seta e soltar pedal nao deixa controles presos")
	input._set_mode(input.SteeringMode.MOTION, false)
	touch(3, right, true)
	for i in 20: await physics_frame
	check(input.steering > 0.8, "Setas continuam disponiveis no modo giroscopio sem sensor")
	touch(4, gas, true)
	touch(5, input._mode_rect().get_center(), true)
	await process_frame
	check(input.steering_mode == input.SteeringMode.ARROWS and input.throttle == 0 and input.pointers.is_empty(), "Botao visivel troca modo e libera todos os dedos")
	input.reverse = true
	input._set_mode(input.SteeringMode.MOTION, false)
	check(input.reverse, "Trocar modo de direcao preserva a marcha re")
	input.motion.step(1.0/60, Vector3(0, -9.81, 0), Vector3.ZERO, 2.5)
	touch(6, input._calibrate_rect().get_center(), true)
	await process_frame
	check(input.motion.pending_calibration and input.reverse, "Botao calibrar solicita novo neutro e preserva a marcha")
	input.clear()
	input.simulated = true
	var points: PackedVector3Array = Track.sample()
	var laps = LapModel.new()
	laps.configure(points)
	var now: float = 0
	laps.step(points[0]-Track.tangent(points, 0)*0.2, now)
	for lap in 3:
		for p in points:
			now += 0.1
			laps.step(p, now)
	check(laps.completed == 2 and absf(laps.best_time-18.0) < 0.01, "Gates ordenados contam duas voltas e salvam melhor")
	laps.reset_attempt()
	var count: int = laps.completed
	for i in 10:
		now += 1
		laps.step(points[0]-Track.tangent(points, 0), now)
		now += 1
		laps.step(points[0]+Track.tangent(points, 0), now)
	check(laps.completed == count, "Repetir largada sem checkpoints nao conta volta")
	var invalid_laps = LapModel.new()
	invalid_laps.configure(points)
	invalid_laps.step(points[0]-Track.tangent(points, 0)*0.2, 0)
	now = 0
	for p in points:
		now += 0.1
		invalid_laps.step(p, now)
	now += 0.1
	invalid_laps.step(points[0], now, "CORTE")
	check(invalid_laps.completed == 1 and not invalid_laps.last_valid and invalid_laps.best_time == 0, "Corte na chegada invalida antes de salvar recorde")
	print("RESULT checks=", checks, " failed=", failed)
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
