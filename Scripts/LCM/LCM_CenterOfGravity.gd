# LCM_CenterOfGravity.gd - Movement-based Center of Gravity positioning
extends Node3D
class_name LCM_CenterOfGravity

# === REFERENCES ===
@export_group("Required References")
@export var character_body: CharacterBody3D

# === OFFSET PARAMETERS ===
@export_group("Movement Offset")
@export var max_forward_offset: float = 0.3      # Maximum forward CoG shift
@export var max_backward_offset: float = 0.1     # Maximum backward CoG shift for deceleration
@export var max_lateral_offset: float = 0.1      # Maximum lateral CoG shift for turning
@export var speed_threshold: float = 1.0         # Speed at which max offset is reached
@export var offset_response_speed: float = 8.0   # How quickly CoG responds to movement changes

# === STABILIZATION PARAMETERS ===
@export_group("Stabilization")
@export var enable_stabilization: bool = true    # Enable foot stabilization offset calculation
@export var stabilization_strength: float = 1.0  # Multiplier for stabilization offset
@export var max_stabilization_distance: float = 0.3  # Maximum distance for stabilization offset

# === DIRECTIONAL CONTROL ===
@export_group("Directional Behavior")
@export var use_movement_direction: bool = true   # Use actual velocity direction
@export var use_input_direction: bool = false    # Use input direction instead

# === DEBUG ===
@export_group("Debug")
@export var enable_debug_visuals: bool = true
@export var show_offset_vector: bool = true
@export var show_base_position: bool = true
@export var show_stabilization_vector: bool = true

# === INTERNAL VARIABLES ===
var base_position: Vector3                       # Original local position relative to character
var target_offset: Vector3 = Vector3.ZERO       # Calculated target offset
var current_offset: Vector3 = Vector3.ZERO      # Current applied offset
var movement_velocity: Vector3
var movement_speed: float
var is_moving: bool = false

# Stabilization variables
var neutral_cog_position: Vector3 = Vector3.ZERO # Character's neutral CoG position in world space
var current_stabilization_offset: Vector3 = Vector3.ZERO

# Debug state tracking
var previous_movement_mode: String = ""
var previous_is_moving: bool = false

func _ready():
	initialize_movement_offset()

func initialize_movement_offset():
	if not validate_references():
		push_error("LCM_CenterOfGravity: Missing required references")
		return
	
	# Store the base position relative to character
	base_position = position
	
	# Initialize neutral CoG position
	update_neutral_cog_position()
	
	print("LCM Center of Gravity Controller initialized")

func validate_references() -> bool:
	return character_body != null

func _process(delta):
	if not validate_references():
		return
	
	update_movement_data()
	update_neutral_cog_position()
	calculate_target_offset()
	apply_offset_smoothing(delta)
	update_cog_position()
	calculate_stabilization_offset()
	
	if enable_debug_visuals:
		draw_debug_visualization()
		debug_state_changes()

func update_movement_data():
	movement_velocity = character_body.velocity
	movement_speed = Vector2(movement_velocity.x, movement_velocity.z).length()
	is_moving = movement_speed > 0.1

func update_neutral_cog_position():
	# Calculate where CoG would be in neutral stance (no movement offset)
	neutral_cog_position = character_body.global_position + (character_body.global_transform.basis * base_position)

func calculate_target_offset():
	if not is_moving:
		# Return to neutral position when stopped
		target_offset = Vector3.ZERO
		return
	
	# Get character's local coordinate system
	var character_transform = character_body.global_transform
	var character_forward = character_transform.basis.z   # Character's forward direction in world space (flipped)
	var character_right = character_transform.basis.x     # Character's right direction in world space
	
	# Convert world velocity to character-local velocity
	var world_velocity_2d = Vector3(movement_velocity.x, 0, movement_velocity.z)
	var local_forward_speed = world_velocity_2d.dot(character_forward)
	var local_right_speed = world_velocity_2d.dot(character_right)
	
	# Calculate forward/backward offset based on forward speed
	var forward_speed_ratio = clamp(abs(local_forward_speed) / speed_threshold, 0.0, 1.0)
	var forward_offset_amount = max_forward_offset * forward_speed_ratio
	
	# Determine if moving forward or backward
	if local_forward_speed < 0:
		# Moving backward, use backward offset
		forward_offset_amount = -max_backward_offset * forward_speed_ratio
	
	# Apply offset in character's LOCAL coordinate system
	var forward_component = Vector3(0, 0, forward_offset_amount)  # Local Z offset
	
	# Calculate lateral offset for strafing/turning
	var lateral_component = Vector3.ZERO
	if max_lateral_offset > 0.0 and abs(local_right_speed) > 0.1:
		var lateral_speed_ratio = clamp(abs(local_right_speed) / speed_threshold, 0.0, 1.0)
		var lateral_offset_amount = max_lateral_offset * lateral_speed_ratio
		if local_right_speed < 0:
			lateral_offset_amount = -lateral_offset_amount
		lateral_component = Vector3(lateral_offset_amount, 0, 0)  # Local X offset
	
	target_offset = forward_component + lateral_component

func apply_offset_smoothing(delta):
	# Direct application - no smoothing
	current_offset = target_offset

func update_cog_position():
	# Apply offset to base position
	var new_position = base_position + current_offset
	
	# Update the node's local position
	position = new_position

func calculate_stabilization_offset():
	if not enable_stabilization:
		current_stabilization_offset = Vector3.ZERO
		return
	
	# Calculate offset from neutral position to current CoG position
	var cog_deviation = global_position - neutral_cog_position
	
	# Project deviation onto horizontal plane (ignore Y axis)
	var horizontal_deviation = Vector3(cog_deviation.x, 0, cog_deviation.z)
	
	# Apply stabilization strength and distance limits
	var stabilization_offset = horizontal_deviation * stabilization_strength
	stabilization_offset = stabilization_offset.limit_length(max_stabilization_distance)
	
	# Invert the offset - if CoG shifts forward, feet should shift forward to compensate
	current_stabilization_offset = stabilization_offset

func draw_debug_visualization():
	if not enable_debug_visuals:
		return
	
	var world_base_position = character_body.global_position + (character_body.global_transform.basis * base_position)
	var world_current_position = global_position
	
	# Draw base position (neutral CoG)
	if show_base_position:
		DebugDraw3D.draw_sphere(world_base_position, 0.08, Color.GRAY)
	
	# Draw current CoG position
	DebugDraw3D.draw_sphere(world_current_position, 0.1, Color.YELLOW)
	
	# Draw offset vector
	if show_offset_vector and current_offset.length() > 0.01:
		DebugDraw3D.draw_arrow(world_base_position, world_current_position, Color.GREEN, 0.02)
	
	# Draw stabilization vector
	if show_stabilization_vector and current_stabilization_offset.length() > 0.01:
		var stabilization_end = world_current_position + current_stabilization_offset
		DebugDraw3D.draw_arrow(world_current_position, stabilization_end, Color.CYAN, 0.02)
		DebugDraw3D.draw_sphere(stabilization_end, 0.05, Color.CYAN)

func debug_state_changes():
	var current_movement_mode = get_movement_mode()
	
	# Only print when movement mode changes
	if current_movement_mode != previous_movement_mode:
		print("Movement mode changed: %s -> %s" % [previous_movement_mode, current_movement_mode])
		previous_movement_mode = current_movement_mode
	
	# Only print when moving state changes
	if is_moving != previous_is_moving:
		print("Moving state changed: %s -> %s" % [previous_is_moving, is_moving])
		previous_is_moving = is_moving

# === PUBLIC API ===
func get_current_offset() -> Vector3:
	return current_offset

func get_target_offset() -> Vector3:
	return target_offset

func is_character_moving() -> bool:
	return is_moving

func get_movement_speed() -> float:
	return movement_speed

func get_movement_mode() -> String:
	return "walking" if is_moving else "standing"

func is_walking_mode() -> bool:
	return is_moving

func is_standing_mode() -> bool:
	return not is_moving

func get_base_position() -> Vector3:
	return base_position

func set_base_position(new_base: Vector3):
	base_position = new_base

func reset_to_base_position():
	target_offset = Vector3.ZERO
	current_offset = Vector3.ZERO
	position = base_position

# === CONFIGURATION API ===
func set_max_forward_offset(offset: float):
	max_forward_offset = offset

func set_offset_response_speed(speed: float):
	offset_response_speed = speed

func set_smoothing_enabled(enabled: bool):
	# Smoothing removed - handled by movement system
	pass

# === API FOR STABILITY CONTROLLER ===
func get_cog_world_position() -> Vector3:
	return global_position

func get_cog_raycast_ground_position() -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3(0, -10, 0)
	)
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		return Vector3(global_position.x, 0, global_position.z)

# === STABILIZATION API ===
func get_stabilization_offset() -> Vector3:
	"""Returns the 3D offset vector for foot positioning to maintain balance"""
	return current_stabilization_offset

func get_neutral_cog_position() -> Vector3:
	"""Returns the neutral (non-offset) center of gravity position"""
	return neutral_cog_position

func set_stabilization_strength(strength: float):
	"""Adjust how strongly the stabilization offset affects foot placement"""
	stabilization_strength = clamp(strength, 0.0, 2.0)

func set_max_stabilization_distance(distance: float):
	"""Set maximum distance the stabilization offset can extend"""
	max_stabilization_distance = clamp(distance, 0.1, 1.0)
