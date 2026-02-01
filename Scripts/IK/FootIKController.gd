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
@export var skeleton_lerp_speed: float = 20.0

@export_group("Thresholds")
@export var vertical_velocity_threshold: float = 2.0
@export var horizontal_velocity_dampening: float = 0.5

@export var max_foot_tilt: float = 45.0 # Max degrees the foot can tilt
@export var max_body_drop: float = 0.5 # Only allow the body to drop 25cm

# --- RUNTIME STATE ---
var foot_bone_l_idx: int = -1
var foot_bone_r_idx: int = -1
var current_inf_l: float = 0.0
var current_inf_r: float = 0.0
var skeleton_original_y: float = 0.0

func _ready():
	# 1. Initialize Bone Indices
	foot_bone_l_idx = skeleton.find_bone("DEF-foot.L")
	foot_bone_r_idx = skeleton.find_bone("DEF-foot.R")
	
	# Store the baseline height of the skeleton relative to the capsule center
	skeleton_original_y = skeleton.position.y
	
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
	
	# 1. GET PURE ANIMATION POSES
	var anim_pose_l = skeleton.global_transform * skeleton.get_bone_global_pose(foot_bone_l_idx)
	var anim_pose_r = skeleton.global_transform * skeleton.get_bone_global_pose(foot_bone_r_idx)
	
	# 2. POSITION RAYCASTS
	_update_ray(raycast_left, anim_pose_l.origin)
	_update_ray(raycast_right, anim_pose_r.origin)
	
	# 3. CALCULATE OFFSETS
	var offset_l = _get_offset(raycast_left, anim_pose_l.origin)
	var offset_r = _get_offset(raycast_right, anim_pose_r.origin)
	
	# 4. VELOCITY-BASED DAMPING
	var h_speed = Vector2(character_body.velocity.x, character_body.velocity.z).length()
	
	# Damping Factor: 1.0 at rest, 0.0 at full sprint (10.0 speed)
	# This dictates how much "drop" we actually allow.
	var speed_damping = clamp(1.0 - (h_speed / 10.0), 0.0, 1.0)
	
	# 5. SKELETON OFFSET
	if character_body.is_on_floor():
		var body_adjustment = min(offset_l, offset_r)
		
		# APPLY DAMPING TO THE DROP DEPTH
		# As you run faster, 'clamped_drop' approaches 0, forcing the skeleton back to original Y
		var clamped_drop = clamp(body_adjustment, -max_body_drop, 0.0) * speed_damping
		
		var target_y = skeleton_original_y + clamped_drop
		
		# Use a consistent lerp speed so the transition back to height is smooth
		skeleton.position.y = lerp(skeleton.position.y, target_y, skeleton_lerp_speed * delta)
	else:
		skeleton.position.y = lerp(skeleton.position.y, skeleton_original_y, 10.0 * delta)

	# 6. SOLVE FEET
	_solve_foot("left", fabrik_left, ik_target_left, raycast_left, anim_pose_l, delta)
	_solve_foot("right", fabrik_right, ik_target_right, raycast_right, anim_pose_r, delta)

# --- HELPER FUNCTIONS ---

func _update_ray(ray: RayCast3D, pos: Vector3):
	# Position the ray at the foot's horizontal position but at the character's mid-body height
	ray.global_position = Vector3(pos.x, character_body.global_position.y + ray_start_height, pos.z)
	ray.force_raycast_update()

func _get_offset(ray: RayCast3D, foot_pos: Vector3) -> float:
	if ray.is_colliding():
		return ray.get_collision_point().y - foot_pos.y
	return 0.0

func _solve_foot(side: String, fabrik: TwoBoneIK3D, target: Node3D, ray: RayCast3D, anim_pose: Transform3D, delta: float):
	# Decision logic: Should we plant the foot?
	var is_grounded = character_body.is_on_floor()
	var vertical_speed = abs(character_body.velocity.y)
	
	# We only apply IK if the ray hits and we aren't jumping/flying
	var should_ik = is_grounded and ray.is_colliding() and vertical_speed < vertical_velocity_threshold
	var target_inf = 1.0 if should_ik else 0.0
	
	# Smoothly blend influence to prevent "snapping" feet
	if side == "left":
		current_inf_l = move_toward(current_inf_l, target_inf, ik_blend_speed * delta)
		fabrik.influence = current_inf_l
	else:
		current_inf_r = move_toward(current_inf_r, target_inf, ik_blend_speed * delta)
		fabrik.influence = current_inf_r
	
	# Apply final target transform
	if should_ik:
		# Position: The hit point on terrain + small padding
		target.global_position = ray.get_collision_point() + Vector3.UP * foot_height_offset
		
		# Rotation: Align foot sole with the ground normal
		var normal = ray.get_collision_normal()
		target.global_basis = _align_with_normal(anim_pose.basis, normal)
	else:
		# Default: Follow the animation exactly
		target.global_position = anim_pose.origin
		target.global_basis = anim_pose.basis

func _align_with_normal(orig_basis: Basis, normal: Vector3) -> Basis:
	# 1. FIX THE FLIP: Limit how much the normal can tilt
	var world_up = Vector3.UP
	var angle_rad = world_up.angle_to(normal)
	var max_rad = deg_to_rad(max_foot_tilt)
	
	var effective_normal = normal
	if angle_rad > max_rad:
		# If the slope is too steep, blend the normal back toward World Up
		# This prevents the 180-degree "snapping"
		var axis = world_up.cross(normal).normalized()
		effective_normal = world_up.rotated(axis, max_rad)
	
	# 2. DIRECTION PRESERVATION
	# Get the direction the toes point in the animation
	var anim_forward = -orig_basis.z 
	
	# Project forward onto the (clamped) terrain plane
	var flat_forward = (anim_forward - effective_normal * anim_forward.dot(effective_normal)).normalized()
	var new_right = effective_normal.cross(flat_forward).normalized()
	var final_forward = new_right.cross(effective_normal).normalized()
	
	# 3. RETURN BASIS
	# Use -final_forward to maintain Godot's -Z forward convention
	return Basis(new_right, effective_normal, final_forward)
