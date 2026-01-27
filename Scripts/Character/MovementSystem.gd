# MovementSystem.gd - Clean version with advanced movement always enabled
extends Node
class_name MovementSystem

@export_group("Configuration")
@export var movement_config: MovementConfig

@export_group("Components")
@export var character_body: CharacterBody3D
@export var camera_pivot: Camera3D

# === CORE STATE ===
var enabled: bool = true
var current_velocity: Vector3 = Vector3.ZERO
var current_rotation: float = 0.0

# === GROUND DETECTION ===
var is_on_ground: bool = false
var was_on_ground: bool = false

# === JUMP SYSTEM ===
var can_jump: bool = true
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_requested: bool = false

# === MOVEMENT STATE ===
var smoothed_speed_multiplier: float = 1.0
var horizontal_speed: float = 0.0
var ground_velocity: Vector2 = Vector2.ZERO

# === SPEED-DEPENDENT TURNING ===
var current_turn_speed: float = 0.0

# === HYBRID MOVEMENT STATE ===
var current_rotation_influence: float = 0.0
var is_maintaining_momentum: bool = false
var previous_input_direction: Vector2 = Vector2.ZERO
var direction_change_threshold: float = 0.8

# === CAMERA ALIGNMENT STATE ===
var camera_align_triggered: bool = false
var locked_alignment_mode: int = -1  # 0=back, 1=front, 2=left, 3=right

# === DEBUG DATA ===
var debug_input_direction: Vector2 = Vector2.ZERO
var debug_blended_direction: Vector2 = Vector2.ZERO

func _ready():
	if not movement_config:
		movement_config = MovementConfig.new()
	else:
		movement_config.calculate_jump_velocity()
	
	current_turn_speed = movement_config.rotation_speed

func process_movement(input_state: InputState, delta: float):
	if not character_body or not movement_config or not enabled:
		return
	
	update_movement_timers(delta)
	update_ground_state()
	process_jump_input(input_state)
	calculate_hybrid_ground_movement(input_state, delta)
	calculate_speed_dependent_rotation(input_state, delta)
	apply_gravity(delta)
	
	character_body.velocity = current_velocity
	character_body.move_and_slide()
	current_velocity = character_body.velocity
	
	horizontal_speed = Vector2(current_velocity.x, current_velocity.z).length()

func update_movement_timers(delta: float):
	coyote_timer = max(0, coyote_timer - delta)
	jump_buffer_timer = max(0, jump_buffer_timer - delta)

func update_ground_state():
	was_on_ground = is_on_ground
	is_on_ground = character_body.is_on_floor()
	
	if is_on_ground and not was_on_ground:
		can_jump = true

func process_jump_input(input_state: InputState):
	if input_state.jump_pressed:
		jump_buffer_timer = movement_config.jump_buffer_time
		jump_requested = true
	
	var can_coyote_jump = coyote_timer > 0.0
	var can_buffer_jump = jump_buffer_timer > 0.0
	
	if jump_requested and can_jump and (is_on_ground or can_coyote_jump):
		if can_buffer_jump:
			current_velocity.y = movement_config.jump_velocity
			can_jump = false
			jump_requested = false
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
	
	if was_on_ground and not is_on_ground:
		coyote_timer = movement_config.coyote_time

func calculate_hybrid_ground_movement(input_state: InputState, delta: float):
	var final_movement = input_state.get_final_movement()
	
	if final_movement.length() > 0.1:
		# Get movement direction - camera-relative with optional alignment
		var input_direction: Vector2
		
		if movement_config.camera_align_on_movement and input_state.walk_pressed:
			input_direction = get_camera_relative_movement(final_movement) if not input_state.is_navigating else final_movement
			if not camera_align_triggered:
				camera_align_triggered = true
				determine_and_lock_alignment_mode()
		else:
			input_direction = get_camera_relative_movement(final_movement) if not input_state.is_navigating else final_movement
		
		# Check if we're maintaining momentum
		if previous_input_direction.length() > 0.1:
			var direction_similarity = previous_input_direction.dot(input_direction)
			is_maintaining_momentum = direction_similarity > direction_change_threshold and horizontal_speed > movement_config.rotation_influence_start_speed
		else:
			is_maintaining_momentum = false
		
		# Calculate rotation influence factor (always enabled)
		current_rotation_influence = movement_config.get_rotation_influence_factor(horizontal_speed, is_maintaining_momentum)
		
		# Get facing direction from current character rotation
		var facing_direction = Vector2(sin(current_rotation), cos(current_rotation))
		
		# Blend between input direction and facing direction
		var blended_direction: Vector2
		if current_rotation_influence > 0.0:
			blended_direction = input_direction.lerp(facing_direction, current_rotation_influence)
			blended_direction = blended_direction.normalized()
		else:
			blended_direction = input_direction
		
		# Store debug data
		debug_input_direction = input_direction
		debug_blended_direction = blended_direction
		
		# Calculate movement based on blended direction
		var base_speed = movement_config.get_movement_speed(input_state.current_input_source)
		
		var target_multiplier: float = 1.0
		if input_state.sprint_pressed:
			target_multiplier = movement_config.sprint_speed / base_speed
		elif input_state.walk_pressed:
			target_multiplier = movement_config.walk_speed / base_speed
		
		smoothed_speed_multiplier = move_toward(smoothed_speed_multiplier, target_multiplier, movement_config.speed_transition_rate * delta)
		
		var final_speed = base_speed * smoothed_speed_multiplier
		var target_velocity = blended_direction * final_speed
		var accel_rate = movement_config.get_acceleration(input_state.current_input_source)
		
		if not is_on_ground:
			accel_rate *= movement_config.air_direction_control
		
		ground_velocity = ground_velocity.move_toward(target_velocity, accel_rate * delta)
		previous_input_direction = input_direction
	else:
		# Apply deceleration when no input
		var decel_rate = movement_config.deceleration
		ground_velocity = ground_velocity.move_toward(Vector2.ZERO, decel_rate * delta)
		is_maintaining_momentum = false
		previous_input_direction = Vector2.ZERO
		
		# Clear debug data when not moving
		debug_input_direction = Vector2.ZERO
		debug_blended_direction = Vector2.ZERO
		
		# Reset camera alignment when walk is released
		if not input_state.walk_pressed:
			camera_align_triggered = false
			locked_alignment_mode = -1
	
	current_velocity.x = ground_velocity.x
	current_velocity.z = ground_velocity.y

func calculate_speed_dependent_rotation(input_state: InputState, delta: float):
	var final_movement = input_state.get_final_movement()
	
	if final_movement.length() < 0.1:
		return
	
	# Handle camera alignment mode
	if movement_config.camera_align_on_movement and input_state.walk_pressed and camera_align_triggered:
		maintain_locked_alignment(delta)
		return
	
	# Normal input-based rotation
	var camera_relative_input = get_camera_relative_movement(final_movement) if not input_state.is_navigating else final_movement
	var target_angle = atan2(camera_relative_input.x, camera_relative_input.y)
	
	# Calculate speed-dependent turn speed
	current_turn_speed = movement_config.get_speed_dependent_rotation_speed(horizontal_speed, movement_config.sprint_speed)
	
	# Apply air rotation control when airborne
	if not is_on_ground:
		current_turn_speed *= movement_config.air_rotation_control
	
	# Apply gamepad multiplier
	current_turn_speed *= movement_config.get_rotation_speed(input_state.current_input_source) / movement_config.rotation_speed
	
	# Apply rotation with optional snapping
	if movement_config.enable_directional_snapping:
		target_angle = snap_angle_to_increment(target_angle, deg_to_rad(movement_config.snap_angle_degrees))
		current_rotation = target_angle
	else:
		current_rotation = lerp_angle(current_rotation, target_angle, current_turn_speed * delta)
	
	character_body.rotation.y = current_rotation

func apply_gravity(delta: float):
	if not is_on_ground:
		current_velocity.y += movement_config.gravity * delta
	elif is_on_ground and current_velocity.y < 0:
		current_velocity.y = 0

func determine_and_lock_alignment_mode():
	if not camera_pivot:
		return
	
	# Get camera forward direction at the moment alignment is triggered
	var camera_forward = -camera_pivot.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	
	# Calculate all four possible target angles
	var back_facing_angle = atan2(camera_forward.x, camera_forward.z)
	var front_facing_angle = back_facing_angle + PI
	var left_side_angle = back_facing_angle + PI/2
	var right_side_angle = back_facing_angle - PI/2
	
	# Normalize angles
	front_facing_angle = fmod(front_facing_angle + PI, 2*PI) - PI
	left_side_angle = fmod(left_side_angle + PI, 2*PI) - PI
	right_side_angle = fmod(right_side_angle + PI, 2*PI) - PI
	
	# Find the best alignment and lock that mode
	var angles = [back_facing_angle, front_facing_angle, left_side_angle, right_side_angle]
	var min_distance = abs(angle_difference(current_rotation, angles[0]))
	locked_alignment_mode = 0
	
	for i in range(1, angles.size()):
		var distance = abs(angle_difference(current_rotation, angles[i]))
		if distance < min_distance:
			min_distance = distance
			locked_alignment_mode = i

func maintain_locked_alignment(delta: float):
	if not camera_pivot or locked_alignment_mode == -1:
		return
	
	# Get current camera forward direction
	var camera_forward = -camera_pivot.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	
	# Calculate target angle based on locked alignment mode
	var base_angle = atan2(camera_forward.x, camera_forward.z)
	var target_angle: float
	
	match locked_alignment_mode:
		0: target_angle = base_angle  # Back facing
		1: target_angle = base_angle + PI  # Front facing
		2: target_angle = base_angle + PI/2  # Left side
		3: target_angle = base_angle - PI/2  # Right side
	
	# Normalize angle
	target_angle = fmod(target_angle + PI, 2*PI) - PI
	
	# Apply rotation with smoothing
	current_rotation = lerp_angle(current_rotation, target_angle, movement_config.camera_align_rotation_speed * delta)
	character_body.rotation.y = current_rotation

# === COMPUTED PROPERTIES ===
func get_ground_velocity() -> Vector2:
	return ground_velocity

func get_camera_directions() -> Dictionary:
	if not camera_pivot:
		return {"forward": Vector3.FORWARD, "right": Vector3.RIGHT}
	
	var forward = -camera_pivot.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right = camera_pivot.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	
	return {"forward": forward, "right": right}

func get_camera_relative_movement(input: Vector2) -> Vector2:
	if input.length() == 0:
		return Vector2.ZERO
	
	var dirs = get_camera_directions()
	var forward_movement = dirs.forward * input.y
	var right_movement = dirs.right * input.x
	var movement_3d = forward_movement + right_movement
	return Vector2(movement_3d.x, movement_3d.z).normalized()

func snap_angle_to_increment(angle: float, increment: float) -> float:
	return round(angle / increment) * increment

# === PUBLIC API ===
func get_current_speed() -> float:
	return horizontal_speed

func get_movement_direction() -> Vector2:
	return get_ground_velocity().normalized()

func is_moving() -> bool:
	return get_ground_velocity().length() > 0.1

func get_rotation_degrees() -> float:
	return rad_to_deg(current_rotation)

func get_current_turn_speed() -> float:
	return current_turn_speed

func get_speed_ratio() -> float:
	return horizontal_speed / movement_config.sprint_speed if movement_config else 0.0

func get_turn_difficulty() -> float:
	if movement_config:
		return 1.0 - (current_turn_speed / movement_config.rotation_speed)
	return 0.0

func get_rotation_influence() -> float:
	return current_rotation_influence

func is_character_maintaining_momentum() -> bool:
	return is_maintaining_momentum

func get_facing_direction() -> Vector2:
	return Vector2(sin(current_rotation), cos(current_rotation))

func get_movement_vs_facing_angle() -> float:
	var movement_dir = get_movement_direction()
	var facing_dir = get_facing_direction()
	if movement_dir.length() > 0.1:
		return movement_dir.angle_to(facing_dir)
	return 0.0

# === DEBUG DATA ACCESS ===
func get_debug_input_direction() -> Vector2:
	return debug_input_direction

func get_debug_blended_direction() -> Vector2:
	return debug_blended_direction
