# InputCoordinator.gd - Updated to work with cleaned handlers
extends Node
class_name InputCoordinator

@export var input_config: InputConfig

# Input handlers
var mouse_handler: MouseInputHandler
var keyboard_handler: KeyboardInputHandler
var gamepad_handler: GamepadInputHandler

# State management
var navigation_mode: bool = false
var camera_active: bool = true
var cached_input_state: InputState

func _ready():
	if not input_config:
		input_config = InputConfig.new()
	
	# Initialize handlers
	mouse_handler = MouseInputHandler.new(input_config)
	keyboard_handler = KeyboardInputHandler.new(input_config)
	gamepad_handler = GamepadInputHandler.new(input_config)
	
	cached_input_state = InputState.new()
	update_mouse_capture()

func _input(event: InputEvent):
	# Direct event type routing instead of can_handle()
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_handler.process_input(event, cached_input_state)
	elif event is InputEventKey:
		keyboard_handler.process_input(event, cached_input_state)
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		gamepad_handler.process_input(event, cached_input_state)

func _process(_delta: float):
	keyboard_handler.update_movement_input(cached_input_state)
	mouse_handler.update_mouse_input(cached_input_state)  # Change this line
	
	if gamepad_handler.gamepad_connected:
		gamepad_handler.update_continuous_input(cached_input_state)
	
	# Handle navigation mode changes from NavigationSystem
	if cached_input_state.navigation_mode_changed:
		navigation_mode = cached_input_state.requested_navigation_mode
		update_mouse_capture()
	
	# Update mouse position for navigation when mouse not captured
	if not mouse_handler.mouse_captured:
		cached_input_state.mouse_screen_position = get_viewport().get_mouse_position()
	
	update_mouse_capture()

func update_mouse_capture():
	var should_capture = camera_active and not navigation_mode
	mouse_handler.set_mouse_captured(should_capture)

func get_raw_input_state() -> InputState:
	return cached_input_state.duplicate()

func process_input_reactions(input_state: InputState):
	# Handle navigation mode changes from systems
	if input_state.navigation_mode_changed:
		navigation_mode = input_state.requested_navigation_mode
		update_mouse_capture()
	
	# Clear frame data after all processing
	cached_input_state.clear_frame_data()

func get_input_state() -> InputState:
	var return_state = cached_input_state.duplicate()
	cached_input_state.clear_frame_data()
	return return_state

func set_camera_active(active: bool):
	camera_active = active
	update_mouse_capture()

func is_navigation_mode() -> bool:
	return navigation_mode

func is_camera_active() -> bool:
	return camera_active

func update_mouse_sensitivity(new_sensitivity: Vector2):
	if input_config:
		input_config.mouse_sensitivity = new_sensitivity
	if mouse_handler:
		mouse_handler.input_config.mouse_sensitivity = new_sensitivity

func update_gamepad_sensitivity(new_sensitivity: Vector2):
	if input_config:
		input_config.gamepad_look_sensitivity = new_sensitivity
	if gamepad_handler:
		gamepad_handler.input_config.gamepad_look_sensitivity = new_sensitivity
