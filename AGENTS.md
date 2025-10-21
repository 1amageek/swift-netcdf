# Repository Guidelines

## Project Structure & Module Organization
- `Sources/NetCDF`: Swift-facing API surface; extend types cautiously to mirror netCDF terminology.
- `Sources/CNetCDF/netcdf-c`: git submodule of upstream C sources, only used when rebuilding the binary bundle.
- `artifacts/netcdf.xcframework`: prebuilt C wrapper consumed by SwiftPM; required before `swift build` runs.
- `Tests/NetCDFTests`: Swift Testing suites covering success/failure paths; keep fixtures temporary.

## Build, Test, and Development Commands
- `git submodule update --init --recursive` — sync the vendored netCDF-C sources after cloning or when upstream revs.
- `./scripts/build-netcdf-xcframework.sh` — produce macOS (arm64+x86_64) and iOS (arm64) slices; export `SKIP_IOS=1` on hosts without iOS SDKs.
- `swift build` / `swift build -v` — compile the Swift wrapper; use verbose mode when diagnosing module maps or linker issues.
- `swift test` / `swift test --enable-code-coverage` — execute Swift Testing suites and capture coverage before pushing.

## Coding Style & Naming Conventions
- Indent with four spaces; keep public APIs documented with `///` explaining netCDF semantics and parameters.
- Types stay UpperCamelCase (e.g. `NetCDFFile`), members lowerCamelCase (e.g. `dimensionCount`), and maintain visible C vocabulary.
- Group related declarations with `// MARK:` sparingly; prefer readable extensions over long files.

## Testing Guidelines
- Author suites with the `Testing` package (`@Suite`, `@Test("Describe behaviour")`); prefer descriptive strings to issue numbers.
- Use temporary directories for sample files and close resources explicitly to avoid file descriptor leaks.
- Add regression tests for both positive results and expected errors whenever C interop changes.

## Release & Binary Management
- Run the "Build netCDF XCFramework" workflow to regenerate `netcdf.xcframework.zip` and its `.sha256`; attach both to the release.
- Update the `.binaryTarget` URL and checksum in `Package.swift`, committing the checksum in the same change set.
- Validate the archive locally with `shasum -a 256 netcdf.xcframework.zip` before publishing.

## Commit & Pull Request Guidelines
- Write imperative, scope-limited commits (e.g. `Add NetCDF dimension helpers`) and avoid bundling unrelated edits.
- Reference the workflow run when regenerating the XCFramework and note any manual steps reviewers must repeat.
- Include test evidence (`swift test`, coverage output, or CI link) and link relevant issues or discussions.
