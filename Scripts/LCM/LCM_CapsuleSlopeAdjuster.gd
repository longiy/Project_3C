# LCM_LCM_CapsuleSlopeAdjuster.gd
# Simple slope-based capsule adjustment using TerrainDetector
extends Node3D
class_name LCM_CapsuleSlopeAdjuster

@export_group("Required References")
@export var character_body: CharacterBody3D
@export var collision_shape: CollisionShape3D
@export var terrain_detector: LCM_TerrainDetector

@export_group("Adjustment Settings")
@export var vertical_smoothing: float = 12.0
@export var uphill_offset: float = 0.15  # How much to raise on uphill
@export var downhill_offset: float = 0.1  # How much to raise on downhill
@export var side_slope_offset: float = 0.08  # How much to raise on side slopes
@export var max_adjustment: float = 0.3  # Maximum total adjustment
@export var side_slope_threshold: float = 10.0  # Minimum angle for side slope detection

@export_group("Debug")
@export var enable_debug: bool = false

# Internal variables
var original_capsule_position: Vector3
var target_vertical_offset: float = 0.0
var current_vertical_offset: float = 0.0

func _ready():
	if not character_body:
		push_error("LCM_CapsuleSlopeAdjuster: CharacterBody3D reference required")
		return
	
	if not collision_shape:
		push_error("LCM_CapsuleSlopeAdjuster: CollisionShape3D reference required")
		return
	
	if not terrain_detector:
		push_error("LCM_CapsuleSlopeAdjuster: LCM_TerrainDetector reference required")
		return
	
	original_capsule_position = collision_shape.position

func _physics_process(delta):
	if not character_body or not collision_shape or not terrain_detector:
		return
	
	calculate_slope_offset()
	apply_smooth_adjustment(delta)
	
	if enable_debug:
		draw_debug_info()

func calculate_slope_offset():
	var terrain_analysis = terrain_detector.get_terrain_analysis()
	var forward_trend = terrain_analysis.forward_trend
	var side_slope_angle = terrain_analysis.side_slope_angle
	
	var forward_offset = 0.0
	var side_offset = 0.0
	
	# Calculate forward slope offset
	match forward_trend:
		"ascending":  # Going uphill
			forward_offset = uphill_offset
		"descending":  # Going downhill
			forward_offset = downhill_offset
		"flat":  # Flat terrain
			forward_offset = 0.0
		_:  # Stationary or unknown
			forward_offset = 0.0
	
	# Calculate side slope offset
	if side_slope_angle > side_slope_threshold:
		side_offset = side_slope_offset
	
	# Combine offsets (take maximum to avoid excessive adjustment)
	var combined_offset = max(forward_offset, side_offset)
	
	# Clamp to maximum adjustment
	target_vertical_offset = clamp(combined_offset, 0.0, max_adjustment)

func get_side_slope_angle() -> float:
	var char_pos = character_body.global_position
	var char_right = character_body.global_transform.basis.x
	
	# Sample terrain to left and right
	var left_pos = char_pos + char_right * -0.5  # 50cm to left
	var right_pos = char_pos + char_right * 0.5  # 50cm to right
	
	var left_height = terrain_detector.get_terrain_height_at(left_pos)
	var right_height = terrain_detector.get_terrain_height_at(right_pos)
	
	# Calculate side slope angle
	var height_difference = right_height - left_height
	var horizontal_distance = 1.0  # 1 meter between samples
	
	var slope_angle = rad_to_deg(atan2(abs(height_difference), horizontal_distance))
	return slope_angle

func apply_smooth_adjustment(delta: float):
	# Smooth interpolation to target offset
	current_vertical_offset = lerp(
		current_vertical_offset,
		target_vertical_offset,
		vertical_smoothing * delta
	)
	
	# Apply offset to collision shape
	collision_shape.position = original_capsule_position + Vector3.UP * current_vertical_offset

func draw_debug_info():
	if not enable_debug:
		return
	
	var terrain_analysis = terrain_detector.get_terrain_analysis()
	var forward_trend = terrain_analysis.forward_trend
	var side_slope = terrain_analysis.side_slope_angle
	var side_trend = terrain_analysis.side_slope_trend
	
	var slope_status = ""
	if side_slope > side_slope_threshold:
		slope_status = " + %s" % side_trend.to_upper()
	
	var debug_text = "Capsule: %s%s | Offset: %.3fm | Side: %.1f°" % [
		forward_trend.to_upper(),
		slope_status,
		current_vertical_offset,
		side_slope
	]
	
	print(debug_text)

func reset_position():
	collision_shape.position = original_capsule_position
	current_vertical_offset = 0.0
	target_vertical_offset = 0.0

func get_current_offset() -> float:
	return current_vertical_offset


func _on_area_3d_body_entered(body: Node3D) -> void:
	print("SOMETHING ENTERED: ", body.name, " | Type: ", body.get_class())


func _on_area_3d_body_exited(body: Node3D) -> void:
	print("SOMETHING ENTERED: ", body.name, " | Type: ", body.get_class())
