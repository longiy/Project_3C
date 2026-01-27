# AnimationController.gd
extends AnimationTree
class_name AnimationController

@export_group("System References")
@export var movement_system: MovementSystem

@export_group("Debug")
@export var debug_values: bool = false
@export var debug_only_changes: bool = true

# === MOVEMENT STATE VARIABLES ===
var movement_speed: float = 0.0
var horizontal_speed: float = 0.0
var vertical_velocity: float = 0.0
var is_grounded: bool = false
var is_moving: bool = false
var is_sprinting: bool = false
var is_jumping: bool = false
var can_jump: bool = false

# === DEBUG TRACKING ===
var prev_movement_speed: float = 0.0
var prev_horizontal_speed: float = 0.0
var prev_movement_blend: float = 0.0
var prev_is_grounded: bool = false
var prev_is_moving: bool = false
var prev_is_sprinting: bool = false

# === MOVEMENT THRESHOLDS ===
var movement_threshold: float = 0.5  # Higher threshold for moving/not moving

# === BLEND SPACE VALUES ===
var movement_blend: float = 0.0

func _ready():
	if movement_system and movement_system.movement_config:
		# Higher threshold to account for residual movement
		movement_threshold = movement_system.movement_config.walk_speed * 0.5

func _process(_delta):
	update_movement_state()
	
	if debug_values:
		if debug_only_changes:
			debug_print_changes()
		else:
			debug_print_values()

func update_movement_state():
	if not movement_system:
		return
	
	# Calculate speeds
	var velocity_2d = Vector2(movement_system.current_velocity.x, movement_system.current_velocity.z)
	horizontal_speed = velocity_2d.length()
	vertical_velocity = movement_system.current_velocity.y
	movement_speed = horizontal_speed
	
	# Update state booleans
	is_grounded = movement_system.is_on_ground
	is_moving = horizontal_speed > movement_threshold
	is_sprinting = false  # Remove complex sprint detection
	is_jumping = not is_grounded and vertical_velocity > 0.1
	can_jump = movement_system.can_jump
	
	# Calculate blend values
	update_blend_values()

func update_blend_values():
	if not movement_system or not movement_system.movement_config:
		return

	var config = movement_system.movement_config
	var walk_speed = config.walk_speed
	var run_speed = config.run_speed
	var sprint_speed = config.sprint_speed

	if horizontal_speed <= walk_speed:
		movement_blend = remap(horizontal_speed, 0.0, walk_speed, 0.0, 0.0)  # Walk range
	elif horizontal_speed <= run_speed:
		movement_blend = remap(horizontal_speed, walk_speed, run_speed, 0.0, 0.5)  # Walk to Run
	else:
		movement_blend = remap(horizontal_speed, run_speed, sprint_speed, 0.5, 1.0)  # Run to Sprint

	movement_blend = clamp(movement_blend, 0.0, 1.0)
	set("parameters/RunSprint/blend_position", movement_blend)
	
# === UTILITY FUNCTIONS FOR ANIMATION TREE ===
func get_movement_blend() -> float:
	return movement_blend

func get_horizontal_speed() -> float:
	return horizontal_speed

func get_movement_speed() -> float:
	return movement_speed

func is_character_grounded() -> bool:
	return is_grounded

func is_character_moving() -> bool:
	return is_moving

func can_character_jump() -> bool:
	return can_jump

func debug_print_changes():
	if abs(movement_speed - prev_movement_speed) > 0.1:
		print("Movement Speed: ", movement_speed)
		prev_movement_speed = movement_speed
	
	if abs(horizontal_speed - prev_horizontal_speed) > 0.1:
		print("Horizontal Speed: ", horizontal_speed)
		prev_horizontal_speed = horizontal_speed
	
	if abs(movement_blend - prev_movement_blend) > 0.05:
		print("Movement Blend: ", movement_blend)
		prev_movement_blend = movement_blend
	
	if is_grounded != prev_is_grounded:
		print("Is Grounded: ", is_grounded)
		prev_is_grounded = is_grounded
	
	if is_moving != prev_is_moving:
		print("Is Moving: ", is_moving)
		prev_is_moving = is_moving
	
	if is_sprinting != prev_is_sprinting:
		print("Is Sprinting: ", is_sprinting)
		prev_is_sprinting = is_sprinting

func debug_print_values():
	print("=== ANIMATION CONTROLLER DEBUG ===")
	print("Movement Speed: ", movement_speed)
	print("Horizontal Speed: ", horizontal_speed)
	print("Movement Blend: ", movement_blend)
	print("Is Grounded: ", is_grounded)
	print("Is Moving: ", is_moving)
	print("Is Jumping: ", is_jumping)
	print("===================================")
