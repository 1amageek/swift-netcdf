#!/bin/bash
set -e

# Build script for netcdf-c
# This builds a minimal netCDF-3 static library without HDF5, DAP, or other dependencies
# Can be called directly or from SwiftPM Build Tool Plugin

# Determine project root (supports both direct execution and plugin execution)
if [ -n "$PROJECT_DIR" ]; then
    PROJECT_ROOT="$PROJECT_DIR"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PROJECT_ROOT="$SCRIPT_DIR/.."
fi

NETCDF_SOURCE="$PROJECT_ROOT/Sources/CNetCDF/netcdf-c"
BUILD_DIR="$PROJECT_ROOT/.build/netcdf-build"
INSTALL_DIR="$PROJECT_ROOT/Sources/CNetCDF/lib"

echo "Building netcdf-c..."
echo "Source: $NETCDF_SOURCE"
echo "Build: $BUILD_DIR"
echo "Install: $INSTALL_DIR"

# Check if library is already built and up-to-date
if [ -f "$INSTALL_DIR/lib/libnetcdf.a" ] && [ -f "$INSTALL_DIR/include/netcdf.h" ]; then
    # Check if source is newer than built library
    if [ "$NETCDF_SOURCE" -ot "$INSTALL_DIR/lib/libnetcdf.a" ]; then
        echo "netcdf-c is already built and up-to-date. Skipping build."
        exit 0
    fi
fi

# Verify CMake is available
if ! command -v cmake &> /dev/null; then
    echo "Error: cmake is not installed"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake - minimal configuration
# Explicitly disable HDF5 to avoid system dependencies
cmake "$NETCDF_SOURCE" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 \
  -DBUILD_SHARED_LIBS=OFF \
  -DNETCDF_ENABLE_NETCDF_4=OFF \
  -DNETCDF_ENABLE_HDF5=OFF \
  -DUSE_HDF5=OFF \
  -DNETCDF_ENABLE_DAP=OFF \
  -DNETCDF_ENABLE_NCZARR=OFF \
  -DNETCDF_BUILD_UTILITIES=OFF \
  -DNETCDF_ENABLE_EXAMPLES=OFF \
  -DNETCDF_ENABLE_TESTS=OFF \
  -DNETCDF_ENABLE_HDF4=OFF \
  -DNETCDF_ENABLE_BYTERANGE=OFF \
  -DNETCDF_ENABLE_PLUGINS=OFF

# Build
cmake --build . --config Release

# Install to local directory
cmake --install .

echo ""
echo "Verifying installation..."

# List of required headers
REQUIRED_HEADERS=(
    "netcdf.h"
    "netcdf_aux.h"
    "netcdf_mem.h"
    "netcdf_meta.h"
    "netcdf_filter.h"
    "netcdf_filter_build.h"
    "netcdf_filter_hdf5_build.h"
)

# Check and copy missing headers
MISSING_COUNT=0
for header in "${REQUIRED_HEADERS[@]}"; do
    if [ ! -f "$INSTALL_DIR/include/$header" ]; then
        echo "Warning: $header not installed by CMake"
        if [ -f "$NETCDF_SOURCE/include/$header" ]; then
            echo "  → Copying from source..."
            cp "$NETCDF_SOURCE/include/$header" "$INSTALL_DIR/include/"
        else
            echo "  → ERROR: Header not found in source!"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    else
        echo "✓ $header"
    fi
done

# Verify static library exists
if [ ! -f "$INSTALL_DIR/lib/libnetcdf.a" ]; then
    echo "ERROR: libnetcdf.a not found!"
    exit 1
fi
echo "✓ libnetcdf.a"

if [ $MISSING_COUNT -gt 0 ]; then
    echo ""
    echo "WARNING: $MISSING_COUNT header(s) could not be found"
    exit 1
fi

echo ""
echo "netcdf-c built successfully!"
echo "Library installed to: $INSTALL_DIR"
echo "Headers: $INSTALL_DIR/include"
echo "Static library: $INSTALL_DIR/lib/libnetcdf.a"
