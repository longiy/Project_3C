shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Color parameters for each face direction
uniform vec3 top_color : source_color = vec3(1.0, 0.0, 0.0);    // Red for top
uniform vec3 bottom_color : source_color = vec3(0.0, 1.0, 0.0); // Green for bottom
uniform vec3 side_color : source_color = vec3(0.0, 0.0, 1.0);   // Blue for sides

// Threshold for determining face direction
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

// Use world space normals (true) or local space (false)
uniform bool use_world_space = true;

// World space texture mapping
uniform sampler2D world_texture : source_color;
uniform float world_texture_scale : hint_range(0.001, 100.0) = 1.0;
uniform float texture_overlay_factor : hint_range(0.0, 1.0) = 0.5;
uniform bool use_additive_texture = false;

// Custom lighting controls
uniform vec3 shadow_tint_color : source_color = vec3(0.5, 0.5, 1.0);
uniform float shadow_tint_strength : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.30;
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.70;
uniform float specular_strength : hint_range(0.0, 0.5) = 0.50;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 1.00;
uniform bool only_colored_specular = true;

varying vec3 world_normal;
varying vec3 local_normal;
varying vec3 world_position;
varying vec3 local_position;
varying vec3 final_albedo;

void vertex() {
    // Calculate world space normal and position
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    local_normal = NORMAL;
    local_position = VERTEX;
}

void fragment() {
    vec3 normal_to_use;
    vec3 position_to_use;

    if (use_world_space) {
        normal_to_use = world_normal;
        position_to_use = world_position;
    } else {
        normal_to_use = local_normal;
        position_to_use = local_position;
    }

    // Calculate face direction based on normal
    float up_factor = dot(normal_to_use, vec3(0.0, 1.0, 0.0));
    float down_factor = dot(normal_to_use, vec3(0.0, -1.0, 0.0));

    vec3 base_color;

    // Determine which face we're on
    if (up_factor > threshold) {
        // Top face
        base_color = top_color;
    } else if (down_factor > threshold) {
        // Bottom face
        base_color = bottom_color;
    } else {
        // Side face
        base_color = side_color;
    }

    // Sample world space texture using XZ coordinates
    vec2 world_uv = position_to_use.xz * world_texture_scale;
    vec3 texture_color = texture(world_texture, world_uv).rgb;

    // Mix texture with base color using overlay factor
    vec3 final_color;
    if (use_additive_texture) {
        final_color = base_color + (texture_color * texture_overlay_factor);
    } else {
        final_color = mix(base_color, base_color * texture_color, texture_overlay_factor);
    }

    final_albedo = final_color;
    ALBEDO = final_color;
}

void light() {
    // Basic light calculation
    float base_light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;

    // All thresholds
    bool shadow = base_light >= shadow_threshold;
    bool specular = base_light >= specular_threshold;
    bool highlight = base_light >= highlight_threshold;

    // Shadow output - binary shadow/lit regions
    DIFFUSE_LIGHT = vec3(shadow ? 1.0 : 0.0);

    // Specular highlights
    vec3 color = LIGHT_COLOR;

    // Only colored specular check
    if (only_colored_specular == true) {
        float color_average = (color.x + color.y + color.z) / 3.0; // greyscale
        bool is_colored = color_average <= 2.0; // checks if it's colored based on greyscale
        color *= vec3(is_colored ? 1.0 : 0.0); // to vec3 (color)
    }

    // Get colored specular
    vec3 specular_vec_color = color * vec3(specular ? 1.0 : 0.0) * vec3(specular_strength);

    // Specular + highlights
    vec3 specular_out = specular_vec_color + vec3(highlight ? 1.0 : 0.0);

    // Shadow color replacement - only applied in shadow regions
    specular_out += shadow_tint_color * vec3(shadow ? 0.0 : 1.0);

    // Specular and highlights output
    SPECULAR_LIGHT = specular_out;
}