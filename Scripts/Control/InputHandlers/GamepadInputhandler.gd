# GamepadInputHandler.gd - Fixed to include walk input
extends RefCounted
class_name GamepadInputHandler

var input_config: InputConfig
var gamepad_connected: bool = false

func _init(config: InputConfig):
	input_config = config
	gamepad_connected = Input.get_connected_joypads().size() > 0
	Input.joy_connection_changed.connect(_on_gamepad_changed)

func process_input(event: InputEvent, input_state: InputState):
	if not gamepad_connected or not event is InputEventJoypadButton or not event.pressed:
		return
	
	match event.button_index:
		JOY_BUTTON_A: input_state.jump_pressed = true
		JOY_BUTTON_START: input_state.toggle_navigation_pressed = true
	
	input_state.current_input_source = InputState.InputSource.GAMEPAD

func update_continuous_input(input_state: InputState):
	if not gamepad_connected:
		return
	
	# Movement stick
	var left_stick = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	
	if left_stick.length() > input_config.left_stick_deadzone:
		var scaled = (left_stick.length() - input_config.left_stick_deadzone) / (1.0 - input_config.left_stick_deadzone)
		input_state.movement = left_stick.normalized() * scaled
		input_state.current_input_source = InputState.InputSource.GAMEPAD
	
	# Look stick
	var right_stick = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	
	if right_stick.length() > input_config.right_stick_deadzone:
		var scaled = (right_stick.length() - input_config.right_stick_deadzone) / (1.0 - input_config.right_stick_deadzone)
		input_state.look_delta += right_stick.normalized() * scaled * input_config.gamepad_look_sensitivity
		input_state.current_input_source = InputState.InputSource.GAMEPAD
	
	# Buttons
	input_state.sprint_pressed = Input.is_action_pressed("sprint")
	input_state.walk_pressed = Input.is_action_pressed("walk")
	
	if input_state.sprint_pressed or input_state.walk_pressed:
		input_state.current_input_source = InputState.InputSource.GAMEPAD

func _on_gamepad_changed(_device: int, _connected: bool):
	gamepad_connected = Input.get_connected_joypads().size() > 0
