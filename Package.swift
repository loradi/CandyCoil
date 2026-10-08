// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CandyCoilCore", platforms: [.macOS(.v13)], products: [.library(name: "CandyCoilCore", targets: ["CandyCoilCore"])], targets: [.target(name: "CandyCoilCore", path: "CandyCoil/Core"), .testTarget(name: "CandyCoilTests", dependencies: ["CandyCoilCore"], path: "Tests")])
