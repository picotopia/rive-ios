#include <metal_stdlib>
using namespace metal;

// Define the kernel function to apply Gaussian blur
kernel void gaussianBlur(texture2d<float, access::read> inTexture [[ texture(0) ]],
                         texture2d<float, access::write> outTexture [[ texture(1) ]],
                         constant float& sigma [[ buffer(0) ]],
                         uint2 gid [[ thread_position_in_grid ]]) {
    // The radius of the blur. The larger, the more blurred.
    const int radius = 3;
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
