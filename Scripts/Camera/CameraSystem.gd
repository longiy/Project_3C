# CameraSystem.gd - Pure modular architecture (no fallbacks)
extends Node3D
class_name CameraSystem

# === COMPONENT REFERENCES (REQUIRED) ===
@export var delay_system: CameraDelay
@export var zoom_system: CameraZoom
@export var rotation_system: CameraRotation

# === DIRECT DEPENDENCIES ===
@export var spring_arm: SpringArm3D
@export var camera: Camera3D
@export var target_object: CharacterBody3D

# === SHARED CONFIGURATION ===
var input_config: InputConfig : set = set_input_config

# === CAMERA SETTINGS ===
@export var enabled: bool = true

@export_group("Camera Position")
@export var camera_height_offset: float = 1.5
@export var camera_distance_offset: float = 2.0

# === INTERNAL STATE ===
var target_position: Vector3 = Vector3.ZERO
var last_input_hash: int = 0
var camera_directions_dirty: bool = true

func _ready():
	configure_spring_arm()
	initialize_camera_position()
	setup_systems()

func configure_spring_arm():
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.1
	spring_arm.spring_length = spring_arm.spring_length + camera_distance_offset

func initialize_camera_position():
	var initial_pos = target_object.global_position + Vector3(0, camera_height_offset, 0)
	target_position = initial_pos
	global_position = initial_pos

func setup_systems():
	var initial_pos = target_object.global_position + Vector3(0, camera_height_offset, 0)
	
	delay_system.initialize(initial_pos, target_object)
	zoom_system.initialize(spring_arm, camera_distance_offset)
	rotation_system.initialize(spring_arm, input_config)

func set_enabled(new_enabled: bool):
	enabled = new_enabled

func process_camera(input_state: InputState, delta: float):
	if not enabled:
		return
	
	update_target_position()
	process_position_smoothing(delta)
	zoom_system.process_zoom(input_state.zoom_delta, delta)
	zoom_system.apply_zoom_smoothing(delta)  # Add this line
	
	var current_hash = hash(input_state.look_delta)
	if current_hash != last_input_hash:
		mark_camera_directions_dirty()
		last_input_hash = current_hash
	
	if input_state.has_look():
		rotation_system.process_rotation(input_state.look_delta, delta)

func mark_camera_directions_dirty():
	camera_directions_dirty = true

func update_target_position():
	var new_target = target_object.global_position
	new_target.y += camera_height_offset
	target_position = new_target

func process_position_smoothing(delta: float):
	var final_position = delay_system.process_delay(target_position, delta)
	global_position = final_position

func reset_all_systems():
	delay_system.reset_delay()
	zoom_system.reset_zoom()
	rotation_system.reset_rotation()
	global_position = target_object.global_position + Vector3(0, camera_height_offset, 0)

# === CAMERA DIRECTION CALCULATION ===
func get_camera_forward() -> Vector3:
	return -camera.global_transform.basis.z.normalized()

func get_camera_right() -> Vector3:
	return camera.global_transform.basis.x.normalized()

func get_camera_up() -> Vector3:
	return camera.global_transform.basis.y.normalized()

# === UTILITY METHODS ===
func get_distance_to_target() -> float:
	return global_position.distance_to(target_object.global_position)

func set_camera_height_offset(new_offset: float):
	camera_height_offset = new_offset
	update_target_position()

# === SYSTEM CONTROL METHODS ===
func configure_delay_system(horizontal_time: float, vertical_time: float, bias_enabled: bool = true, bias_strength: float = 0.5):
	delay_system.set_delay_times(horizontal_time, vertical_time)
	delay_system.set_direction_bias(bias_enabled, bias_strength)

func configure_zoom_system(min_dist: float, max_dist: float, speed: float, smoothing: float):
	zoom_system.set_zoom_limits(min_dist, max_dist)
	zoom_system.set_zoom_speed(speed)
	zoom_system.set_zoom_smoothing(smoothing)

func configure_rotation_system(horizontal_smooth: float, vertical_smooth: float, invert_h: bool = false, invert_v: bool = false):
	rotation_system.set_rotation_smoothing(horizontal_smooth, vertical_smooth)
	rotation_system.set_rotation_inversion(invert_h, invert_v)

# === COMPONENT ACCESS METHODS ===
func get_camera_distance() -> float:
	return zoom_system.get_current_distance()

func set_camera_distance(new_distance: float):
	zoom_system.set_target_distance(new_distance)

func get_current_rotation() -> Vector2:
	return rotation_system.get_current_rotation()

func set_camera_rotation(horizontal: float, vertical: float):
	rotation_system.set_target_rotation(horizontal, vertical)

func get_smoothed_position() -> Vector3:
	return delay_system.get_smoothed_position()

# === INPUT CONFIG SETTER ===
func set_input_config(config: InputConfig):
	input_config = config
	if rotation_system and spring_arm:
		rotation_system.initialize(spring_arm, input_config)
