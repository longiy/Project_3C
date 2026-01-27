# res://systems/environment/environment_manager.gd
@tool
extends Node
class_name EnvironmentManager

@export_group("References")
@export var time_manager: TimeManager:
	set(value):
		# Disconnect old signal if exists
		if time_manager and time_manager.time_changed.is_connected(_on_time_changed):
			time_manager.time_changed.disconnect(_on_time_changed)
		
		time_manager = value
		
		# Connect new signal
		if time_manager:
			if not time_manager.time_changed.is_connected(_on_time_changed):
				time_manager.time_changed.connect(_on_time_changed)
			# Immediate update with current time
			_on_time_changed(time_manager.current_time)

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D

@export_group("Moon Settings")
@export var enable_moon: bool = true
@export var moon_opposite_sun: bool = true

@export_group("Sun Settings")
@export var sun_rotation_offset: float = 0.0

@export_group("Transition")
@export_range(0.5, 3.0) var transition_blend: float = 1.5

var sky_material: ShaderMaterial

func _ready():
	_setup_sky_material()
	
	# Connect to time manager if not already connected
	if time_manager and not time_manager.time_changed.is_connected(_on_time_changed):
		time_manager.time_changed.connect(_on_time_changed)
	
	if not Engine.is_editor_hint():
		if sky_material:
			sky_material.set_shader_parameter("transition_blend", transition_blend)

func _setup_sky_material():
	if not world_environment:
		return
	if not world_environment.environment:
		return
	if not world_environment.environment.sky:
		return
	
	sky_material = world_environment.environment.sky.sky_material as ShaderMaterial

func _on_time_changed(time: float):
	_setup_sky_material()

	if not sky_material:
		return

	sky_material.set_shader_parameter("time", time)
	
	# Calculate phase weights (same logic as shader)
	var weights = calculate_phase_weights(time)
	
	# Update lights and environment
	update_sun_light(time, weights)
	update_moon_light(time, weights)
	update_ambient(weights)

func calculate_phase_weights(time: float) -> Dictionary:
	var w_morning = get_phase_weight(time, 7.0, 2.0)
	var w_midday = get_phase_weight(time, 12.0, 3.0)
	var w_afternoon = get_phase_weight(time, 16.5, 1.5)
	var w_evening = get_phase_weight(time, 19.5, 1.5)
	var w_night = get_phase_weight(time, 1.0, 4.0)
	
	var total = w_morning + w_midday + w_afternoon + w_evening + w_night
	if total > 0.0:
		w_morning /= total
		w_midday /= total
		w_afternoon /= total
		w_evening /= total
		w_night /= total
	
	return {
		"morning": w_morning,
		"midday": w_midday,
		"afternoon": w_afternoon,
		"evening": w_evening,
		"night": w_night
	}

func get_phase_weight(current_time: float, phase_center: float, phase_half_width: float) -> float:
	var dist = time_distance(current_time, phase_center)
	
	if dist < phase_half_width:
		return 1.0
	
	var fade_end = phase_half_width + transition_blend
	if dist < fade_end:
		return 1.0 - smoothstep(phase_half_width, fade_end, dist)
	
	return 0.0

func time_distance(t1: float, t2: float) -> float:
	var diff = abs(t1 - t2)
	if diff > 12.0:
		diff = 24.0 - diff
	return diff

func update_sun_light(time: float, weights: Dictionary):
	if not sun_light or not sky_material:
		return
	
	# Read lighting data directly from shader uniforms
	var sun_color = blend_shader_colors(weights, "sun_color")
	var sun_intensity = blend_shader_floats(weights, "sun_intensity")
	var sun_angle = blend_shader_floats(weights, "sun_angle")
	
	sun_light.light_color = sun_color
	sun_light.light_energy = sun_intensity
	
	var azimuth = ((time - 6.0) / 12.0) * 180.0 + 90.0 + sun_rotation_offset
	sun_light.rotation_degrees = Vector3(-sun_angle, azimuth, 0)
	
	sun_light.visible = sun_angle > -10.0

func update_moon_light(time: float, weights: Dictionary):
	if not moon_light or not enable_moon or not sky_material:
		if moon_light:
			moon_light.visible = false
		return
	
	var moon_color = blend_shader_colors(weights, "moon_color")
	var moon_intensity = blend_shader_floats(weights, "moon_intensity")
	var moon_angle = blend_shader_floats(weights, "moon_angle")
	
	moon_light.light_color = moon_color
	moon_light.light_energy = moon_intensity
	
	if moon_opposite_sun:
		var moon_time = fmod(time + 12.0, 24.0)
		var azimuth = ((moon_time - 6.0) / 12.0) * 180.0 + 90.0
		moon_light.rotation_degrees = Vector3(-moon_angle, azimuth, 0)
	else:
		var azimuth = ((time - 18.0) / 12.0) * 180.0 + 270.0
		moon_light.rotation_degrees = Vector3(-moon_angle, azimuth, 0)
	
	moon_light.visible = weights["night"] > 0.1

func update_ambient(weights: Dictionary):
	if not world_environment or not sky_material:
		return
	
	var ambient_color = blend_shader_colors(weights, "ambient_color")
	var ambient_energy = blend_shader_floats(weights, "ambient_energy")
	
	world_environment.environment.ambient_light_color = ambient_color
	world_environment.environment.ambient_light_energy = ambient_energy

# Read color from shader uniforms per-phase and blend
func blend_shader_colors(weights: Dictionary, property: String) -> Color:
	var result = Color.BLACK
	
	var morning = sky_material.get_shader_parameter("morning_" + property)
	var midday = sky_material.get_shader_parameter("midday_" + property)
	var afternoon = sky_material.get_shader_parameter("afternoon_" + property)
	var evening = sky_material.get_shader_parameter("evening_" + property)
	var night = sky_material.get_shader_parameter("night_" + property)
	
	if morning != null:
		result += Color(morning) * weights["morning"]
	if midday != null:
		result += Color(midday) * weights["midday"]
	if afternoon != null:
		result += Color(afternoon) * weights["afternoon"]
	if evening != null:
		result += Color(evening) * weights["evening"]
	if night != null:
		result += Color(night) * weights["night"]
	
	return result

# Read float from shader uniforms per-phase and blend
func blend_shader_floats(weights: Dictionary, property: String) -> float:
	var result = 0.0
	
	var morning = sky_material.get_shader_parameter("morning_" + property)
	var midday = sky_material.get_shader_parameter("midday_" + property)
	var afternoon = sky_material.get_shader_parameter("afternoon_" + property)
	var evening = sky_material.get_shader_parameter("evening_" + property)
	var night = sky_material.get_shader_parameter("night_" + property)
	
	if morning != null:
		result += morning * weights["morning"]
	if midday != null:
		result += midday * weights["midday"]
	if afternoon != null:
		result += afternoon * weights["afternoon"]
	if evening != null:
		result += evening * weights["evening"]
	if night != null:
		result += night * weights["night"]
	
	return result
