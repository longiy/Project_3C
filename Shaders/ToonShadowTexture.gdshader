shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture  : source_color;
uniform sampler2D shadow_texture  : source_color;
uniform float shadow_threshold    : hint_range(0.0, 1.0) = 0.30;
uniform float specular_threshold  : hint_range(0.0, 1.0) = 0.70;
uniform float specular_strenght   : hint_range(0.0, 0.5) = 0.50;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 1.00;
uniform bool only_colored_specular = true;


void fragment() {
	// Normal texture
	vec4 uv_texture = texture(albedo_texture, UV);
	ALBEDO = vec3(uv_texture.xyz);
}

void light() {
	// basic light
	float base_light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;

	// all threshholds
	bool shadow = base_light >= shadow_threshold;
	bool specular = base_light >= specular_threshold;
	bool highlight = base_light >= highlight_threshold;

	// shadow output
	DIFFUSE_LIGHT = vec3(shadow ? 1.0 : 0.0);

	// specular highlights
	vec3 color = LIGHT_COLOR;

	// only colored check
	if (only_colored_specular == true) {
		float color_avarage = (color.x + color.y + color.z) / 3.0; // greyscale
		bool is_colored = color_avarage <= 2.0; // checks if it's colored based on greyscale
		color *= vec3(is_colored ? 1.0 : 0.0); // to vec3 (color)
	}

	// get colored specular
	vec3 specular_vec_color = color * vec3(specular ? 1.0 : 0.0) * vec3(specular_strenght);
	// specular + highlights
	vec3 specular_out = specular_vec_color + vec3(highlight ? 1.0 : 0.0);
	// specular + shadow texture only on shadow
	specular_out += texture(shadow_texture, UV).xyz * vec3(shadow ? 0.0 : 1.0);

	// specular and highlights output
	SPECULAR_LIGHT = specular_out;
}