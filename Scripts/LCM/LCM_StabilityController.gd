class_name LCM_StabilityEvaluator
extends Node3D

# ================================
# LCM_StabilityEvaluator.gd
# Enhanced with terrain normal alignment and consistent zone offsets
# ================================

enum StabilityState {
	STABLE,
	MARGINAL,
	UNSTABLE,
	CRITICAL
}

## REFERENCES
@export_group("Required References")
@export var lcm_center_of_gravity: LCM_CenterOfGravity
@export var left_foot_reference: Node3D
@export var right_foot_reference: Node3D
@export var movement_system: MovementSystem  # Reference to movement system for facing direction

## STABILITY CONFIGURATION - FIXED OFFSETS
@export_group("Stability Zone Offsets")
@export var stable_zone_offset: float = 0.0		# Base quadrilateral
@export var marginal_zone_offset: float = 0.05	# +15cm from base
@export var unstable_zone_offset: float = 0.1		# +30cm from base  
@export var critical_zone_offset: float = 0.2		# +50cm from base

@export_group("Quadrilateral Dimensions")
@export var quadrilateral_depth: float = 0.2

@export_group("Terrain Alignment")
@export var use_terrain_alignment: bool = true
@export var terrain_raycast_distance: float = 2.0
@export var terrain_collision_mask: int = 1

@export_group("Debug Visualization")
@export var enable_debug_visuals: bool = true
@export var show_stability_zones: bool = true
@export var debug_line_thickness: float = 0.01

## INTERNAL STATE
var current_stability: StabilityState = StabilityState.STABLE
var foot_polygon_center: Vector2 = Vector2.ZERO
var left_foot_position: Vector3 = Vector3.ZERO
var right_foot_position: Vector3 = Vector3.ZERO

## CHANGE DETECTION
var previous_stability_state: StabilityState = StabilityState.STABLE
var previous_left_foot_position: Vector3 = Vector3.ZERO
var previous_right_foot_position: Vector3 = Vector3.ZERO

## TERRAIN ALIGNMENT
var space_state: PhysicsDirectSpaceState3D
var terrain_normal_cache: Dictionary = {}

func _ready():
	validate_dependencies()
	space_state = get_world_3d().direct_space_state

func _process(_delta):
	if dependencies_available():
		update_current_foot_positions()
		evaluate_stability()
	
	if enable_debug_visuals:
		draw_stability_quadrilateral()

func validate_dependencies():
	var missing = []
	if not lcm_center_of_gravity: missing.append("lcm_center_of_gravity")
	if not left_foot_reference: missing.append("left_foot_reference")
	if not right_foot_reference: missing.append("right_foot_reference")
	if not movement_system: missing.append("movement_system")
	
	if missing.size() > 0:
		push_error("LCM_StabilityEvaluator missing dependencies: " + str(missing))

func dependencies_available() -> bool:
	return (lcm_center_of_gravity != null and 
			left_foot_reference != null and 
			right_foot_reference != null)

# ================================
# FOOT POSITION UPDATE
# ================================

func update_current_foot_positions():
	var new_left_position = left_foot_reference.global_position
	var new_right_position = right_foot_reference.global_position
	
	previous_left_foot_position = left_foot_position
	previous_right_foot_position = right_foot_position
	
	left_foot_position = new_left_position
	right_foot_position = new_right_position
	
	foot_polygon_center = Vector2(
		(left_foot_position.x + right_foot_position.x) * 0.5,
		(left_foot_position.z + right_foot_position.z) * 0.5
	)

# ================================
# TERRAIN ALIGNMENT FUNCTIONS
# ================================

func get_terrain_normal_at(position: Vector3) -> Vector3:
	if not use_terrain_alignment or not space_state:
		return Vector3.UP
	
	# Use cache to avoid excessive raycasting
	var cache_key = str(int(position.x * 10)) + "_" + str(int(position.z * 10))
	if terrain_normal_cache.has(cache_key):
		return terrain_normal_cache[cache_key]
	
	var query = PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 0.5,
		position - Vector3.UP * terrain_raycast_distance
	)
	query.collision_mask = terrain_collision_mask
	
	var result = space_state.intersect_ray(query)
	var normal = Vector3.UP
	
	if result:
		normal = result.normal
	
	terrain_normal_cache[cache_key] = normal
	return normal

func project_to_terrain(position: Vector3) -> Vector3:
	if not use_terrain_alignment or not space_state:
		return position
	
	var query = PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 0.5,
		position - Vector3.UP * terrain_raycast_distance
	)
	query.collision_mask = terrain_collision_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return position

# ================================
# STABILITY EVALUATION
# ================================

func evaluate_stability():
	if not lcm_center_of_gravity:
		return
	
	var current_cog = lcm_center_of_gravity.get_cog_world_position()
	var cog_2d = Vector2(current_cog.x, current_cog.z)
	
	var base_quad = create_stability_quadrilateral()
	
	previous_stability_state = current_stability
	current_stability = determine_stability_zone(cog_2d, base_quad)

func create_stability_quadrilateral() -> Array:
	var left_2d = Vector2(left_foot_position.x, left_foot_position.z)
	var right_2d = Vector2(right_foot_position.x, right_foot_position.z)
	
	if use_terrain_alignment:
		return create_terrain_aligned_quadrilateral()
	else:
		return create_flat_quadrilateral(left_2d, right_2d)

func create_terrain_aligned_quadrilateral() -> Array:
	# Get character facing direction
	var character_forward = get_character_forward_direction()
	var forward_2d = Vector2(character_forward.x, character_forward.z).normalized()
	
	# Create quadrilateral aligned with character facing direction
	var front_left = Vector3(
		left_foot_position.x + forward_2d.x * quadrilateral_depth,
		left_foot_position.y,
		left_foot_position.z + forward_2d.y * quadrilateral_depth
	)
	var front_right = Vector3(
		right_foot_position.x + forward_2d.x * quadrilateral_depth,
		right_foot_position.y,
		right_foot_position.z + forward_2d.y * quadrilateral_depth
	)
	var back_left = Vector3(
		left_foot_position.x - forward_2d.x * quadrilateral_depth,
		left_foot_position.y,
		left_foot_position.z - forward_2d.y * quadrilateral_depth
	)
	var back_right = Vector3(
		right_foot_position.x - forward_2d.x * quadrilateral_depth,
		right_foot_position.y,
		right_foot_position.z - forward_2d.y * quadrilateral_depth
	)
	
	# Project each point to terrain surface if terrain alignment is enabled
	if use_terrain_alignment:
		front_left = project_to_terrain(front_left)
		front_right = project_to_terrain(front_right)
		back_left = project_to_terrain(back_left)
		back_right = project_to_terrain(back_right)
	
	return [front_left, front_right, back_right, back_left]

func get_character_forward_direction() -> Vector3:
	if movement_system:
		var facing_2d = movement_system.get_facing_direction()
		return Vector3(facing_2d.x, 0, facing_2d.y)
	elif lcm_center_of_gravity and lcm_center_of_gravity.character_body:
		return -lcm_center_of_gravity.character_body.global_transform.basis.z
	return Vector3(0, 0, 1)  # Fallback

func create_flat_quadrilateral(left_2d: Vector2, right_2d: Vector2) -> Array:
	# Use character facing direction instead of foot line direction
	var character_forward = get_character_forward_direction()
	var forward_direction = Vector2(character_forward.x, character_forward.z).normalized()
	
	var front_left = Vector3(
		left_foot_position.x + forward_direction.x * quadrilateral_depth,
		left_foot_position.y,
		left_foot_position.z + forward_direction.y * quadrilateral_depth
	)
	var front_right = Vector3(
		right_foot_position.x + forward_direction.x * quadrilateral_depth,
		right_foot_position.y,
		right_foot_position.z + forward_direction.y * quadrilateral_depth
	)
	var back_left = Vector3(
		left_foot_position.x - forward_direction.x * quadrilateral_depth,
		left_foot_position.y,
		left_foot_position.z - forward_direction.y * quadrilateral_depth
	)
	var back_right = Vector3(
		right_foot_position.x - forward_direction.x * quadrilateral_depth,
		right_foot_position.y,
		right_foot_position.z - forward_direction.y * quadrilateral_depth
	)
	
	return [front_left, front_right, back_right, back_left]

func determine_stability_zone(cog_2d: Vector2, base_quad: Array) -> StabilityState:
	# Test against each stability zone using consistent offsets
	if is_point_in_offset_zone(cog_2d, base_quad, stable_zone_offset):
		return StabilityState.STABLE
	elif is_point_in_offset_zone(cog_2d, base_quad, marginal_zone_offset):
		return StabilityState.MARGINAL
	elif is_point_in_offset_zone(cog_2d, base_quad, unstable_zone_offset):
		return StabilityState.UNSTABLE
	else:
		return StabilityState.CRITICAL

func is_point_in_offset_zone(point: Vector2, base_quad: Array, offset_distance: float) -> bool:
	if base_quad.size() != 4:
		return false
	
	# Convert 3D quad to 2D
	var quad_2d = []
	for vertex in base_quad:
		quad_2d.append(Vector2(vertex.x, vertex.z))
	
	# If no offset, use original quad
	if offset_distance <= 0.0:
		return point_in_polygon(point, quad_2d)
	
	# Create offset polygon by expanding edges outward
	var offset_points = create_offset_polygon(quad_2d, offset_distance)
	return point_in_polygon(point, offset_points)

func create_offset_polygon(polygon: Array, offset_distance: float) -> Array:
	if polygon.size() < 3:
		return polygon
	
	var offset_points = []
	
	for i in range(polygon.size()):
		var current = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]
		var prev = polygon[(i - 1 + polygon.size()) % polygon.size()]
		
		# Calculate edge vectors and normals
		var edge_to_next = (next - current).normalized()
		var edge_from_prev = (current - prev).normalized()
		
		# Get outward normals (rotate 90 degrees clockwise)
		var normal_to_next = Vector2(edge_to_next.y, -edge_to_next.x)
		var normal_from_prev = Vector2(edge_from_prev.y, -edge_from_prev.x)
		
		# Average the normals for corner direction
		var corner_direction = (normal_to_next + normal_from_prev).normalized()
		
		# Handle acute angles - prevent excessive offset
		var angle_factor = 1.0 / max(0.5, corner_direction.dot(normal_to_next))
		var final_offset = corner_direction * offset_distance * angle_factor
		
		offset_points.append(current + final_offset)
	
	return offset_points

func point_in_polygon(point: Vector2, polygon: Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		var xi = polygon[i].x
		var yi = polygon[i].y
		var xj = polygon[j].x
		var yj = polygon[j].y
		
		if ((yi > point.y) != (yj > point.y)) and (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi):
			inside = !inside
		j = i
	
	return inside

# ================================
# DEBUG VISUALIZATION
# ================================

func draw_stability_quadrilateral():
	if not dependencies_available():
		return
	
	var base_quad = create_stability_quadrilateral()
	var effective_thickness = get_effective_thickness()
	
	if not show_stability_zones:
		return
	
	# Clear terrain normal cache periodically
	if randf() < 0.01:  # 1% chance per frame
		terrain_normal_cache.clear()
	
	# Draw stability zones (largest to smallest for proper layering)
	draw_offset_quadrilateral(base_quad, critical_zone_offset, Color.RED)
	draw_offset_quadrilateral(base_quad, unstable_zone_offset, Color.ORANGE)
	draw_offset_quadrilateral(base_quad, marginal_zone_offset, Color.YELLOW)
	draw_offset_quadrilateral(base_quad, stable_zone_offset, Color.GREEN)
	
	# Draw current CoG position
	if lcm_center_of_gravity:
		var current_cog = lcm_center_of_gravity.get_cog_world_position()
		DebugDraw3D.draw_sphere(current_cog, effective_thickness * 4.0, Color.WHITE)

func get_effective_thickness() -> float:
	var camera = get_viewport().get_camera_3d()
	if camera and lcm_center_of_gravity and lcm_center_of_gravity.character_body:
		var distance = camera.global_position.distance_to(lcm_center_of_gravity.character_body.global_position)
		return debug_line_thickness * (distance / 5.0)
	return debug_line_thickness

func draw_offset_quadrilateral(base_quad: Array, offset: float, color: Color):
	if base_quad.size() != 4:
		return
	
	# Convert to 2D, create offset polygon, convert back to 3D
	var quad_2d = []
	for vertex in base_quad:
		quad_2d.append(Vector2(vertex.x, vertex.z))
	
	var offset_polygon_2d = quad_2d if offset <= 0.0 else create_offset_polygon(quad_2d, offset)
	
	# Get average Y from base quad for flat world space projection
	var avg_y = 0.0
	for vertex in base_quad:
		avg_y += vertex.y
	avg_y = avg_y / base_quad.size() + 0.05  # Slight elevation for visibility
	
	# Convert back to 3D using flat world space Y
	var offset_quad_3d = []
	for point_2d in offset_polygon_2d:
		var world_pos = Vector3(point_2d.x, avg_y, point_2d.y)
		offset_quad_3d.append(world_pos)
	
	# Set line thickness for debug drawing
	DebugDraw3D.scoped_config().set_thickness(debug_line_thickness)
	
	# Draw quadrilateral lines
	for i in range(offset_quad_3d.size()):
		var current_point = offset_quad_3d[i]
		var next_point = offset_quad_3d[(i + 1) % offset_quad_3d.size()]
		DebugDraw3D.draw_line(current_point, next_point, color)

# ================================
# PUBLIC API
# ================================

func get_current_stability_state() -> StabilityState:
	return current_stability

func get_foot_polygon_center() -> Vector2:
	return foot_polygon_center

func get_left_foot_position() -> Vector3:
	return left_foot_position

func get_right_foot_position() -> Vector3:
	return right_foot_position

func get_recommended_step_foot() -> String:
	return "left"  # Simplified for now

func should_trigger_step() -> bool:
	return current_stability >= StabilityState.MARGINAL

func get_instability_direction() -> Vector2:
	if lcm_center_of_gravity:
		var current_cog = lcm_center_of_gravity.get_cog_world_position()
		var cog_2d = Vector2(current_cog.x, current_cog.z)
		return (cog_2d - foot_polygon_center).normalized()
	return Vector2.ZERO

# ================================
# DEBUG CONTROLS
# ================================

func toggle_debug_visuals():
	enable_debug_visuals = !enable_debug_visuals
	print("StabilityEvaluator debug: ", "ON" if enable_debug_visuals else "OFF")

func toggle_stability_zones():
	show_stability_zones = !show_stability_zones
	print("Stability zones debug: ", "ON" if show_stability_zones else "OFF")

func toggle_terrain_alignment():
	use_terrain_alignment = !use_terrain_alignment
	terrain_normal_cache.clear()
	print("Terrain alignment: ", "ON" if use_terrain_alignment else "OFF")

func print_stability_status():
	var state_names = ["STABLE", "MARGINAL", "UNSTABLE", "CRITICAL"]
	print("=== STABILITY STATUS ===")
	print("Current state: %s" % state_names[current_stability])
	print("Foot polygon center: (%.2f, %.2f)" % [foot_polygon_center.x, foot_polygon_center.y])
	print("Left foot: %s" % left_foot_position)
	print("Right foot: %s" % right_foot_position)
	print("Terrain alignment: %s" % ("ON" if use_terrain_alignment else "OFF"))
	print("Zone offsets: S=%.2f M=%.2f U=%.2f C=%.2f" % [stable_zone_offset, marginal_zone_offset, unstable_zone_offset, critical_zone_offset])
	print("========================")
