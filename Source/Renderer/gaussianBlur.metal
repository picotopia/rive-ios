#include <metal_stdlib>
using namespace metal;

// Horizontal Gaussian blur
kernel void horizontalGaussianBlur(texture2d<float, access::read> inTexture [[ texture(0) ]],
                                   texture2d<float, access::write> outTexture [[ texture(1) ]],
                                   constant int& radius [[ buffer(0) ]],
                                   const device float* blurKernel [[ buffer(1) ]],
                                   uint2 gid [[ thread_position_in_grid ]]) {
  float4 colorSum = float4(0.0);
  float weightSum = 0.001;
  
  int i = 0;
  for (int dx = -radius; dx <= radius; ++i, ++dx) {
    uint2 samplePos = gid + uint2(dx, 0.0);
    float4 sample = inTexture.read(samplePos);
    float weight = blurKernel[i];
    if (sample.a > 0.99) {
      colorSum += weight * sample;
      weightSum += weight;
    }
  }
  
  outTexture.write(colorSum / weightSum, gid);
}

// Vertical Gaussian blur
kernel void verticalGaussianBlur(texture2d<float, access::read> inTexture [[ texture(0) ]],
                                 texture2d<float, access::write> outTexture [[ texture(1) ]],
                                 constant int& radius [[ buffer(0) ]],
                                 const device float* blurKernel [[ buffer(1) ]],
                                 uint2 gid [[ thread_position_in_grid ]]) {
  float4 colorSum = float4(0.0);
  float weightSum = 0.001;
  
  int i = 0;
  for (int dy = -radius; dy <= radius; ++dy, ++i) {
    uint2 samplePos = gid + uint2(0.0, dy);
    float4 sample = inTexture.read(samplePos);
    float weight = blurKernel[i];
    if (sample.a > 0.99) {
      colorSum += weight * sample;
      weightSum += weight;
    }
  }
  
  outTexture.write(colorSum / weightSum, gid);
}

kernel void alphaMask(texture2d<float, access::read> inputTexture [[texture(0)]],
                      texture2d<float, access::read> alphaTexture [[texture(1)]],
                      texture2d<float, access::write> outputTexture [[texture(2)]],
                      uint2 gid [[thread_position_in_grid]]) {
  // Read the color from the blurred texture
  float4 color = inputTexture.read(gid);
  // Read the alpha value from the alpha texture
  color *= alphaTexture.read(gid).a;
  // Apply the alpha mask
  
  // debug
  //    color.rgb = color.a;
  //    color.a = 1;
  
  // Write the result to the output texture
  outputTexture.write(color, gid);
}
