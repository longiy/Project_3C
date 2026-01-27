# InputState.gd - Clean implementation
extends RefCounted
class_name InputState

enum InputSource {
	KEYBOARD_MOUSE,
	GAMEPAD
}

# === MOVEMENT INPUT ===
var movement: Vector2 = Vector2.ZERO
var sprint_pressed: bool = false
var walk_pressed: bool = false

# === CAMERA/LOOK INPUT ===
var look_delta: Vector2 = Vector2.ZERO
var zoom_delta: float = 0.0

# === JUMP INPUT ===
var jump_pressed: bool = false
var jump_held: bool = false
var jump_just_pressed: bool = false

# === NAVIGATION INPUT ===
var navigation_click_position: Vector2 = Vector2.ZERO
var toggle_navigation_pressed: bool = false
var mouse_screen_position: Vector2 = Vector2.ZERO
var left_mouse_pressed: bool = false
var left_mouse_released: bool = false
var navigation_mode_changed: bool = false
var requested_navigation_mode: bool = false

# === NAVIGATION MOVEMENT ===
var navigation_movement: Vector2 = Vector2.ZERO
var is_navigating: bool = false

# === INPUT SOURCE TRACKING ===
var current_input_source: InputSource = InputSource.KEYBOARD_MOUSE

# === MOVEMENT QUERIES ===
func has_movement() -> bool:
	return movement.length() > 0.0 or navigation_movement.length() > 0.0

func has_look() -> bool:
	return look_delta.length() > 0.0

func has_zoom() -> bool:
	return zoom_delta != 0.0

func has_jump_input() -> bool:
	return jump_pressed or jump_just_pressed

func get_final_movement() -> Vector2:
	if is_navigating and navigation_movement.length() > 0.0:
		return navigation_movement
	return movement

func get_movement_magnitude() -> float:
	return get_final_movement().length()

func is_sprinting() -> bool:
	return sprint_pressed

func is_walking() -> bool:
	return walk_pressed

# === NAVIGATION METHODS ===
func set_navigation_movement(nav_movement: Vector2, navigating: bool):
	navigation_movement = nav_movement
	is_navigating = navigating

func clear_navigation():
	navigation_movement = Vector2.ZERO
	is_navigating = false

# === FRAME DATA MANAGEMENT ===
func clear_frame_data():
	look_delta = Vector2.ZERO
	jump_pressed = false
	jump_just_pressed = false
	toggle_navigation_pressed = false
	left_mouse_pressed = false
	left_mouse_released = false
	navigation_click_position = Vector2.ZERO
	navigation_mode_changed = false
	zoom_delta = 0.0

# === INPUT STATE DUPLICATION ===
func duplicate() -> InputState:
	var new_state = InputState.new()
	
	new_state.movement = movement
	new_state.sprint_pressed = sprint_pressed
	new_state.walk_pressed = walk_pressed
	new_state.look_delta = look_delta
	new_state.zoom_delta = zoom_delta  # Add this line
	new_state.jump_pressed = jump_pressed
	new_state.jump_held = jump_held
	new_state.jump_just_pressed = jump_just_pressed
	new_state.navigation_click_position = navigation_click_position
	new_state.toggle_navigation_pressed = toggle_navigation_pressed
	new_state.mouse_screen_position = mouse_screen_position
	new_state.left_mouse_pressed = left_mouse_pressed
	new_state.left_mouse_released = left_mouse_released
	new_state.navigation_mode_changed = navigation_mode_changed
	new_state.requested_navigation_mode = requested_navigation_mode
	new_state.navigation_movement = navigation_movement
	new_state.is_navigating = is_navigating
	new_state.current_input_source = current_input_source
	
	return new_state
