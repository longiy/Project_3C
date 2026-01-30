# MovementConfig.gd - Clean version with advanced movement always enabled
extends Resource
class_name MovementConfig

@export_group("Movement Speeds")
@export var walk_speed: float = 1.3
@export var run_speed: float = 3.0
@export var sprint_speed: float = 6.3

@export_group("Speed Transitions")
@export var speed_transition_rate: float = 1

@export_group("Movement Physics")
@export var acceleration: float = 30.0
@export var deceleration: float = 10.0
@export var air_direction_control: float = 0.3
@export var air_rotation_control: float = 0.1

@export_group("Jump Settings")
@export var jump_height: float = 1.5
@export var gravity: float = -20.0
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1

@export_group("Rotation")
@export var rotation_speed: float = 8.0
@export var min_rotation_speed: float = 0.1
@export var speed_rotation_reduction: float = 0.7
@export var enable_directional_snapping: bool = false
@export var snap_angle_degrees: float = 45.0

@export_group("Movement Feel")
@export var max_rotation_influence: float = 1.0
@export var rotation_influence_start_speed: float = 2.0
@export var rotation_influence_curve: float = 1.0
@export var momentum_rotation_bonus: float = 0.2

@export_group("Camera Alignment")
@export var camera_align_on_movement: bool = false
@export var camera_align_rotation_speed: float = 5.0

@export_group("Gamepad Settings")
@export var gamepad_movement_multiplier: float = 1.0
@export var gamepad_acceleration_multiplier: float = 1.2
@export var gamepad_rotation_speed_multiplier: float = 1.1

var jump_velocity: float

func _init():
	calculate_jump_velocity()

func calculate_jump_velocity():
	if gravity < 0:
		jump_velocity = sqrt(-2.0 * gravity * jump_height)
	else:
		gravity = -abs(gravity)
		jump_velocity = sqrt(-2.0 * gravity * jump_height)

func get_speed_dependent_rotation_speed(current_speed: float, max_speed: float) -> float:
	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
	var rotation_multiplier = lerp(1.0, min_rotation_speed / rotation_speed, speed_ratio * speed_rotation_reduction)
	return rotation_speed * rotation_multiplier

func get_rotation_influence_factor(current_speed: float, has_momentum: bool = false) -> float:
	# Calculate base influence based on speed
	if current_speed < rotation_influence_start_speed:
		return 0.0
	
	var speed_above_threshold = current_speed - rotation_influence_start_speed
	var max_speed_range = sprint_speed - rotation_influence_start_speed
	var speed_ratio = clamp(speed_above_threshold / max_speed_range, 0.0, 1.0)
	
	# Apply curve to the speed ratio
	var curved_ratio = pow(speed_ratio, rotation_influence_curve)
	var base_influence = curved_ratio * max_rotation_influence
	
	# Add momentum bonus if maintaining momentum
	if has_momentum:
		base_influence += momentum_rotation_bonus
	
	return clamp(base_influence, 0.0, 1.0)

func get_movement_speed(input_source: InputState.InputSource) -> float:
	var base_speed = run_speed
	if input_source == InputState.InputSource.GAMEPAD:
		return base_speed * gamepad_movement_multiplier
	return base_speed

func get_acceleration(input_source: InputState.InputSource) -> float:
	var base_acceleration = acceleration
	if input_source == InputState.InputSource.GAMEPAD:
		return base_acceleration * gamepad_acceleration_multiplier
	return base_acceleration

func get_rotation_speed(input_source: InputState.InputSource) -> float:
	var base_rotation = rotation_speed
	if input_source == InputState.InputSource.GAMEPAD:
		return base_rotation * gamepad_rotation_speed_multiplier
	return base_rotation

func validate() -> bool:
	if gravity > 0:
		gravity = -abs(gravity)
		calculate_jump_velocity()
	
	# Validate parameters
	min_rotation_speed = clamp(min_rotation_speed, 0.1, rotation_speed)
	speed_rotation_reduction = clamp(speed_rotation_reduction, 0.0, 1.0)
	rotation_speed = max(rotation_speed, 0.1)
	
	max_rotation_influence = clamp(max_rotation_influence, 0.0, 1.0)
	rotation_influence_start_speed = clamp(rotation_influence_start_speed, 0.0, sprint_speed)
	rotation_influence_curve = max(rotation_influence_curve, 0.1)
	momentum_rotation_bonus = clamp(momentum_rotation_bonus, 0.0, 1.0)
	
	return gravity < 0.0 and jump_height > 0.0 and run_speed > 0.0
