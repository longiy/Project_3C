# CameraZoom.gd - Separated zoom functionality
extends Node
class_name CameraZoom

# === ZOOM CONFIGURATION ===
@export_group("Zoom Settings")
@export var initial_distance: float = 3.0
@export var min_distance: float = 2.0
@export var max_distance: float = 10.0
@export var zoom_speed: float = 1.0
@export var zoom_smoothing: float = 4.0


# === INTERNAL STATE ===
var target_spring_length: float = 0.0
var spring_arm: SpringArm3D

func initialize(spring_arm_ref: SpringArm3D, distance_offset: float = 0.0):
	spring_arm = spring_arm_ref
	target_spring_length = initial_distance + distance_offset
	
	if spring_arm:
		spring_arm.spring_length = target_spring_length

func process_zoom(zoom_delta: float, delta: float):
	if not zoom_delta or not spring_arm:
		return
	
	var zoom_amount = zoom_delta * zoom_speed
	target_spring_length = clamp(
		target_spring_length - zoom_amount,
		min_distance,
		max_distance
	)

func apply_zoom_smoothing(delta: float):
	if not spring_arm:
		return
	
	spring_arm.spring_length = lerp(
		spring_arm.spring_length,
		target_spring_length,
		zoom_smoothing * delta
	)

func set_target_distance(distance: float):
	target_spring_length = clamp(distance, min_distance, max_distance)

func get_current_distance() -> float:
	if spring_arm:
		return spring_arm.spring_length
	return target_spring_length

func get_target_distance() -> float:
	return target_spring_length

func set_zoom_limits(min_dist: float, max_dist: float):
	min_distance = min_dist
	max_distance = max_dist
	target_spring_length = clamp(target_spring_length, min_distance, max_distance)

func set_zoom_speed(speed: float):
	zoom_speed = speed

func set_zoom_smoothing(smoothing: float):
	zoom_smoothing = smoothing

func reset_zoom():
	target_spring_length = initial_distance
	if spring_arm:
		spring_arm.spring_length = target_spring_length
