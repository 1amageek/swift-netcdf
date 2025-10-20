#!/bin/bash
set -euo pipefail

# Build netcdf-c for macOS (universal). Optionally build an iOS slice when ENABLE_IOS=1.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
NETCDF_SRC="${PROJECT_ROOT}/Sources/CNetCDF/netcdf-c"
OUTPUT_DIR="${PROJECT_ROOT}/artifacts"
MAC_BUILD_DIR="${PROJECT_ROOT}/.build/netcdf-macos"
IOS_BUILD_DIR="${PROJECT_ROOT}/.build/netcdf-ios"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/netcdf.xcframework"
ENABLE_IOS=${ENABLE_IOS:-0}

rm -rf "${OUTPUT_DIR}" "${MAC_BUILD_DIR}" "${IOS_BUILD_DIR}" "${XCFRAMEWORK_PATH}"
mkdir -p "${OUTPUT_DIR}" "${MAC_BUILD_DIR}"

common_flags=(
  -DBUILD_SHARED_LIBS=OFF
  -DENABLE_NETCDF_4=OFF
  -DENABLE_HDF5=OFF
  -DENABLE_DAP=OFF
  -DENABLE_NCZARR=OFF
  -DENABLE_BYTERANGE=OFF
  -DENABLE_HDF4=OFF
  -DNETCDF_BUILD_UTILITIES=OFF
  -DNETCDF_ENABLE_TESTS=OFF
  -DNETCDF_ENABLE_PLUGINS=OFF
  -DCMAKE_DISABLE_FIND_PACKAGE_HDF5=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_HDF4=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=ON
)

force_c_flags="-UHAVE_SNPRINTF -UHAVE_STRLCPY -UHAVE_STRLCAT -UHAVE_STDDEF_H -DHAVE_SNPRINTF=1 -DHAVE_STRLCPY=1 -DHAVE_STRLCAT=1 -DHAVE_STDDEF_H=1"

# macOS universal build
cmake -S "${NETCDF_SRC}" -B "${MAC_BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_C_FLAGS="${force_c_flags}" \
  "${common_flags[@]}"
cmake --build "${MAC_BUILD_DIR}" --target netcdf --config Release
cmake --install "${MAC_BUILD_DIR}" --component netCDF --config Release --prefix "${MAC_BUILD_DIR}/install"

create_module_map() {
  local include_dir=$1
  mkdir -p "${include_dir}"
  cat >"${include_dir}/module.modulemap" <<'MAP'
module CNetCDF [system] {
  header "netcdf.h"
  export *
  link "netcdf"
}
MAP
}

create_module_map "${MAC_BUILD_DIR}/install/include"

libraries=( "${MAC_BUILD_DIR}/install/lib/libnetcdf.a" )
headers=( "${MAC_BUILD_DIR}/install/include" )

if [[ ${ENABLE_IOS} == 1 ]]; then
  if xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    mkdir -p "${IOS_BUILD_DIR}"
    cmake -S "${NETCDF_SRC}" -B "${IOS_BUILD_DIR}" \
      -GXcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
      -DCMAKE_C_FLAGS="${force_c_flags}" \
      "${common_flags[@]}"
    cmake --build "${IOS_BUILD_DIR}" --target netcdf --config Release -- -sdk iphoneos
    cmake --install "${IOS_BUILD_DIR}" --component netCDF --config Release --prefix "${IOS_BUILD_DIR}/install"
    create_module_map "${IOS_BUILD_DIR}/install/include"
    libraries+=( "${IOS_BUILD_DIR}/install/lib/libnetcdf.a" )
    headers+=( "${IOS_BUILD_DIR}/install/include" )
  else
    echo "iphoneos SDK not found; skipping iOS slice"
  fi
fi

xc_args=()
for idx in "${!libraries[@]}"; do
  xc_args+=( -library "${libraries[$idx]}" -headers "${headers[$idx]}" )
done

xcodebuild -create-xcframework "${xc_args[@]}" -output "${XCFRAMEWORK_PATH}"

echo "XCFramework created: ${XCFRAMEWORK_PATH}"
