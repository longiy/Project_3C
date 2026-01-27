# InputConfig.gd - Pure input settings only
extends Resource
class_name InputConfig

@export_group("Mouse Settings")
@export var mouse_sensitivity: Vector2 = Vector2(0.002, 0.002)
@export var invert_y: bool = false
@export var mouse_acceleration: float = 1.0

@export_group("Gamepad Settings")
@export var gamepad_look_sensitivity: Vector2 = Vector2(0.3, 0.15)
@export var left_stick_deadzone: float = 0.1
@export var right_stick_deadzone: float = 0.1
@export var gamepad_acceleration: float = 1.0

@export_group("Input Detection")
@export var auto_detect_input_device: bool = true
@export var input_switch_threshold: float = 0.1

@export_group("Camera Integration")
@export var vertical_look_limit: float = 80.0
@export var horizontal_smoothing: float = 10.0
@export var vertical_smoothing: float = 10.0
