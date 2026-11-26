extends Control

const CompactHUD = preload("res://ui/compact_hud.gd")
const TrackOverlay = preload("res://ui/track_overlay.gd")
const MotionSteering = preload("res://ui/motion_steering.gd")
enum SteeringMode { MOTION, ARROWS, SLIDE }
enum Role { SLIDE, GAS, BRAKE, HANDBRAKE, LEFT, RIGHT, SHIFT_DOWN, SHIFT_UP }
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
var steering_mode: int = SteeringMode.MOTION if OS.has_feature("mobile") else SteeringMode.ARROWS
var sensitivity: float = 2.5
var fov: float = 65.0
var volume: float = 0.6
var camera_motion: bool = true
var graphics_quality: int = 1
var ghost_enabled: bool = true
var manual_gears: bool = false
var track_guide: bool = true
var compact_hud: bool = true
var compact_overlay = CompactHUD.new()
var track_overlay = TrackOverlay.new()
var simulated: bool = false
var paused: bool = false
var pointers: Dictionary = {}
var arrows_active: Dictionary = {}
var anchor: float = 0.0
var anchor_steering: float = 0.0
var steering_target: float = 0.0
var motion = MotionSteering.new()
var width: float = 1280.0
var ui_scale: float = 1.0
var origin := Vector2.ZERO
var font: Font
var skin := StyleBoxFlat.new()
var active_skin := StyleBoxFlat.new()
const INK := Color(0.025, 0.04, 0.055, 0.64)
const GREEN := Color(0.35, 0.85, 0.58)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	for plate in [skin, active_skin]:
		plate.set_corner_radius_all(10)
		plate.set_border_width_all(1)
		plate.border_color = Color(0.8, 0.9, 1.0, 0.18)
	skin.bg_color = INK
	active_skin.bg_color = Color(0.12, 0.45, 0.3, 0.85)
	_metrics()
	var prefs := ConfigFile.new()
	if prefs.load("user://preferences.cfg") == OK:
		steer_assist = bool(prefs.get_value("driving", "steer_assist", true))
		tc = bool(prefs.get_value("driving", "tc", true))
		abs_enabled = bool(prefs.get_value("driving", "abs", true))
		if prefs.has_section_key("driving", "steering_mode"):
			steering_mode = clampi(int(prefs.get_value("driving", "steering_mode")), 0, 2)
		elif prefs.has_section_key("driving", "tilt"):
			steering_mode = SteeringMode.MOTION if bool(prefs.get_value("driving", "tilt")) else SteeringMode.ARROWS
		fov = clampf(float(prefs.get_value("driving", "fov", 65.0)), 55, 75)
		sensitivity = clampf(float(prefs.get_value("driving", "sensitivity", 2.5)), 1.5, 3.5)
		volume = clampf(float(prefs.get_value("driving", "volume", 0.6)), 0, 1)
		compact_hud = bool(prefs.get_value("driving", "compact_hud", true))
		manual_gears = bool(prefs.get_value("driving", "manual_gears", false))
		track_guide = bool(prefs.get_value("driving", "track_guide", true))
		ghost_enabled = bool(prefs.get_value("driving", "ghost_enabled", true))
		camera_motion = bool(prefs.get_value("driving", "camera_motion", true))
		graphics_quality = clampi(int(prefs.get_value("driving", "graphics_quality", 1)), 0, 2)
	motion.calibrate()

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
		motion.calibrate()
	origin = area.position
	ui_scale = next_scale
	width = next_width

func _physics_process(dt: float) -> void:
	_metrics()
	queue_redraw()
	if simulated:
		return
	var target: float = steering_target
	if steering_mode == SteeringMode.MOTION:
		var gravity := Input.get_gravity()
		if gravity.length_squared() < 1.0:
			gravity = Input.get_accelerometer()
		target = motion.step(dt, gravity, Input.get_gyroscope(), sensitivity)
	if paused:
		return
	if steering_mode == SteeringMode.ARROWS or arrows_active.values().has(true):
		target = _arrow_target()
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		target = -1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		target = 1.0
	steering = move_toward(steering, target, dt*(4.2 if arrows_active.values().has(true) else 6.0))
	if not pointers.values().has(Role.GAS):
		throttle = 1.0 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0.0
	if not pointers.values().has(Role.BRAKE):
		brake = 1.0 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) else 0.0
	handbrake = pointers.values().has(Role.HANDBRAKE) or Input.is_physical_key_pressed(KEY_SPACE)

func _input(event: InputEvent) -> void:
	if simulated:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			set_paused(not paused)
		elif not paused and event.keycode == KEY_R:
			world.restart()
		elif not paused and event.keycode == KEY_E:
			car.request_shift(1)
		elif not paused and event.keycode == KEY_C:
			car.request_shift(-1)
		elif not paused and event.keycode == KEY_Q:
			_toggle_reverse()
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
		for i in 16:
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
	if _mode_rect().has_point(p):
		_set_mode((steering_mode+1)%3)
		return
	if steering_mode == SteeringMode.MOTION and _calibrate_rect().has_point(p):
		var direction: bool = reverse
		clear()
		reverse = direction
		motion.calibrate()
		return
	if _reverse_rect().has_point(p):
		_toggle_reverse()
		return
	var role: int = -1
	if manual_gears and _shift_rect(false).has_point(p):
		role = Role.SHIFT_DOWN
	elif manual_gears and _shift_rect(true).has_point(p):
		role = Role.SHIFT_UP
	elif _handbrake_rect().has_point(p):
		role = Role.HANDBRAKE
	elif _gas_rect().has_point(p):
		role = Role.GAS
	elif _brake_rect().has_point(p):
		role = Role.BRAKE
	elif steering_mode == SteeringMode.SLIDE and _slide_rect().has_point(p):
		role = Role.SLIDE
	elif steering_mode != SteeringMode.SLIDE:
		if _arrow_rect(false).has_point(p): role = Role.LEFT
		if _arrow_rect(true).has_point(p): role = Role.RIGHT
	if role >= 0 and not pointers.values().has(role):
		pointers[id] = role
		if role == Role.SHIFT_DOWN or role == Role.SHIFT_UP:
			car.request_shift(1 if role == Role.SHIFT_UP else -1)
		if role == Role.SLIDE:
			anchor = p.x
			anchor_steering = steering
		_move(id, p)

func _move(id: int, p: Vector2) -> void:
	var role: int = int(pointers.get(id, -1))
	if role == Role.SLIDE:
		steering_target = clampf(anchor_steering+(p.x-anchor)/(width*0.14)*sensitivity/2.5, -1, 1)
	elif role == Role.GAS:
		throttle = clampf(inverse_lerp(_gas_rect().end.y, _gas_rect().position.y+_gas_rect().size.y*0.15, p.y), 0, 1)
	elif role == Role.BRAKE:
		brake = clampf(inverse_lerp(_brake_rect().end.y, _brake_rect().position.y+_brake_rect().size.y*0.15, p.y), 0, 1)
	elif role == Role.HANDBRAKE:
		handbrake = true
	elif role == Role.LEFT or role == Role.RIGHT:
		arrows_active[id] = _arrow_rect(role == Role.RIGHT).grow(12).has_point(p)

func _arrow_held(right: bool) -> bool:
	for id in arrows_active:
		if arrows_active[id] and int(pointers.get(id, -1)) == (Role.RIGHT if right else Role.LEFT):
			return true
	return false

func _arrow_target() -> float:
	return float(_arrow_held(true))-float(_arrow_held(false))

func _end(id: int) -> void:
	match int(pointers.get(id, -1)):
		Role.SLIDE: steering_target = 0.0
		Role.GAS: throttle = 0.0
		Role.BRAKE: brake = 0.0
		Role.HANDBRAKE: handbrake = false
	pointers.erase(id)
	arrows_active.erase(id)

func _set_mode(mode: int, save: bool = true) -> void:
	var direction: bool = reverse
	clear()
	reverse = direction
	steering_mode = clampi(mode, 0, 2)
	motion.calibrate()
	if save:
		_save_preferences()
	queue_redraw()

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
	arrows_active.clear()

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
		1: _set_mode((steering_mode+1)%3, false)
		2: motion.calibrate()
		3: steer_assist = not steer_assist
		4: abs_enabled = not abs_enabled
		5: tc = not tc
		6: fov = 55.0 if fov >= 75 else fov+5
		7: sensitivity = 1.5 if sensitivity >= 3.5 else sensitivity+0.5
		8: volume = 0.0 if volume >= 0.99 else minf(1, volume+0.2)
		10:
			camera_motion = not camera_motion
			if not camera_motion: car.cockpit.reset_view()
		11:
			graphics_quality = (graphics_quality+1)%3
			world.apply_graphics_quality()
		12: ghost_enabled = not ghost_enabled
		13:
			var direction: bool = reverse
			clear()
			reverse = direction
			manual_gears = not manual_gears
			car.gearbox.manual = manual_gears
		14: track_guide = not track_guide
		15: compact_hud = not compact_hud
		9:
			world.restart()
			motion.calibrate()
			set_paused(false)
	if index > 0:
		_save_preferences()

func _save_preferences() -> void:
	var prefs := ConfigFile.new()
	for key in ["steer_assist", "tc", "steering_mode", "fov", "sensitivity", "volume", "camera_motion", "graphics_quality", "ghost_enabled", "manual_gears", "track_guide", "compact_hud"]:
		prefs.set_value("driving", key, get(key))
	prefs.set_value("driving", "abs", abs_enabled)
	prefs.save("user://preferences.cfg")

func _gas_rect() -> Rect2: return Rect2(width-144, 568, 120, 128)
func _brake_rect() -> Rect2: return Rect2(width-284, 568, 120, 128)
func _handbrake_rect() -> Rect2: return Rect2(width-144, 514, 120, 42)
func _reverse_rect() -> Rect2: return Rect2(width-284, 514, 120, 42)
func _arrow_rect(right: bool) -> Rect2: return Rect2(172 if right else 24, 572, 128, 124)
func _slide_rect() -> Rect2: return Rect2(24, 572, minf(380, width*0.34), 124)
func _mode_rect() -> Rect2: return Rect2(24, 514, 180, 42)
func _calibrate_rect() -> Rect2: return Rect2(216, 514, 134, 42)
func _shift_rect(up: bool) -> Rect2: return Rect2(width-144 if up else width-284, 420, 120, 78)
func _menu_rect(i: int) -> Rect2: return Rect2(width*0.5-354+(i%2)*362, 138+floori(i/2.0)*60, 346, 50)
func _mode_name() -> String: return ["GIROSCÓPIO", "SETAS", "DESLIZAR"][steering_mode]

func _draw() -> void:
	if car == null or font == null:
		return
	draw_set_transform(origin, 0, Vector2.ONE*ui_scale)
	if paused:
		draw_rect(Rect2(0, 0, width, 720), Color(0.015, 0.025, 0.04, 0.95))
		_text(Vector2(width*0.5-230, 82), "PAUSA / AJUSTES", 28)
		var labels: Array[String] = ["RETOMAR", "DIREÇÃO: "+_mode_name(), "CALIBRAR INCLINAÇÃO", "AJUDA DE DIREÇÃO: "+_on(steer_assist), "ABS: "+_on(abs_enabled), "CONTROLE DE TRAÇÃO: "+_on(tc), "CAMPO DE VISÃO: %d" % fov, "SENSIBILIDADE: %.1f" % sensitivity, "VOLUME: %d%%" % (volume*100), "REINICIAR TREINO", "CÂMERA: "+("DINÂMICA" if camera_motion else "FIXA"), "GRÁFICOS: "+["ECONÔMICO", "EQUILIBRADO", "ALTO"][graphics_quality], "FANTASMA: "+_on(ghost_enabled), "CÂMBIO: "+("MANUAL" if manual_gears else "AUTOMÁTICO"), "MAPA E CURVAS: "+_on(track_guide), "HUD: "+("COMPACTO" if compact_hud else "COMPLETO")]
		for i in 16:
			_button(_menu_rect(i), labels[i], false, 17)
		_text(Vector2(width*0.5-230, 658), "Calibre segurando o celular na posição de pilotagem.", 15)
		_text(Vector2(width*0.5-230, 683), "Câmbio manual: botões +/−; teclas E/C no PC.", 15, GREEN)
		return
	if not compact_hud:
		draw_style_box(skin, Rect2(20, 18, 238, 105))
		_text(Vector2(32, 43), "CONTRA O RELÓGIO  /  VOLTA %d" % (world.laps.completed+1), 14)
		_text(Vector2(32, 72), _clock(world.clock-world.laps.started_at) if world.laps.running else "--:--.---", 23)
		_text(Vector2(32, 94), "Melhor  "+_clock(world.laps.best_time), 13)
		_text(Vector2(32, 113), "Última   "+_clock(world.laps.last_time)+(" X" if world.laps.last_time > 0 and not world.laps.last_valid else ""), 13)
	_button(Rect2(width-132, 16, 116, 46), "PAUSA")
	_button(Rect2(width-268, 16, 124, 46), "REINICIAR")
	if not world.laps.running:
		_text(Vector2(width*0.5-164, 106) if compact_hud else Vector2(24, 146), "Cruze a linha para iniciar a volta.", 14)
	elif not world.laps.valid:
		_text(Vector2(width*0.5-164, 106) if compact_hud else Vector2(24, 146), "VOLTA INVÁLIDA / "+world.laps.reason, 14, Color(1, 0.6, 0.4))
	_button(_mode_rect(), _mode_name(), false, 16)
	if steering_mode == SteeringMode.MOTION:
		_button(_calibrate_rect(), "CALIBRAR", false, 15)
		_text(Vector2(24, 500), "INCLINE PARA VIRAR" if motion.ready else "SEGURE O CELULAR E CALIBRE", 14, GREEN)
	if steering_mode == SteeringMode.SLIDE:
		_button(_slide_rect(), "DESLIZE PARA VIRAR", false, 16)
		draw_line(Vector2(48, 663), Vector2(_slide_rect().end.x-24, 663), Color(0.8, 0.9, 1, 0.3), 3)
		draw_circle(Vector2(_slide_rect().get_center().x+steering*(_slide_rect().size.x*0.42), 663), 9, GREEN)
	else:
		_arrow(false)
		_arrow(true)
	var center_x: float = width*0.5
	if not compact_hud:
		draw_style_box(skin, Rect2(center_x-90, 18, 180, 98))
		_text(Vector2(center_x-70, 60), "%3d" % (car.linear_velocity.length()*3.6), 36)
		_text(Vector2(center_x+20, 56), ("R" if reverse else str(car.gearbox.gear))+(" M" if manual_gears else " A"), 24, GREEN)
		_text(Vector2(center_x-62, 79), "km/h   %4d rpm" % car.gearbox.rpm, 13)
		draw_rect(Rect2(center_x-72, 90, 144, 4), Color(0.3, 0.33, 0.36))
		draw_rect(Rect2(center_x-72, 90, 144*clampf((car.gearbox.rpm-900)/6000.0, 0, 1), 4), Color.RED if car.gearbox.rpm > 6200 else GREEN)
		_text(Vector2(center_x-62, 110), "TC %s   ABS %s" % [("*" if car.tc_active else _on(tc)), ("*" if car.abs_active else _on(abs_enabled))], 12)
		_timing_hud()
		_feedback_hud(center_x)
	else:
		compact_overlay.draw(self)
	if track_guide: track_overlay.draw(self, compact_hud)
	if car.gearbox.overrev_block_left > 0:
		_text(Vector2(center_x-112, 138), "GIRO ALTO: REDUÇÃO BLOQUEADA", 12, Color(1, 0.7, 0.35))
	_pedal(_gas_rect(), throttle, GREEN, "ACELERAR")
	_pedal(_brake_rect(), brake, Color(0.85, 0.25, 0.2), "FREIO")
	if manual_gears:
		_button(_shift_rect(false), "−  REDUZIR", false, 17)
		_button(_shift_rect(true), "+  SUBIR", false, 17)
	_button(_reverse_rect(), "R > D" if reverse else "D > R", false, 16)
	_button(_handbrake_rect(), "FREIO DE MÃO", handbrake, 13)
	if not OS.has_feature("mobile"):
		_text(Vector2(center_x-178, 715), "WASD · Espaço: freio de mão · E/C: marchas · P: pausa", 12)

func _timing_hud() -> void:
	var reference = world.ghost
	draw_style_box(skin, Rect2(width-268, 78, 252, 100))
	_text(Vector2(width-254, 100), "VS MELHOR VOLTA GRAVADA", 12)
	var tint: Color = GREEN if world.delta < 0 else Color(1, 0.7, 0.35)
	_text(Vector2(width-254, 136), "%+.3f s" % world.delta if world.delta_ready else "--.--- s", 30, tint if world.delta_ready else Color.WHITE)
	_text(Vector2(width-254, 163), "REF "+_clock(reference.best_time) if reference.has_reference() else "COMPLETE UMA VOLTA VÁLIDA", 13)
	var showing_last: bool = world.laps.last_time > 0 and world.clock-world.laps.started_at < 4
	var values := PackedFloat64Array()
	if showing_last:
		values = world.laps.last_sectors
	else:
		for i in world.laps.split_times.size():
			values.append(world.laps.split_times[i]-(world.laps.split_times[i-1] if i > 0 else 0.0))
	for i in 3:
		var at := Vector2(20+i*80, 176)
		draw_style_box(skin, Rect2(at, Vector2(74, 51)))
		_text(at+Vector2(8, 18), "S%d" % (i+1), 12)
		var seconds: float = values[i] if values.size() > i else 0.0
		var color := Color.WHITE
		if seconds > 0 and reference.best_sectors.size() == 3:
			color = GREEN if seconds <= reference.best_sectors[i]+0.0001 else Color(1, 0.7, 0.35)
		if (showing_last and not world.laps.last_valid) or (not showing_last and not world.laps.valid): color = Color(1, 0.45, 0.35)
		_text(at+Vector2(8, 39), "%.3f" % seconds if seconds > 0 else "--.---", 13, color)
	if world.clock-world.ghost_saved_at < 4:
		_text(Vector2(width-264, 200), "NOVA MELHOR GRAVADA", 14, GREEN)

func _feedback_hud(center_x: float) -> void:
	draw_style_box(skin, Rect2(center_x-310, 18, 204, 98))
	var at := Vector2(center_x-264, 61)
	var line := Color(0.7, 0.8, 0.9, 0.32)
	draw_arc(at, 28, 0, TAU, 32, line, 1.0, true)
	draw_arc(at, 14, 0, TAU, 24, line, 1.0, true)
	draw_line(at-Vector2(30, 0), at+Vector2(30, 0), line)
	draw_line(at-Vector2(0, 30), at+Vector2(0, 30), line)
	var force := Vector2(car.feedback.local_g.x, car.feedback.local_g.z)
	draw_circle(at+force.limit_length(1.5)*(28.0/1.5), 4, GREEN, true, -1, true)
	_text(Vector2(at.x-22, 108), "%.2f G" % force.length(), 13)
	_text(Vector2(center_x-214, 39), "PNEUS", 12)
	var slipping: bool = false
	for i in 4:
		var slip: Vector2 = car.wheel_slips[i]
		var stress: float = clampf(maxf(absf(slip.x)/0.4, absf(slip.y)/0.22), 0, 1)
		var tint: Color = GREEN.lerp(Color(1, 0.72, 0.18), stress*2.0) if stress < 0.5 else Color(1, 0.72, 0.18).lerp(Color(1, 0.3, 0.18), (stress-0.5)*2.0)
		if not car.grounded[i]: tint = Color(0.35, 0.4, 0.45)
		var tire := Rect2(center_x-209+(i%2)*34, 46+floori(i/2.0)*23, 18, 18)
		draw_rect(tire, Color(tint, 0.25))
		draw_rect(tire, tint, false, 1.5)
		draw_rect(Rect2(tire.position+Vector2(3, tire.size.y*(1-stress)), Vector2(12, tire.size.y*stress)), tint)
		slipping = slipping or (car.grounded[i] and stress > 0.7)
	_text(Vector2(center_x-213, 108), "DESLIZA" if slipping and car.linear_velocity.length() > 3 else "CONTATO", 11, Color(1, 0.65, 0.25) if slipping else Color.WHITE)

func _arrow(right: bool) -> void:
	var area := _arrow_rect(right)
	draw_style_box(active_skin if _arrow_held(right) else skin, area)
	var at := area.get_center()
	var sign_x: float = 1.0 if right else -1.0
	draw_colored_polygon(PackedVector2Array([at+Vector2(sign_x*23, 0), at+Vector2(-sign_x*15, -25), at+Vector2(-sign_x*15, 25)]), GREEN if _arrow_held(right) else Color.WHITE)

func _text(at: Vector2, text: String, font_size: int, color: Color = Color.WHITE) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _button(area: Rect2, text: String, active: bool = false, font_size: int = 19) -> void:
	draw_style_box(active_skin if active else skin, area)
	var measured: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_text(Vector2(area.get_center().x-measured.x*0.5, area.get_center().y+font_size*0.35), text, font_size)

func _pedal(area: Rect2, value: float, color: Color, label: String) -> void:
	draw_style_box(skin, area)
	var inner := area.grow(-5)
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y-inner.size.y*value), Vector2(inner.size.x, inner.size.y*value)), Color(color, 0.4))
	var measured: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	_text(Vector2(area.get_center().x-measured.x*0.5, area.get_center().y+6), label, 16)

static func _on(value: bool) -> String: return "ON" if value else "OFF"
static func _clock(value: float) -> String:
	if value <= 0:
		return "--:--.---"
	var ms: int = int(minf(value, 5999.999)*1000)
	return "%02d:%02d.%03d" % [floori(ms/60000.0), floori(ms/1000.0)%60, ms%1000]
