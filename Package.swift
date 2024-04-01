// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "RiveRuntime",
  platforms: [.iOS("14.0"), .macOS("13.1")],
  products: [
    .library(
      name: "RiveRuntime",
      targets: ["RiveRuntime"])
  ],
  targets: [
    .binaryTarget(
      name: "RiveRuntime",
      url:
        "https://github.com/picotopia/rive-ios/releases/download/blurclip-0.0.1/RiveRuntime.xcframework.zip",
      checksum: "a10d464a57f4982fbbc6c989ab35615e34c9566cac94bedb34120c9683b1d8ad"
    )
  ]
)
