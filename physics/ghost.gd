extends RefCounted

const INTERVAL: float = 0.05
const MAX_FRAMES: int = 12002
const MAX_FILE_BYTES: int = 4194304
const TRACK_ID: String = "club-v1"
var track_length: float = 0.0
var best_time: float = 0.0
var best_sectors := PackedFloat64Array()
var best_times := PackedFloat64Array()
var best_distances := PackedFloat64Array()
var best_poses: Array[Transform3D] = []
var recording: bool = false
var _times := PackedFloat64Array()
var _distances := PackedFloat64Array()
var _poses: Array[Transform3D] = []
var _observed_time: float = 0.0
var _observed_distance: float = 0.0
var _observed_pose := Transform3D.IDENTITY
var _next_time: float = INTERVAL

func has_reference() -> bool:
	return best_times.size() >= 3 and best_time > 0

func begin(pose: Transform3D) -> void:
	cancel_recording()
	if not pose.is_finite() or track_length <= 0: return
	recording = true
	_times.append(0.0)
	_distances.append(0.0)
	_poses.append(pose)
	_observed_time = 0.0
	_observed_distance = 0.0
	_observed_pose = pose
	_next_time = INTERVAL

func cancel_recording() -> void:
	recording = false
	_times = PackedFloat64Array()
	_distances = PackedFloat64Array()
	_poses = []

func sample(elapsed: float, pose: Transform3D, distance: float) -> void:
	if not recording or elapsed <= _observed_time:
		return
	if not is_finite(elapsed) or elapsed > 600 or not pose.is_finite() or not is_finite(distance) or pose.origin.distance_to(_observed_pose.origin) > 35:
		cancel_recording()
		return
	var progress: float = clampf(maxf(distance, _observed_distance), 0, track_length)
	while _next_time <= elapsed+0.0000001:
		if _times.size() >= MAX_FRAMES:
			cancel_recording()
			return
		var fraction: float = clampf((_next_time-_observed_time)/(elapsed-_observed_time), 0, 1)
		_times.append(_next_time)
		_poses.append(_observed_pose.interpolate_with(pose, fraction))
		_distances.append(lerpf(_observed_distance, progress, fraction))
		_next_time += INTERVAL
	_observed_pose = pose
	_observed_time = elapsed
	_observed_distance = progress

func finish(valid: bool, duration: float, pose: Transform3D, sectors: PackedFloat64Array) -> bool:
	if not valid or not recording or duration <= 0 or not is_finite(duration) or sectors.size() != 3:
		cancel_recording()
		return false
	for sector in sectors:
		if not is_finite(sector) or sector <= 0:
			cancel_recording()
			return false
	if absf(sectors[0]+sectors[1]+sectors[2]-duration) > 0.001:
		cancel_recording()
		return false
	sample(duration, pose, track_length)
	if not recording or _times.size() < 3:
		cancel_recording()
		return false
	if duration > _times[-1]+0.000001:
		_times.append(duration)
		_poses.append(pose)
		_distances.append(track_length)
	else:
		_times[-1] = duration
		_poses[-1] = pose
		_distances[-1] = track_length
	var faster: bool = best_time <= 0 or duration < best_time-0.0001
	if faster:
		best_time = duration
		best_times = _times.duplicate()
		best_poses = _poses.duplicate()
		best_distances = _distances.duplicate()
		best_sectors = sectors.duplicate()
	cancel_recording()
	return faster

func _lower_index(values: PackedFloat64Array, value: float) -> int:
	var low: int = 0
	var high: int = values.size()-1
	while low+1 < high:
		var middle: int = (low+high)>>1
		if values[middle] <= value: low = middle
		else: high = middle
	return low

func pose_at(elapsed: float) -> Transform3D:
	if not has_reference(): return Transform3D.IDENTITY
	if elapsed >= best_time: return best_poses[-1]
	var index: int = _lower_index(best_times, maxf(elapsed, 0))
	var weight: float = clampf(inverse_lerp(best_times[index], best_times[index+1], elapsed), 0, 1)
	return best_poses[index].interpolate_with(best_poses[index+1], weight)

func time_at_distance(distance: float) -> float:
	if not has_reference() or distance <= 0: return 0.0
	if distance >= track_length: return best_time
	var index: int = _lower_index(best_distances, distance)
	var span: float = best_distances[index+1]-best_distances[index]
	var weight: float = clampf((distance-best_distances[index])/maxf(span, 0.000001), 0, 1)
	return lerpf(best_times[index], best_times[index+1], weight)

func save_best(path: String) -> Error:
	if not has_reference(): return ERR_INVALID_DATA
	var frames: Array = []
	for i in best_times.size():
		var p: Vector3 = best_poses[i].origin
		var q: Quaternion = best_poses[i].basis.get_rotation_quaternion()
		frames.append([best_times[i], p.x, p.y, p.z, q.x, q.y, q.z, q.w, best_distances[i]])
	var encoded: String = JSON.stringify({"version": 1, "track": TRACK_ID, "length": track_length, "time": best_time, "sectors": Array(best_sectors), "frames": frames})
	if encoded.length() > MAX_FILE_BYTES: return ERR_OUT_OF_MEMORY
	var file := FileAccess.open(path+".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(encoded)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK: return write_error
	return DirAccess.rename_absolute(path+".tmp", path)

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func load_best(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES: return false
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK: return false
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1 or data.get("track") != TRACK_ID: return false
	if not _number(data.get("length")) or absf(float(data.length)-track_length) > 0.01 or not _number(data.get("time")): return false
	var duration: float = float(data.time)
	if duration <= 0 or duration > 600: return false
	if not data.get("sectors") is Array or data.sectors.size() != 3 or not data.get("frames") is Array: return false
	var sectors := PackedFloat64Array()
	for value in data.sectors:
		if not _number(value) or float(value) <= 0: return false
		sectors.append(float(value))
	if absf(sectors[0]+sectors[1]+sectors[2]-duration) > 0.001: return false
	if data.frames.size() < 3 or data.frames.size() > MAX_FRAMES: return false
	var times := PackedFloat64Array()
	var distances := PackedFloat64Array()
	var poses: Array[Transform3D] = []
	for row in data.frames:
		if not row is Array or row.size() != 9: return false
		for value in row:
			if not _number(value): return false
		var t: float = float(row[0])
		var progress: float = float(row[8])
		var q := Quaternion(row[4], row[5], row[6], row[7])
		var p := Vector3(row[1], row[2], row[3])
		if absf(q.length_squared()-1.0) > 0.05 or p.length() > 5000 or t < 0 or t > duration+0.000001 or progress < 0 or progress > track_length+0.001: return false
		if not times.is_empty() and (t <= times[-1] or progress < distances[-1]-0.000001 or p.distance_to(poses[-1].origin) > 35): return false
		times.append(t)
		distances.append(progress)
		poses.append(Transform3D(Basis(q.normalized()), p))
	if times[0] != 0 or distances[0] != 0 or absf(times[-1]-duration) > 0.000001 or absf(distances[-1]-track_length) > 0.001: return false
	best_time = duration
	best_sectors = sectors
	best_times = times
	best_distances = distances
	best_poses = poses
	return true
