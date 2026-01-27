# LCM_BodyEffects.gd - Visual body effects for movement
extends Node3D
class_name LCM_BodyEffects

@export_group("Required References")
@export var movement_system: MovementSystem
@export var lcm_step_rhythm: LCM_StepRhythm

@export_group("Gait Bobbing")
@export var enable_gait_bobbing: bool = true
@export var gait_amplitude_curve: Curve
@export var gait_speed_threshold: float = 0.1
@export var max_gait_speed: float = 4.0

@export_group("Height Adjustments")
@export var enable_height_offset: bool = true
@export var height_offset_curve: Curve
@export var toe_lift_height: float = 0.05
@export var toe_lift_speed_threshold: float = 2.0

@export_group("Movement Lean")
@export var enable_movement_lean: bool = true
@export var forward_lean_curve: Curve
@export var acceleration_lean_curve: Curve
@export var deceleration_lean_curve: Curve
@export var max_acceleration_for_curves: float = 10.0

@export_group("Turn Banking")
@export var enable_turn_banking: bool = true
@export var turn_lean_curve: Curve
@export var max_turn_rate: float = 5.0

@export_group("Slope Adaptation")
@export var enable_slope_lean: bool = true
@export var max_slope_lean: float = 20.0

@export_group("Idle Breathing")
@export var enable_breathing: bool = true
@export var breathing_amplitude: float = 0.002
@export var breathing_frequency: float = 0.3

@export_group("Response Speeds")
@export var lean_response_speed: float = 4.0
@export var height_response_speed: float = 3.0
@export var toe_lift_response_speed: float = 6.0

# Internal state
var original_position: Vector3
var original_rotation: Vector3
var target_position_offset: Vector3 = Vector3.ZERO
var target_rotation_offset: Vector3 = Vector3.ZERO
var current_position_offset: Vector3 = Vector3.ZERO
var current_rotation_offset: Vector3 = Vector3.ZERO

# Movement analysis
var previous_velocity: Vector3 = Vector3.ZERO
var acceleration: Vector3 = Vector3.ZERO
var turn_velocity: float = 0.0
var previous_facing: Vector2 = Vector2.ZERO

# Breathing timer
var breathing_time: float = 0.0

# Lean components
var current_sustained_lean: float = 0.0
var current_acceleration_lean: float = 0.0
var current_toe_lift: float = 0.0

func _ready():
	if not validate_references():
		push_error("BodyEffects: Missing required references")
		return
	
	# Store original transform
	original_position = position
	original_rotation = rotation_degrees
	
	setup_default_curves()
	print("LCM Body Effects initialized")

func validate_references() -> bool:
	return movement_system != null

func _process(delta):
	if not movement_system:
		return
	
	update_movement_analysis(delta)
	
	calculate_gait_bobbing()
	calculate_height_adjustments()
	calculate_movement_lean(delta)
	calculate_turn_banking()
	calculate_slope_adaptation()
	calculate_breathing(delta)
	
	apply_visual_effects(delta)

func setup_default_curves():
	if not gait_amplitude_curve:
		gait_amplitude_curve = Curve.new()
		gait_amplitude_curve.add_point(Vector2(0.0, 0.02))
		gait_amplitude_curve.add_point(Vector2(0.375, 0.05))
		gait_amplitude_curve.add_point(Vector2(1.0, 0.12))
	
	if not height_offset_curve:
		height_offset_curve = Curve.new()
		height_offset_curve.add_point(Vector2(0.0, 0.0))
		height_offset_curve.add_point(Vector2(0.375, -0.02))
		height_offset_curve.add_point(Vector2(1.0, -0.08))
	
	if not forward_lean_curve:
		forward_lean_curve = Curve.new()
		forward_lean_curve.add_point(Vector2(0.0, 0.0))
		forward_lean_curve.add_point(Vector2(0.2, 3.0))
		forward_lean_curve.add_point(Vector2(0.6, 8.0))
		forward_lean_curve.add_point(Vector2(1.0, 15.0))
	
	if not acceleration_lean_curve:
		acceleration_lean_curve = Curve.new()
		acceleration_lean_curve.add_point(Vector2(0.0, 0.0))
		acceleration_lean_curve.add_point(Vector2(0.3, 5.0))
		acceleration_lean_curve.add_point(Vector2(1.0, 12.0))
	
	if not deceleration_lean_curve:
		deceleration_lean_curve = Curve.new()
		deceleration_lean_curve.add_point(Vector2(0.0, 0.0))
		deceleration_lean_curve.add_point(Vector2(0.3, 4.0))
		deceleration_lean_curve.add_point(Vector2(1.0, 10.0))
	
	if not turn_lean_curve:
		turn_lean_curve = Curve.new()
		turn_lean_curve.add_point(Vector2(0.0, 0.0))
		turn_lean_curve.add_point(Vector2(0.3, 8.0))
		turn_lean_curve.add_point(Vector2(1.0, 20.0))

func update_movement_analysis(delta: float):
	var current_velocity = movement_system.character_body.velocity
	acceleration = (current_velocity - previous_velocity) / delta
	previous_velocity = current_velocity
	
	# Calculate turn velocity
	var current_facing = movement_system.get_facing_direction()
	if previous_facing.length() > 0:
		var facing_change = current_facing.angle_to(previous_facing)
		turn_velocity = facing_change / delta
	previous_facing = current_facing

func calculate_gait_bobbing():
	if not enable_gait_bobbing or not lcm_step_rhythm:
		return
	
	var current_speed = movement_system.get_current_speed()
	
	if current_speed < gait_speed_threshold:
		return
	
	# Sample amplitude from curve
	var speed_ratio = clamp(current_speed / max_gait_speed, 0.0, 1.0)
	var amplitude = gait_amplitude_curve.sample(speed_ratio)
	
	# Get gait phase from LCM rhythm
	var gait_phase = lcm_step_rhythm.get_left_phase()
	
	# Create bobbing motion (4 bobs per cycle = 2 per step)
	var bob_factor = sin(gait_phase * 4.0 * PI)
	var gait_offset = amplitude * bob_factor
	
	target_position_offset.y += gait_offset

func calculate_height_adjustments():
	if not enable_height_offset:
		return
	
	var current_speed = movement_system.get_current_speed()
	
	# Speed-based height offset (crouch)
	var speed_ratio = clamp(current_speed / max_gait_speed, 0.0, 1.0)
	var height_offset = height_offset_curve.sample(speed_ratio)
	target_position_offset.y += height_offset
	
	# Toe lift for high-speed movement
	var toe_lift_target = 0.0
	if current_speed > toe_lift_speed_threshold:
		var lift_ratio = clamp((current_speed - toe_lift_speed_threshold) / (max_gait_speed - toe_lift_speed_threshold), 0.0, 1.0)
		toe_lift_target = toe_lift_height * lift_ratio
	
	current_toe_lift = move_toward(current_toe_lift, toe_lift_target, toe_lift_response_speed * get_process_delta_time())
	target_position_offset.y += current_toe_lift

func calculate_movement_lean(delta: float):
	if not enable_movement_lean:
		return
	
	# Sustained forward lean based on speed
	var current_speed = movement_system.get_current_speed()
	var speed_ratio = clamp(current_speed / max_gait_speed, 0.0, 1.0)
	var sustained_lean_target = -(forward_lean_curve.sample(speed_ratio))
	
	# Acceleration/deceleration lean
	var forward_acceleration = acceleration.dot(-transform.basis.z)
	var accel_magnitude = clamp(abs(forward_acceleration) / max_acceleration_for_curves, 0.0, 1.0)
	
	var acceleration_lean_target = 0.0
	if forward_acceleration > 0.1:
		# Accelerating forward
		acceleration_lean_target = -(acceleration_lean_curve.sample(accel_magnitude))
	elif forward_acceleration < -0.1:
		# Decelerating
		acceleration_lean_target = deceleration_lean_curve.sample(accel_magnitude)
	
	# Smooth lean transitions
	current_sustained_lean = move_toward(current_sustained_lean, sustained_lean_target, lean_response_speed * 0.5 * delta)
	current_acceleration_lean = move_toward(current_acceleration_lean, acceleration_lean_target, lean_response_speed * delta)
	
	var total_lean = current_sustained_lean + current_acceleration_lean
	target_rotation_offset.x += total_lean

func calculate_turn_banking():
	if not enable_turn_banking:
		return
	
	var turn_rate_ratio = clamp(abs(turn_velocity) / max_turn_rate, 0.0, 1.0)
	var lean_magnitude = turn_lean_curve.sample(turn_rate_ratio)
	
	# Banking direction (negative turn = lean right)
	var bank_amount = -turn_velocity * lean_magnitude / max_turn_rate
	bank_amount = clamp(bank_amount, -lean_magnitude, lean_magnitude)
	
	target_rotation_offset.z += bank_amount

func calculate_slope_adaptation():
	if not enable_slope_lean:
		return
	
	var character_body = movement_system.character_body
	if not character_body.is_on_floor():
		return
	
	var floor_normal = character_body.get_floor_normal()
	var floor_angle = character_body.get_floor_angle()
	
	if floor_angle <= deg_to_rad(1.0):
		return
	
	var slope_intensity = clamp(floor_angle / character_body.floor_max_angle, 0.0, 1.0)
	
	# Lean into slope
	var lean_forward = floor_normal.dot(Vector3.FORWARD) * max_slope_lean * slope_intensity
	var lean_right = floor_normal.dot(Vector3.RIGHT) * max_slope_lean * slope_intensity
	
	target_rotation_offset.x += lean_forward
	target_rotation_offset.z += lean_right

func calculate_breathing(delta: float):
	if not enable_breathing:
		return
	
	# Only breathe when idle
	if movement_system.get_current_speed() > 0.2:
		return
	
	breathing_time += delta
	var breath_factor = sin(breathing_time * breathing_frequency * 2.0 * PI)
	var breath_offset = breathing_amplitude * breath_factor
	
	target_position_offset.y += breath_offset

func apply_visual_effects(delta: float):
	# Smooth interpolation to targets
	current_position_offset = current_position_offset.lerp(target_position_offset, height_response_speed * delta)
	current_rotation_offset = current_rotation_offset.lerp(target_rotation_offset, lean_response_speed * delta)
	
	# Apply to transform
	position = original_position + current_position_offset
	rotation_degrees = original_rotation + current_rotation_offset
	
	# Reset targets for next frame
	target_position_offset = Vector3.ZERO
	target_rotation_offset = Vector3.ZERO

# Public API
func reset_effects():
	target_position_offset = Vector3.ZERO
	target_rotation_offset = Vector3.ZERO
	current_position_offset = Vector3.ZERO
	current_rotation_offset = Vector3.ZERO
	current_sustained_lean = 0.0
	current_acceleration_lean = 0.0
	current_toe_lift = 0.0
	position = original_position
	rotation_degrees = original_rotation

func set_gait_bobbing_enabled(enabled: bool):
	enable_gait_bobbing = enabled

func set_movement_lean_enabled(enabled: bool):
	enable_movement_lean = enabled

func set_turn_banking_enabled(enabled: bool):
	enable_turn_banking = enabled

func get_current_toe_lift() -> float:
	return current_toe_lift

func get_current_effects() -> Dictionary:
	return {
		"position_offset": current_position_offset,
		"rotation_offset": current_rotation_offset,
		"sustained_lean": current_sustained_lean,
		"acceleration_lean": current_acceleration_lean,
		"toe_lift": current_toe_lift,
		"total_forward_lean": current_sustained_lean + current_acceleration_lean
	}
