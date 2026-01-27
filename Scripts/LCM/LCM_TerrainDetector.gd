class_name LCM_TerrainDetector
extends Node3D

# ================================
# LCM_TerrainDetector.gd
# Self-contained character-centric terrain analysis
# Grid-based sampling with movement-aware prediction
# ================================

## REFERENCES
@export_group("Required References")
@export var character_body: CharacterBody3D

## SAMPLING CONFIGURATION
@export_group("Terrain Sampling")
@export var near_radius: float = 0.8  # Close detail sampling
@export var far_radius: float = 1.6   # General trend sampling
@export var near_samples: int = 16     # Points in near ring
@export var far_samples: int = 32      # Points in far ring
@export var forward_bias_samples: int = 4  # Extra samples in movement direction

@export_group("Raycast Settings")
@export var raycast_height: float = 2.0
@export var raycast_length: float = 10.0
@export var collision_mask: int = 1

@export_group("Analysis Thresholds")
@export var flat_slope_threshold: float = 5.0    # Degrees
@export var moderate_slope_threshold: float = 20.0
@export var steep_slope_threshold: float = 35.0
@export var step_height_threshold: float = 0.3   # Max step height

@export_group("Debug Visualization")
@export var enable_debug_visuals: bool = false
@export var show_sample_grid: bool = true
@export var show_terrain_analysis: bool = true
@export var show_movement_prediction: bool = true
@export var debug_line_thickness: float = 0.01

## TERRAIN DATA STRUCTURES
class TerrainSample:
	var world_position: Vector3
	var ground_height: float
	var has_ground: bool = false
	var ground_normal: Vector3
	var slope_angle: float = 0.0
	var sample_type: String = "unknown"  # "near", "far", "forward"

class TerrainAnalysis:
	var average_height: float = 0.0
	var height_variance: float = 0.0
	var dominant_slope_direction: Vector2 = Vector2.ZERO
	var max_slope_angle: float = 0.0
	var terrain_roughness: float = 0.0
	var forward_trend: String = "flat"  # "ascending", "descending", "flat"
	var steppable_zones: Array = []
	var side_slope_angle: float = 0.0
	var side_slope_trend: String = "level"  # "left_high", "right_high", "level"
## INTERNAL STATE
var space_state: PhysicsDirectSpaceState3D
var current_samples: Array[TerrainSample] = []
var current_analysis: TerrainAnalysis
var previous_analysis: TerrainAnalysis

## CHANGE DETECTION (for console logging)
var last_terrain_trend: String = ""
var last_max_slope: float = 0.0
var last_roughness: float = 0.0

func _ready():
	space_state = get_world_3d().direct_space_state
	current_analysis = TerrainAnalysis.new()
	previous_analysis = TerrainAnalysis.new()
	
	if not character_body:
		push_error("LCM_TerrainDetector: character_body reference required!")
	
	# Auto-enable debug for standalone testing
	if get_parent().get_child_count() == 1:
		enable_debug_visuals = true
		print("LCM_TerrainDetector: Standalone mode - debug enabled")

func _process(_delta):
	if character_body:
		update_terrain_analysis()
		detect_changes_and_log()
	
	if enable_debug_visuals:
		draw_debug_visualization()

# ================================
# MAIN API METHODS
# ================================

func get_terrain_height_at(position: Vector3) -> float:
	var sample = sample_terrain_at_position(position, "query")
	return sample.ground_height if sample.has_ground else position.y

func get_slope_angle_at(position: Vector3) -> float:
	var sample = sample_terrain_at_position(position, "query")
	return sample.slope_angle

func get_terrain_analysis() -> TerrainAnalysis:
	return current_analysis

func is_position_steppable(position: Vector3) -> bool:
	var sample = sample_terrain_at_position(position, "query")
	if not sample.has_ground:
		return false
	
	var height_diff = abs(position.y - sample.ground_height)
	return height_diff <= step_height_threshold and sample.slope_angle <= steep_slope_threshold

func get_steppable_zones_around_character() -> Array:
	return current_analysis.steppable_zones

func analyze_movement_path(direction: Vector3, distance: float, samples: int = 5) -> Dictionary:
	var path_analysis = {
		"is_safe": true,
		"obstacles": [],
		"height_changes": [],
		"max_slope": 0.0
	}
	
	for i in range(samples):
		var t = float(i) / float(samples - 1)
		var sample_pos = character_body.global_position + direction * distance * t
		var sample = sample_terrain_at_position(sample_pos, "path")
		
		if not sample.has_ground:
			path_analysis["obstacles"].append({"position": sample_pos, "type": "void"})
			path_analysis["is_safe"] = false
		
		path_analysis["height_changes"].append(sample.ground_height)
		path_analysis["max_slope"] = max(path_analysis["max_slope"], sample.slope_angle)
		
		if sample.slope_angle > steep_slope_threshold:
			path_analysis["obstacles"].append({"position": sample_pos, "type": "steep_slope"})
			path_analysis["is_safe"] = false
	
	return path_analysis

# ================================
# INTERNAL UPDATE METHODS
# ================================

func update_terrain_analysis():
	# Store previous analysis for change detection
	previous_analysis = current_analysis
	current_analysis = TerrainAnalysis.new()
	
	# Clear and regenerate samples
	current_samples.clear()
	
	var char_pos = character_body.global_position
	var movement_direction = get_movement_direction()
	
	# Sample in rings around character
	generate_ring_samples(char_pos, near_radius, near_samples, "near")
	generate_ring_samples(char_pos, far_radius, far_samples, "far")
	
	# Extra samples in movement direction
	if movement_direction.length() > 0.1:
		generate_forward_samples(char_pos, movement_direction)
	
	# Analyze collected samples
	analyze_terrain_data()

func generate_ring_samples(center: Vector3, radius: float, count: int, sample_type: String):
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var sample_pos = center + offset
		
		var sample = sample_terrain_at_position(sample_pos, sample_type)
		current_samples.append(sample)

func generate_forward_samples(center: Vector3, direction: Vector3):
	var normalized_dir = direction.normalized()
	
	for i in range(forward_bias_samples):
		var distance = near_radius + (float(i) / float(forward_bias_samples - 1)) * (far_radius - near_radius)
		var sample_pos = center + normalized_dir * distance
		
		var sample = sample_terrain_at_position(sample_pos, "forward")
		current_samples.append(sample)

func sample_terrain_at_position(world_pos: Vector3, sample_type: String) -> TerrainSample:
	var sample = TerrainSample.new()
	sample.world_position = world_pos
	sample.sample_type = sample_type
	
	if not space_state:
		return sample
	
	var start_pos = world_pos + Vector3(0, raycast_height, 0)
	var end_pos = world_pos + Vector3(0, -raycast_length, 0)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	
	var result = space_state.intersect_ray(query)
	
	if result.has("position"):
		sample.has_ground = true
		sample.ground_height = result.position.y
		sample.ground_normal = result.get("normal", Vector3.UP)
		sample.slope_angle = rad_to_deg(sample.ground_normal.angle_to(Vector3.UP))
	else:
		sample.ground_height = world_pos.y  # Fallback
	
	return sample

func analyze_terrain_data():
	var valid_samples = current_samples.filter(func(s): return s.has_ground)
	
	if valid_samples.is_empty():
		return
	
	# Existing analysis code...
	var heights = valid_samples.map(func(s): return s.ground_height)
	current_analysis.average_height = heights.reduce(func(a, b): return a + b) / heights.size()
	
	# Height variance (terrain roughness)
	var variance_sum = 0.0
	for height in heights:
		variance_sum += pow(height - current_analysis.average_height, 2)
	current_analysis.height_variance = variance_sum / heights.size()
	current_analysis.terrain_roughness = sqrt(current_analysis.height_variance)
	
	# Slope analysis
	var slopes = valid_samples.map(func(s): return s.slope_angle)
	current_analysis.max_slope_angle = slopes.max()
	
	# Movement direction trend
	analyze_movement_trend()
	
	# NEW: Side slope analysis
	analyze_side_slope()
	
	# Identify steppable zones
	identify_steppable_zones()

func analyze_side_slope():
	var char_pos = character_body.global_position
	var char_right = character_body.global_transform.basis.x
	
	# Sample terrain to left and right (50cm each side)
	var left_pos = char_pos + char_right * -0.5
	var right_pos = char_pos + char_right * 0.5
	
	var left_height = get_terrain_height_at(left_pos)
	var right_height = get_terrain_height_at(right_pos)
	
	# Calculate side slope angle
	var height_difference = right_height - left_height
	var horizontal_distance = 1.0  # 1 meter between samples
	
	current_analysis.side_slope_angle = rad_to_deg(atan2(abs(height_difference), horizontal_distance))
	
	# Determine side slope trend
	var height_threshold = 0.05  # 5cm threshold for "level"
	if height_difference > height_threshold:
		current_analysis.side_slope_trend = "right_high"
	elif height_difference < -height_threshold:
		current_analysis.side_slope_trend = "left_high"
	else:
		current_analysis.side_slope_trend = "level"

func analyze_movement_trend():
	var movement_dir = get_movement_direction()
	if movement_dir.length() < 0.1:
		current_analysis.forward_trend = "stationary"
		return
	
	# Compare near vs far samples in movement direction
	var near_samples = current_samples.filter(func(s): return s.sample_type == "near")
	var far_samples = current_samples.filter(func(s): return s.sample_type == "far")
	
	if near_samples.is_empty() or far_samples.is_empty():
		return
	
	var near_avg = near_samples.map(func(s): return s.ground_height).reduce(func(a, b): return a + b) / near_samples.size()
	var far_avg = far_samples.map(func(s): return s.ground_height).reduce(func(a, b): return a + b) / far_samples.size()
	
	var height_diff = far_avg - near_avg
	
	if height_diff > 0.1:
		current_analysis.forward_trend = "ascending"
	elif height_diff < -0.1:
		current_analysis.forward_trend = "descending"
	else:
		current_analysis.forward_trend = "flat"

func identify_steppable_zones():
	current_analysis.steppable_zones.clear()
	
	for sample in current_samples:
		if not sample.has_ground:
			continue
		
		var char_height = character_body.global_position.y
		var height_diff = abs(sample.ground_height - char_height)
		
		if height_diff <= step_height_threshold and sample.slope_angle <= steep_slope_threshold:
			current_analysis.steppable_zones.append({
				"position": sample.world_position,
				"height": sample.ground_height,
				"slope": sample.slope_angle,
				"quality": calculate_zone_quality(sample)
			})

func calculate_zone_quality(sample: TerrainSample) -> float:
	var quality = 1.0
	
	# Penalize slopes
	quality -= (sample.slope_angle / steep_slope_threshold) * 0.5
	
	# Prefer closer zones
	var distance = character_body.global_position.distance_to(sample.world_position)
	quality -= (distance / far_radius) * 0.3
	
	return clamp(quality, 0.0, 1.0)

func get_movement_direction() -> Vector3:
	# Primary: Use actual velocity if moving
	if character_body.velocity.length() > 0.1:
		return character_body.velocity.normalized()
	
	# Fallback: Use character forward direction (positive Z in Godot)
	# Most character controllers face forward along +Z axis
	return character_body.global_transform.basis.z
	
	# Alternative fallback if your character faces along -Z:
	# return -character_body.global_transform.basis.z

# ================================
# CHANGE DETECTION AND LOGGING
# ================================

func detect_changes_and_log():
	var changes = []
	
	# Terrain trend changes
	if current_analysis.forward_trend != last_terrain_trend:
		changes.append("Terrain trend: %s → %s" % [last_terrain_trend, current_analysis.forward_trend])
		last_terrain_trend = current_analysis.forward_trend
	
	# Significant slope changes
	var slope_diff = abs(current_analysis.max_slope_angle - last_max_slope)
	if slope_diff > 5.0:
		changes.append("Max slope: %.1f° → %.1f°" % [last_max_slope, current_analysis.max_slope_angle])
		last_max_slope = current_analysis.max_slope_angle
	
	# Roughness changes
	var roughness_diff = abs(current_analysis.terrain_roughness - last_roughness)
	if roughness_diff > 0.1:
		changes.append("Terrain roughness: %.2f → %.2f" % [last_roughness, current_analysis.terrain_roughness])
		last_roughness = current_analysis.terrain_roughness
	
	# Log changes
	if not changes.is_empty():
		print("=== TERRAIN CHANGES ===")
		for change in changes:
			print("  " + change)
		print("Steppable zones: %d" % current_analysis.steppable_zones.size())
		print("=======================")

# ================================
# DEBUG VISUALIZATION
# ================================

func draw_debug_visualization():
	if not enable_debug_visuals or not character_body:
		return
	
	var effective_thickness = get_effective_thickness()
	var scoped_config = DebugDraw3D.new_scoped_config().set_thickness(effective_thickness)
	
	# Draw character position
	DebugDraw3D.draw_sphere(character_body.global_position, effective_thickness * 4.0, Color.WHITE)
	
	if show_sample_grid:
		draw_sample_grid_debug(effective_thickness)
	
	if show_terrain_analysis:
		draw_terrain_analysis_debug(effective_thickness)
	
	if show_movement_prediction:
		draw_movement_prediction_debug(effective_thickness)

func get_effective_thickness() -> float:
	var camera = get_viewport().get_camera_3d()
	if camera and character_body:
		var distance = camera.global_position.distance_to(character_body.global_position)
		return debug_line_thickness * (distance / 5.0)
	return debug_line_thickness

func draw_sample_grid_debug(thickness: float):
	# Draw sampling rings
	draw_circle_outline(character_body.global_position, near_radius, Color.CYAN, 16)
	draw_circle_outline(character_body.global_position, far_radius, Color.BLUE, 16)
	
	# Draw sample points
	for sample in current_samples:
		var color = get_sample_color(sample)
		var size = thickness * 2.0
		
		if sample.sample_type == "forward":
			size *= 1.5  # Larger for forward samples
		
		DebugDraw3D.draw_sphere(sample.world_position, size, color)
		
		if sample.has_ground:
			# Draw line to ground contact
			var ground_pos = Vector3(sample.world_position.x, sample.ground_height, sample.world_position.z)
			DebugDraw3D.draw_line(sample.world_position, ground_pos, color)
			DebugDraw3D.draw_sphere(ground_pos, thickness * 1.5, color)

func draw_circle_outline(center: Vector3, radius: float, color: Color, segments: int):
	for i in range(segments):
		var angle1 = (float(i) / segments) * TAU
		var angle2 = (float(i + 1) / segments) * TAU
		
		var pos1 = center + Vector3(cos(angle1) * radius, 0, sin(angle1) * radius)
		var pos2 = center + Vector3(cos(angle2) * radius, 0, sin(angle2) * radius)
		
		DebugDraw3D.draw_line(pos1, pos2, color)

func get_sample_color(sample: TerrainSample) -> Color:
	if not sample.has_ground:
		return Color.RED
	
	# Color by slope steepness
	if sample.slope_angle < flat_slope_threshold:
		return Color.GREEN
	elif sample.slope_angle < moderate_slope_threshold:
		return Color.YELLOW
	else:
		return Color.ORANGE

func draw_terrain_analysis_debug(thickness: float):
	var char_pos = character_body.global_position
	
	# Existing debug code...
	# Draw steppable zones
	for zone in current_analysis.steppable_zones:
		var quality = zone["quality"]
		var zone_color = Color.GREEN.lerp(Color.YELLOW, 1.0 - quality)
		DebugDraw3D.draw_sphere(zone["position"], thickness * 3.0, zone_color)
	
	# Draw forward trend indicator
	var trend_pos = char_pos + Vector3(0, 1.0, 0)
	var trend_color = Color.WHITE
	
	match current_analysis.forward_trend:
		"ascending":
			trend_color = Color.GREEN
		"descending":
			trend_color = Color.RED
		"flat":
			trend_color = Color.BLUE
	
	DebugDraw3D.draw_sphere(trend_pos, thickness * 2.0, trend_color)
	
	# NEW: Draw side slope indicator
	var side_pos = char_pos + Vector3(0, 1.2, 0)
	var side_color = Color.WHITE
	
	match current_analysis.side_slope_trend:
		"left_high":
			side_color = Color.MAGENTA
		"right_high":
			side_color = Color.CYAN
		"level":
			side_color = Color.GRAY
	
	DebugDraw3D.draw_sphere(side_pos, thickness * 1.5, side_color)
	
	# Draw left/right sample positions
	var char_right = character_body.global_transform.basis.x
	var left_sample_pos = char_pos + char_right * -0.5
	var right_sample_pos = char_pos + char_right * 0.5
	DebugDraw3D.draw_sphere(left_sample_pos, thickness * 1.0, Color.MAGENTA)
	DebugDraw3D.draw_sphere(right_sample_pos, thickness * 1.0, Color.CYAN)

func draw_movement_prediction_debug(thickness: float):
	var movement_dir = get_movement_direction()
	if movement_dir.length() < 0.1:
		return
	
	var char_pos = character_body.global_position
	var prediction_distance = far_radius
	var end_pos = char_pos + movement_dir * prediction_distance
	
	# Draw movement vector
	DebugDraw3D.draw_arrow(char_pos, end_pos, Color.MAGENTA, thickness * 1.5)

# ================================
# DEBUG CONTROLS
# ================================

func toggle_debug_visuals():
	enable_debug_visuals = !enable_debug_visuals
	print("TerrainDetector debug: ", "ON" if enable_debug_visuals else "OFF")

func toggle_sample_grid():
	show_sample_grid = !show_sample_grid
	print("Sample grid debug: ", "ON" if show_sample_grid else "OFF")

func toggle_terrain_analysis():
	show_terrain_analysis = !show_terrain_analysis
	print("Terrain analysis debug: ", "ON" if show_terrain_analysis else "OFF")

func toggle_movement_prediction():
	show_movement_prediction = !show_movement_prediction
	print("Movement prediction debug: ", "ON" if show_movement_prediction else "OFF")

func print_full_analysis():
	print("=== FULL TERRAIN ANALYSIS ===")
	print("Average height: %.2f" % current_analysis.average_height)
	print("Height variance: %.3f" % current_analysis.height_variance)
	print("Terrain roughness: %.3f" % current_analysis.terrain_roughness)
	print("Max slope angle: %.1f°" % current_analysis.max_slope_angle)
	print("Forward trend: %s" % current_analysis.forward_trend)
	print("Steppable zones: %d" % current_analysis.steppable_zones.size())
	print("Total samples: %d" % current_samples.size())
	print("Valid samples: %d" % current_samples.filter(func(s): return s.has_ground).size())
	print("==============================")
