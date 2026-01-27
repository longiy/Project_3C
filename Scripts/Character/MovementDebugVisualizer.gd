# MovementDebugVisualizer.gd - Separate debug visualization for MovementSystem
extends Node
class_name MovementDebugVisualizer

@export_group("Debug Visualization")
@export var enable_debug_vectors: bool = false
@export var enable_console_debug: bool = false
@export var vector_length_multiplier: float = 2.0
@export var vector_height_offset: float = 1.5
@export var console_update_interval: int = 30  # Frames between console updates
@export var line_thickness: float = 0.01  # Base thickness for debug arrows and lines
@export var use_screen_space_thickness: bool = true  # Scale thickness based on camera distance

@export_group("Vector Colors")
@export var input_direction_color: Color = Color.YELLOW
@export var facing_direction_color: Color = Color.RED
@export var blended_direction_color: Color = Color.GREEN
@export var velocity_direction_color: Color = Color.BLUE

# Reference to parent MovementSystem
var movement_system: MovementSystem

# Debug data storage
var debug_input_direction: Vector2 = Vector2.ZERO
var debug_facing_direction: Vector2 = Vector2.ZERO
var debug_blended_direction: Vector2 = Vector2.ZERO
var debug_velocity_direction: Vector2 = Vector2.ZERO
var debug_rotation_influence: float = 0.0
var debug_is_maintaining_momentum: bool = false
var debug_horizontal_speed: float = 0.0
var debug_turn_speed: float = 0.0

func _ready():
	# Get reference to parent MovementSystem
	movement_system = get_parent() as MovementSystem
	if not movement_system:
		push_error("MovementDebugVisualizer must be a child of MovementSystem!")
		queue_free()
		return
	
	print("MovementDebugVisualizer initialized")

func _process(_delta):
	if not movement_system or not movement_system.character_body:
		return
	
	# Update debug data from MovementSystem
	update_debug_data()
	
	# Draw visual debug if enabled
	if enable_debug_vectors:
		draw_debug_vectors()
	
	# Print console debug if enabled
	if enable_console_debug and Engine.get_process_frames() % console_update_interval == 0:
		print_debug_info()

func update_debug_data():
	if not movement_system:
		return
	
	# Get debug data from MovementSystem through public getters
	debug_horizontal_speed = movement_system.get_current_speed()
	debug_turn_speed = movement_system.get_current_turn_speed()
	debug_rotation_influence = movement_system.get_rotation_influence()
	debug_is_maintaining_momentum = movement_system.is_character_maintaining_momentum()
	
	# Get directions
	debug_facing_direction = movement_system.get_facing_direction()
	debug_velocity_direction = movement_system.get_movement_direction()
	
	# Access internal debug data (MovementSystem will expose these)
	if movement_system.has_method("get_debug_input_direction"):
		debug_input_direction = movement_system.get_debug_input_direction()
	if movement_system.has_method("get_debug_blended_direction"):
		debug_blended_direction = movement_system.get_debug_blended_direction()

func draw_debug_vectors():
	if not movement_system or not movement_system.character_body:
		return
	
	var char_pos = movement_system.character_body.global_position
	var base_pos = Vector3(char_pos.x, char_pos.y + vector_height_offset, char_pos.z)
	
	if not has_debug_draw():
		return
	
	# Calculate thickness scaling for screen-space effect
	var effective_thickness = line_thickness
	if use_screen_space_thickness:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var distance = camera.global_position.distance_to(base_pos)
			effective_thickness = line_thickness * (distance / 5.0)  # Adjust 5.0 as needed
	
	# Set line thickness for all arrows using scoped config
	var scoped_config = DebugDraw3D.new_scoped_config().set_thickness(effective_thickness)
	
	# Input direction vector (Yellow)
	if debug_input_direction.length() > 0.1:
		var input_end = base_pos + Vector3(debug_input_direction.x, 0, debug_input_direction.y) * vector_length_multiplier
		DebugDraw3D.draw_arrow(base_pos, input_end, input_direction_color, effective_thickness * 2.0)
		DebugDraw3D.draw_sphere(input_end, effective_thickness * 3.0, input_direction_color)
	
	# Facing direction vector (Red)
	if debug_facing_direction.length() > 0.1:
		var facing_end = base_pos + Vector3(debug_facing_direction.x, 0, debug_facing_direction.y) * vector_length_multiplier
		DebugDraw3D.draw_arrow(base_pos, facing_end, facing_direction_color, effective_thickness * 2.0)
		DebugDraw3D.draw_sphere(facing_end, effective_thickness * 3.0, facing_direction_color)
	
	# Blended direction vector (Green)
	if debug_blended_direction.length() > 0.1:
		var blended_end = base_pos + Vector3(debug_blended_direction.x, 0, debug_blended_direction.y) * vector_length_multiplier
		DebugDraw3D.draw_arrow(base_pos, blended_end, blended_direction_color, effective_thickness * 2.0)
		DebugDraw3D.draw_sphere(blended_end, effective_thickness * 3.0, blended_direction_color)
	
	# Velocity direction vector (Blue)
	if debug_velocity_direction.length() > 0.1:
		var velocity_end = base_pos + Vector3(debug_velocity_direction.x, 0, debug_velocity_direction.y) * vector_length_multiplier
		DebugDraw3D.draw_arrow(base_pos, velocity_end, velocity_direction_color, effective_thickness * 1.5)
		DebugDraw3D.draw_sphere(velocity_end, effective_thickness * 2.5, velocity_direction_color)

func print_debug_info():
	if not has_meaningful_debug_data():
		return
	
	print("=== MOVEMENT DEBUG ===")
	print("Input Direction: (%.2f, %.2f)" % [debug_input_direction.x, debug_input_direction.y])
	print("Facing Direction: (%.2f, %.2f)" % [debug_facing_direction.x, debug_facing_direction.y])
	print("Blended Direction: (%.2f, %.2f)" % [debug_blended_direction.x, debug_blended_direction.y])
	print("Velocity Direction: (%.2f, %.2f)" % [debug_velocity_direction.x, debug_velocity_direction.y])
	print("Rotation Influence: %.1f%%" % (debug_rotation_influence * 100))
	print("Maintaining Momentum: %s" % ("YES" if debug_is_maintaining_momentum else "NO"))
	print("Speed: %.2f" % debug_horizontal_speed)
	print("Turn Speed: %.2f" % debug_turn_speed)
	print("====================")

func has_debug_draw() -> bool:
	# Check if DebugDraw3D is available
	return Engine.has_singleton("DebugDraw3D") or (get_node_or_null("/root/DebugDraw3D") != null)

func has_meaningful_debug_data() -> bool:
	return debug_input_direction.length() > 0.1 or debug_facing_direction.length() > 0.1 or debug_horizontal_speed > 0.1

# === MANUAL DEBUG TRIGGERS ===
func toggle_vector_debug():
	enable_debug_vectors = !enable_debug_vectors
	print("Debug vectors: ", "ON" if enable_debug_vectors else "OFF")

func toggle_console_debug():
	enable_console_debug = !enable_console_debug
	print("Console debug: ", "ON" if enable_console_debug else "OFF")

func print_single_debug():
	print_debug_info()

# === CONFIGURATION METHODS ===
func set_vector_colors(input: Color, facing: Color, blended: Color, velocity: Color):
	input_direction_color = input
	facing_direction_color = facing
	blended_direction_color = blended
	velocity_direction_color = velocity

func set_vector_scale(length_multiplier: float, height_offset: float):
	vector_length_multiplier = length_multiplier
	vector_height_offset = height_offset

func set_console_interval(frames: int):
	console_update_interval = max(1, frames)

func set_line_thickness(thickness: float):
	line_thickness = max(0.001, thickness)
