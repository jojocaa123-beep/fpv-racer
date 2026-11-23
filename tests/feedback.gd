extends SceneTree

const Feedback = preload("res://physics/feedback.gd")
const HeadMotion = preload("res://visuals/head_motion.gd")
const Game = preload("res://main.tscn")
var checks: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failed += 1
	print("PASS " if condition else "FAIL ", label)

func touch(input, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = input.origin+input._menu_rect(index).get_center()*input.ui_scale
	event.index = 40
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func _run() -> void:
	var results: Array[Vector3] = []
	var poses: Array[Vector3] = []
	for rate in [30, 60, 120]:
		var feedback = Feedback.new()
		var view = HeadMotion.new()
		feedback.step(1.0/rate, Vector3.ZERO, Basis.IDENTITY)
		for i in 2*rate:
			feedback.step(1.0/rate, Vector3(0, 0, -4.905*(i+1)/rate), Basis.IDENTITY)
			view.step(1.0/rate, Vector3(0.6, 0, -0.5), -0.4, true)
		results.append(feedback.local_g)
		poses.append(view.offset)
		check(absf(feedback.local_g.z+0.5) < 0.002, "Aceleracao conhecida mede 0,5 G a %d Hz" % rate)
	check(results[0].distance_to(results[2]) < 0.001 and poses[0].distance_to(poses[2]) < 0.0001, "Telemetria e camera independem da taxa de quadros")
	var stable_feedback = Feedback.new()
	stable_feedback.step(1.0/60, Vector3(10, 0, -20), Basis.IDENTITY)
	for i in 120:
		stable_feedback.step(1.0/60, Vector3(10, 0, -20), Basis(Vector3.UP, i*0.01))
	check(stable_feedback.local_g.length() < 0.0001, "Rotacao do chassi nao inventa aceleracao a velocidade constante")
	var limited_view = HeadMotion.new()
	for i in 240: limited_view.step(1.0/60, Vector3(100, 100, 100), 100, true)
	check(limited_view.offset.length() < 0.06 and limited_view.angles.length() < 0.09, "Impactos extremos mantem a camera dentro da cabine")
	limited_view.step(1.0/60, Vector3.ONE, 1.0, false)
	check(limited_view.offset == Vector3.ZERO and limited_view.angles == Vector3.ZERO, "Camera fixa remove todo o movimento adicional")
	var game = Game.instantiate()
	root.add_child(game)
	var input = game.controls
	input.simulated = true
	input.set_paused(false)
	for i in 120: await physics_frame
	input.throttle = 1.0
	for i in 120: await physics_frame
	check(game.car.feedback.local_g.z < -0.05, "Carro acelerando produz G longitudinal com sinal correto")
	input.throttle = 0
	input.brake = 1
	for i in 20: await physics_frame
	check(game.car.feedback.local_g.z > 0.05, "Frenagem real inverte o G longitudinal")
	input.brake = 0
	input.handbrake = true
	for i in 30: await physics_frame
	check(game.tire_marks.segment_count > 0, "Rodas travadas em movimento deixam marcas no asfalto")
	game.restart()
	check(game.car.feedback.local_g == Vector3.ZERO and game.car.cockpit.head_motion.offset == Vector3.ZERO, "Reinicio elimina impulso residual da camera e do medidor")
	input.simulated = false
	input.set_paused(true)
	input.graphics_quality = 1
	touch(input, 11)
	check(input.graphics_quality == 2 and root.msaa_3d == Viewport.MSAA_4X and game.sun.shadow_enabled, "Toque seleciona graficos altos e aplica sombras e antisserrilhado")
	touch(input, 11)
	check(input.graphics_quality == 0 and is_equal_approx(root.scaling_3d_scale, 0.75) and root.msaa_3d == Viewport.MSAA_DISABLED and not game.sun.shadow_enabled, "Modo economico reduz renderizacao 3D e desliga sombras")
	input.camera_motion = true
	touch(input, 10)
	var saved := ConfigFile.new()
	var loaded: bool = saved.load("user://preferences.cfg") == OK
	check(not input.camera_motion and loaded and not saved.get_value("driving", "camera_motion", true) and saved.get_value("driving", "graphics_quality", -1) == 0, "Menu salva camera fixa e qualidade grafica nas preferencias")
	input.set_paused(false)
	game.queue_free()
	await process_frame
	print("RESULT checks=", checks, " failed=", failed)
	quit(0 if failed == 0 else 1)
