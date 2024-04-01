//
//  StressTest.swift
//  RiveExample
//
//  Created by Chris Dalton on 1/30/23.
//  Copyright © 2023 Rive. All rights reserved.
//

import UIKit
import RiveRuntime
import SwiftUI

// Example to test drawing multiple times within a single view
class StressTestViewController: UIViewController {
    var viewModel: RiveViewModel?
    var rView: CustomRiveView?

    @objc func onTap(_ sender:UITapGestureRecognizer) {
        if let riveView = rView {
            riveView.drawRepeat += 3;
            self.title = "Stress Test (x\(riveView.drawRepeat))"
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        let rModel = try! RiveModel(fileName: "marty", extension: ".riv", in: .main)
        rView = CustomRiveView(model: rModel, autoPlay: true)
        viewModel = RiveViewModel(rModel, animationName: "Animation2")
        viewModel!.fit = RiveFit.contain
        viewModel!.setView(rView!)
        view.addSubview(rView!)
        let f = view.frame
        let h = UIApplication.shared.statusBarFrame.height + 40
        rView!.frame = CGRect(x:f.minX, y:f.minY + h, width:f.width, height:f.height - h)

        let gesture = UITapGestureRecognizer(target: self, action:  #selector (self.onTap (_:)))
        rView!.addGestureRecognizer(gesture)

        rView!.showFPS = true
    }
}

// New RiveView that overrides the drawing logic to re-draw the view multiple times.
class CustomRiveView: RiveView {
    private var rModel: RiveModel?
    public var drawRepeat: Int32 = 10
    init(model: RiveModel, autoPlay: Bool = true) {
        super.init()
        rModel = model
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    override func drawRive(_ rect: CGRect, size: CGSize) {
        // This prevents breaking when loading RiveFile async
        guard let artboard = rModel?.artboard else { return }
        
        let newFrame = CGRect(origin: rect.origin, size: size)
        align(with: newFrame, contentRect: artboard.bounds(), alignment: .center, fit: .contain)
        
        let pad:Float = 100.0
        let r = min(drawRepeat, 8)
        let x0:Float = Float(r - 1) * 0.5 * -pad
        var x:Float = x0
        var y:Float = -pad * 4
        for i in 1...drawRepeat {
          // 0x111
            if (i & 0x7) == 0 {
                y += pad
                x = x0
            }
            save()
            transform(1, xy:0, yx:0, yy:1, tx:x, ty:y);
            draw(with: artboard)
            
            restore()
            x += pad
        }
    }
}

enum BlurClipError: Error {
  case missingTexture
  case missingDefaultLibrary
  case couldntMakeFunction
  case couldntMakeBlitEncoder
  case couldntMakeComputeEncoder
  case couldntCreateTexture
}
class BlurClipRiveView: RiveView {
  override open func postprocess(_ commandBuffer: MTLCommandBuffer, on device: MTLDevice) {
    /// Generates a Gaussian blur kernel.
    /// - Parameter radius: The radius of the blur.
    /// - Returns: An array of kernel values, with the center value being the peak.
    func gaussianBlurKernel(radius: Int) -> [Float] {
        let diameter = 2 * radius + 1
        let sigma = 0.3 * Float(radius - 1) + 0.8
        var kernel = [Float](repeating: 0, count: diameter)
        var sum: Float = 0
        
        for i in 0..<diameter {
            let x = Float(i - radius)
            let exponent = -(x*x) / (2 * sigma * sigma)
            kernel[i] = exp(exponent) / (sqrt(2 * .pi) * sigma)
            sum += kernel[i]
        }
        
        // Normalize the kernel values
        for i in 0..<diameter {
            kernel[i] /= sum
        }
        
        return kernel
    }
    
    do {
      guard let viewTexture = self.currentDrawable?.texture else {
        throw BlurClipError.missingTexture
      }
      
      let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: viewTexture.pixelFormat, width: viewTexture.width, height: viewTexture.height, mipmapped: false)
      textureDescriptor.usage = .shaderWrite.union(.shaderRead)
      
      guard let tmp0 = device.makeTexture(descriptor: textureDescriptor),
            let tmp1 = device.makeTexture(descriptor: textureDescriptor),
            let blurred = device.makeTexture(descriptor: textureDescriptor) else {
        throw BlurClipError.couldntCreateTexture
      }
      
      guard let defaultLibrary = device.makeDefaultLibrary() else {
        throw BlurClipError.missingDefaultLibrary
      }
      guard let horizontalBlur = defaultLibrary.makeFunction(name: "horizontalGaussianBlur"),
            let verticalBlur = defaultLibrary.makeFunction(name: "verticalGaussianBlur"),
            let alphaMask = defaultLibrary.makeFunction(name: "alphaMask") else {
        throw BlurClipError.couldntMakeFunction
      }
      
      let horizontalBlurPipeline = try device.makeComputePipelineState(function: horizontalBlur)
      let verticalBlurPipeline = try device.makeComputePipelineState(function: verticalBlur)
      let alphaMaskPipeline = try device.makeComputePipelineState(function: alphaMask)
      
      guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
        throw BlurClipError.couldntMakeBlitEncoder
      }
      blitEncoder.copy(from: viewTexture, to: tmp0)
      blitEncoder.endEncoding()
      
      let threadgroupSize = MTLSizeMake(8, 8, 1)
      let threadgroupCount = MTLSizeMake((viewTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                         (viewTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                         1);
      
      var radius: Int = 25
      let blurKernel = gaussianBlurKernel(radius: radius)
      let blurBuffer = device.makeBuffer(bytes: blurKernel, length: blurKernel.count * MemoryLayout<Float>.stride)
      do {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
          throw BlurClipError.couldntMakeComputeEncoder
        }
        encoder.setComputePipelineState(horizontalBlurPipeline)
        encoder.setTexture(tmp0, index: 0)
        encoder.setTexture(tmp1, index: 1)
        encoder.setBytes(&radius, length: MemoryLayout<Int>.size, index: 0)
        encoder.setBuffer(blurBuffer, offset: 0, index: 1)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
      }
      
      do {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
          throw BlurClipError.couldntMakeComputeEncoder
        }
        encoder.setComputePipelineState(verticalBlurPipeline)
        encoder.setTexture(tmp1, index: 0)
        encoder.setTexture(blurred, index: 1)
        encoder.setBytes(&radius, length: MemoryLayout<Int>.size, index: 0)
        encoder.setBuffer(blurBuffer, offset: 0, index: 1)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
      }
      
      do {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
          throw BlurClipError.couldntMakeComputeEncoder
        }
        encoder.setComputePipelineState(alphaMaskPipeline)
        encoder.setTexture(blurred, index: 0)
        encoder.setTexture(tmp0, index: 1)
        encoder.setTexture(viewTexture, index: 2)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
      }
      
      //    guard let blitEncoder2 = commandBuffer.makeBlitCommandEncoder() else {
      //      throw BlurClipError.couldntMakeBlitEncoder
      //    }
      //    blitEncoder2.copy(from: blurred, to: viewTexture)
      //    blitEncoder2.endEncoding()
      
      commandBuffer.addCompletedHandler { buffer in
        if let error = buffer.error {
          print("Error running postprocessing command buffer \(error)")
        }
      }
    } catch {
      print("error in postprocessing: \(error)")
    }
  }
}
