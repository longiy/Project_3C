# MarkerManager.gd - Simplified marker management
extends Node
class_name MarkerManager

var target_marker_scene: PackedScene
var enabled: bool = true
var active_markers: Array[Node3D] = []

func spawn_marker(position: Vector3) -> Node3D:
	if not enabled or not target_marker_scene or not is_inside_tree():
		return null
	
	clear_all_markers()
	
	var marker = target_marker_scene.instantiate()
	marker.position = position
	get_tree().current_scene.call_deferred("add_child", marker)
	marker.call_deferred("set", "global_position", position)
	
	active_markers.append(marker)
	return marker

func clear_all_markers():
	for marker in active_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	active_markers.clear()

func set_enabled(new_enabled: bool):
	enabled = new_enabled
	if not enabled:
		clear_all_markers()
