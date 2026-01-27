shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_enable;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float min_lum : hint_range(0.0, 1.0) = 0.0;
uniform float max_lum : hint_range(0.0, 1.0) = 1.0;
uniform float time_scale : hint_range(0.0, 1.0) = 0.5;

float noise(vec2 p) {
    return (fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;
}

vec3 soft_light(vec3 A, vec3 B) {
    vec3 branch1 = 2.0 * A * B + A * A * (1.0 - 2.0 * B);
    vec3 branch2 = 2.0 * A * (1.0 - B) + sqrt(A) * (2.0 * B - 1.0);
    vec3 condition = step(0.5, B);
    return mix(branch1, branch2, condition);
}

void fragment() {
    vec2 uv = UV;
    vec3 original_color = texture(screen_texture, uv).rgb;

    float lum = dot(original_color, vec3(0.299, 0.587, 0.114));
    float factor = 1.0 - smoothstep(min_lum, max_lum, lum);

    vec2 offset = vec2(sin(TIME * time_scale), cos(TIME * time_scale)) * 20.0;
    vec2 noise_uv = uv + offset;

    float noise_r = noise(noise_uv);
    float noise_g = noise(noise_uv + vec2(0.1, 0.2));
    float noise_b = noise(noise_uv + vec2(0.3, 0.4));
    vec3 grain = vec3(noise_r, noise_g, noise_b) * grain_intensity * factor;

    vec3 grain_color = clamp(vec3(0.5) + grain, 0.0, 1.0);
    vec3 final_color = soft_light(original_color, grain_color);

    COLOR = vec4(final_color, 1.0);
}