// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "skit",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "dos2unix", targets: ["Dos2Unix"]),
    .executable(name: "tree", targets: ["Tree"]),
  ],
  targets: [
    .target(name: "SkitSupport"),
    .executableTarget(name: "Dos2Unix", dependencies: ["SkitSupport"]),
    .executableTarget(name: "Tree", dependencies: ["SkitSupport"]),
    .testTarget(name: "Dos2UnixTests", dependencies: ["Dos2Unix"]),
    .testTarget(name: "TreeTests", dependencies: ["Tree"]),
    .testTarget(name: "SkitSupportTests", dependencies: ["SkitSupport"]),
  ]
)
