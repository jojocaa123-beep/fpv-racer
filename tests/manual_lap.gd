extends "res://tests/lap_drive.gd"

func _initialize() -> void:
	manual_run = true
	call_deferred("_run")
