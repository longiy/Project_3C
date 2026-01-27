# NavigationConfig.gd - Navigation configuration
extends Resource
class_name NavigationConfig

@export_group("Navigation")
@export var navigation_threshold: float = 0.5
@export var drag_threshold: float = 0.1

@export_group("Visual")
@export var cursor_scene: PackedScene
@export var target_marker_scene: PackedScene

@export_group("Drag Behavior")
@export var enable_drag_navigation: bool = true
@export var drag_continues_to_end: bool = false  # false = cancel on drag end (original behavior)
@export var show_marker_during_drag: bool = false  # false = hide marker during drag (original behavior)
