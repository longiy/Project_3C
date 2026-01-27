# KeyboardInputHandler.gd - Fixed to include walk input
extends RefCounted
class_name KeyboardInputHandler

var input_config: InputConfig

func _init(config: InputConfig):
	input_config = config

func process_input(event: InputEvent, input_state: InputState):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB: input_state.toggle_navigation_pressed = true
			KEY_SPACE: input_state.jump_pressed = true

func update_movement_input(input_state: InputState):
	var movement = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_backward", "move_forward")
	)
	
	input_state.movement = movement
	input_state.jump_held = Input.is_action_pressed("jump")
	input_state.sprint_pressed = Input.is_action_pressed("sprint")
	input_state.walk_pressed = Input.is_action_pressed("walk")
	
	if input_state.movement.length() > 0.0:
		input_state.current_input_source = InputState.InputSource.KEYBOARD_MOUSE
