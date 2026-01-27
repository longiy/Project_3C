shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_prepass_alpha;
uniform sampler2D depth_texture : source_color, hint_depth_texture;
uniform vec4 shallow_color: source_color = vec4(0.4, 0.8, 1.0, 0.8);
uniform vec4 deep_color: source_color = vec4(0.1, 0.3, 0.6, 0.95);
uniform float depth_fade_distance = 2.0;
uniform float fresnel_power = 2.0;
uniform float min_alpha = 0.1;
uniform float max_alpha = 0.9;
void fragment() {
   float depth = texture(depth_texture, SCREEN_UV).x;
   vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
   vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
   view.xyz /= view.w;
   float linear_depth = -view.z;

   float object_depth = FRAGCOORD.z;
   vec3 object_ndc = vec3(SCREEN_UV * 2.0 - 1.0, object_depth);
   vec4 object_view = INV_PROJECTION_MATRIX * vec4(object_ndc, 1.0);
   object_view.xyz /= object_view.w;
   float linear_object_depth = -object_view.z;

   // Calculate depth difference for water depth effect
   float depth_diff = max(0.0, linear_depth - linear_object_depth);
   float depth_factor = 1.0 - exp(-depth_diff / depth_fade_distance);

   // Fresnel for edge transparency
   float fresnel = pow(1.0 - dot(normalize(VIEW), NORMAL), fresnel_power);

   // Blend colors based on depth
   ALBEDO = mix(shallow_color.rgb, deep_color.rgb, depth_factor);

   // Combine depth and fresnel for alpha, clamped to avoid sorting issues
   float base_alpha = mix(shallow_color.a, deep_color.a, depth_factor);
   ALPHA = clamp(base_alpha + fresnel * 0.3, min_alpha, max_alpha);
}