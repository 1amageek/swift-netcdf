// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-netcdf",
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
                "NetCDF"
            ]
        )
    ]
)
