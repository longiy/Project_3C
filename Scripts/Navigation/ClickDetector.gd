# ClickDetector.gd - Simplified click processing
extends Node
class_name ClickDetector

signal click_detected(world_position: Vector3)
signal drag_started(start_position: Vector3)
signal drag_ended(end_position: Vector3)

var camera: Camera3D
var drag_threshold: float = 0.1
var enabled: bool = true
var mouse_down: bool = false
var click_start_time: float = 0.0
var is_dragging: bool = false

func _input(event: InputEvent):
	if not enabled or not event is InputEventMouseButton:
		return
	
	var mouse_event = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if mouse_event.pressed:
		mouse_down = true
		click_start_time = Time.get_unix_time_from_system()
		is_dragging = false
	else:
		mouse_down = false
		
		if is_dragging:
			var world_pos = screen_to_world(mouse_event.position)
			if world_pos != Vector3.ZERO:
				drag_ended.emit(world_pos)
		else:
			var world_pos = screen_to_world(mouse_event.position)
			if world_pos != Vector3.ZERO:
				click_detected.emit(world_pos)
		
		is_dragging = false

func _process(_delta: float):
	if not enabled or not mouse_down or is_dragging:
		return
	
	if Time.get_unix_time_from_system() - click_start_time > drag_threshold:
		is_dragging = true
		var world_pos = screen_to_world(get_viewport().get_mouse_position())
		if world_pos != Vector3.ZERO:
			drag_started.emit(world_pos)

func screen_to_world(screen_pos: Vector2) -> Vector3:
	if not camera:
		return Vector3.ZERO
	
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000.0
	
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	return result.position if result else Vector3.ZERO

func set_enabled(new_enabled: bool):
	enabled = new_enabled
	if not enabled:
		mouse_down = false
		is_dragging = false

func is_currently_dragging() -> bool:
	return is_dragging
