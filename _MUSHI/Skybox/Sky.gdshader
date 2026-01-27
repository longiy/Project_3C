shader_type sky;

// === GLOBAL SETTINGS ===
group_uniforms Global;
uniform float time : hint_range(0.0, 24.0) = 12.0;
uniform float transition_blend : hint_range(0.5, 3.0) = 1.5;
group_uniforms;

// === SKY GRADIENTS ===
group_uniforms SkyGradients;
uniform sampler2D morning_sky_gradient : source_color, filter_linear, repeat_disable;
uniform sampler2D midday_sky_gradient : source_color, filter_linear, repeat_disable;
uniform sampler2D afternoon_sky_gradient : source_color, filter_linear, repeat_disable;
uniform sampler2D evening_sky_gradient : source_color, filter_linear, repeat_disable;
uniform sampler2D night_sky_gradient : source_color, filter_linear, repeat_disable;
group_uniforms;

// === MORNING PHASE (7.0 ± 2.0) ===
group_uniforms Morning;
uniform vec3 morning_sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float morning_sun_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float morning_sun_angle : hint_range(-90.0, 90.0) = 20.0;
uniform vec3 morning_moon_color : source_color = vec3(0.7, 0.7, 0.9);
uniform float morning_moon_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float morning_moon_angle : hint_range(-90.0, 90.0) = -30.0;
uniform vec3 morning_ambient_color : source_color = vec3(0.6, 0.7, 0.8);
uniform float morning_ambient_energy : hint_range(0.0, 1.0) = 0.3;
group_uniforms;

// === MIDDAY PHASE (12.0 ± 3.0) ===
group_uniforms Midday;
uniform vec3 midday_sun_color : source_color = vec3(1.0, 1.0, 0.95);
uniform float midday_sun_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float midday_sun_angle : hint_range(-90.0, 90.0) = 70.0;
uniform vec3 midday_moon_color : source_color = vec3(0.8, 0.8, 1.0);
uniform float midday_moon_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float midday_moon_angle : hint_range(-90.0, 90.0) = -70.0;
uniform vec3 midday_ambient_color : source_color = vec3(0.8, 0.85, 0.9);
uniform float midday_ambient_energy : hint_range(0.0, 1.0) = 0.5;
group_uniforms;

// === AFTERNOON PHASE (16.5 ± 1.5) ===
group_uniforms Afternoon;
uniform vec3 afternoon_sun_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float afternoon_sun_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float afternoon_sun_angle : hint_range(-90.0, 90.0) = 40.0;
uniform vec3 afternoon_moon_color : source_color = vec3(0.8, 0.8, 1.0);
uniform float afternoon_moon_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float afternoon_moon_angle : hint_range(-90.0, 90.0) = -40.0;
uniform vec3 afternoon_ambient_color : source_color = vec3(0.85, 0.75, 0.7);
uniform float afternoon_ambient_energy : hint_range(0.0, 1.0) = 0.4;
group_uniforms;

// === EVENING PHASE (19.5 ± 1.5) ===
group_uniforms Evening;
uniform vec3 evening_sun_color : source_color = vec3(1.0, 0.6, 0.3);
uniform float evening_sun_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float evening_sun_angle : hint_range(-90.0, 90.0) = 5.0;
uniform vec3 evening_moon_color : source_color = vec3(0.7, 0.75, 0.9);
uniform float evening_moon_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float evening_moon_angle : hint_range(-90.0, 90.0) = -10.0;
uniform vec3 evening_ambient_color : source_color = vec3(0.5, 0.4, 0.5);
uniform float evening_ambient_energy : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

// === NIGHT PHASE (1.0 ± 4.0) ===
group_uniforms Night;
uniform vec3 night_sun_color : source_color = vec3(0.3, 0.3, 0.4);
uniform float night_sun_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float night_sun_angle : hint_range(-90.0, 90.0) = -30.0;
uniform vec3 night_moon_color : source_color = vec3(0.7, 0.75, 1.0);
uniform float night_moon_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float night_moon_angle : hint_range(-90.0, 90.0) = 50.0;
uniform vec3 night_ambient_color : source_color = vec3(0.15, 0.15, 0.25);
uniform float night_ambient_energy : hint_range(0.0, 1.0) = 0.1;
group_uniforms;

// Convert view direction to spherical UV coordinates
vec2 view_to_uv(vec3 view_dir) {
    float u = atan(view_dir.x, view_dir.z) / (2.0 * PI) + 0.5;
    float v = view_dir.y * 0.5 + 0.5;
    return vec2(u, v);
}


// Normalize time to handle wrap-around
float normalize_time(float t) {
    while (t < 0.0) t += 24.0;
    while (t >= 24.0) t -= 24.0;
    return t;
}


// Calculate shortest distance between two times (handling wrap)
float time_distance(float t1, float t2) {
    float diff = abs(t1 - t2);
    if (diff > 12.0) {
        diff = 24.0 - diff;
    }
    return diff;
}


// Calculate phase weight using distance from center
float get_phase_weight(float current_time, float phase_center, float phase_half_width, float blend_width) {
    float dist = time_distance(current_time, phase_center);
    
    // Full weight in the center
    if (dist < phase_half_width) {
        return 1.0;
    }
    
    // Fade out beyond center
    float fade_start = phase_half_width;
    float fade_end = phase_half_width + blend_width;
    
    if (dist < fade_end) {
        return 1.0 - smoothstep(fade_start, fade_end, dist);
    }
    
    return 0.0;
}


void sky() {
    vec3 view_dir = EYEDIR;
    vec2 uv = view_to_uv(view_dir);
    
    // Define phases by CENTER and HALF-WIDTH instead of start/end
    // This makes wrap-around phases work identically to normal phases
    
    // Morning: 5-9 → center at 7, half-width 2
    float w_morning = get_phase_weight(time, 7.0, 2.0, transition_blend);
    
    // Midday: 9-15 → center at 12, half-width 3
    float w_midday = get_phase_weight(time, 12.0, 3.0, transition_blend);
    
    // Afternoon: 15-18 → center at 16.5, half-width 1.5
    float w_afternoon = get_phase_weight(time, 16.5, 1.5, transition_blend);
    
    // Evening: 18-21 → center at 19.5, half-width 1.5
    float w_evening = get_phase_weight(time, 19.5, 1.5, transition_blend);
    
    // Night: 21-5 (wraps) → center at 1 (25-24=1), half-width 4
    float w_night = get_phase_weight(time, 1.0, 4.0, transition_blend);
    
    // Normalize weights
    float total_weight = w_morning + w_midday + w_afternoon + w_evening + w_night;
    total_weight = max(total_weight, 0.001);
    
    w_morning /= total_weight;
    w_midday /= total_weight;
    w_afternoon /= total_weight;
    w_evening /= total_weight;
    w_night /= total_weight;
    
    // Sample all sky gradients
    vec4 sky_morning = texture(morning_sky_gradient, uv);
    vec4 sky_midday = texture(midday_sky_gradient, uv);
    vec4 sky_afternoon = texture(afternoon_sky_gradient, uv);
    vec4 sky_evening = texture(evening_sky_gradient, uv);
    vec4 sky_night = texture(night_sky_gradient, uv);
    
    // Blend sky colors
    vec3 final_sky = 
        sky_morning.rgb * w_morning +
        sky_midday.rgb * w_midday +
        sky_afternoon.rgb * w_afternoon +
        sky_evening.rgb * w_evening +
        sky_night.rgb * w_night;
    
    COLOR = final_sky;
    
    // === BLEND LIGHTING DATA (GPU-side calculation) ===
    // These will be read by EnvironmentManager via get_shader_parameter()
    // Stored in global variables accessible from outside the shader
    
    // NOTE: Godot sky shaders don't support custom outputs
    // Solution: Store blended values in alpha channels of COLOR for manager to read
    // We'll use a cleaner approach: manager reads uniforms + time, calculates on CPU once per frame
}