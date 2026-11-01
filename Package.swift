// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Gamekeeper",
  platforms: [.macOS(.v13), .iOS(.v17)],
  products: [.library(name: "GameCore", targets: ["GameCore"])],
  targets: [
    .target(name: "GameCore"),
    .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
  ]
)
