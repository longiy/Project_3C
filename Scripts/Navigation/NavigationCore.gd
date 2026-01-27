# NavigationCore.gd - Simplified core logic
extends Node
class_name NavigationCore

signal target_set(position: Vector3)
signal target_reached()
signal navigation_stopped()

var arrival_threshold: float = 0.5
var current_target: Vector3 = Vector3.ZERO
var is_active: bool = false
var enabled: bool = true

func set_target(world_position: Vector3):
	if not enabled:
		return
	
	current_target = world_position
	is_active = true
	target_set.emit(world_position)

func stop_navigation():
	if is_active:
		is_active = false
		current_target = Vector3.ZERO
		navigation_stopped.emit()

func check_arrival(character_position: Vector3) -> bool:
	if not is_active or not enabled:
		return false
	
	if character_position.distance_to(current_target) < arrival_threshold:
		stop_navigation()
		target_reached.emit()
		return true
	return false

func get_movement_direction(character_position: Vector3) -> Vector2:
	if not is_active or not enabled:
		return Vector2.ZERO
	
	var direction_3d = (current_target - character_position).normalized()
	return Vector2(direction_3d.x, direction_3d.z)

func set_enabled(new_enabled: bool):
	enabled = new_enabled
	if not enabled:
		stop_navigation()

func is_navigation_active() -> bool:
	return is_active and enabled

func get_target_position() -> Vector3:
	return current_target

func get_distance_to_target(character_position: Vector3) -> float:
	if not is_active:
		return 0.0
	return character_position.distance_to(current_target)
