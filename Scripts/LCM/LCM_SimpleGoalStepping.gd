# LCM_SimpleGoalStepping.gd - Goal-Directed Stepping with Speed-Responsive Parameters
extends Node3D
class_name LCM_SimpleGoalStepping

# ================================
# SIMPLE GOAL-DIRECTED STEPPING
# Direct input-to-foot-placement with biomechanically-informed parameter scaling
# ================================

## REFERENCES
@export_group("Required References")
@export var movement_system: MovementSystem
@export var lcm_terrain_detector: LCM_TerrainDetector
@export var lcm_center_of_gravity: LCM_CenterOfGravity

## SPEED-RESPONSIVE PARAMETERS
@export_group("Speed Curves")
@export var step_length_curve: Curve				# Step distance scaling with speed
@export var step_frequency_curve: Curve			# Step timing scaling with speed
@export var stance_width_curve: Curve				# Foot spacing scaling with speed
@export var stance_ratio_curve: Curve				# Ground contact ratio scaling with speed
@export var step_height_curve: Curve				# Step arc height scaling with speed
@export var trigger_distance_curve: Curve			# Step trigger sensitivity scaling with speed

@export_group("Speed Range")
@export var max_speed_reference: float = 4.0		# Maximum speed for curve sampling
@export var walk_run_transition_speed: float = 2.0	# Speed where gait transitions occur

## BASIC PARAMETERS (Fallback Values)
@export_group("Fallback Parameters")
@export var base_step_distance: float = 0.4		# Fallback if no curve
@export var base_stance_width: float = 0.3			# Fallback if no curve
@export var base_step_duration: float = 0.5		# Fallback if no curve
@export var base_step_trigger: float = 0.25		# Fallback if no curve

## STABILIZATION PARAMETERS
@export_group("Idle Stabilization")
@export var enable_cog_stabilization: bool = true
@export var idle_stabilization_delay: float = 1.5
@export var cog_influence_strength: float = 0.6
@export var max_cog_offset: float = 0.4

## MOVEMENT RESPONSE
@export_group("Input Response")
@export var direction_response_speed: float = 3.0
@export var min_movement_threshold: float = 0.1

## SLOPE ADJUSTMENT
@export_group("Slope Adjustment")
@export var enable_slope_adjustment: bool = true
@export var uphill_knee_multiplier: float = 2.0  # How much extra height for uphill steps
@export var slope_detection_distance: float = 0.2  # Distance ahead to check slope
@export var min_slope_for_adjustment: float = 0.3  # Minimum slope to trigger adjustment (radians ~17 degrees)

## DEBUG
@export_group("Debug")
@export var enable_debug: bool = false
@export var show_ideal_positions: bool = true
@export var show_step_triggers: bool = true
@export var show_cog_influence: bool = true
@export var show_speed_info: bool = false

## CURRENT SAMPLED VALUES
var current_step_length: float
var current_step_frequency: float
var current_stance_width: float
var current_stance_ratio: float
var current_step_height: float
var current_trigger_distance: float
var current_step_duration: float

## STEP STATE
var left_foot_target: Vector3 = Vector3.ZERO
var right_foot_target: Vector3 = Vector3.ZERO

# Step execution state
var is_left_stepping: bool = false
var is_right_stepping: bool = false
var left_step_progress: float = 0.0
var right_step_progress: float = 0.0
var left_step_start: Vector3
var right_step_start: Vector3

# Stance timing state
var left_stance_timer: float = 0.0
var right_stance_timer: float = 0.0
var can_start_left_step: bool = true
var can_start_right_step: bool = true

# Ideal positions (where feet should be based on input + speed)
var ideal_left_position: Vector3
var ideal_right_position: Vector3

# Input tracking
var current_input_direction: Vector3 = Vector3.ZERO
var smoothed_input_direction: Vector3 = Vector3.ZERO

# Idle stabilization state
var idle_timer: float = 0.0
var is_idle: bool = false
var was_moving: bool = false

func _ready():
	initialize_speed_responsive_stepping()

func _process(delta):
	if not validate_references():
		return
	
	update_input_tracking(delta)
	update_idle_state(delta)
	sample_speed_parameters()
	update_stance_timing(delta)
	calculate_ideal_positions()
	check_step_triggers()
	update_stepping(delta)
	
	if enable_debug:
		draw_debug_visualization()

# ================================
# INITIALIZATION
# ================================

func initialize_speed_responsive_stepping():
	if not validate_references():
		push_error("SimpleGoalStepping: Missing required references")
		return
	
	setup_default_curves()
	
	# Initialize foot positions under character
	var char_pos = movement_system.character_body.global_position
	var char_right = movement_system.character_body.global_transform.basis.x
	
	# Sample initial parameters
	sample_speed_parameters()
	
	left_foot_target = char_pos - char_right * (current_stance_width * 0.5)
	right_foot_target = char_pos + char_right * (current_stance_width * 0.5)
	
	# Apply terrain height
	if lcm_terrain_detector:
		left_foot_target.y = lcm_terrain_detector.get_terrain_height_at(left_foot_target)
		right_foot_target.y = lcm_terrain_detector.get_terrain_height_at(right_foot_target)
	
	ideal_left_position = left_foot_target
	ideal_right_position = right_foot_target
	
	print("Speed-Responsive Goal Stepping initialized")

func validate_references() -> bool:
	return movement_system != null

func setup_default_curves():
	# Create default curves if not assigned
	if not step_length_curve:
		step_length_curve = Curve.new()
		step_length_curve.add_point(Vector2(0.0, 0.2))  # Standing: small steps
		step_length_curve.add_point(Vector2(0.5, 0.4))  # Walking: normal steps
		step_length_curve.add_point(Vector2(1.0, 0.8))  # Running: large steps
	
	if not step_frequency_curve:
		step_frequency_curve = Curve.new()
		step_frequency_curve.add_point(Vector2(0.0, 1.0))  # Standing: slow stepping
		step_frequency_curve.add_point(Vector2(0.5, 2.0))  # Walking: normal frequency
		step_frequency_curve.add_point(Vector2(1.0, 3.0))  # Running: fast frequency
	
	if not stance_width_curve:
		stance_width_curve = Curve.new()
		stance_width_curve.add_point(Vector2(0.0, 0.4))  # Standing: wide stance
		stance_width_curve.add_point(Vector2(0.5, 0.3))  # Walking: normal width
		stance_width_curve.add_point(Vector2(1.0, 0.2))  # Running: narrow stance
	
	if not stance_ratio_curve:
		stance_ratio_curve = Curve.new()
		stance_ratio_curve.add_point(Vector2(0.0, 0.8))  # Standing: long ground contact
		stance_ratio_curve.add_point(Vector2(0.5, 0.6))  # Walking: medium contact
		stance_ratio_curve.add_point(Vector2(1.0, 0.4))  # Running: short contact
	
	if not step_height_curve:
		step_height_curve = Curve.new()
		step_height_curve.add_point(Vector2(0.0, 0.05)) # Standing: minimal lift
		step_height_curve.add_point(Vector2(0.5, 0.1))  # Walking: low lift
		step_height_curve.add_point(Vector2(1.0, 0.2))  # Running: high lift
	
	if not trigger_distance_curve:
		trigger_distance_curve = Curve.new()
		trigger_distance_curve.add_point(Vector2(0.0, 0.15)) # Standing: close trigger
		trigger_distance_curve.add_point(Vector2(0.5, 0.25)) # Walking: normal trigger
		trigger_distance_curve.add_point(Vector2(1.0, 0.4))  # Running: far trigger

# ================================
# SPEED PARAMETER SAMPLING
# ================================

func sample_speed_parameters():
	var movement_speed = movement_system.get_current_speed()
	var speed_ratio = clamp(movement_speed / max_speed_reference, 0.0, 1.0)
	
	# Sample all curves based on current speed
	current_step_length = step_length_curve.sample(speed_ratio) if step_length_curve else base_step_distance
	current_step_frequency = step_frequency_curve.sample(speed_ratio) if step_frequency_curve else (1.0 / base_step_duration)
	current_stance_width = stance_width_curve.sample(speed_ratio) if stance_width_curve else base_stance_width
	current_stance_ratio = stance_ratio_curve.sample(speed_ratio) if stance_ratio_curve else 0.6
	current_step_height = step_height_curve.sample(speed_ratio) if step_height_curve else 0.1
	current_trigger_distance = trigger_distance_curve.sample(speed_ratio) if trigger_distance_curve else base_step_trigger
	
	# Calculate step duration from frequency
	current_step_duration = 1.0 / current_step_frequency if current_step_frequency > 0 else base_step_duration

# ================================
# INPUT AND TIMING STATE
# ================================

func update_input_tracking(delta: float):
	var velocity = movement_system.current_velocity
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	if horizontal_velocity.length() > min_movement_threshold:
		current_input_direction = horizontal_velocity.normalized()
	else:
		current_input_direction = -movement_system.character_body.global_transform.basis.z
	
	smoothed_input_direction = smoothed_input_direction.lerp(current_input_direction, direction_response_speed * delta)

func update_idle_state(delta: float):
	var movement_speed = movement_system.get_current_speed()
	var is_currently_moving = movement_speed > min_movement_threshold
	
	if is_currently_moving != was_moving:
		if not is_currently_moving:
			idle_timer = 0.0
			is_idle = false
		was_moving = is_currently_moving
	
	if not is_currently_moving:
		idle_timer += delta
		if idle_timer >= idle_stabilization_delay:
			is_idle = true
	else:
		idle_timer = 0.0
		is_idle = false

func update_stance_timing(delta: float):
	# Update stance timers for both feet
	if not is_left_stepping:
		left_stance_timer += delta
	else:
		left_stance_timer = 0.0
	
	if not is_right_stepping:
		right_stance_timer += delta
	else:
		right_stance_timer = 0.0
	
	# Calculate minimum stance duration based on current stance ratio
	var min_stance_duration = current_step_duration * current_stance_ratio
	
	# Allow new steps only after minimum stance time
	can_start_left_step = left_stance_timer >= min_stance_duration
	can_start_right_step = right_stance_timer >= min_stance_duration

# ================================
# IDEAL POSITION CALCULATION
# ================================

func calculate_ideal_positions():
	var char_pos = movement_system.character_body.global_position
	var char_right = movement_system.character_body.global_transform.basis.x
	var movement_speed = movement_system.get_current_speed()
	
	if movement_speed > min_movement_threshold:
		# Moving: feet alternate between forward and backward positions
		var half_step = current_step_length * 0.5
		var forward_offset = smoothed_input_direction * half_step
		var backward_offset = smoothed_input_direction * (-half_step)
		var left_offset = char_right * (current_stance_width * 0.5)
		var right_offset = -char_right * (current_stance_width * 0.5)
		
		# Determine which foot should be forward based on stepping state
		if is_left_stepping:
			# Left foot stepping forward, right foot stays back
			ideal_left_position = char_pos + forward_offset + left_offset
			ideal_right_position = char_pos + backward_offset + right_offset
		elif is_right_stepping:
			# Right foot stepping forward, left foot stays back
			ideal_left_position = char_pos + backward_offset + left_offset
			ideal_right_position = char_pos + forward_offset + right_offset
		else:
			# Neither stepping - determine which foot should go forward
			var left_forward_pos = char_pos + forward_offset + left_offset
			var right_forward_pos = char_pos + forward_offset + right_offset
			var left_back_pos = char_pos + backward_offset + left_offset
			var right_back_pos = char_pos + backward_offset + right_offset
			
			var left_to_forward = left_foot_target.distance_to(left_forward_pos)
			var left_to_back = left_foot_target.distance_to(left_back_pos)
			var right_to_forward = right_foot_target.distance_to(right_forward_pos)
			var right_to_back = right_foot_target.distance_to(right_back_pos)
			
			# If left foot is closer to back position, it should step forward
			if left_to_back < left_to_forward and right_to_forward < right_to_back:
				ideal_left_position = left_forward_pos
				ideal_right_position = right_back_pos
			elif right_to_back < right_to_forward and left_to_forward < left_to_back:
				ideal_left_position = left_back_pos
				ideal_right_position = right_forward_pos
			else:
				# Default alternating pattern
				ideal_left_position = left_forward_pos
				ideal_right_position = right_back_pos
	else:
		# Stationary: use current stance width with optional CoG influence
		var left_offset = char_right * (current_stance_width * 0.5)
		var right_offset = -char_right * (current_stance_width * 0.5)
		
		ideal_left_position = char_pos + left_offset
		ideal_right_position = char_pos + right_offset
		
		# Apply CoG stabilization when idle
		if is_idle and enable_cog_stabilization and lcm_center_of_gravity:
			var cog_offset = lcm_center_of_gravity.get_stabilization_offset()
			cog_offset = cog_offset.limit_length(max_cog_offset) * cog_influence_strength
			
			ideal_left_position += cog_offset
			ideal_right_position += cog_offset
	
	# Apply terrain height to ideal positions
	if lcm_terrain_detector:
		ideal_left_position.y = lcm_terrain_detector.get_terrain_height_at(ideal_left_position)
		ideal_right_position.y = lcm_terrain_detector.get_terrain_height_at(ideal_right_position)

# ================================
# STEP TRIGGERING
# ================================

func check_step_triggers():
	# Calculate distances from current foot positions to ideal positions
	var left_distance = left_foot_target.distance_to(ideal_left_position)
	var right_distance = right_foot_target.distance_to(ideal_right_position)
	
	# Check if we should trigger a new step for left foot
	if not is_left_stepping and can_start_left_step and left_distance > current_trigger_distance:
		# Only step if the other foot isn't already stepping (prevent simultaneous steps)
		if not is_right_stepping:
			start_left_step()
	
	# Check if we should trigger a new step for right foot
	if not is_right_stepping and can_start_right_step and right_distance > current_trigger_distance:
		# Only step if the other foot isn't already stepping
		if not is_left_stepping:
			start_right_step()

func start_left_step():
	is_left_stepping = true
	left_step_progress = 0.0
	left_step_start = left_foot_target
	left_stance_timer = 0.0

func start_right_step():
	is_right_stepping = true
	right_step_progress = 0.0
	right_step_start = right_foot_target
	right_stance_timer = 0.0

# ================================
# STEP EXECUTION
# ================================

func update_stepping(delta: float):
	# Update left foot stepping
	if is_left_stepping:
		left_step_progress += delta / current_step_duration
		if left_step_progress >= 1.0:
			# Step complete
			left_step_progress = 1.0
			left_foot_target = ideal_left_position
			is_left_stepping = false
		else:
			# Interpolate step with arc
			left_foot_target = interpolate_step_arc(left_step_start, ideal_left_position, left_step_progress, true)
	
	# Update right foot stepping
	if is_right_stepping:
		right_step_progress += delta / current_step_duration
		if right_step_progress >= 1.0:
			# Step complete
			right_step_progress = 1.0
			right_foot_target = ideal_right_position
			is_right_stepping = false
		else:
			# Interpolate step with arc
			right_foot_target = interpolate_step_arc(right_step_start, ideal_right_position, right_step_progress, false)

func interpolate_step_arc(start_pos: Vector3, end_pos: Vector3, progress: float, is_left_foot: bool) -> Vector3:
	# Linear interpolation for X and Z
	var horizontal_pos = start_pos.lerp(end_pos, progress)
	
	# Get slope-adjusted step height
	var adjusted_step_height = calculate_slope_adjusted_step_height(end_pos, true)
	
	# Arc interpolation for Y (height) with slope adjustment
	var arc_height = adjusted_step_height * sin(progress * PI)
	var base_height = start_pos.y + (end_pos.y - start_pos.y) * progress
	
	return Vector3(horizontal_pos.x, base_height + arc_height, horizontal_pos.z)

# ================================
# PUBLIC ACCESS METHODS
# ================================

func get_left_foot_target() -> Vector3:
	return left_foot_target

func get_right_foot_target() -> Vector3:
	return right_foot_target

func get_is_left_stepping() -> bool:
	return is_left_stepping

func get_is_right_stepping() -> bool:
	return is_right_stepping

func get_current_step_parameters() -> Dictionary:
	return {
		"step_length": current_step_length,
		"step_frequency": current_step_frequency,
		"stance_width": current_stance_width,
		"stance_ratio": current_stance_ratio,
		"step_height": current_step_height,
		"trigger_distance": current_trigger_distance,
		"step_duration": current_step_duration
	}

# ================================
# SLOPE ADJUSTMENT FUNCTIONS
# ================================

func calculate_slope_adjusted_step_height(target_position: Vector3, is_stepping: bool) -> float:
	if not enable_slope_adjustment or not is_stepping or not lcm_terrain_detector:
		return current_step_height
	
	# Get terrain normal at target position
	var terrain_normal = get_terrain_normal_at(target_position)
	if terrain_normal == Vector3.ZERO:
		return current_step_height
	
	# Calculate slope in movement direction
	var movement_dir = smoothed_input_direction
	if movement_dir.length() < 0.1:
		return current_step_height
	
	# Dot product of terrain normal with upward vector gives slope steepness
	var slope_factor = 1.0 - terrain_normal.dot(Vector3.UP)
	
	# Check if slope is upward in movement direction
	var slope_direction = Vector3(terrain_normal.x, 0, terrain_normal.z).normalized()
	var uphill_factor = movement_dir.dot(-slope_direction)  # Negative because normal points away from slope
	
	# Only adjust for uphill movement
	if uphill_factor > 0 and slope_factor > min_slope_for_adjustment:
		var adjustment = slope_factor * uphill_factor * uphill_knee_multiplier
		return current_step_height + adjustment
	
	return current_step_height

func get_terrain_normal_at(position: Vector3) -> Vector3:
	if not lcm_terrain_detector:
		return Vector3.ZERO
	
	# Sample 3 points to calculate normal
	var sample_distance = 0.1
	var center = position
	var right = position + Vector3(sample_distance, 0, 0)
	var forward = position + Vector3(0, 0, sample_distance)
	
	# Get heights at each point
	var center_height = lcm_terrain_detector.get_terrain_height_at(center)
	var right_height = lcm_terrain_detector.get_terrain_height_at(right)
	var forward_height = lcm_terrain_detector.get_terrain_height_at(forward)
	
	# Create 3D points
	var p1 = Vector3(center.x, center_height, center.z)
	var p2 = Vector3(right.x, right_height, right.z)
	var p3 = Vector3(forward.x, forward_height, forward.z)
	
	# Calculate normal using cross product
	var v1 = p2 - p1
	var v2 = p3 - p1
	var normal = v1.cross(v2).normalized()
	
	# Ensure normal points upward
	if normal.y < 0:
		normal = -normal
	
	return normal

# ================================
# DEBUG VISUALIZATION
# ================================

func draw_debug_visualization():
	if not enable_debug:
		return
	
	var thickness = 0.02
	
	# Draw current foot positions
	var left_color = Color.BLUE if not is_left_stepping else Color.CYAN
	var right_color = Color.RED if not is_right_stepping else Color.MAGENTA
	
	DebugDraw3D.draw_sphere(left_foot_target, thickness * 2, left_color)
	DebugDraw3D.draw_sphere(right_foot_target, thickness * 2, right_color)
	
	if show_ideal_positions:
		# Draw ideal positions
		DebugDraw3D.draw_sphere(ideal_left_position, thickness * 1.5, Color.CYAN)
		DebugDraw3D.draw_sphere(ideal_right_position, thickness * 1.5, Color.MAGENTA)
		
		# Draw lines from current to ideal
		DebugDraw3D.draw_line(left_foot_target, ideal_left_position, Color.CYAN)
		DebugDraw3D.draw_line(right_foot_target, ideal_right_position, Color.MAGENTA)
	
	if show_step_triggers:
		# Draw trigger radius around character
		var char_pos = movement_system.character_body.global_position
		DebugDraw3D.draw_sphere(char_pos, current_trigger_distance, Color.YELLOW)
	
	# Draw input direction
	var char_pos = movement_system.character_body.global_position
	var direction_end = char_pos + smoothed_input_direction * 0.5
	DebugDraw3D.draw_arrow(char_pos, direction_end, Color.GREEN, thickness)
	
	if show_speed_info:
		# Display speed parameters (would need UI system)
		pass
