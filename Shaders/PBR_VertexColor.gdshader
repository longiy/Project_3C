shader_type spatial;

varying vec4 vertex_color;
uniform bool use_vertex_colors = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

void vertex() {
    vertex_color = COLOR;
}

void fragment() {
    vec4 albedo = texture(albedo_texture, UV) * albedo_color;

    if (use_vertex_colors) {
        albedo *= vertex_color;
    }

    ALBEDO = albedo.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
}