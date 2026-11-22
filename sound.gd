extends Node

var car
var controls
var motor: AudioStreamPlayer
var tires: AudioStreamPlayer

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	motor = AudioStreamPlayer.new()
	motor.stream = _loop(false)
	add_child(motor)
	motor.play()
	tires = AudioStreamPlayer.new()
	tires.stream = _loop(true)
	add_child(tires)
	tires.play()

func _process(_dt: float) -> void:
	if motor == null or car == null:
		return
	motor.pitch_scale = clampf(car.gearbox.rpm/3000.0, 0.25, 2.5)
	motor.volume_db = linear_to_db(maxf(0.0001, (0.12+controls.throttle*0.35)*controls.volume))
	var skid: float = clampf((car.max_slip-0.15)/0.55, 0, 1) * clampf(car.linear_velocity.length()/8.0, 0, 1)
	tires.volume_db = linear_to_db(maxf(0.0001, skid*0.25*controls.volume))

static func _loop(noise_only: bool) -> AudioStreamWAV:
	const RATE: int = 22050
	const COUNT: int = 11025
	var data := PackedByteArray()
	data.resize(COUNT*2)
	var random := RandomNumberGenerator.new()
	random.seed = 54872
	var filtered: float = 0.0
	for i in COUNT:
		var phase: float = TAU*100.0*i/RATE
		filtered = lerpf(filtered, random.randf_range(-1, 1), 0.24)
		var fade: float = minf(1, minf(i/128.0, (COUNT-1-i)/128.0))
		var value: float = filtered*0.75*fade if noise_only else sin(phase)*0.35+sin(phase*2)*0.12+sin(phase*4)*0.05
		data.encode_s16(i*2, int(clampf(value, -1, 1)*32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.stereo = false
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = COUNT
	sound.data = data
	return sound
