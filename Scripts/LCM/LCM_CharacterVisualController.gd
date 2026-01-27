# LCM_CharacterVisualController.gd - Clean visual effects for SimpleGoalStepping
extends Node3D
class_name LCM_CharacterVisualController

# ================================
# VISUAL EFFECTS CONTROLLER FOR SIMPLE GOAL STEPPING
# Provides gait synchronization, movement lean, and body dynamics
# ================================

@export_group("System References")
@export var movement_system: MovementSystem
@export var simple_goal_stepping: Node3D  # LCM_SimpleGoalStepping
@export var lcm_center_of_gravity: Node3D  # LCM_CenterOfGravity

@export_group("Gait Synchronization")
@export var enable_gait_sync: bool = true
@export var gait_amplitude_curve: Curve
@export var gait_sync_speed_threshold: float = 0.1

@export_group("Height Dynamics")
@export var enable_height_adjustment: bool = true
@export var speed_height_curve: Curve
@export var height_response_speed: float = 3.0

@export_group("Movement Lean")
@export var enable_movement_lean: bool = true
@export var acceleration_lean_curve: Curve
@export var max_acceleration_for_curves: float = 10.0
@export var lean_response_speed: float = 8.0

@export_group("Turn Banking")
@export var enable_turn_banking: bool = true
@export var turn_lean_curve: Curve
@export var max_turn_rate: float = 5.0
@export var turn_response_speed: float = 4.0

@export_group("Slope Adaptation")
@export var enable_slope_lean: bool = true
@export var max_slope_lean: float = 20.0

@export_group("CoG Integration")
@export var enable_cog_lean_enhancement: bool = true
@export var cog_lean_multiplier: float = 0.3

@export_group("Step Synchronization")
@export var step_sync_influence: float = 0.8
@export var stance_ratio_influence: float = 0.6

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

# Component state tracking
var current_lean_angle: float = 0.0
var current_height_offset: float = 0.0
var current_cog_lean_enhancement: float = 0.0

# Step synchronization state
var synthetic_gait_time: float = 0.0

func _ready():
	initialize_visual_controller()

func _process(delta):
	if not movement_system:
		return
	
	update_movement_analysis(delta)
	update_step_synchronization(delta)
	
	calculate_gait_synchronization()
	calculate_height_adjustments(delta)
	calculate_movement_lean(delta)
	calculate_turn_banking(delta)
	calculate_slope_adaptation()
	calculate_cog_lean_enhancement()
	
	apply_visual_effects(delta)

# ================================
# INITIALIZATION
# ================================

func initialize_visual_controller():
	if not validate_references():
		push_error("LCM_CharacterVisualController: Missing MovementSystem reference")
		return
	
	# Store original transform
	original_position = position
	original_rotation = rotation_degrees
	
	# Setup curves
	setup_default_curves()
	
	print("LCM Character Visual Controller initialized for SimpleGoalStepping")

func validate_references() -> bool:
	return movement_system != null

func setup_default_curves():
	if not gait_amplitude_curve:
		gait_amplitude_curve = Curve.new()
		gait_amplitude_curve.add_point(Vector2(0.0, 0.02))   # Slow: 2cm bobbing
		gait_amplitude_curve.add_point(Vector2(0.375, 0.05)) # Normal: 5cm bobbing
		gait_amplitude_curve.add_point(Vector2(1.0, 0.12))   # Fast: 12cm bobbing
	
	if not speed_height_curve:
		speed_height_curve = Curve.new()
		speed_height_curve.add_point(Vector2(0.0, 0.0))     # Idle: neutral height
		speed_height_curve.add_point(Vector2(0.3, -0.02))   # Walking: slight crouch (-2cm)
		speed_height_curve.add_point(Vector2(0.7, -0.01))   # Jogging: less crouch (-1cm)
		speed_height_curve.add_point(Vector2(1.0, 0.02))    # Sprinting: on toes (+2cm)
	
	if not acceleration_lean_curve:
		acceleration_lean_curve = Curve.new()
		acceleration_lean_curve.add_point(Vector2(-1.0, -10.0))    # Strong deceleration: 10° backward lean
		acceleration_lean_curve.add_point(Vector2(-0.5, -6.0))     # Moderate deceleration: 6° backward lean
		acceleration_lean_curve.add_point(Vector2(-0.1, -1.0))     # Light deceleration: 1° backward lean
		acceleration_lean_curve.add_point(Vector2(0.0, 0.0))       # No acceleration: neutral
		acceleration_lean_curve.add_point(Vector2(0.1, 1.0))       # Light acceleration: 1° forward lean
		acceleration_lean_curve.add_point(Vector2(0.5, 6.0))       # Moderate acceleration: 6° forward lean
		acceleration_lean_curve.add_point(Vector2(1.0, 12.0))      # Strong acceleration: 12° forward lean
	
	if not turn_lean_curve:
		turn_lean_curve = Curve.new()
		turn_lean_curve.add_point(Vector2(0.0, 0.0))
		turn_lean_curve.add_point(Vector2(0.3, 8.0))
		turn_lean_curve.add_point(Vector2(1.0, 20.0))

# ================================
# MOVEMENT ANALYSIS
# ================================

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

# ================================
# STEP SYNCHRONIZATION
# ================================

func update_step_synchronization(delta: float):
	if simple_goal_stepping:
		# Update synthetic gait time based on actual step parameters
		var step_params = simple_goal_stepping.get_current_step_parameters()
		var step_frequency = step_params.get("step_frequency", 2.0)
		synthetic_gait_time += delta * step_frequency
	else:
		# Fallback: time-based synthetic gait
		var speed = movement_system.get_current_speed()
		var frequency = 2.0 if speed > 0.1 else 0.0
		synthetic_gait_time += delta * frequency

# ================================
# GAIT SYNCHRONIZATION
# ================================

func get_max_gait_speed() -> float:
	if movement_system and movement_system.movement_config:
		return movement_system.movement_config.sprint_speed
	return 6.3  # Fallback value

func calculate_gait_synchronization():
	if not enable_gait_sync:
		return
	
	var current_speed = movement_system.get_current_speed()
	if current_speed < gait_sync_speed_threshold:
		return
	
	# Get gait phase
	var gait_phase = get_gait_phase()
	if gait_phase < 0:
		return
	
	# Sample amplitude with speed-responsive parameter influence
	var max_speed = get_max_gait_speed()
	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
	var amplitude = gait_amplitude_curve.sample(speed_ratio)
	
	# Enhance amplitude based on SimpleGoalStepping parameters
	if simple_goal_stepping:
		var step_params = simple_goal_stepping.get_current_step_parameters()
		var step_length = step_params.get("step_length", 0.4)
		var step_height = step_params.get("step_height", 0.1)
		
		# Modulate amplitude based on actual step characteristics
		var length_modifier = step_length / 0.4  # Normalize against default
		var height_modifier = step_height / 0.1  # Normalize against default
		amplitude *= lerp(1.0, length_modifier * height_modifier, step_sync_influence)
	
	# Create synchronized bobbing (4 bobs per cycle = 2 per step)
	var bob_factor = sin(gait_phase * 4.0 * PI)
	var gait_bobbing = amplitude * bob_factor
	
	# Add gait bobbing to Y position (separate from height dynamics)
	target_position_offset.y += gait_bobbing

func get_gait_phase() -> float:
	if simple_goal_stepping:
		# Use SimpleGoalStepping's timing information
		var step_params = simple_goal_stepping.get_current_step_parameters()
		var stance_ratio = step_params.get("stance_ratio", 0.6)
		
		# Adjust synthetic gait timing based on stance ratio
		var adjusted_time = synthetic_gait_time * lerp(1.0, stance_ratio, stance_ratio_influence)
		return fmod(adjusted_time, 1.0)
	else:
		# Fallback: pure synthetic timing
		return fmod(synthetic_gait_time, 1.0)

# ================================
# HEIGHT ADJUSTMENTS
# ================================

func calculate_height_adjustments(delta: float):
	if not enable_height_adjustment:
		current_height_offset = move_toward(current_height_offset, 0.0, height_response_speed * delta)
		target_position_offset.y += current_height_offset
		return
	
	# Single speed-based height curve (negative=crouch, positive=toe lift)
	var current_speed = movement_system.get_current_speed()
	var max_speed = get_max_gait_speed()
	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
	var target_height = speed_height_curve.sample(speed_ratio)
	
	# Smooth transition to target
	current_height_offset = move_toward(current_height_offset, target_height, height_response_speed * delta)
	
	target_position_offset.y += current_height_offset

# ================================
# MOVEMENT LEAN
# ================================

func calculate_movement_lean(delta: float):
	if not enable_movement_lean:
		current_lean_angle = move_toward(current_lean_angle, 0.0, lean_response_speed * delta)
		target_rotation_offset.x = -current_lean_angle
		return
	
	# Calculate forward acceleration in character space
	var character_forward = movement_system.character_body.global_transform.basis.z
	var forward_acceleration = acceleration.dot(-character_forward)
	
	# Normalize acceleration to -1.0 to 1.0 range
	var accel_ratio = clamp(forward_acceleration / max_acceleration_for_curves, -1.0, 1.0)
	
	# Sample single curve (handles both acceleration and deceleration)
	var target_lean = acceleration_lean_curve.sample(accel_ratio)
	
	# Smooth transition to target
	current_lean_angle = move_toward(current_lean_angle, target_lean, lean_response_speed * delta)
	
	# Apply lean (positive = forward, negative = backward)
	target_rotation_offset.x = -current_lean_angle

# ================================
# TURN BANKING
# ================================

func calculate_turn_banking(delta: float):
	if not enable_turn_banking:
		return
	
	var turn_ratio = clamp(abs(turn_velocity) / max_turn_rate, 0.0, 1.0)
	var banking_angle = turn_lean_curve.sample(turn_ratio)
	
	# Apply banking in the direction of turn
	if abs(turn_velocity) > 0.1:
		var bank_direction = sign(turn_velocity)
		target_rotation_offset.z += banking_angle * bank_direction

# ================================
# SLOPE ADAPTATION
# ================================

func calculate_slope_adaptation():
	if not enable_slope_lean:
		return
	
	# Get slope information from character's floor normal
	var floor_normal = movement_system.character_body.get_floor_normal()
	if floor_normal.length() > 0.5:
		var slope_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
		var forward_slope = floor_normal.cross(Vector3.UP).normalized()
		var slope_lean = clamp(slope_angle / max_slope_lean, -1.0, 1.0) * max_slope_lean
		
		# Apply slope lean opposite to slope direction
		var movement_dot = movement_system.get_facing_direction().dot(Vector2(forward_slope.x, forward_slope.z))
		target_rotation_offset.x -= slope_lean * movement_dot

# ================================
# COG LEAN ENHANCEMENT
# ================================

func calculate_cog_lean_enhancement():
	if not enable_cog_lean_enhancement or not lcm_center_of_gravity:
		return
	
	# Get CoG offset and convert to lean
	var cog_offset = lcm_center_of_gravity.get_current_offset()
	var forward_lean_enhancement = -cog_offset.z * cog_lean_multiplier * rad_to_deg(1.0)
	
	current_cog_lean_enhancement = forward_lean_enhancement
	target_rotation_offset.x += current_cog_lean_enhancement

# ================================
# VISUAL EFFECTS APPLICATION
# ================================

func apply_visual_effects(delta: float):
	# Smooth interpolation to targets
	current_position_offset = current_position_offset.lerp(target_position_offset, height_response_speed * delta)
	current_rotation_offset = current_rotation_offset.lerp(target_rotation_offset, turn_response_speed * delta)
	
	# Apply to transform
	position = original_position + current_position_offset
	rotation_degrees = original_rotation + current_rotation_offset
	
	# Reset targets for next frame
	target_position_offset = Vector3.ZERO
	target_rotation_offset = Vector3.ZERO
	
	if target_rotation_offset.length() > 0.1:
		print("Target rotation: ", target_rotation_offset)
		print("Current rotation: ", current_rotation_offset)

# ================================
# PUBLIC API
# ================================

func reset_visual_effects():
	target_position_offset = Vector3.ZERO
	target_rotation_offset = Vector3.ZERO
	current_position_offset = Vector3.ZERO
	current_rotation_offset = Vector3.ZERO
	current_lean_angle = 0.0
	current_height_offset = 0.0
	current_cog_lean_enhancement = 0.0
	position = original_position
	rotation_degrees = original_rotation

func get_current_effects() -> Dictionary:
	return {
		"position_offset": current_position_offset,
		"rotation_offset": current_rotation_offset,
		"lean_angle": current_lean_angle,
		"height_offset": current_height_offset,
		"cog_lean_enhancement": current_cog_lean_enhancement,
		"total_forward_lean": current_lean_angle + current_cog_lean_enhancement,
		"simple_stepping_available": simple_goal_stepping != null
	}

func set_simple_stepping_reference(stepping_ref: Node3D):
	simple_goal_stepping = stepping_ref
	print("SimpleGoalStepping reference updated")

func get_gait_state() -> String:
	if simple_goal_stepping and simple_goal_stepping.has_method("get_gait_state"):
		return simple_goal_stepping.get_gait_state()
	else:
		var speed = movement_system.get_current_speed()
		if speed < 0.1:
			return "idle"
		elif speed < 2.0:
			return "walking"
		else:
			return "running"
