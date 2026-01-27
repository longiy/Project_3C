@tool
extends CompositorEffect
class_name Kuwahara

@export_range(0.0, 1.0) var strength: float = 1.0
@export_range(1.0, 10.0) var radius: float = 5.0

var rd: RenderingDevice
var shader: RID
var pipeline: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
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

	var shader_file := load(get_script().resource_path.get_base_dir() + "/kuwahara.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)


func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and pipeline.is_valid():
		# Early exit if effect is disabled
		if strength < 0.01:
			return
			
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

			# Pack parameters
			var push_constant := PackedFloat32Array([
				size.x,
				size.y,
				strength,
				radius
			])

			var view_count: int = render_scene_buffers.get_view_count()
			for view in view_count:
				var input_image: RID = render_scene_buffers.get_color_layer(view)

				# Uniform set 0: color image (write)
				var uniform_color := RDUniform.new()
				uniform_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform_color.binding = 0
				uniform_color.add_id(input_image)
				var uniform_set_0 := UniformSetCacheRD.get_cache(shader, 0, [uniform_color])
				
				# Uniform set 1: color texture (read)
				var sampler_state := RDSamplerState.new()
				sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
				sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
				
				var uniform_color_tex := RDUniform.new()
				uniform_color_tex.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				uniform_color_tex.binding = 0
				uniform_color_tex.add_id(rd.sampler_create(sampler_state))
				uniform_color_tex.add_id(input_image)
				var uniform_set_1 := UniformSetCacheRD.get_cache(shader, 1, [uniform_color_tex])

				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_0, 0)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_1, 1)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
#endregion
