// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swift-async-broadcaster",
  platforms: [.iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
  products: [
    .library(
      name: "AsyncBroadcaster",
      targets: ["AsyncBroadcaster"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-collections",
      from: "1.1.4"
    ),
    .package(
      url: "https://github.com/apple/swift-async-algorithms",
      from: "1.0.3"
    ),
  ],
  targets: [
    .target(
      name: "AsyncBroadcaster",
      dependencies: [
        .product(name: "DequeModule", package: "swift-collections"),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      ]
    ),
    .testTarget(
      name: "AsyncBroadcasterTests",
      dependencies: ["AsyncBroadcaster"]
    ),
  ]
)
