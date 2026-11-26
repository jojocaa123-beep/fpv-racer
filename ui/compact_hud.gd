extends RefCounted

func draw(ui) -> void:
	var world = ui.world
	var car = ui.car
	var center: float = ui.width*0.5
	ui.draw_style_box(ui.skin, Rect2(20, 18, 226, 70))
	ui._text(Vector2(32, 40), "VOLTA %d" % (world.laps.completed+1), 12)
	ui._text(Vector2(32, 69), ui._clock(world.clock-world.laps.started_at) if world.laps.running else "--:--.---", 23)
	ui._text(Vector2(164, 40), "MELHOR", 10, Color(0.72, 0.81, 0.85))
	ui._text(Vector2(164, 64), "%.3f" % world.laps.best_time if world.laps.best_time > 0 else "--.---", 13)
	ui.draw_style_box(ui.skin, Rect2(center-78, 18, 156, 70))
	ui._text(Vector2(center-61, 57), "%3d" % (car.linear_velocity.length()*3.6), 34)
	ui._text(Vector2(center+25, 54), "R" if ui.reverse else str(car.gearbox.gear), 27, ui.GREEN)
	ui._text(Vector2(center-52, 76), "km/h", 11)
	ui._text(Vector2(center+21, 76), "MAN" if ui.manual_gears else "AUTO", 10, Color(0.72, 0.81, 0.85))
	ui.draw_rect(Rect2(center-63, 83, 126, 3), Color(0.2, 0.25, 0.28))
	ui.draw_rect(Rect2(center-63, 83, 126*clampf((car.gearbox.rpm-900)/6000, 0, 1), 3), Color(1, 0.35, 0.2) if car.gearbox.rpm > 6200 else ui.GREEN)
	ui.draw_style_box(ui.skin, Rect2(ui.width-268, 78, 252, 50))
	if world.delta_ready:
		ui._text(Vector2(ui.width-254, 112), "%+.3f s" % world.delta, 26, ui.GREEN if world.delta < 0 else Color(1, 0.72, 0.35))
		ui._text(Vector2(ui.width-114, 110), "VS MELHOR", 10, Color(0.72, 0.81, 0.85))
	else:
		ui._text(Vector2(ui.width-254, 108), "COMPLETE UMA VOLTA VÁLIDA", 12)
	if world.clock-world.ghost_saved_at < 4:
		ui._text(Vector2(center-94, 113), "NOVA MELHOR GRAVADA", 13, ui.GREEN)
