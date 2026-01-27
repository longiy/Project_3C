# CursorVisual.gd - Cursor visualization only
extends Node
class_name CursorVisual

var camera: Camera3D
var cursor_scene: PackedScene
var enabled: bool = true
var cursor_object: Node3D
var is_visible: bool = false

func _ready():
	call_deferred("setup_cursor")

func setup_cursor():
	if not cursor_scene or not is_inside_tree():
		return
	
	cursor_object = cursor_scene.instantiate()
	get_tree().current_scene.call_deferred("add_child", cursor_object)
	cursor_object.visible = false

func show_cursor():
	is_visible = true
	if cursor_object:
		cursor_object.visible = enabled

func hide_cursor():
	is_visible = false
	if cursor_object:
		cursor_object.visible = false

func update_cursor_position(screen_position: Vector2):
	if not enabled or not is_visible or not cursor_object or not camera:
		return
	
	var world_position = screen_to_world(screen_position)
	if world_position != Vector3.ZERO:
		cursor_object.global_position = world_position

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
	if cursor_object:
		cursor_object.visible = enabled and is_visible
