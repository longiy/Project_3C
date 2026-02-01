extends Node
class_name FootIKController

# --- NODE REFERENCES ---
@export_group("References")
@export var skeleton: Skeleton3D
@export var character_body: CharacterBody3D

@export_subgroup("IK Nodes")
@export var fabrik_left: TwoBoneIK3D
@export var fabrik_right: TwoBoneIK3D
@export var ik_target_left: Node3D
@export var ik_target_right: Node3D

@export_subgroup("Raycasts")
@export var raycast_left: RayCast3D
@export var raycast_right: RayCast3D

# --- CONFIGURATION ---
@export_group("IK Settings")
@export var ray_start_height: float = 1.0
@export var ray_length: float = 2.0
@export var ik_blend_speed: float = 15.0
@export var foot_height_offset: float = 0.02

@export_group("Thresholds")
@export var vertical_velocity_threshold: float = 2.0  # Upward velocity that disables IK
@export var falling_velocity_threshold: float = -5.0  # Downward velocity that disables IK
@export var max_foot_tilt: float = 45.0

# --- RUNTIME STATE ---
var foot_bone_l_idx: int = -1
var foot_bone_r_idx: int = -1
var current_inf_l: float = 0.0
var current_inf_r: float = 0.0

func _ready():
	# 1. Initialize Bone Indices
	foot_bone_l_idx = skeleton.find_bone("DEF-foot.L")
	foot_bone_r_idx = skeleton.find_bone("DEF-foot.R")
	
	if foot_bone_l_idx == -1 or foot_bone_r_idx == -1:
		push_error("FootIKController: Foot bones not found! Please check bone names.")
		return
	
	# 2. Setup Raycasts
	raycast_left.target_position = Vector3.DOWN * ray_length
	raycast_right.target_position = Vector3.DOWN * ray_length
	
	# 3. Disable IK by default to prevent "pop" on start
	fabrik_left.influence = 0.0
	fabrik_right.influence = 0.0

func _physics_process(delta: float):
	if foot_bone_l_idx == -1: return
	
	# 1. Get current animated positions
	var anim_pose_l = skeleton.global_transform * skeleton.get_bone_global_pose(foot_bone_l_idx)
	var anim_pose_r = skeleton.global_transform * skeleton.get_bone_global_pose(foot_bone_r_idx)
	
	# 2. Update Rays
	_update_ray(raycast_left, anim_pose_l.origin)
	_update_ray(raycast_right, anim_pose_r.origin)

	# 3. Solve IK (This now handles rotation too)
	_solve_foot("left", fabrik_left, ik_target_left, raycast_left, anim_pose_l, delta)
	_solve_foot("right", fabrik_right, ik_target_right, raycast_right, anim_pose_r, delta)
	
	# REMOVED: _apply_foot_rotation (The IK node handles this now via the target)

func _reset_target_rotations():
	# Maintain character-forward orientation
	var char_forward = -character_body.global_transform.basis.z
	var flat_forward = Vector3(char_forward.x, 0, char_forward.z).normalized()
	var basis = Basis.looking_at(flat_forward, Vector3.UP)
	
	ik_target_left.global_basis = basis
	ik_target_right.global_basis = basis


# --- HELPER FUNCTIONS ---



# TO THIS
func _align_with_normal(forward_direction: Vector3, normal: Vector3) -> Basis:
	var world_up = Vector3.UP
	
	# 1. Safety Check: If the slope is near vertical or upside down, 
	# ignore the normal and just use world up to prevent flipping.
	var slope_steepness = normal.dot(world_up)
	if slope_steepness < 0.2: # Adjust this threshold (0.2 is roughly 78 degrees)
		return Basis.looking_at(forward_direction, world_up)

	var angle_rad = world_up.angle_to(normal)
	var max_rad = deg_to_rad(max_foot_tilt)
	
	var effective_normal = normal
	if angle_rad > max_rad:
		var axis = world_up.cross(normal).normalized()
		effective_normal = world_up.rotated(axis, max_rad)
	
	# 2. Project forward direction onto the slope plane
	# This ensures the foot points "forward" along the ground
	var final_right = effective_normal.cross(forward_direction).normalized()
	var final_forward = final_right.cross(effective_normal).normalized()
	
	# Construct the Basis (X, Y, Z)
	# We use -final_forward because Godot's forward is -Z
	return Basis(final_right, effective_normal, -final_forward)

func _apply_foot_rotation(bone_idx: int, ray: RayCast3D):
	if not ray.is_colliding(): return

	var normal = ray.get_collision_normal()
	var char_forward = -character_body.global_transform.basis.z
	var aligned_basis = _align_with_normal(char_forward, normal)
	
	# Convert world-space rotation to bone's local space
	var bone_global_pose = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
	var parent_basis = bone_global_pose.basis * skeleton.get_bone_pose(bone_idx).basis.inverse()
	var local_rotation = parent_basis.inverse() * aligned_basis
	
	skeleton.set_bone_pose_rotation(bone_idx, local_rotation.get_rotation_quaternion())

func _update_ray(ray: RayCast3D, pos: Vector3):
	# Position the ray at the foot's horizontal position but at the character's mid-body height
	ray.global_position = Vector3(pos.x, character_body.global_position.y + ray_start_height, pos.z)
	ray.force_raycast_update()

func _get_offset(ray: RayCast3D, foot_pos: Vector3) -> float:
	if ray.is_colliding():
		return ray.get_collision_point().y - foot_pos.y
	return 0.0

func _solve_foot(side: String, fabrik: TwoBoneIK3D, target: Node3D, ray: RayCast3D, anim_pose: Transform3D, delta: float):
	var is_grounded = character_body.is_on_floor()
	var vertical_vel = character_body.velocity.y
	
	var is_jumping = vertical_vel > vertical_velocity_threshold
	var is_falling_fast = vertical_vel < falling_velocity_threshold
	var should_ik = is_grounded and ray.is_colliding() and not is_jumping and not is_falling_fast
	
	# Update influence blending
	var target_inf = 1.0 if should_ik else 0.0
	if side == "left":
		current_inf_l = move_toward(current_inf_l, target_inf, ik_blend_speed * delta)
		fabrik.influence = current_inf_l
	else:
		current_inf_r = move_toward(current_inf_r, target_inf, ik_blend_speed * delta)
		fabrik.influence = current_inf_r
	
	var char_forward = -character_body.global_transform.basis.z

	if should_ik:
		# Position: Ground hit + offset
		target.global_position = ray.get_collision_point() + Vector3.UP * foot_height_offset
		
		# Rotation: Align target node with ground normal
		# This is the key: The IK node will force the foot to match this target's basis
		target.global_basis = _align_with_normal(char_forward, ray.get_collision_normal())
	else:
		# Fallback: Follow animation
		target.global_position = anim_pose.origin
		target.global_basis = anim_pose.basis
