#!/bin/bash
set -euo pipefail

# Build netcdf-c for macOS (universal) and iOS (arm64) and bundle as an XCFramework.
# Set SKIP_IOS=1 if you want to omit the iOS slice.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
NETCDF_SRC="${PROJECT_ROOT}/Sources/CNetCDF/netcdf-c"
OUTPUT_DIR="${PROJECT_ROOT}/artifacts"
MAC_BUILD_DIR="${PROJECT_ROOT}/.build/netcdf-macos"
MAC_STAGE_DIR="${MAC_BUILD_DIR}/stage"
IOS_BUILD_DIR="${PROJECT_ROOT}/.build/netcdf-ios"
IOS_STAGE_DIR="${IOS_BUILD_DIR}/stage"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/netcdf.xcframework"
SKIP_IOS=${SKIP_IOS:-0}

rm -rf "${OUTPUT_DIR}" "${MAC_BUILD_DIR}" "${IOS_BUILD_DIR}" "${XCFRAMEWORK_PATH}"
mkdir -p "${OUTPUT_DIR}" "${MAC_BUILD_DIR}" "${MAC_STAGE_DIR}/lib" "${MAC_STAGE_DIR}/include"

common_flags=(
  -DBUILD_SHARED_LIBS=OFF
  -DNETCDF_ENABLE_NETCDF_4=OFF
  -DNETCDF_ENABLE_HDF5=OFF
  -DNETCDF_ENABLE_DAP=OFF
  -DNETCDF_ENABLE_NCZARR=OFF
  -DNETCDF_ENABLE_BYTERANGE=OFF
  -DNETCDF_ENABLE_HDF4=OFF
  -DNETCDF_BUILD_UTILITIES=OFF
  -DNETCDF_ENABLE_TESTS=OFF
  -DNETCDF_ENABLE_PLUGINS=OFF
  -DCMAKE_DISABLE_FIND_PACKAGE_HDF5=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_HDF4=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_SZIP=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_ZSTD=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_BZip2=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_LIBXML2=ON
  -DENABLE_DOCS=OFF
  -DNETCDF_BUILD_DOCS=OFF
)

force_c_flags="-UHAVE_SNPRINTF -UHAVE_STRLCPY -UHAVE_STRLCAT -UHAVE_STDDEF_H -DHAVE_SNPRINTF=1 -DHAVE_STRLCPY=1 -DHAVE_STRLCAT=1 -DHAVE_STDDEF_H=1"

sync_headers() {
  rsync -a "$1/" "$2/" >/dev/null 2>&1 || true
}

# macOS universal build
cmake -S "${NETCDF_SRC}" -B "${MAC_BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_C_FLAGS="${force_c_flags}" \
  "${common_flags[@]}"
cmake --build "${MAC_BUILD_DIR}" --target netcdf --config Release
cp "${MAC_BUILD_DIR}/libnetcdf.a" "${MAC_STAGE_DIR}/lib/"
if [ -d "${MAC_BUILD_DIR}/include" ]; then
  sync_headers "${MAC_BUILD_DIR}/include" "${MAC_STAGE_DIR}/include"
fi
sync_headers "${NETCDF_SRC}/include" "${MAC_STAGE_DIR}/include"

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

create_module_map "${MAC_STAGE_DIR}/include"

libraries=( "${MAC_STAGE_DIR}/lib/libnetcdf.a" )
headers=( "${MAC_STAGE_DIR}/include" )

if [[ ${SKIP_IOS} != 1 ]]; then
  if xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    mkdir -p "${IOS_BUILD_DIR}" "${IOS_STAGE_DIR}/lib" "${IOS_STAGE_DIR}/include"
    cmake -S "${NETCDF_SRC}" -B "${IOS_BUILD_DIR}" \
      -GXcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
      -DCMAKE_C_FLAGS="${force_c_flags}" \
      "${common_flags[@]}"
    cmake --build "${IOS_BUILD_DIR}" --target netcdf --config Release -- -sdk iphoneos
    if [ -f "${IOS_BUILD_DIR}/Release-iphoneos/libnetcdf.a" ]; then
      cp "${IOS_BUILD_DIR}/Release-iphoneos/libnetcdf.a" "${IOS_STAGE_DIR}/lib/"
    else
      cp "${IOS_BUILD_DIR}/libnetcdf.a" "${IOS_STAGE_DIR}/lib/"
    fi
    if [ -d "${IOS_BUILD_DIR}/include" ]; then
      sync_headers "${IOS_BUILD_DIR}/include" "${IOS_STAGE_DIR}/include"
    fi
    sync_headers "${NETCDF_SRC}/include" "${IOS_STAGE_DIR}/include"
    create_module_map "${IOS_STAGE_DIR}/include"
    libraries+=( "${IOS_STAGE_DIR}/lib/libnetcdf.a" )
    headers+=( "${IOS_STAGE_DIR}/include" )
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
