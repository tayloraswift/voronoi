// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
// sudo apt-get install libcairo-dev

import PackageDescription

let package = Package(
    name: "cloudgen",
    products:
    [
        .executable(name: "game", targets: ["game"])
    ],
    dependencies:
    [
        .package(url: "https://github.com/kelvin13/swift-opengl", .branch("master")),
        .package(url: "https://github.com/kelvin13/maxpng", .branch("master")),
        .package(url: "https://github.com/kelvin13/noise", .branch("master"))
    ],
    targets:
    [
        .target(name: "GLFW", path: "sources/GLFW"),
        .target(name: "CCairo", path: "sources/ccairo"),
        .target(name: "Cairo", dependencies: ["CCairo"], path: "sources/cairo"),
        .target(name: "game", dependencies: ["OpenGL", "Noise", "MaxPNG", "GLFW", "Cairo"], path: "sources/game")
    ]
)
