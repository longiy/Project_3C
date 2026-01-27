#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 1, binding = 0) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
   vec2 raster_size;
   float strength;     // 0.0 = off, 1.0 = full painterly
   float radius;       // Kernel size
} params;

void main() {
   ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
   ivec2 size = ivec2(params.raster_size);

   if (uv.x >= size.x || uv.y >= size.y) {
      return;
   }

   vec4 original = imageLoad(color_image, uv);
   vec2 normalized_uv = vec2(uv) / params.raster_size;
   
   if (params.strength < 0.01 || params.radius < 0.1) {
      return; // Skip processing
   }
   
   int kernel_size = int(ceil(params.radius));
   int region_size = (kernel_size + 1) / 2;
   
   // Sample 4 regions around the pixel
   vec3 mean_a = vec3(0.0);
   vec3 mean_b = vec3(0.0);
   vec3 mean_c = vec3(0.0);
   vec3 mean_d = vec3(0.0);
   
   float var_a = 0.0;
   float var_b = 0.0;
   float var_c = 0.0;
   float var_d = 0.0;
   
   float count = float(region_size * region_size);
   vec2 pixel_size = 1.0 / params.raster_size;
   
   // Region A (top-left)
   for (int y = -region_size; y < 0; ++y) {
      for (int x = -region_size; x < 0; ++x) {
         vec2 offset = vec2(float(x), float(y)) * pixel_size;
         vec3 sample_col = texture(color_texture, normalized_uv + offset).rgb;
         mean_a += sample_col;
         var_a += dot(sample_col, sample_col);
      }
   }
   mean_a /= count;
   var_a = abs(var_a / count - dot(mean_a, mean_a));
   
   // Region B (top-right)
   for (int y = -region_size; y < 0; ++y) {
      for (int x = 0; x < region_size; ++x) {
         vec2 offset = vec2(float(x), float(y)) * pixel_size;
         vec3 sample_col = texture(color_texture, normalized_uv + offset).rgb;
         mean_b += sample_col;
         var_b += dot(sample_col, sample_col);
      }
   }
   mean_b /= count;
   var_b = abs(var_b / count - dot(mean_b, mean_b));
   
   // Region C (bottom-left)
   for (int y = 0; y < region_size; ++y) {
      for (int x = -region_size; x < 0; ++x) {
         vec2 offset = vec2(float(x), float(y)) * pixel_size;
         vec3 sample_col = texture(color_texture, normalized_uv + offset).rgb;
         mean_c += sample_col;
         var_c += dot(sample_col, sample_col);
      }
   }
   mean_c /= count;
   var_c = abs(var_c / count - dot(mean_c, mean_c));
   
   // Region D (bottom-right)
   for (int y = 0; y < region_size; ++y) {
      for (int x = 0; x < region_size; ++x) {
         vec2 offset = vec2(float(x), float(y)) * pixel_size;
         vec3 sample_col = texture(color_texture, normalized_uv + offset).rgb;
         mean_d += sample_col;
         var_d += dot(sample_col, sample_col);
      }
   }
   mean_d /= count;
   var_d = abs(var_d / count - dot(mean_d, mean_d));
   
   // Choose region with lowest variance (most homogeneous)
   float min_var = min(min(var_a, var_b), min(var_c, var_d));
   
   vec3 result = original.rgb;
   if (min_var == var_a) result = mean_a;
   else if (min_var == var_b) result = mean_b;
   else if (min_var == var_c) result = mean_c;
   else if (min_var == var_d) result = mean_d;
   
   // Mix with original based on strength
   result = mix(original.rgb, result, params.strength);
   
   imageStore(color_image, uv, vec4(result, original.a));
}
