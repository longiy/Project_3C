# MouseInputHandler.gd - Full input map implementation
extends RefCounted
class_name MouseInputHandler

var input_config: InputConfig
var mouse_captured: bool = false

func _init(config: InputConfig):
	input_config = config

func process_input(event: InputEvent, input_state: InputState):
	# Handle mouse motion for look and position tracking
	if event is InputEventMouseMotion:
		input_state.mouse_screen_position = event.position
		if mouse_captured:
			input_state.look_delta += event.relative * input_config.mouse_sensitivity
		input_state.current_input_source = InputState.InputSource.KEYBOARD_MOUSE

func update_mouse_input(input_state: InputState):
	# Handle mouse buttons via input map
	if Input.is_action_just_pressed("primary_action"):
		input_state.left_mouse_pressed = true
		input_state.navigation_click_position = input_state.mouse_screen_position
		input_state.current_input_source = InputState.InputSource.KEYBOARD_MOUSE
	
	if Input.is_action_just_released("primary_action"):
		input_state.left_mouse_released = true
		input_state.current_input_source = InputState.InputSource.KEYBOARD_MOUSE
	
	# Handle mouse wheel via input map
	if Input.is_action_just_pressed("mouse_wheel_up"):
		input_state.zoom_delta += 1.0
		input_state.current_input_source = InputState.InputSource.KEYBOARD_MOUSE
	
	if Input.is_action_just_pressed("mouse_wheel_down"):
		input_state.zoom_delta -= 1.0
		input_state.current_input_source = InputState.InputSource.KEYBOARD_MOUSE
	
	# Handle secondary action if needed
	if Input.is_action_just_pressed("secondary_action"):
		# Add right mouse functionality here if needed
		input_state.current_input_source = InputState.InputSource.KEYBOARD_MOUSE

func set_mouse_captured(captured: bool):
	mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
