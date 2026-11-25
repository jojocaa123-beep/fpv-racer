extends SceneTree

const Game = preload("res://main.tscn")
const Track = preload("res://physics/track.gd")
const Driving = preload("res://physics/driving_math.gd")
var game
var manual_run: bool = false
var max_error: float = 0.0
var top_speed: float = 0.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = Game.instantiate()
	root.add_child(game)
	game.controls.simulated = true
	game.controls.manual_gears = manual_run
	for i in 150:
		await physics_frame
	var points: PackedVector3Array = game.samples
	var car = game.car
	var previous_completed: int = 0
	var bad_laps: int = 0
	for frame in 10800:
		var closest: int = 0
		var distance: float = INF
		for i in points.size():
			var d: float = car.global_position.distance_squared_to(points[i])
			if d < distance:
				distance = d
				closest = i
		if manual_run:
			if car.gearbox.rpm > 6200: car.request_shift(1)
			elif car.gearbox.rpm < 2100: car.request_shift(-1)
		var forward: Vector3 = -car.global_basis.z
		var right: Vector3 = car.global_basis.x
		var speed: float = car.linear_velocity.length()
		top_speed = maxf(top_speed, speed)
		var target_speed: float = 22.0
		var accumulated: float = 0.0
		for ahead in 30:
			var k: int = (closest+ahead) % points.size()
			var a: Vector3 = Track.tangent(points, k)
			var b: Vector3 = Track.tangent(points, (k+2)%points.size())
			var spacing: float = maxf(1, points[k].distance_to(points[(k+2)%points.size()]))
			var curvature: float = a.angle_to(b) / spacing
			var corner_speed: float = clampf(sqrt(5.0 / maxf(0.001, curvature)), 7, 22)
			target_speed = minf(target_speed, sqrt(corner_speed*corner_speed+2.0*4.0*accumulated))
			accumulated += points[k].distance_to(points[(k+1)%points.size()])
		var lookahead: float = 6.0 + speed*0.4
		var target: Vector3 = points[closest]
		var length: float = 0.0
		for ahead in 30:
			var k: int = (closest+ahead)%points.size()
			length += points[k].distance_to(points[(k+1)%points.size()])
			target = points[(k+1)%points.size()]
			if length >= lookahead:
				break
		var offset: Vector3 = target-car.global_position
		var alpha: float = atan2(offset.dot(right), offset.dot(forward))
		var desired: float = atan(2.0*2.4*sin(alpha)/maxf(3, Vector2(offset.x, offset.z).length()))
		var max_steer: float = Driving.steer_limit(speed, 1.0)
		game.controls.steering = move_toward(game.controls.steering, clampf(desired/maxf(0.001, max_steer), -1, 1), 3.0/60.0)
		var error: float = target_speed-speed
		game.controls.throttle = clampf(error*0.4+0.12, 0, 1) if error > -0.3 else 0.0
		game.controls.brake = clampf(-error*0.25, 0, 1) if error < -0.5 else 0.0
		# Mede distancia perpendicular, sem contar a distancia longitudinal ate
		# a primeira amostra durante a aproximacao da linha de largada.
		var lateral: float = absf((car.global_position-points[closest]).dot(Track.tangent(points, closest).cross(Vector3.UP)))
		max_error = maxf(max_error, lateral)
		if car.global_basis.y.dot(Vector3.UP) < 0.6 or lateral > 6:
			print("FAIL saiu da pista/capotou frame=", frame, " lateral=", lateral)
			quit(1)
			return
		if game.laps.completed != previous_completed:
			previous_completed = game.laps.completed
			if not game.laps.last_valid:
				bad_laps += 1
			print("LAP ", previous_completed, " time=", game.laps.last_time, " valid=", game.laps.last_valid)
		if previous_completed >= 2:
			if not game.ghost.has_reference() or game.ghost.best_times.size() < 500 or game.ghost.best_sectors.size() != 3 or (game.ghost.best_time-game.laps.last_time > 0.01):
				print("FAIL duas voltas nao geraram fantasma e setores consistentes")
				quit(1)
				return
			print("GHOST frames=", game.ghost.best_times.size(), " duration=", game.ghost.best_time, " sectors=", game.ghost.best_sectors)
			print("RESULT mode=", "manual" if manual_run else "automatic", " laps=", previous_completed, " invalid=", bad_laps, " top_kmh=", top_speed*3.6, " max_lateral_m=", max_error)
			game.queue_free()
			await process_frame
			quit(0 if bad_laps == 0 else 1)
			return
		await physics_frame
	print("FAIL tempo limite sem completar duas voltas")
	quit(1)
