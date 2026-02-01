extends Node
class_name FootIKController

# Node references
@export var skeleton: Skeleton3D
@export var character_body: CharacterBody3D

# IK components
@export var fabrik_left: FABRIK3D
@export var fabrik_right: FABRIK3D
@export var ik_target_left: Node3D
@export var ik_target_right: Node3D
@export var raycast_left: RayCast3D
@export var raycast_right: RayCast3D

# Bone indices (cached)
var foot_bone_left_idx: int = -1
var foot_bone_right_idx: int = -1

# Configuration
@export_group("IK Settings")
@export var ray_start_height: float = 0.5  # Height above foot to start ray
@export var ray_length: float = 2.0  # Max distance to check
@export var ik_blend_speed: float = 10.0  # How fast IK influence changes
@export var foot_height_offset: float = 0.0  # Adjust if feet sink/float

@export_group("Contact Detection")
@export var enable_contact_detection: bool = true
@export var contact_velocity_threshold: float = 0.5  # Speed below which foot is "planted"
@export var vertical_velocity_threshold: float = 2.0  # Vertical speed to disable IK (jumping)

# Runtime state
var current_ik_influence_left: float = 0.0
var current_ik_influence_right: float = 0.0
var is_grounded: bool = false

func _ready():
	# Cache bone indices
	foot_bone_left_idx = skeleton.find_bone("DEF-toe.L")
	foot_bone_right_idx = skeleton.find_bone("DEF-toe.R")
	
	if foot_bone_left_idx == -1 or foot_bone_right_idx == -1:
		push_error("FootIKController: Could not find foot bones. Check bone names.")
		return
	
	# Configure raycasts
	raycast_left.target_position = Vector3.DOWN * ray_length
	raycast_right.target_position = Vector3.DOWN * ray_length
	
	# Initial IK influence
	fabrik_left.influence = 0.0
	fabrik_right.influence = 0.0

func _physics_process(delta):
	if foot_bone_left_idx == -1 or foot_bone_right_idx == -1:
		return
	
	# Update grounded state
	is_grounded = character_body.is_on_floor()
	
	# Process each foot
	process_foot_ik(
		foot_bone_left_idx,
		raycast_left,
		ik_target_left,
		fabrik_left,
		current_ik_influence_left,
		delta
	)
	
	process_foot_ik(
		foot_bone_right_idx,
		raycast_right,
		ik_target_right,
		fabrik_right,
		current_ik_influence_right,
		delta
	)

func process_foot_ik(
	bone_idx: int,
	raycast: RayCast3D,
	ik_target: Node3D,
	fabrik: FABRIK3D,
	influence_var: float,
	delta: float
) -> void:
	# Get animated foot position (before IK)
	var foot_global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
	var foot_position = foot_global_transform.origin
	
	# Position raycast above foot
	raycast.global_position = foot_position + Vector3.UP * ray_start_height
	raycast.force_raycast_update()
	
	# Determine if IK should be active
	var should_apply_ik = should_use_ik_for_foot(raycast, foot_position)
	
	# Blend influence
	var target_influence = 1.0 if should_apply_ik else 0.0
	influence_var = move_toward(influence_var, target_influence, ik_blend_speed * delta)
	fabrik.influence = influence_var
	
	# Update IK target position if ray hits
	if raycast.is_colliding():
		var hit_point = raycast.get_collision_point()
		var hit_normal = raycast.get_collision_normal()
		
		# Position target at ground with offset
		ik_target.global_position = hit_point + Vector3.UP * foot_height_offset
		
		# Optional: Align target to terrain normal
		# ik_target.global_transform.basis = align_to_normal(hit_normal, foot_global_transform.basis)
	else:
		# No ground detected - use animated position
		ik_target.global_position = foot_position

func should_use_ik_for_foot(raycast: RayCast3D, foot_pos: Vector3) -> bool:
	# Disable IK if not grounded
	if not is_grounded:
		return false
	
	# Disable IK if moving too fast vertically (jumping/falling)
	if abs(character_body.velocity.y) > vertical_velocity_threshold:
		return false
	
	# Disable if no ground detected
	if not raycast.is_colliding():
		return false
	
	# Optional: Contact detection based on horizontal velocity
	if enable_contact_detection:
		var horizontal_velocity = Vector2(character_body.velocity.x, character_body.velocity.z)
		var is_moving_fast = horizontal_velocity.length() > contact_velocity_threshold
		
		# Simple approach: always apply IK when grounded and slow
		# Advanced: detect foot contact phase from animation
		return not is_moving_fast or is_grounded
	
	return true

func align_to_normal(normal: Vector3, original_basis: Basis) -> Basis:
	# Align Y-axis to normal, preserve forward direction
	var up = normal
	var forward = -original_basis.z  # Keep foot pointing direction
	
	# Handle edge case: normal parallel to forward
	if abs(up.dot(forward)) > 0.99:
		forward = original_basis.x
	
	var right = forward.cross(up).normalized()
	forward = up.cross(right).normalized()
	
	return Basis(right, up, forward)
