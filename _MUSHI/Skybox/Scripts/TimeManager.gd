# res://systems/environment/time_manager.gd
@tool
extends Node
class_name TimeManager

signal time_changed(new_time: float)

@export_group("Time Settings")
@export var start_time: float = 7.0
@export_range(0.0, 24.0, 0.1) var current_time: float = 7.0:
	set(value):
		current_time = value
		time_changed.emit(current_time)
		
@export var time_scale: float = 1.0
@export var paused: bool = false
@export var auto_start: bool = true

func _ready():
	current_time = start_time
	if auto_start and not Engine.is_editor_hint():
		time_changed.emit(current_time)

func _process(delta):
	# Only advance time in runtime
	if Engine.is_editor_hint() or paused:
		return
	
	current_time += delta * time_scale / 60.0
	
	if current_time >= 24.0:
		current_time -= 24.0
	
	time_changed.emit(current_time)

func set_time(new_time: float):
	current_time = clamp(new_time, 0.0, 24.0)
	time_changed.emit(current_time)

func get_time() -> float:
	return current_time
