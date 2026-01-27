shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform bool use_vertex_color = false;
uniform float shadow_threshold    : hint_range(0.0, 1.0) = 0.30;
uniform float specular_threshold  : hint_range(0.0, 1.0) = 0.70;
uniform float specular_strenght   : hint_range(0.0, 0.5) = 0.50;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 1.00;
uniform bool only_colored_specular = true;

void fragment() {
   ALBEDO = use_vertex_color ? COLOR.rgb : albedo_color.rgb;
}

void light() {
   float base_light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;

   bool shadow = base_light >= shadow_threshold;
   bool specular = base_light >= specular_threshold;
   bool highlight = base_light >= highlight_threshold;

   DIFFUSE_LIGHT = vec3(shadow ? 1.0 : 0.0);

   vec3 color = LIGHT_COLOR;
   if (only_colored_specular == true) {
   	float color_avarage = (color.x + color.y + color.z) / 3.0;
   	bool is_colored = color_avarage <= 2.0;
   	color *= vec3(is_colored ? 1.0 : 0.0);
   }

   vec3 specular_vec_color = color * vec3(specular ? 1.0 : 0.0) * vec3(specular_strenght);
   vec3 specular_out = specular_vec_color + vec3(highlight ? 1.0 : 0.0);
   specular_out += shadow_color.rgb * vec3(shadow ? 0.0 : 1.0);

   SPECULAR_LIGHT = specular_out;
}