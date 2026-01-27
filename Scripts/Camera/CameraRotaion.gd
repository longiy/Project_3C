# CameraRotation.gd - Separated rotation functionality
extends Node
class_name CameraRotation

# === ROTATION CONFIGURATION ===
@export_group("Rotation Settings")
@export var horizontal_smoothing: float = 12.0
@export var vertical_smoothing: float = 12.0
@export var invert_horizontal: bool = false
@export var invert_vertical: bool = false

# === INTERNAL STATE ===
var current_horizontal_rotation: float = 0.0
var current_vertical_rotation: float = 0.0
var target_horizontal_rotation: float = 0.0
var target_vertical_rotation: float = 0.0
var spring_arm: SpringArm3D
var input_config: InputConfig

func initialize(spring_arm_ref: SpringArm3D, config: InputConfig):
	spring_arm = spring_arm_ref
	input_config = config
	
	# Initialize rotations to current spring arm rotation
	if spring_arm:
		current_horizontal_rotation = spring_arm.rotation.y
		current_vertical_rotation = spring_arm.rotation.x
		target_horizontal_rotation = current_horizontal_rotation
		target_vertical_rotation = current_vertical_rotation

func process_rotation(look_delta: Vector2, delta: float):
	if look_delta == Vector2.ZERO or not spring_arm or not input_config:
		return
	
	# Apply inversion
	var adjusted_delta = look_delta
	if invert_horizontal:
		adjusted_delta.x = -adjusted_delta.x
	if invert_vertical:
		adjusted_delta.y = -adjusted_delta.y
	
	# Update target rotations
	target_horizontal_rotation -= adjusted_delta.x
	target_vertical_rotation -= adjusted_delta.y
	
	# Apply vertical limits
	var vertical_limit = deg_to_rad(input_config.vertical_look_limit)
	target_vertical_rotation = clamp(target_vertical_rotation, -vertical_limit, vertical_limit)
	
	# Smooth to target rotations
	current_horizontal_rotation = lerp_angle(
		current_horizontal_rotation, 
		target_horizontal_rotation, 
		horizontal_smoothing * delta
	)
	current_vertical_rotation = lerp_angle(
		current_vertical_rotation, 
		target_vertical_rotation, 
		vertical_smoothing * delta
	)
	
	# Apply to spring arm
	spring_arm.rotation.y = current_horizontal_rotation
	spring_arm.rotation.x = current_vertical_rotation

func set_rotation_smoothing(horizontal: float, vertical: float):
	horizontal_smoothing = horizontal
	vertical_smoothing = vertical

func set_rotation_inversion(horizontal: bool, vertical: bool):
	invert_horizontal = horizontal
	invert_vertical = vertical

func reset_rotation():
	current_horizontal_rotation = 0.0
	current_vertical_rotation = 0.0
	target_horizontal_rotation = 0.0
	target_vertical_rotation = 0.0
	
	if spring_arm:
		spring_arm.rotation = Vector3.ZERO

func get_current_rotation() -> Vector2:
	return Vector2(current_horizontal_rotation, current_vertical_rotation)

func get_target_rotation() -> Vector2:
	return Vector2(target_horizontal_rotation, target_vertical_rotation)

func set_target_rotation(horizontal: float, vertical: float):
	target_horizontal_rotation = horizontal
	
	if input_config:
		var vertical_limit = deg_to_rad(input_config.vertical_look_limit)
		target_vertical_rotation = clamp(vertical, -vertical_limit, vertical_limit)
	else:
		target_vertical_rotation = vertical

func set_rotation_immediately(horizontal: float, vertical: float):
	set_target_rotation(horizontal, vertical)
	current_horizontal_rotation = target_horizontal_rotation
	current_vertical_rotation = target_vertical_rotation
	
	if spring_arm:
		spring_arm.rotation.y = current_horizontal_rotation
		spring_arm.rotation.x = current_vertical_rotation
