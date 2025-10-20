// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "netcdf-swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NetCDF",
            targets: ["NetCDF"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0")
    ],
    targets: [
        .binaryTarget(
            name: "CNetCDF",
            path: "artifacts/netcdf.xcframework"
        ),
        .target(
            name: "NetCDF",
            dependencies: ["CNetCDF"]
        ),
        .testTarget(
            name: "NetCDFTests",
            dependencies: [
                "NetCDF",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
