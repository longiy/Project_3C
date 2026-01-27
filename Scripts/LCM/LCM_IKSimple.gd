# LCM_SimpleIK.gd - Ultra Simplified IK Controller
extends Node3D
class_name LCM_SimpleIK

# ================================
# ULTRA SIMPLE IK CONTROLLER
# Just connects SimpleGoalStepping to IK effectors
# ================================

## REFERENCES
@export_group("Required References")
@export var simple_goal_stepping: LCM_SimpleGoalStepping
@export var left_foot_effector: Node3D
@export var right_foot_effector: Node3D

## OPTIONAL SETTINGS
@export_group("IK Settings")
@export var enable_ik: bool = true
@export var foot_height_offset: float = 0.0
@export var ik_influence: float = 1.0

## DEBUG
@export_group("Debug")
@export var enable_debug: bool = false

func _ready():
	if not validate_references():
		push_error("SimpleIK: Missing required references")

func _process(_delta):
	if not enable_ik or not validate_references():
		return
	
	update_ik_targets()
	
	if enable_debug:
		print_debug_info()

func validate_references() -> bool:
	return simple_goal_stepping != null and left_foot_effector != null and right_foot_effector != null

func update_ik_targets():
	"""Apply SimpleGoalStepping targets directly to IK effectors"""
	# Get targets from SimpleGoalStepping
	var left_target = simple_goal_stepping.get_left_foot_target()
	var right_target = simple_goal_stepping.get_right_foot_target()
	
	# Apply height offset if needed
	left_target.y += foot_height_offset
	right_target.y += foot_height_offset
	
	# Set effector positions
	left_foot_effector.global_position = left_target
	right_foot_effector.global_position = right_target
	
	# Apply influence if effectors support it
	apply_influence(left_foot_effector)
	apply_influence(right_foot_effector)

func apply_influence(effector: Node3D):
	"""Apply IK influence if the effector supports it"""
	if effector.has_method("set_influence"):
		effector.set_influence(ik_influence)
	elif effector.has_property("influence"):
		effector.influence = ik_influence

# ================================
# PUBLIC API (for compatibility)
# ================================

func get_left_foot_target() -> Vector3:
	"""Get current left foot target"""
	if simple_goal_stepping:
		return simple_goal_stepping.get_left_foot_target()
	return Vector3.ZERO

func get_right_foot_target() -> Vector3:
	"""Get current right foot target"""
	if simple_goal_stepping:
		return simple_goal_stepping.get_right_foot_target()
	return Vector3.ZERO

func set_ik_enabled(enabled: bool):
	"""Enable/disable IK"""
	enable_ik = enabled

# ================================
# DEBUG
# ================================

func print_debug_info():
	"""Print debug information"""
	if simple_goal_stepping:
		var left_stepping = "STEPPING" if simple_goal_stepping.is_left_stepping else "PLANTED"
		var right_stepping = "STEPPING" if simple_goal_stepping.is_right_stepping else "PLANTED"
		
		print("SimpleIK | Left: %s | Right: %s | Targets: L%s R%s" % [
			left_stepping,
			right_stepping,
			get_left_foot_target(),
			get_right_foot_target()
		])

func toggle_debug():
	"""Toggle debug output"""
	enable_debug = !enable_debug
	print("SimpleIK debug: ", "ON" if enable_debug else "OFF")
