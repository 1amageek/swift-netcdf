# swift-netcdf

Swift bindings for the [netCDF](https://www.unidata.ucar.edu/software/netcdf/) scientific data format, packaged as a SwiftPM library with a prebuilt C shim for macOS and iOS. The package exposes Swift-friendly APIs while preserving the terminology used by the underlying C library.

## Features
- Swift-native wrapper around the netCDF C API with type-safe error handling.
- Ships a universal `.xcframework` so consumers can link without rebuilding netCDF locally.
- Unified build and test scripts that match continuous-integration workflows.

## Prerequisites
- Xcode 15 or newer with macOS SDK; optional iOS SDK required for iOS slices.
- Swift 5.9 toolchain (included with Xcode 15).
- `git` with submodule support.

## Repository Layout
- `Sources/NetCDF`: Public Swift targets—extend these to add functionality.
- `Sources/CNetCDF/netcdf-c`: Vendored upstream C sources (git submodule), used only when regenerating binaries.
- `artifacts/netcdf.xcframework`: Prebuilt C shim consumed by SwiftPM.
- `Tests/NetCDFTests`: Swift Testing suites covering positive and failure paths.

## Getting Started
```sh
# Clone and hydrate submodule
git clone https://github.com/<org>/swift-netcdf.git
cd swift-netcdf
git submodule update --init --recursive

# Build the universal xcframework (macOS + iOS)
./scripts/build-netcdf-xcframework.sh

# Build and test the Swift package
swift build
swift test --enable-code-coverage
```
Set `SKIP_IOS=1` if building on a host without iOS SDK support.

## Using the Package
Add swift-netcdf as a dependency in `Package.swift`:
```swift
.package(url: "https://github.com/<org>/swift-netcdf.git", branch: "main")
```
Then import and open datasets:
```swift
import NetCDF

let dataset = try NetCDFFile(path: "climate.nc", mode: .read)
print(dataset.dimensionCount)
```

## Rebuilding & Releases
- Use the "Build netCDF XCFramework" GitHub workflow to regenerate release artifacts.
- Update `Package.swift` with the new `.binaryTarget` URL and checksum, and commit both source and checksum together.
- Validate artifacts locally with `shasum -a 256 netcdf.xcframework.zip` before publishing.

## Contributing
Follow the guidance in `AGENTS.md` for coding style, testing expectations, and pull-request etiquette. Bug reports and feature ideas are welcome via GitHub issues.
