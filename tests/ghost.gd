extends SceneTree

const Ghost = preload("res://physics/ghost.gd")
const Progress = preload("res://physics/track_progress.gd")
const Track = preload("res://physics/track.gd")
const Laps = preload("res://physics/laps.gd")
const Game = preload("res://main.tscn")
const Visual = preload("res://visuals/ghost_car.gd")
var checks: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failed += 1
	print("PASS " if condition else "FAIL ", label)

func record(reference, duration: float, valid: bool, rate: int = 60) -> bool:
	reference.begin(Transform3D.IDENTITY)
	for i in int(duration*rate):
		var elapsed: float = (i+1.0)/rate
		reference.sample(elapsed, Transform3D(Basis(Vector3.UP, elapsed*0.02), Vector3(200*elapsed/duration, 0, 0)), 200*elapsed/duration)
	return reference.finish(valid, duration, Transform3D(Basis(Vector3.UP, duration*0.02), Vector3(200, 0, 0)), PackedFloat64Array([duration*0.3, duration*0.4, duration*0.3]))

func _run() -> void:
	var reference = Ghost.new()
	reference.track_length = 200
	check(not reference.has_reference(), "Primeira abertura nao inventa uma volta de referencia")
	check(record(reference, 10, true), "Primeira volta valida cria referencia")
	check(reference.best_times.size() == 201 and absf(reference.pose_at(5).origin.x-100) < 0.001, "Gravacao a 20 Hz reproduz posicao interpolada no tempo correto")
	check(absf(reference.time_at_distance(100)-5) < 0.001, "Delta usa tempo no mesmo ponto da pista")
	check(not record(reference, 8, false) and reference.best_time == 10, "Corte de pista nunca substitui o fantasma por volta mais rapida")
	check(not record(reference, 12, true) and reference.best_time == 10, "Volta valida mais lenta preserva a referencia")
	check(record(reference, 9, true) and reference.best_time == 9, "Volta valida mais rapida substitui a referencia")
	check(5-reference.time_at_distance(100) > 0 and 4-reference.time_at_distance(100) < 0, "Delta positivo indica atraso e negativo indica vantagem")
	for rate in [30, 120]:
		var other = Ghost.new()
		other.track_length = 200
		record(other, 9, true, rate)
		check(other.pose_at(4.51).origin.distance_to(reference.pose_at(4.51).origin) < 0.001 and absf(other.time_at_distance(123)-reference.time_at_distance(123)) < 0.001, "Fantasma e delta consistentes a %d Hz" % rate)
	var saved: Error = reference.save_best("user://ghost-test.json")
	var loaded = Ghost.new()
	loaded.track_length = 200
	check(saved == OK and loaded.load_best("user://ghost-test.json") and loaded.best_time == 9 and loaded.pose_at(4.5).origin.distance_to(Vector3(100, 0, 0)) < 0.001, "Melhor gravacao sobrevive ao fechamento e reabertura")
	check(reference.save_best("user://ghost-test.json") == OK, "Salvar novamente substitui o arquivo de forma atomica")
	var file := FileAccess.open("user://ghost-test.json", FileAccess.WRITE)
	file.store_string('{"version":1,"track":"outro-circuito"}')
	file.close()
	check(not loaded.load_best("user://ghost-test.json") and loaded.best_time == 9, "Dados incompatíveis sao recusados sem apagar referencia em memoria")
	file = FileAccess.open("user://ghost-test.json", FileAccess.WRITE)
	file.store_string('{broken')
	file.close()
	check(not loaded.load_best("user://ghost-test.json") and loaded.best_time == 9, "Arquivo danificado nao trava a inicializacao")
	reference.begin(Transform3D.IDENTITY)
	reference.sample(601, Transform3D.IDENTITY, 0)
	check(not reference.recording and reference.best_time == 9, "Tentativa longa tem memoria limitada e preserva a melhor volta")
	var route: PackedVector3Array = Track.sample()
	var progress = Progress.new()
	progress.configure(route)
	check(progress.project(route[0], 1) < 0.001 and absf(progress.project(route[0], 0)-progress.length) < 0.001, "Largada e chegada usam lados corretos do circuito fechado")
	check(progress.project(route[-2], 1) < progress.length*0.15 and progress.project(route[-2], 0) > progress.length*0.9, "Busca de progresso respeita os checkpoints ordenados")
	var laps = Laps.new()
	laps.configure(route)
	laps.step(route[0]-Track.tangent(route, 0)*0.2, 0)
	var now: float = 0.0
	for p in route:
		now += 0.1
		laps.step(p, now)
	now += 0.1
	laps.step(route[0], now)
	check(laps.last_valid and laps.last_sectors.size() == 3 and absf(laps.last_sectors[0]+laps.last_sectors[1]+laps.last_sectors[2]-laps.last_time) < 0.000001, "Tres setores somam exatamente a volta interpolada")
	var visual = Visual.new()
	root.add_child(visual)
	visual.replay(reference, 4.5, Vector3.ZERO, true)
	var was_visible: bool = visual.visible
	visual.replay(reference, 4.5, Vector3(100, 0, 0), true)
	check(was_visible and not visual.visible, "Fantasma some perto do piloto para manter o para-brisa livre")
	visual.replay(reference, 4.5, Vector3.ZERO, false)
	check(not visual.visible, "Desligar fantasma esconde sua geometria")
	visual.queue_free()
	var game = Game.instantiate()
	root.add_child(game)
	game.controls.ghost_enabled = true
	game.controls.set_paused(true)
	var event := InputEventScreenTouch.new()
	event.index = 60
	event.position = game.controls.origin+game.controls._menu_rect(12).get_center()*game.controls.ui_scale
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	var prefs := ConfigFile.new()
	var preference_saved: bool = prefs.load("user://preferences.cfg") == OK
	check(not game.controls.ghost_enabled and preference_saved and not prefs.get_value("driving", "ghost_enabled", true), "Menu permite desligar fantasma e salva a escolha")
	game.controls.ghost_enabled = true
	game.controls._save_preferences()
	game.controls.set_paused(false)
	game.queue_free()
	await process_frame
	print("RESULT checks=", checks, " failed=", failed)
	quit(0 if failed == 0 else 1)
