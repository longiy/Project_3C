@tool
extends CompositorEffect
class_name Sanity

# Main sanity control (0 = sane/no effects, 1 = insane/full effects)
@export_range(0.0, 1.0) var sanity_level: float = 0.0

# Base effect strengths (sanity_level scales these)
@export_group("Vignette")
@export_range(0.0, 1.0) var vignette_intensity: float = 1
@export_range(0.1, 2.0) var vignette_radius: float = 0.7
@export var vignette_gradient: GradientTexture1D

@export_group("Film Grain")
@export_range(0.0, 1.0) var grain_amount: float = 0.6
@export_range(1.0, 20.0) var grain_size: float = 1.0
@export_range(1.0, 60.0) var grain_updates_per_second: float = 24.0  # How many times grain pattern changes per second

@export_group("Color Grading")
@export_range(0.5, 2.0) var contrast: float = 1
@export_range(0.0, 2.0) var saturation: float = 0.5
@export_range(-0.5, 0.5) var brightness: float = -0.2
@export_range(-1.0, 1.0) var temperature: float = -0.3

@export_group("Depth Fog")
@export_range(0.0, 1000.0) var fog_start: float = 10.0
@export_range(0.0, 1000.0) var fog_end: float = 200.0
@export_range(0.0, 1.0) var fog_intensity: float = 0.9
@export var fog_gradient: GradientTexture1D
@export var fog_curve: CurveTexture
@export var fog_use_radial: bool = true  # False = linear depth, True = radial distance from camera

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var default_gradient_rid: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	
	# Create default gradients/curves if none provided
	if not fog_gradient:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
		gradient.set_color(1, Color(0.0, 0.0, 0.0, 1.0))
		fog_gradient = GradientTexture1D.new()
		fog_gradient.gradient = gradient
		fog_gradient.width = 256
	
	if not fog_curve:
		var curve := Curve.new()
		var point_0 = curve.add_point(Vector2(0.0, 0.0))
		var point_1 = curve.add_point(Vector2(1.0, 1.0))

		# Make exponential (slow start, fast end)
		curve.set_point_left_mode(point_0, Curve.TANGENT_LINEAR)
		curve.set_point_right_mode(point_0, Curve.TANGENT_LINEAR)
		curve.set_point_left_mode(point_1, Curve.TANGENT_LINEAR)
		curve.set_point_right_mode(point_1, Curve.TANGENT_LINEAR)

		# Adjust tangents for exponential shape
		curve.set_point_right_tangent(point_0, 0.0)  # Flat start
		curve.set_point_left_tangent(point_1, 2.0)   # Steep end
		fog_curve = CurveTexture.new()
		fog_curve.curve = curve
		fog_curve.width = 256
	
	if not vignette_gradient:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color.BLACK)
		vignette_gradient = GradientTexture1D.new()
		vignette_gradient.gradient = gradient
		vignette_gradient.width = 256
	
	RenderingServer.call_on_render_thread(_initialize_compute)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			RenderingServer.free_rid(shader)


#region Rendering thread code
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	var shader_file := load(get_script().resource_path.get_base_dir() + "/sanity.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)


func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and pipeline.is_valid():
		var render_scene_buffers := p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var size: Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			@warning_ignore("integer_division")
			var x_groups := (size.x - 1) / 8 + 1
			@warning_ignore("integer_division")
			var y_groups := (size.y - 1) / 8 + 1
			var z_groups := 1

			# Pack all parameters
			# Grain updates based on time, not frames (framerate independent)
			var grain_time_step = floor(Time.get_ticks_msec() / 1000.0 * grain_updates_per_second)
			
			var push_constant := PackedFloat32Array([
				size.x,
				size.y,
				sanity_level,
				float(grain_time_step),
				vignette_intensity,
				vignette_radius,
				grain_amount,
				grain_size,
				contrast,
				saturation,
				brightness,
				temperature,
				fog_start,
				fog_end,
				fog_intensity,
				1.0 if fog_use_radial else 0.0
			])

			var view_count: int = render_scene_buffers.get_view_count()
			for view in view_count:
				var input_image: RID = render_scene_buffers.get_color_layer(view)
				var depth_image: RID = render_scene_buffers.get_depth_layer(view)

				# Uniform set 0: color image
				var uniform_color := RDUniform.new()
				uniform_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform_color.binding = 0
				uniform_color.add_id(input_image)
				var uniform_set_0 := UniformSetCacheRD.get_cache(shader, 0, [uniform_color])
				
				# Uniform set 1: depth texture
				var sampler_state := RDSamplerState.new()
				sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
				sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
				
				var uniform_depth := RDUniform.new()
				uniform_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				uniform_depth.binding = 0
				uniform_depth.add_id(rd.sampler_create(sampler_state))
				uniform_depth.add_id(depth_image)
				var uniform_set_1 := UniformSetCacheRD.get_cache(shader, 1, [uniform_depth])
				
				# Uniform set 2: fog gradient texture
				var fog_gradient_rid := RenderingServer.texture_get_rd_texture(fog_gradient.get_rid())
				var uniform_fog_gradient := RDUniform.new()
				uniform_fog_gradient.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				uniform_fog_gradient.binding = 0
				uniform_fog_gradient.add_id(rd.sampler_create(sampler_state))
				uniform_fog_gradient.add_id(fog_gradient_rid)
				var uniform_set_2 := UniformSetCacheRD.get_cache(shader, 2, [uniform_fog_gradient])
				
				# Uniform set 3: fog curve texture
				var fog_curve_rid := RenderingServer.texture_get_rd_texture(fog_curve.get_rid())
				var uniform_fog_curve := RDUniform.new()
				uniform_fog_curve.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				uniform_fog_curve.binding = 0
				uniform_fog_curve.add_id(rd.sampler_create(sampler_state))
				uniform_fog_curve.add_id(fog_curve_rid)
				var uniform_set_3 := UniformSetCacheRD.get_cache(shader, 3, [uniform_fog_curve])
				
				# Uniform set 4: vignette gradient texture
				var vignette_gradient_rid := RenderingServer.texture_get_rd_texture(vignette_gradient.get_rid())
				var uniform_vignette := RDUniform.new()
				uniform_vignette.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				uniform_vignette.binding = 0
				uniform_vignette.add_id(rd.sampler_create(sampler_state))
				uniform_vignette.add_id(vignette_gradient_rid)
				var uniform_set_4 := UniformSetCacheRD.get_cache(shader, 4, [uniform_vignette])

				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_0, 0)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_1, 1)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_2, 2)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_3, 3)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_4, 4)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
#endregion
