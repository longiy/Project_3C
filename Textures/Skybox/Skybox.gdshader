shader_type sky;

uniform sampler2D hdri_gradient : filter_linear, source_color;
uniform float hdri_gradient_lighting_exposure : hint_range(0, 128) = 1.0;
uniform float hdri_gradient_visual_exposure : hint_range(0, 128) = 1.0;
uniform sampler2D sky_gradient : filter_linear, source_color;
uniform sampler2D clouds : filter_linear, source_color, hint_default_black;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.1;
uniform float exposure : hint_range(0, 128) = 1.0;

void sky() {
   if(AT_CUBEMAP_PASS){
       COLOR = texture(hdri_gradient, vec2(SKY_COORDS.y, 0.0)).rgb * hdri_gradient_lighting_exposure;
   }
   else{
       vec3 sky_color = texture(sky_gradient, vec2(SKY_COORDS.y, 0.0)).rgb;
       vec2 cloud_uv = SKY_COORDS + vec2(TIME * cloud_speed, 0.0);
       vec4 cloud_sample = texture(clouds, cloud_uv);
       vec3 final_cloud_color = cloud_sample.rgb * cloud_color.rgb;
       COLOR = mix(sky_color, final_cloud_color, cloud_sample.a);
   }
}