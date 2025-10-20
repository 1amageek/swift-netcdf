# Repository Guidelines

## Project Structure & Module Organization
netcdf-swift ships a Swift wrapper target in `Sources/NetCDF`. The upstream C sources live as a git submodule under `Sources/CNetCDF/netcdf-c` purely for building release artifacts; the Swift package itself links against a prebuilt `CNetCDF` `.xcframework` placed in `artifacts/`. Tests reside in `Tests/NetCDFTests` and use Swift Testing.

## Build, Test, and Development Commands
Run `git submodule update --init --recursive` after cloning so the netCDF-C sources are present. Use `./scripts/build-netcdf-xcframework.sh` to generate `artifacts/netcdf.xcframework` locally—`swift build` expects that bundle to exist. Set `ENABLE_IOS=1` if you also need an iOS slice (the GitHub Actions workflow runs with the default macOS-only slice). For iterative Swift work run `swift build`, add `-v` when you need verbose logging, and run `swift test` (optionally `--enable-code-coverage`) to execute the Swift Testing suite.

## Coding Style & Naming Conventions
Follow the Swift API Design Guidelines: UpperCamelCase types, lowerCamelCase members, and doc comments (`///`) for every public symbol to capture NetCDF semantics. Keep C terminology visible in Swift names (`NetCDFFile`, `dimensionCount`). Indent with four spaces and group related members using `// MARK:` sparingly for readability.

## Testing Guidelines
Tests use the `Testing` package (`@Suite`, `@Test`). Describe the behaviour under test in the attribute string (`@Test("Open NetCDF file for reading")`) and use temporary files for fixtures. Every change impacting C interop should add or update tests that cover both success and failure paths. Run `swift test` before any PR; CI will rebuild the XCFramework and run the same suite.

## Release & Binary Management
When preparing a release, trigger the `Build netCDF XCFramework` workflow (manually or by pushing a tag). Download the produced `netcdf.xcframework.zip` and `.sha256`, attach them to the GitHub Release, and update `Package.swift` so the `.binaryTarget` points to the new URL and checksum. Commit the updated checksum alongside any Swift source changes.

## Commit & Pull Request Guidelines
Write imperative, focused commits (`Add NetCDF dimension helpers`). If your change requires a regenerated XCFramework, mention the workflow run and resulting checksum in the PR description. Always include test evidence (command output or CI link) and call out any manual steps reviewers must perform.
