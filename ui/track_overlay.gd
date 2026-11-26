extends RefCounted

func draw(ui, compact: bool = false) -> void:
	var world = ui.world
	var guide = world.navigation
	var center: Vector2 = Vector2(82, 160) if compact else Vector2(126, 356)
	var scale: float = 91.0 if compact else 166.0
	ui.draw_style_box(ui.skin, Rect2(20, 104, 124, 116) if compact else Rect2(20, 246, 212, 222))
	if not compact: ui._text(Vector2(34, 269), "CIRCUITO / %d m" % roundi(guide.length), 12)
	var route := PackedVector2Array()
	for point in guide.map_route: route.append(center+point*scale)
	ui.draw_polyline(route, Color(0.03, 0.06, 0.08), 7.0, true)
	ui.draw_polyline(route, Color(0.7, 0.8, 0.85), 2.5, true)
	var start: Vector2 = route[0]
	var right: Vector2 = (route[1]-route[0]).orthogonal().normalized()
	ui.draw_line(start-right*6, start+right*6, Color.WHITE, 3.0, true)
	if ui.ghost_enabled and world.ghost.has_reference() and world.laps.running and world.laps.valid:
		var pose: Transform3D = world.ghost.pose_at(world.clock-world.laps.started_at)
		ui.draw_circle(center+guide.map_position(pose.origin)*scale, 4.5, Color(0.25, 0.82, 1), true, -1, true)
	var at: Vector2 = (center+guide.map_position(ui.car.global_position)*scale).clamp(center-(Vector2(52, 47) if compact else Vector2(87, 78)), center+(Vector2(52, 47) if compact else Vector2(87, 78)))
	var forward := Vector2(-ui.car.global_basis.z.x, -ui.car.global_basis.z.z).normalized()
	if forward.length_squared() < 0.1: forward = Vector2.UP
	var lateral := forward.orthogonal()
	ui.draw_colored_polygon(PackedVector2Array([at+forward*8, at-forward*5+lateral*5, at-forward*5-lateral*5]), ui.GREEN)
	if not compact: ui._text(Vector2(34, 454), "VOCÊ", 11, ui.GREEN)
	if not compact and ui.ghost_enabled and world.ghost.has_reference(): ui._text(Vector2(100, 454), "FANTASMA", 11, Color(0.25, 0.82, 1))
	var turn: Dictionary = guide.next_turn(world.track_distance)
	var side: int = int(turn.side)
	var cue_y: float = 140.0 if compact else 188.0
	ui.draw_style_box(ui.skin, Rect2(ui.width-268, cue_y, 252, 44 if compact else 58))
	var tint: Color = Color(1, 0.72, 0.35) if side != 0 and float(turn.meters) < 40 else Color.WHITE
	var origin := Vector2(ui.width-246, cue_y+(27 if compact else 31))
	var arrow := PackedVector2Array([origin+Vector2(0, 14), origin+Vector2(0, -8), origin+Vector2(side*15, -8)]) if side != 0 else PackedVector2Array([origin+Vector2(0, 14), origin+Vector2(0, -12)])
	ui.draw_polyline(arrow, tint, 3.0, true)
	var tip: Vector2 = arrow[-1]
	ui.draw_colored_polygon(PackedVector2Array([tip+Vector2(side*5, 0), tip+Vector2(-side*3, -6), tip+Vector2(-side*3, 6)]) if side != 0 else PackedVector2Array([tip+Vector2(0, -5), tip+Vector2(-6, 3), tip+Vector2(6, 3)]), tint)
	ui._text(Vector2(ui.width-220, cue_y+(18 if compact else 23)), "PRÓXIMA: "+("DIREITA" if side > 0 else "ESQUERDA") if side != 0 else "RETA", 14, tint)
	ui._text(Vector2(ui.width-220, cue_y+(36 if compact else 46)), "~%d m" % (roundi(float(turn.meters)/5.0)*5) if side != 0 else "Sem curva próxima", 13)
