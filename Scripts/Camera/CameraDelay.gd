# CameraDelay.gd - Complete camera delay system with organized sections
extends Node
class_name CameraDelay

# ============================================================================
# HORIZONTAL DELAY SYSTEM (SIMPLIFIED)
# ============================================================================

@export_group("Horizontal Following")
@export var horizontal_delay_time: float = 0.3

# === HORIZONTAL STATE ===
var current_horizontal: Vector3 = Vector3.ZERO
var is_horizontal_smoothing: bool = false

# ============================================================================
# VERTICAL DELAY SYSTEM (SIMPLIFIED)
# ============================================================================

# === VERTICAL DELAY SYSTEM ===
@export_group("Vertical Following")
@export var vertical_delay_time: float = 0.5
@export var vertical_deadzone: float = 0.5  
@export var vertical_deadzone_exit_speed: float = 0.5 

# === VERTICAL STATE ===
var current_vertical: float = 0.0
var is_vertical_smoothing: bool = false

# ============================================================================
# CAMERA LEAD SYSTEM
# ============================================================================
@export_group("Camera Lead")
@export var target_visualization: Node3D
@export var enable_camera_lead: bool = true
@export var camera_lead_distance: float = 1.5
@export var persistent_lead: bool = true
@export var max_movement_speed: float = 6.0

@export var lead_start_multiplier: float = 8.0  # Speed of lead response when moving
@export var lead_end_multiplier: float = 3.0    # Speed of lead return when stopped

# Lead state
var current_lead_direction: Vector2 = Vector2.ZERO
var current_lead_strength: float = 0.0
var frozen_lead_strength: float = 0.0
var is_stopping: bool = false
# ============================================================================
# SHARED CONFIGURATION
# ============================================================================

@export_group("Smoothing Thresholds")
@export var movement_threshold: float = 0.1
@export var position_close_threshold: float = 0.01

# === SHARED STATE ===
var smoothed_position: Vector3 = Vector3.ZERO
var last_target_position: Vector3 = Vector3.ZERO
var target_node: Node3D

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(initial_position: Vector3, target: Node3D):
	smoothed_position = initial_position
	last_target_position = initial_position
	target_node = target
	
	# Initialize horizontal
	current_horizontal = initial_position
	is_horizontal_smoothing = false
	
	# Initialize vertical
	current_vertical = initial_position.y
	is_vertical_smoothing = false
	
	# Initialize lead
	current_lead_direction = Vector2.ZERO


# ============================================================================
# MAIN PROCESSING
# ============================================================================

func process_delay(target_position: Vector3, delta: float) -> Vector3:
	# Store previous position for comparison
	last_target_position = smoothed_position
	
	# Process each axis separately
	process_horizontal_delay(target_position, delta)
	process_vertical_delay(target_position, delta)
	
	return smoothed_position

# ============================================================================
# HORIZONTAL DELAY IMPLEMENTATION
# ============================================================================

func process_horizontal_delay(target_position: Vector3, delta: float):
	# Initialize current horizontal position
	current_horizontal = Vector3(smoothed_position.x, smoothed_position.y, smoothed_position.z)
	
	# Start with character position
	var camera_target = Vector3(target_position.x, target_position.y, target_position.z)
	
	# Apply camera lead FIRST to get final target
	if enable_camera_lead:
		var movement_direction = get_movement_direction()
		camera_target = apply_camera_lead(camera_target, movement_direction, delta)
	
		# Update visualization for non-lead target if no lead active
	if target_visualization and not enable_camera_lead:
		target_visualization.global_position = camera_target
	
	# Apply simple time-based smoothing only
	if horizontal_delay_time > 0:
		var lerp_factor = 1.0 - exp(-delta / horizontal_delay_time)
		current_horizontal = current_horizontal.lerp(camera_target, lerp_factor)
		is_horizontal_smoothing = current_horizontal.distance_to(camera_target) > position_close_threshold
	else:
		current_horizontal = camera_target
		is_horizontal_smoothing = false
	
	# Update final position
	smoothed_position.x = current_horizontal.x
	smoothed_position.z = current_horizontal.z


# ============================================================================
# VERTICAL DELAY IMPLEMENTATION (NEW SIMPLIFIED)
# ============================================================================


func process_vertical_delay(target_position: Vector3, delta: float):
	current_vertical = smoothed_position.y
	
	# Calculate vertical distance from camera to target
	var vertical_distance = target_position.y - current_vertical
	
	# Apply deadzone gating
	if vertical_deadzone > 0:
		# Character is within deadzone - don't move camera
		if abs(vertical_distance) <= vertical_deadzone:
			is_vertical_smoothing = false
			smoothed_position.y = current_vertical
			return
		
		# Character exceeded deadzone - move camera
		# Subtract deadzone from distance so movement starts from zone edge
		var distance_outside_zone = abs(vertical_distance) - vertical_deadzone
		var direction = sign(vertical_distance)
		var target_outside_zone = current_vertical + (direction * distance_outside_zone)
		
		# Smooth movement toward edge of deadzone
		var lerp_factor = 1.0 - exp(-delta / vertical_delay_time)
		current_vertical = lerp(current_vertical, target_outside_zone, lerp_factor)
		is_vertical_smoothing = true
	else:
		# Original behavior - no deadzone, smooth to target
		if vertical_delay_time > 0:
			var lerp_factor = 1.0 - exp(-delta / vertical_delay_time)
			current_vertical = lerp(current_vertical, target_position.y, lerp_factor)
			is_vertical_smoothing = current_vertical != target_position.y
		else:
			current_vertical = target_position.y
			is_vertical_smoothing = false
	
	smoothed_position.y = current_vertical



# ============================================================================
# CAMERA LEAD IMPLEMENTATION
# ============================================================================

func apply_camera_lead(camera_target: Vector3, movement_direction: Vector2, delta: float) -> Vector3:
	if not enable_camera_lead:
		if target_visualization:
			target_visualization.global_position = camera_target
		return camera_target
	
	# Get current velocity magnitude
	var current_speed = 0.0
	if target_node and target_node.has_method("get_velocity"):
		var velocity = target_node.get_velocity()
		current_speed = Vector2(velocity.x, velocity.z).length()
	
	# Determine if moving or stopped
	var is_moving = movement_direction.length() > movement_threshold
	
	if is_moving:
		# MOVING STATE
		is_stopping = false
		
		# Calculate target lead strength based on velocity (0-1 normalized)
		var target_lead_strength = clamp(current_speed / max_movement_speed, 0.0, 1.0)
		
		# Lerp strength and direction toward target
		var lerp_speed = lead_start_multiplier * delta
		current_lead_strength = lerp(current_lead_strength, target_lead_strength, lerp_speed)
		current_lead_direction = current_lead_direction.lerp(movement_direction, lerp_speed)
	
	elif not persistent_lead:
		# STOPPED STATE (only executes if persistent_lead is false)
		if not is_stopping:
			is_stopping = true
			frozen_lead_strength = current_lead_strength
		
		# Lerp back to zero
		var lerp_speed = lead_end_multiplier * delta
		current_lead_direction = current_lead_direction.lerp(Vector2.ZERO, lerp_speed)
		current_lead_strength = lerp(current_lead_strength, 0.0, lerp_speed)
	
	# If persistent_lead is true and stopped: do nothing - values freeze
	
	# Apply lead offset using direction * strength
	if current_lead_direction.length() > 0.01 and current_lead_strength > 0.01:
		var direction_offset = Vector3(current_lead_direction.x, 0, current_lead_direction.y)
		direction_offset *= camera_lead_distance * current_lead_strength
		camera_target += direction_offset
	
	# Update visualization
	if target_visualization:
		target_visualization.global_position = camera_target
	
	return camera_target

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_movement_direction() -> Vector2:
	# Get movement direction from target node velocity if available
	if target_node and target_node.has_method("get_velocity"):
		var velocity = target_node.get_velocity()
		return Vector2(velocity.x, velocity.z).normalized()
	return Vector2.ZERO

func reset_delay():
	if target_node:
		smoothed_position = target_node.global_position
	is_vertical_smoothing = false
	is_horizontal_smoothing = false

func get_smoothed_position() -> Vector3:
	return smoothed_position

# ============================================================================
# CONFIGURATION SETTERS
# ============================================================================

# === HORIZONTAL SETTERS ===

func set_horizontal_delay_time(time: float):
	horizontal_delay_time = time

# === VERTICAL SETTERS ===

func set_vertical_delay_time(new_time: float):
	vertical_delay_time = new_time

# === LEAD SETTERS ===
func set_lead_multipliers(start_mult: float, end_mult: float):
	lead_start_multiplier = start_mult
	lead_end_multiplier = end_mult

func set_max_movement_speed(speed: float):
	max_movement_speed = speed

# ============================================================================
# STATUS QUERIES
# ============================================================================

func is_horizontal_camera_smoothing() -> bool:
	return is_horizontal_smoothing

func is_vertical_camera_smoothing() -> bool:
	return is_vertical_smoothing

func is_camera_lead_active() -> bool:
	return enable_camera_lead and current_lead_direction.length() > 0.01
