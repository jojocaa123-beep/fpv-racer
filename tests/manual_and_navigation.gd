extends SceneTree

const Gearbox = preload("res://physics/powertrain.gd")
const Guide = preload("res://physics/track_guide.gd")
const Track = preload("res://physics/track.gd")
const Progress = preload("res://physics/track_progress.gd")
const Game = preload("res://main.tscn")
var game
var checks: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failed += 1
	print("PASS " if condition else "FAIL ", label)

func touch(id: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = game.controls.origin+at*game.controls.ui_scale
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func circle(side: float) -> PackedVector3Array:
	var route := PackedVector3Array()
	for i in 120:
		var angle: float = side*i*TAU/120.0
		route.append(Vector3(sin(angle)*40, 0, -cos(angle)*40))
	return route

func _run() -> void:
	var box = Gearbox.new()
	check(not box.try_shift(1, 0, 0) and box.gear == 1, "Automatico ignora comandos manuais")
	box.manual = true
	check(box.try_shift(1, 0, 0) and box.gear == 2, "Comando manual seleciona a proxima marcha")
	check(not box.try_shift(1, 0, 0) and box.gear == 2, "Troca em andamento nao aceita outra marcha")
	check(box.step(0.1, 1, false, 100, 100, true, 3) == 0, "Torque e interrompido durante a troca")
	check(box.step(0.2, 1, false, 100, 100, true, 3) > 0, "Torque retorna ao terminar a troca")
	box.gear = 3
	check(not box.try_shift(-1, 1000, 30) and box.gear == 3 and box.overrev_block_left > 0, "Reducao que excede o giro seguro e recusada")
	check(not box.try_shift(-1, 0, 35) and box.gear == 3, "Rodas travadas nao burlam a protecao de reducao")
	check(box.try_shift(-1, 400, 10) and box.gear == 2, "Reducao em velocidade compativel e aceita")
	box.shift_left = 0
	box.gear = 1
	for i in 60: box.step(1.0/60, 1, false, 900, 900, true, 30)
	check(box.gear == 1 and box.limiter, "Modo manual segura a marcha no limitador")
	box.gear = 4
	for i in 60: box.step(1.0/60, 0, false, 0, 0, true, 0)
	check(box.gear == 4, "Parar nao muda sozinho a marcha manual selecionada")
	box.gear = 5
	check(not box.try_shift(1, 0, 0), "Quinta marcha respeita o limite superior")
	box.gear = 1
	check(not box.try_shift(-1, 0, 0), "Primeira marcha respeita o limite inferior")
	box.reversing = true
	check(not box.try_shift(1, 0, 0), "Re nao aceita selecao de marchas para frente")
	for side in [1.0, -1.0]:
		var route: PackedVector3Array = circle(side)
		var circle_progress = Progress.new()
		circle_progress.configure(route)
		var circle_guide = Guide.new()
		circle_guide.configure(route, circle_progress.distances)
		var turn: Dictionary = circle_guide.next_turn(0)
		check(not circle_guide.corners.is_empty() and int(turn.side) == int(side), "Geometria identifica curva para %s" % ("direita" if side > 0 else "esquerda"))
		check(int(circle_guide.next_turn(1).side) == int(circle_guide.next_turn(circle_guide.length+1).side) and absf(float(circle_guide.next_turn(1).meters)-float(circle_guide.next_turn(circle_guide.length+1).meters)) < 0.001, "Aviso de curva e continuo ao cruzar a largada")
	var progress = Progress.new()
	progress.configure(Track.sample())
	var guide = Guide.new()
	guide.configure(progress.points, progress.distances)
	var inside: bool = true
	for point in guide.map_route:
		inside = inside and absf(point.x) <= 0.501 and absf(point.y) <= 0.501
	check(inside and guide.map_route[0] == guide.map_route[-1], "Mapa conserva proporcoes e fecha a pista dentro do painel")
	game = Game.instantiate()
	root.add_child(game)
	var input = game.controls
	input.simulated = true
	input.set_paused(false)
	for i in 150: await physics_frame
	input.simulated = false
	input.manual_gears = true
	input._set_mode(input.SteeringMode.ARROWS, false)
	touch(0, input._arrow_rect(false).get_center(), true)
	touch(1, input._gas_rect().position+Vector2(60, 8), true)
	touch(2, input._shift_rect(true).get_center(), true)
	check(game.car.gearbox.gear == 2 and input.throttle > 0.99 and input._arrow_held(false), "Tres dedos trocam marcha sem soltar acelerador e direcao")
	for i in 40: await physics_frame
	check(game.car.gearbox.gear == 2, "Segurar botao nao repete marchas")
	touch(2, input._shift_rect(true).get_center(), false, true)
	check(input.throttle > 0.99 and input._arrow_held(false) and not input.pointers.has(2), "Cancelar troca nao cancela outros dedos")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	root.push_input(key, true)
	key.echo = true
	root.push_input(key, true)
	check(game.car.gearbox.gear == 3, "Tecla E sobe uma marcha e ignora repeticao automatica")
	input._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(input.paused and input.pointers.is_empty() and input.throttle == 0, "Perda de foco libera tambem os controles de marcha")
	input.reverse = true
	touch(3, input._menu_rect(13).get_center(), true)
	touch(3, input._menu_rect(13).get_center(), false)
	check(not input.manual_gears and input.reverse, "Menu troca cambio e preserva D/R")
	touch(4, input._menu_rect(14).get_center(), true)
	touch(4, input._menu_rect(14).get_center(), false)
	var prefs := ConfigFile.new()
	var saved: bool = prefs.load("user://preferences.cfg") == OK
	check(not input.track_guide and saved and not prefs.get_value("driving", "track_guide", true) and not prefs.get_value("driving", "manual_gears", true), "Mapa e cambio ficam salvos nas preferencias")
	input.manual_gears = false
	input.track_guide = true
	input._save_preferences()
	input.set_paused(false)
	game.queue_free()
	await process_frame
	print("RESULT checks=", checks, " failed=", failed)
	quit(0 if failed == 0 else 1)
