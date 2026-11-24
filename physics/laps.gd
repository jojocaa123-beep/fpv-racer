extends RefCounted

const Track = preload("res://physics/track.gd")
var centers: PackedVector3Array = []
var forwards: PackedVector3Array = []
var previous := Vector3.ZERO
var previous_time: float = 0.0
var has_previous: bool = false
var expected: int = 0
var running: bool = false
var valid: bool = true
var reason: String = ""
var started_at: float = 0.0
var completed: int = 0
var last_time: float = 0.0
var last_valid: bool = false
var best_time: float = 0.0
var split_times := PackedFloat64Array()
var last_sectors := PackedFloat64Array()
var crossing_gate: int = -1
var crossing_time: float = 0.0

func configure(points: PackedVector3Array) -> void:
	centers.clear()
	forwards.clear()
	for i in 8:
		var k: int = int(i * points.size() / 8.0)
		centers.append(points[k])
		forwards.append(Track.tangent(points, k))

func reset_attempt() -> void:
	has_previous = false
	split_times = PackedFloat64Array()
	crossing_gate = -1
	expected = 0
	running = false
	valid = true
	reason = ""

func invalidate(message: String) -> void:
	if running and valid:
		valid = false
		reason = message

func step(position: Vector3, now: float, invalid_reason: String = "") -> void:
	crossing_gate = -1
	if not position.is_finite() or not is_finite(now):
		reset_attempt()
		return
	if has_previous and now <= previous_time:
		return
	if not invalid_reason.is_empty():
		invalidate(invalid_reason)
	if has_previous and position.distance_to(previous) > 35:
		reset_attempt()
	if has_previous:
		var before: float = (previous - centers[expected]).dot(forwards[expected])
		var after: float = (position - centers[expected]).dot(forwards[expected])
		if before < 0 and after >= 0 and after-before > 0.00001:
			var fraction: float = -before / (after-before)
			var crossing: Vector3 = previous.lerp(position, fraction)
			var right: Vector3 = forwards[expected].cross(Vector3.UP)
			if absf((crossing-centers[expected]).dot(right)) <= 6:
				var crossed_at: float = lerpf(previous_time, now, fraction)
				crossing_gate = expected
				crossing_time = crossed_at
				if running and expected in [3, 5]:
					split_times.append(crossed_at-started_at)
				if expected == 0:
					if running:
						last_time = crossed_at - started_at
						last_sectors = PackedFloat64Array([split_times[0], split_times[1]-split_times[0], last_time-split_times[1]]) if split_times.size() == 2 else PackedFloat64Array()
						last_valid = valid
						completed += 1
						if valid and (best_time <= 0 or last_time < best_time):
							best_time = last_time
					split_times = PackedFloat64Array()
					started_at = crossed_at
					running = true
					valid = true
					reason = ""
				expected = (expected + 1) % 8
	previous = position
	previous_time = now
	has_previous = true
	if not invalid_reason.is_empty():
		invalidate(invalid_reason)
