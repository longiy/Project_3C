# NavigationCoordinator.gd - Component orchestration
extends Node
class_name NavigationCoordinator


@export_group("Configuration")
@export var navigation_config: NavigationConfig

@export_group("Components")
@export var camera: Camera3D
@export var character_body: CharacterBody3D
@export var navigation_core: NavigationCore
@export var click_detector: ClickDetector
@export var cursor_visual: CursorVisual
@export var marker_manager: MarkerManager



var enabled: bool = true
var navigation_mode: bool = false
var is_dragging_navigation: bool = false

func _ready():
	setup_components()
	connect_signals()

func setup_components():
	if not navigation_config:
		navigation_config = NavigationConfig.new()
	
	if click_detector:
		click_detector.camera = camera
		click_detector.drag_threshold = navigation_config.drag_threshold
	
	if cursor_visual:
		cursor_visual.camera = camera
		cursor_visual.cursor_scene = navigation_config.cursor_scene
	
	if marker_manager:
		marker_manager.target_marker_scene = navigation_config.target_marker_scene
	
	if navigation_core:
		navigation_core.arrival_threshold = navigation_config.navigation_threshold

func connect_signals():
	if click_detector:
		click_detector.click_detected.connect(_on_click_detected)
		click_detector.drag_started.connect(_on_drag_started)
		click_detector.drag_ended.connect(_on_drag_ended)
	
	if navigation_core:
		navigation_core.target_set.connect(_on_target_set)
		navigation_core.target_reached.connect(_on_target_reached)

func process_navigation(input_state: InputState, delta: float):
	if not enabled:
		input_state.clear_navigation()
		return
	
	if input_state.toggle_navigation_pressed:
		toggle_navigation_mode()
		input_state.navigation_mode_changed = true
		input_state.requested_navigation_mode = navigation_mode
	
	if not navigation_mode:
		input_state.clear_navigation()
		return
	
	if cursor_visual:
		cursor_visual.update_cursor_position(input_state.mouse_screen_position)
	
	# Continuous drag following
	if is_dragging_navigation and navigation_config.enable_drag_navigation and click_detector.is_currently_dragging():
		var world_pos = cursor_visual.screen_to_world(input_state.mouse_screen_position)
		if world_pos != Vector3.ZERO and navigation_core:
			navigation_core.set_target(world_pos)
	
	# Active navigation processing
	if navigation_core and navigation_core.is_navigation_active():
		var character_pos = get_character_position()
		if character_pos != Vector3.ZERO:
			if not navigation_core.check_arrival(character_pos):
				var direction = navigation_core.get_movement_direction(character_pos)
				input_state.set_navigation_movement(direction, true)
				return
	
	input_state.clear_navigation()

func _on_click_detected(world_position: Vector3):
	if enabled and navigation_mode and navigation_core:
		navigation_core.set_target(world_position)

func _on_drag_started(start_position: Vector3):
	if not enabled or not navigation_mode or not navigation_config.enable_drag_navigation:
		return
	
	is_dragging_navigation = true
	
	if navigation_core:
		navigation_core.set_target(start_position)
	
	if not navigation_config.show_marker_during_drag and marker_manager:
		marker_manager.clear_all_markers()

func _on_drag_ended(end_position: Vector3):
	is_dragging_navigation = false
	
	if not enabled or not navigation_mode or not navigation_config.enable_drag_navigation:
		return
	
	if not navigation_config.drag_continues_to_end:
		cancel_navigation()
	elif navigation_core:
		navigation_core.set_target(end_position)

func _on_target_set(position: Vector3):
	if marker_manager:
		marker_manager.clear_all_markers()
		marker_manager.spawn_marker(position)

func _on_target_reached():
	if marker_manager:
		marker_manager.clear_all_markers()

func toggle_navigation_mode():
	navigation_mode = not navigation_mode
	
	if cursor_visual:
		if navigation_mode:
			cursor_visual.show_cursor()
		else:
			cursor_visual.hide_cursor()
	
	if not navigation_mode:
		cancel_navigation()

func cancel_navigation():
	if navigation_core:
		navigation_core.stop_navigation()
	if marker_manager:
		marker_manager.clear_all_markers()

func set_enabled(new_enabled: bool):
	enabled = new_enabled
	
	if navigation_core:
		navigation_core.set_enabled(enabled)
	if click_detector:
		click_detector.set_enabled(enabled)
	if cursor_visual:
		cursor_visual.set_enabled(enabled)
	if marker_manager:
		marker_manager.set_enabled(enabled)
	
	if not enabled:
		navigation_mode = false

func get_character_position() -> Vector3:
	return character_body.global_position if character_body else Vector3.ZERO

func is_navigation_mode() -> bool:
	return navigation_mode

func is_navigation_active() -> bool:
	return navigation_core and navigation_core.is_navigation_active()

func get_current_target() -> Vector3:
	if navigation_core:
		return navigation_core.get_target_position()
	return Vector3.ZERO

func get_distance_to_target() -> float:
	if not navigation_core or not navigation_core.is_navigation_active():
		return 0.0
	
	var character_pos = get_character_position()
	if character_pos != Vector3.ZERO:
		return navigation_core.get_distance_to_target(character_pos)
	return 0.0
