#include "rive_renderer_view.hh"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import "RivePrivateHeaders.h"
#import <RenderContext.h>
#import <RenderContextManager.h>

@implementation RiveRendererView
{
    RenderContext* _renderContext;
    rive::Renderer* _renderer;
}

- (instancetype)initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];

    _renderContext = [[RenderContextManager shared] getDefaultContext];
    assert(_renderContext);
    self.device = [_renderContext metalDevice];

    [self setDepthStencilPixelFormat:_renderContext.depthStencilPixelFormat];
    [self setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
    [self setFramebufferOnly:_renderContext.framebufferOnly];
    [self setSampleCount:1];
  
  self.opaque = false;
  self.backgroundColor = [UIColor clearColor];
  
    return self;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    _renderContext = [[RenderContextManager shared] getDefaultContext];
    assert(_renderContext);

    auto value = [super initWithFrame:frameRect device:_renderContext.metalDevice];

    [self setDepthStencilPixelFormat:_renderContext.depthStencilPixelFormat];
    [self setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
    [self setFramebufferOnly:_renderContext.framebufferOnly];
    [self setSampleCount:1];
  
  self.opaque = false;
  self.backgroundColor = [UIColor clearColor];
  
    return value;
}

- (void)alignWithRect:(CGRect)rect
          contentRect:(CGRect)contentRect
            alignment:(RiveAlignment)alignment
                  fit:(RiveFit)fit
{
    rive::AABB frame(rect.origin.x,
                     rect.origin.y,
                     rect.size.width + rect.origin.x,
                     rect.size.height + rect.origin.y);

    rive::AABB content(contentRect.origin.x,
                       contentRect.origin.y,
                       contentRect.size.width + contentRect.origin.x,
                       contentRect.size.height + contentRect.origin.y);

    auto riveFit = [self riveFit:fit];
    auto riveAlignment = [self riveAlignment:alignment];

    _renderer->align(riveFit, riveAlignment, frame, content);
}
- (void)save
{
    assert(_renderer != nil);
    _renderer->save();
}

- (void)restore
{
    assert(_renderer != nil);
    _renderer->restore();
}

- (void)transform:(float)xx xy:(float)xy yx:(float)yx yy:(float)yy tx:(float)tx ty:(float)ty
{
    assert(_renderer != nil);
    _renderer->transform(rive::Mat2D{xx, xy, yx, yy, tx, ty});
}

- (void)drawWithArtboard:(RiveArtboard*)artboard
{
    assert(_renderer != nil);
    [artboard artboardInstance]->draw(_renderer);
}

- (void)drawRive:(CGRect)rect size:(CGSize)size
{
  NSLog(@"Hello zach");
    // Intended to be overridden.
}

- (bool)isPaused
{
    return true;
}

- (void)drawRect:(CGRect)rect
{
  // XXX
  self.opaque = false;
  self.layer.backgroundColor = [UIColor clearColor].CGColor;
  // XXX
  
    [super drawRect:rect];
    if (![[self currentDrawable] texture])
    {
        return;
    }

    _renderer = [_renderContext beginFrame:self];
    if (_renderer != nil)
    {
        _renderer->save();
        [self drawRive:rect size:self.drawableSize];
        _renderer->restore();
    }
    [_renderContext endFrame];
    _renderer = nil;

    id<MTLCommandBuffer> commandBuffer = [_renderContext.metalQueue commandBuffer];
#if TRUE
  
  id<MTLDevice> _device = [_renderContext metalDevice];
  id<MTLTexture> viewTexture = [[self currentDrawable] texture];
  
  MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:viewTexture.pixelFormat
                                                                                          width:viewTexture.width
                                                                                         height:viewTexture.height
                                                                                      mipmapped:NO];
  descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
  
  id<MTLTexture> tmp0Texture = [_device newTextureWithDescriptor:descriptor];
  id<MTLTexture> tmp1Texture = [_device newTextureWithDescriptor:descriptor];
  id<MTLTexture> blurredTexture = [_device newTextureWithDescriptor:descriptor];

  id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
  id<MTLFunction> horizontalBlur = [defaultLibrary newFunctionWithName:@"horizontalGaussianBlur"];
  id<MTLFunction> verticalBlur = [defaultLibrary newFunctionWithName:@"verticalGaussianBlur"];
  id<MTLFunction> alphaMask = [defaultLibrary newFunctionWithName:@"alphaMask"];
  
  NSError *error = nil;
  id<MTLComputePipelineState> horizontalBlurPipeline = [_device newComputePipelineStateWithFunction:horizontalBlur error:&error];
  if (!horizontalBlurPipeline) {
      NSLog(@"Failed to create compute pipeline state: %@", error);
      return;
  }
  error = nil;
  id<MTLComputePipelineState> verticalBlurPipeline = [_device newComputePipelineStateWithFunction:verticalBlur error:&error];
  if (!verticalBlurPipeline) {
      NSLog(@"Failed to create compute pipeline state: %@", error);
      return;
  }
  error = nil;
  id<MTLComputePipelineState> alphaMaskPipeline = [_device newComputePipelineStateWithFunction:alphaMask error:&error];
  if (!alphaMaskPipeline) {
      NSLog(@"Failed to create compute pipeline state: %@", error);
      return;
  }
  
  id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
  [blitCommandEncoder copyFromTexture:viewTexture toTexture:tmp0Texture];
  [blitCommandEncoder endEncoding];
  
  MTLSize threadgroupSize = MTLSizeMake(8, 8, 1);
  MTLSize threadgroupCount = MTLSizeMake((viewTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                         (viewTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                         1);
  
  id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
  float sigma = 10;
  
  [commandEncoder setComputePipelineState:horizontalBlurPipeline];
  [commandEncoder setTexture:tmp0Texture atIndex:0];
  [commandEncoder setTexture:tmp1Texture atIndex:1];
  [commandEncoder setBytes:&sigma length:sizeof(float) atIndex:0];
  [commandEncoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadgroupSize];
  [commandEncoder endEncoding];
  
  id<MTLComputeCommandEncoder> verticalEncoder = [commandBuffer computeCommandEncoder];
  [verticalEncoder setComputePipelineState:verticalBlurPipeline];
  [verticalEncoder setTexture:tmp1Texture atIndex:0];
  [verticalEncoder setTexture:blurredTexture atIndex:1];
  [verticalEncoder setBytes:&sigma length:sizeof(float) atIndex:0];
  [verticalEncoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadgroupSize];
  [verticalEncoder endEncoding];
  
  id<MTLComputeCommandEncoder> blurEncoder = [commandBuffer computeCommandEncoder];
  [blurEncoder setComputePipelineState:alphaMaskPipeline];
  [blurEncoder setTexture:blurredTexture atIndex:0];
  [blurEncoder setTexture:tmp0Texture atIndex:1];
  [blurEncoder setTexture:viewTexture atIndex:2];
  [blurEncoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadgroupSize];
  [blurEncoder endEncoding];
  
//  id<MTLBlitCommandEncoder> blitCommandEncoder2 = [commandBuffer blitCommandEncoder];
//  [blitCommandEncoder2 copyFromTexture:blurredTexture toTexture:viewTexture];
//  [blitCommandEncoder2 endEncoding];
  
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
      if (buffer.error) {
          NSLog(@"Error occurred: %@", buffer.error);
      }
  }];
  
#endif
    [commandBuffer presentDrawable:[self currentDrawable]];
    [commandBuffer commit];
//  [commandBuffer waitUntilCompleted];
  
    bool paused = [self isPaused];
    [self setEnableSetNeedsDisplay:paused];
    [self setPaused:paused];
}

- (rive::Fit)riveFit:(RiveFit)fit
{
    rive::Fit riveFit;

    switch (fit)
    {
        case fill:
            riveFit = rive::Fit::fill;
            break;
        case contain:
            riveFit = rive::Fit::contain;
            break;
        case cover:
            riveFit = rive::Fit::cover;
            break;
        case fitHeight:
            riveFit = rive::Fit::fitHeight;
            break;
        case fitWidth:
            riveFit = rive::Fit::fitWidth;
            break;
        case scaleDown:
            riveFit = rive::Fit::scaleDown;
            break;
        case noFit:
            riveFit = rive::Fit::none;
            break;
    }

    return riveFit;
}

- (rive::Alignment)riveAlignment:(RiveAlignment)alignment
{
    rive::Alignment riveAlignment = rive::Alignment::center;

    switch (alignment)
    {
        case topLeft:
            riveAlignment = rive::Alignment::topLeft;
            break;
        case topCenter:
            riveAlignment = rive::Alignment::topCenter;
            break;
        case topRight:
            riveAlignment = rive::Alignment::topRight;
            break;
        case centerLeft:
            riveAlignment = rive::Alignment::centerLeft;
            break;
        case center:
            riveAlignment = rive::Alignment::center;
            break;
        case centerRight:
            riveAlignment = rive::Alignment::centerRight;
            break;
        case bottomLeft:
            riveAlignment = rive::Alignment::bottomLeft;
            break;
        case bottomCenter:
            riveAlignment = rive::Alignment::bottomCenter;
            break;
        case bottomRight:
            riveAlignment = rive::Alignment::bottomRight;
            break;
    }

    return riveAlignment;
}

- (CGPoint)artboardLocationFromTouchLocation:(CGPoint)touchLocation
                                  inArtboard:(CGRect)artboardRect
                                         fit:(RiveFit)fit
                                   alignment:(RiveAlignment)alignment
{
    // Note, we've offset the frame by the frame.origin before
    // but in testing our touch location seems to already take this into account
    rive::AABB frame(0, 0, self.frame.size.width, self.frame.size.height);

    rive::AABB content(artboardRect.origin.x,
                       artboardRect.origin.y,
                       artboardRect.size.width + artboardRect.origin.x,
                       artboardRect.size.height + artboardRect.origin.y);

    auto riveFit = [self riveFit:fit];
    auto riveAlignment = [self riveAlignment:alignment];

    rive::Mat2D forward = rive::computeAlignment(riveFit, riveAlignment, frame, content);
    rive::Mat2D inverse = forward.invertOrIdentity();

    rive::Vec2D frameLocation(touchLocation.x, touchLocation.y);
    rive::Vec2D convertedLocation = inverse * frameLocation;

    return CGPointMake(convertedLocation.x, convertedLocation.y);
}

@end
