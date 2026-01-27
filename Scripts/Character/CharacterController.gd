# CharacterController.gd - Cleaned navigation integration
extends Node
class_name CharacterController

@export_group("Configuration")
@export var input_config: InputConfig

@export_group("Components")
@export var character_body: CharacterBody3D
@export var camera_system: CameraSystem
@export var input_coordinator: InputCoordinator
@export var movement_system: MovementSystem
@export var navigation_coordinator: NavigationCoordinator

func _ready():
	initialize_character_controller()

func initialize_character_controller():
	if not input_config:
		input_config = InputConfig.new()
	
	character_body.slide_on_ceiling = false
	character_body.floor_stop_on_slope = true
	character_body.floor_block_on_wall = true
	character_body.floor_snap_length = 0.1
	character_body.floor_max_angle = deg_to_rad(45.0)
	character_body.collision_layer = 2
	character_body.collision_mask = 1
	
	if input_coordinator:
		input_coordinator.input_config = input_config
	if camera_system:
		camera_system.input_config = input_config

func _process(delta):
	var input_state = input_coordinator.get_input_state() if input_coordinator else InputState.new()
	
	if navigation_coordinator:
		navigation_coordinator.process_navigation(input_state, delta)
	if movement_system:
		movement_system.process_movement(input_state, delta)
	if camera_system:	
		camera_system.process_camera(input_state, delta)
	if input_coordinator:
		input_coordinator.process_input_reactions(input_state)

# === NAVIGATION CONVENIENCE METHODS ===
func set_navigation_target(target: Vector3):
	if navigation_coordinator and navigation_coordinator.navigation_core:
		navigation_coordinator.navigation_core.set_target(target)

func cancel_navigation():
	if navigation_coordinator:
		navigation_coordinator.cancel_navigation()

func is_navigation_active() -> bool:
	return navigation_coordinator and navigation_coordinator.is_navigation_active()

# === UTILITY METHODS ===
func get_character_position() -> Vector3:
	return character_body.global_position if character_body else Vector3.ZERO

func get_character_velocity() -> Vector3:
	return character_body.velocity if character_body else Vector3.ZERO

func is_character_on_ground() -> bool:
	return character_body.is_on_floor() if character_body else false
