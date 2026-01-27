#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 1, binding = 0) uniform sampler2D depth_texture;
layout(set = 2, binding = 0) uniform sampler2D fog_gradient;
layout(set = 3, binding = 0) uniform sampler2D fog_curve;
layout(set = 4, binding = 0) uniform sampler2D vignette_gradient;

layout(push_constant, std430) uniform Params {
   vec2 raster_size;
   float sanity_level;
   float grain_time_step;
   float vignette_intensity;
   float vignette_radius;
   float grain_amount;
   float grain_size;
   float contrast;
   float saturation;
   float brightness;
   float temperature;
   float fog_start;
   float fog_end;
   float fog_intensity;
   float fog_use_radial;  // 0.0 = linear depth fog, 1.0 = radial distance fog
} params;

vec3 rgb_to_hsv(vec3 c) {
   vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
   vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
   vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

   float d = q.x - min(q.w, q.y);
   float e = 1.0e-10;
   return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
   vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
   vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
   return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float rand(vec2 seed, float frame_seed, float scale) {
   // Scale down coordinates for larger grain
   vec2 scaled = floor(seed / scale);
   
   // High-quality 2D hash without directional bias
   scaled = fract(scaled * vec2(0.1031, 0.1030));
   scaled += dot(scaled, scaled.yx + 33.33);
   float hash = fract((scaled.x + scaled.y) * scaled.x);
   
   // Frame-based variation with large prime
   float frame_offset = fract(frame_seed * 0.7548776662);
   hash = fract(hash + frame_offset);
   
   // Convert to [-1, 1] and apply film-like distribution
   hash = hash * 2.0 - 1.0;
   hash = sign(hash) * pow(abs(hash), 0.8);
   
   return hash * 0.01;
}

void main() {
   ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
   ivec2 size = ivec2(params.raster_size);

   if (uv.x >= size.x || uv.y >= size.y) {
      return;
   }

   vec4 color = imageLoad(color_image, uv);
   vec2 normalized_uv = vec2(uv) / params.raster_size;
   vec2 centered = normalized_uv - 0.5;
   
   // Sanity influence: 0 = sane (no effects), 1 = insane (full effects)
   float effect_strength = params.sanity_level;
   
   // === COLOR GRADING (1st - sensor/film response) ===
   float brightness_scaled = params.brightness * effect_strength;
   float contrast_scaled = 1.0 + ((params.contrast - 1.0) * effect_strength);
   float saturation_scaled = 1.0 - ((1.0 - params.saturation) * effect_strength);
   float temperature_scaled = params.temperature * effect_strength;
   
   // Brightness
   color.rgb += brightness_scaled;
   
   // Contrast
   color.rgb = (color.rgb - 0.5) * contrast_scaled + 0.5;
   
   // Saturation
   vec3 hsv = rgb_to_hsv(color.rgb);
   hsv.y *= saturation_scaled;
   color.rgb = hsv_to_rgb(hsv);
   
   // Temperature
   if (temperature_scaled > 0.0) {
      color.r += temperature_scaled * 0.1;
      color.b -= temperature_scaled * 0.05;
   } else {
      color.b -= temperature_scaled * 0.1;
      color.r += temperature_scaled * 0.05;
   }
   
   // === DEPTH FOG (2nd - atmospheric/scene effect) ===
   float depth = texelFetch(depth_texture, uv, 0).r;
   // Linearize depth (assuming reverse-Z)
   float linear_depth = 1.0 / depth;
   
   float fog_distance;
   if (params.fog_use_radial > 0.5) {
      // Radial fog: 3D distance from camera position
      // Reconstruct view-space ray direction
      vec2 ndc = normalized_uv * 2.0 - 1.0;
      // Approximate radial distance (accurate enough for fog)
      float radial_factor = length(vec3(ndc, 1.0));
      fog_distance = linear_depth * radial_factor;
   } else {
      // Depth fog: linear distance along view direction
      fog_distance = linear_depth;
   }
   
   // Calculate fog factor
   float fog_factor = smoothstep(params.fog_start, params.fog_end, fog_distance);
   // Remap fog progression using curve texture
   fog_factor = texture(fog_curve, vec2(fog_factor, 0.5)).r;
   fog_factor *= params.fog_intensity * effect_strength;
   
   // Sample gradient texture (including alpha)
   vec4 fog_color_alpha = texture(fog_gradient, vec2(fog_factor, 0.5));
   
   // Mix fog into scene using gradient's alpha channel
   // Alpha controls fog opacity, allowing transparent fog
   float final_fog_factor = fog_factor * fog_color_alpha.a;
   color.rgb = mix(color.rgb, fog_color_alpha.rgb, final_fog_factor);
   
   // === FILM GRAIN (3rd - film emulsion structure) ===
   float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
   float noise = rand(gl_GlobalInvocationID.xy, params.grain_time_step, params.grain_size);
   float grain_strength = params.grain_amount * effect_strength * (0.02 + luminance * 100.0);
   color.rgb += noise * grain_strength;
   
   // === VIGNETTE (4th - lens optical falloff) ===
   float dist = length(centered);
   // Normalize distance by radius
   float vignette_factor = clamp(dist / params.vignette_radius, 0.0, 1.0);
   // Sample gradient for vignette color
   vec3 vignette_color = texture(vignette_gradient, vec2(vignette_factor, 0.5)).rgb;
   // Apply intensity scaling
   vignette_color = mix(vec3(1.0), vignette_color, params.vignette_intensity * effect_strength);
   color.rgb *= vignette_color;
   
   // Clamp
   color.rgb = clamp(color.rgb, vec3(0.0), vec3(1.0));
   
   imageStore(color_image, uv, color);
}
