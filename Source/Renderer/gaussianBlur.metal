#include <metal_stdlib>
using namespace metal;

// Define the kernel function to apply Gaussian blur
kernel void gaussianBlur(texture2d<float, access::read> inTexture [[ texture(0) ]],
                         texture2d<float, access::write> outTexture [[ texture(1) ]],
                         constant float& sigma [[ buffer(0) ]],
                         uint2 gid [[ thread_position_in_grid ]]) {
    // The radius of the blur. The larger, the more blurred.
    const int radius = 5;
    float delta = 0.0;
    float weightSum = 0.0;
    float3 colorSum = float3(0.0);
    
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            uint2 samplePos = gid + uint2(x, y);
            float weight = exp(-(x*x + y*y) / (2*sigma*sigma));
            weightSum += weight;
            colorSum += weight * inTexture.read(samplePos).rgb;
        }
    }
    
    float3 resultColor = colorSum / weightSum;
    outTexture.write(float4(resultColor, 1.0), gid);
}

// Utility function to compute Gaussian weight
inline float gaussian_weight(float x, float sigma) {
    return exp(-x*x / (2 * sigma * sigma)) / (sqrt(2 * M_PI_F) * sigma);
}

// Horizontal Gaussian blur
kernel void horizontalGaussianBlur(texture2d<float, access::read> inTexture [[ texture(0) ]],
                                   texture2d<float, access::write> outTexture [[ texture(1) ]],
                                   constant float& sigma [[ buffer(0) ]],
                                   uint2 gid [[ thread_position_in_grid ]]) {
    const int radius = 25; // Change as needed
    float4 colorSum = float4(0.0);
    float weightSum = 0.001;

    for (int i = -radius; i <= radius; ++i) {
        uint2 samplePos = gid + uint2(i, 0.0);
        float4 sample = inTexture.read(samplePos);
        float weight = gaussian_weight(float(i), sigma);
      if (sample.a > 0.99) {
        colorSum += weight * sample;
        weightSum += weight;
      }
    }

    outTexture.write(float4(colorSum / weightSum), gid);
}

// Vertical Gaussian blur
kernel void verticalGaussianBlur(texture2d<float, access::read> inTexture [[ texture(0) ]],
                                 texture2d<float, access::write> outTexture [[ texture(1) ]],
                                 constant float& sigma [[ buffer(0) ]],
                                 uint2 gid [[ thread_position_in_grid ]]) {
    const int radius = 25; // Change as needed
    float4 colorSum = float4(0.0);
    float weightSum = 0.001;

    for (int i = -radius; i <= radius; ++i) {
      uint2 samplePos = gid + uint2(0.0, i);
      float4 sample = inTexture.read(samplePos);
      float weight = gaussian_weight(float(i), sigma);
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
