shader_type spatial;
render_mode cull_disabled;

// Toon Shading
group_uniforms Toon;
uniform float ToonRampOffset: hint_range(0.0, 1.0) = 0.5;
uniform float ToonRampSmoothness: hint_range(0.0, 1.0) = 0.05;
uniform vec3 ToonRampTinting: source_color = vec3(0.2, 0.3, 0.2);

// Rim Lighting
group_uniforms Rim;
uniform float RimPower: hint_range(0.0, 10.0) = 1.0;
uniform float RimCutOff: hint_range(0.0, 1.0) = 0.5;
uniform float RimSmoothness: hint_range(0.0, 1.0) = 0.05;
uniform float RimLightBrightness: hint_range(0.0, 50.0) = 20.0;

// Distance Culling
group_uniforms DistanceCulling;
uniform float fadeout_start_distance: hint_range(10.0, 200.0) = 50.0;
uniform float fadeout_end_distance: hint_range(20.0, 300.0) = 100.0;
uniform float sink_amount: hint_range(0.0, 10.0) = 2.0;

// Wind Animation
group_uniforms Wind;
uniform float wind_strength: hint_range(0.0, 100.0) = 10.0;
uniform float wind_speed: hint_range(0.0, 10.0) = 5.0;
uniform float wind_noise_scale: hint_range(0.01, 1.0) = 0.1;
uniform vec2 wind_direction = vec2(1.0, 0.0);

// Grass Settings
group_uniforms Grass;
uniform sampler2D gradient_texture: source_color;
uniform bool backface_culling = true;
uniform bool use_world_up_normal = true;
uniform float gradient_height: hint_range(0.1, 10.0) = 2.0;

varying vec3 world_position;
varying vec3 object_position;
varying vec3 original_normal;
varying float distance_fade;

// Noise functions
vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
  return mod289(((x*34.0)+1.0)*x);
}

float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);

  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;

  i = mod289(i);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));

  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m;
  m = m*m;

  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;

  m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);

  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;

  return 130.0 * dot(m, g);
}

float fresnel(float amount, vec3 normal, vec3 view) {
   return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

void vertex() {
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  object_position = VERTEX;
  original_normal = NORMAL;

  // Calculate distance to camera
  vec3 camera_world_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
  float distance_to_camera = length(world_position - camera_world_pos);

  // Calculate fade factor based on distance
  distance_fade = 1.0 - smoothstep(fadeout_start_distance, fadeout_end_distance, distance_to_camera);

  // Sink grass down based on distance
  float sink_offset = (1.0 - distance_fade) * sink_amount;
  VERTEX.y -= sink_offset;

  float height_factor = (object_position.y + 1.0) * 0.5;

  vec2 wind_uv1 = world_position.xz * wind_noise_scale + TIME * wind_speed * 0.1;
  vec2 wind_uv2 = world_position.xz * wind_noise_scale * 2.0 + TIME * wind_speed * 0.15;

  float wind_noise = snoise(wind_uv1) * 0.7 + snoise(wind_uv2) * 0.3;

  vec3 wind_offset = vec3(
      wind_direction.x * wind_noise * wind_strength * height_factor * 0.01,
      0.0,
      wind_direction.y * wind_noise * wind_strength * height_factor * 0.01
  );

  // Apply wind only if grass is still visible
  VERTEX += wind_offset * distance_fade;

  if (use_world_up_normal) {
      NORMAL = vec3(0.0, 1.0, 0.0);
  }
}

void fragment() {
  if (backface_culling && !FRONT_FACING) {
      discard;
  }

  // Use manual gradient height parameter
  float gradient_uv = (object_position.y + gradient_height * 0.5) / gradient_height;
  gradient_uv = clamp(gradient_uv, 0.0, 1.0);

  vec3 gradient_color = texture(gradient_texture, vec2(gradient_uv, 0.5)).rgb;

  ALBEDO = gradient_color;
}

void light() {
   // Toon diffuse shading
   float d = dot(NORMAL, LIGHT) * 0.5 + 0.5;
   float toonRamp = smoothstep(ToonRampOffset, ToonRampOffset + ToonRampSmoothness, d);

   // Apply shadows
   toonRamp *= ATTENUATION;

   vec3 toonRampOutput = LIGHT_COLOR * toonRamp;
   vec3 ambientLightOutput = ALBEDO * ToonRampTinting;
   DIFFUSE_LIGHT += clamp((toonRampOutput - ambientLightOutput), vec3(0.0), vec3(1.0));

   // Rim lighting
   float fresnel_rim = fresnel(RimPower, NORMAL, VIEW);
   float rim_dot = dot(NORMAL, LIGHT);
   rim_dot *= fresnel_rim;
   rim_dot = smoothstep(RimCutOff, RimCutOff + RimSmoothness, rim_dot);

   vec3 rimOutput = rim_dot * RimLightBrightness * ALBEDO;
   DIFFUSE_LIGHT += rimOutput;

   SPECULAR_LIGHT = ambientLightOutput;
}