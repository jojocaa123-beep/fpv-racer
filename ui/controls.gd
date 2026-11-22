extends Control

var world
var car
var steering: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var handbrake: bool = false
var reverse: bool = false
var steer_assist: bool = true
var tc: bool = true
var abs_enabled: bool = true
var tilt: bool = false
var sensitivity: float = 2.5
var fov: float = 65.0
var volume: float = 0.6
var simulated: bool = false
var paused: bool = false
var pointers: Dictionary = {}
var anchor: float = 0.0
var anchor_steering: float = 0.0
var steering_target: float = 0.0
var tilt_center: float = 0.0
var filtered_tilt: float = 0.0
var width: float = 1280.0
var ui_scale: float = 1.0
var origin := Vector2.ZERO
var font: Font
const INK := Color(0.025, 0.04, 0.055, 0.85)
const GREEN := Color(0.35, 0.85, 0.58)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	_metrics()
	var prefs := ConfigFile.new()
	if prefs.load("user://preferences.cfg") == OK:
		steer_assist = bool(prefs.get_value("driving", "steer_assist", true))
		tc = bool(prefs.get_value("driving", "tc", true))
		abs_enabled = bool(prefs.get_value("driving", "abs", true))
		tilt = bool(prefs.get_value("driving", "tilt", false))
		fov = clampf(float(prefs.get_value("driving", "fov", 65.0)), 55, 75)
		sensitivity = clampf(float(prefs.get_value("driving", "sensitivity", 2.5)), 1.5, 3.5)
		volume = clampf(float(prefs.get_value("driving", "volume", 0.6)), 0, 1)
	tilt_center = Input.get_accelerometer().x / 9.81
	filtered_tilt = tilt_center

func _metrics() -> void:
	var area := get_viewport_rect()
	if OS.has_feature("mobile"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if safe.size.x > 0 and window_size.x > 0:
			var ratio: Vector2 = area.size / window_size
			area = Rect2(safe.position * ratio, safe.size * ratio)
	var next_scale: float = maxf(0.001, area.size.y / 720.0)
	var next_width: float = area.size.x / next_scale
	if origin != area.position or not is_equal_approx(ui_scale, next_scale) or not is_equal_approx(width, next_width):
		clear()
	origin = area.position
	ui_scale = next_scale
	width = next_width

func _physics_process(dt: float) -> void:
	_metrics()
	queue_redraw()
	if simulated or paused:
		return
	var target: float = steering_target
	if tilt:
		filtered_tilt = lerpf(filtered_tilt, Input.get_accelerometer().x / 9.81, 1.0-exp(-12*dt))
		target = clampf((filtered_tilt-tilt_center)*sensitivity, -1, 1)
		if absf(target) < 0.025:
			target = 0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		target = -1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		target = 1.0
	steering = move_toward(steering, target, dt*(5.0 if pointers.values().has(0) or tilt else 2.5))
	if not pointers.values().has(1):
		throttle = 1.0 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0.0
	if not pointers.values().has(2):
		brake = 1.0 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) else 0.0
	handbrake = pointers.values().has(3) or Input.is_physical_key_pressed(KEY_SPACE)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			set_paused(not paused)
		elif not paused and event.keycode == KEY_R:
			world.restart()
		elif not paused and event.keycode == KEY_Q:
			_toggle_reverse()
	if simulated:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_begin(event.index, (event.position-origin)/ui_scale)
		else:
			_end(event.index)
	elif event is InputEventScreenDrag:
		_move(event.index, (event.position-origin)/ui_scale)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(-2, (event.position-origin)/ui_scale)
		else:
			_end(-2)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_move(-2, (event.position-origin)/ui_scale)

func _begin(id: int, p: Vector2) -> void:
	_end(id)
	if paused:
		for i in 9:
			if _menu_rect(i).has_point(p):
				_option(i)
				return
		return
	if Rect2(width-132, 16, 116, 46).has_point(p):
		set_paused(true)
		return
	if Rect2(width-268, 16, 124, 46).has_point(p):
		world.restart()
		return
	if Rect2(width*0.62, 485, width*0.15, 46).has_point(p):
		_toggle_reverse()
		return
	var role: int = -1
	if Rect2(width*0.8, 445, width*0.17, 46).has_point(p):
		role = 3
	elif _gas_rect().has_point(p):
		role = 1
	elif _brake_rect().has_point(p):
		role = 2
	elif not tilt and Rect2(20, 555, width*0.39, 145).has_point(p):
		role = 0
	if role >= 0 and not pointers.values().has(role):
		pointers[id] = role
		if role == 0:
			anchor = p.x
			anchor_steering = steering
		_move(id, p)

func _move(id: int, p: Vector2) -> void:
	var role: int = int(pointers.get(id, -1))
	if role == 0:
		steering_target = clampf(anchor_steering+(p.x-anchor)/(width*0.14)*sensitivity/2.5, -1, 1)
	elif role == 1:
		throttle = clampf(inverse_lerp(_gas_rect().end.y, _gas_rect().position.y+_gas_rect().size.y*0.15, p.y), 0, 1)
	elif role == 2:
		brake = clampf(inverse_lerp(_brake_rect().end.y, _brake_rect().position.y+_brake_rect().size.y*0.15, p.y), 0, 1)
	elif role == 3:
		handbrake = true

func _end(id: int) -> void:
	match int(pointers.get(id, -1)):
		0: steering_target = 0.0
		1: throttle = 0.0
		2: brake = 0.0
		3: handbrake = false
	pointers.erase(id)

func _toggle_reverse() -> void:
	if car != null and car.linear_velocity.length() < 0.83 and throttle < 0.05:
		reverse = not reverse

func clear() -> void:
	steering = 0.0
	steering_target = 0.0
	throttle = 0.0
	brake = 0.0
	handbrake = false
	reverse = false
	pointers.clear()

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	var direction: bool = reverse
	clear()
	reverse = direction
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not simulated:
			set_paused(true)

func _option(index: int) -> void:
	match index:
		0: set_paused(false)
		1:
			tilt = not tilt
			tilt_center = Input.get_accelerometer().x / 9.81
			filtered_tilt = tilt_center
		2: steer_assist = not steer_assist
		3: abs_enabled = not abs_enabled
		4: tc = not tc
		5: fov = 55.0 if fov >= 75 else fov+5
		6: sensitivity = 1.5 if sensitivity >= 3.5 else sensitivity+0.5
		7: volume = 0.0 if volume >= 0.99 else minf(1, volume+0.2)
		8:
			world.restart()
			set_paused(false)
	var prefs := ConfigFile.new()
	for key in ["steer_assist", "tc", "tilt", "fov", "sensitivity", "volume"]:
		prefs.set_value("driving", key, get(key))
	prefs.set_value("driving", "abs", abs_enabled)
	prefs.save("user://preferences.cfg")

func _gas_rect() -> Rect2: return Rect2(width*0.8, 505, width*0.17, 195)
func _brake_rect() -> Rect2: return Rect2(width*0.62, 545, width*0.15, 155)
func _menu_rect(i: int) -> Rect2: return Rect2(width*0.5-220, 128+i*54, 440, 46)

func _draw() -> void:
	if car == null or font == null:
		return
	draw_set_transform(origin, 0, Vector2.ONE*ui_scale)
	if paused:
		draw_rect(Rect2(0, 0, width, 720), Color(0.015, 0.025, 0.04, 0.94))
		_text(Vector2(width*0.5-220, 88), "TREINO PAUSADO", 32)
		var labels: Array[String] = ["RETOMAR", "DIREÇÃO: " + ("INCLINAÇÃO" if tilt else "TOQUE"), "AJUDA DE DIREÇÃO: "+_on(steer_assist), "ABS: "+_on(abs_enabled), "CONTROLE DE TRAÇÃO: "+_on(tc), "CAMPO DE VISÃO: %d" % fov, "SENSIBILIDADE: %.1f" % sensitivity, "VOLUME: %d%%" % (volume*100), "REINICIAR TREINO"]
		for i in 9:
			_button(_menu_rect(i), labels[i])
		_text(Vector2(width*0.5-220, 655), "Toque para alterar. Calibre a inclinação na posição de pilotagem.", 15)
		return
	draw_rect(Rect2(16, 16, 298, 143), INK)
	_text(Vector2(30, 45), "TREINO LIVRE  /  VOLTA %d" % (world.laps.completed+1), 17)
	_text(Vector2(30, 78), _clock(world.clock-world.laps.started_at) if world.laps.running else "--:--.---", 23)
	_text(Vector2(30, 110), "Melhor  "+_clock(world.laps.best_time), 17)
	_text(Vector2(30, 140), "Última   "+_clock(world.laps.last_time)+(" X" if world.laps.last_time > 0 and not world.laps.last_valid else ""), 17)
	_button(Rect2(width-132, 16, 116, 46), "PAUSA")
	_button(Rect2(width-268, 16, 124, 46), "REINICIAR")
	if not world.laps.running:
		_text(Vector2(30, 187), "Cruze a linha para iniciar a volta.", 17)
	elif not world.laps.valid:
		_text(Vector2(30, 187), "VOLTA INVÁLIDA / "+world.laps.reason, 17, Color(1, 0.6, 0.4))
	var center: float = width*0.51
	draw_rect(Rect2(center-105, 550, 210, 150), INK)
	_text(Vector2(center-52, 593), "%3d" % (car.linear_velocity.length()*3.6), 42)
	_text(Vector2(center-63, 621), "km/h    |    "+("R" if reverse else str(car.gearbox.gear)), 20)
	draw_rect(Rect2(center-86, 634, 172, 6), Color(0.3, 0.33, 0.36))
	draw_rect(Rect2(center-86, 634, 172*clampf((car.gearbox.rpm-900)/6000.0, 0, 1), 6), Color.RED if car.gearbox.rpm > 6200 else GREEN)
	_text(Vector2(center-65, 667), "%4d rpm" % car.gearbox.rpm, 19)
	_text(Vector2(center-85, 692), "TC %s   ABS %s" % [("*" if car.tc_active else _on(tc)), ("*" if car.abs_active else _on(abs_enabled))], 15)
	_pedal(_gas_rect(), throttle, GREEN, "ACELERAR")
	_pedal(_brake_rect(), brake, Color(0.85, 0.25, 0.2), "FREIO")
	_button(Rect2(width*0.62, 485, width*0.15, 46), "R > D" if reverse else "D > R")
	_button(Rect2(width*0.8, 445, width*0.17, 46), "FREIO DE MÃO")
	_button(Rect2(20, 555, width*0.39, 145), "INCLINE O CELULAR" if tilt else "DESLIZE PARA VIRAR")
	draw_rect(Rect2(20+width*0.195+steering*width*0.17-5, 655, 10, 18), GREEN)
	if not OS.has_feature("mobile"):
		_text(Vector2(22, 482), "WASD / setas   |   Espaço: freio de mão   |   Q: D/R   |   R: reiniciar   |   P: pausa", 16)

func _text(at: Vector2, text: String, font_size: int, color: Color = Color.WHITE) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _button(area: Rect2, text: String) -> void:
	draw_rect(area, INK)
	var measured: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	_text(area.get_center()-measured*0.5+Vector2(0, 15), text, 19)

func _pedal(area: Rect2, value: float, color: Color, label: String) -> void:
	_button(area, label)
	draw_rect(Rect2(area.position+Vector2(3, area.size.y*(1-value)), Vector2(area.size.x-6, (area.size.y-3)*value)), Color(color, 0.45))

static func _on(value: bool) -> String: return "ON" if value else "OFF"
static func _clock(value: float) -> String:
	if value <= 0:
		return "--:--.---"
	var ms: int = int(minf(value, 5999.999)*1000)
	return "%02d:%02d.%03d" % [floori(ms/60000.0), floori(ms/1000.0)%60, ms%1000]
