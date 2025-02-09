#!/usr/bin/env bash

set -o errexit
set -o pipefail

set -o igncr # Ignore CR in this script for Windows compatibility.

# shellcheck source=.evergreen/scripts/env-var-utils.sh
. "$(dirname "${BASH_SOURCE[0]}")/env-var-utils.sh"

check_var_opt BYPASS_FIND_CMAKE "OFF"
check_var_opt C_STD_VERSION # CMake default: 99.
check_var_opt CC "Visual Studio 15 2017 Win64"
check_var_opt COMPILE_LIBMONGOCRYPT "OFF"
check_var_opt DEBUG "OFF"
check_var_opt EXTRA_CONFIGURE_FLAGS
check_var_opt RELEASE "OFF"
check_var_opt SASL "SSPI"   # CMake default: AUTO.
check_var_opt SNAPPY        # CMake default: AUTO.
check_var_opt SRV           # CMake default: AUTO.
check_var_opt SSL "WINDOWS" # CMake default: OFF.
check_var_opt ZSTD          # CMake default: AUTO.

declare script_dir
script_dir="$(to_absolute "$(dirname "${BASH_SOURCE[0]}")")"

declare mongoc_dir
mongoc_dir="$(to_absolute "${script_dir}/../..")"

declare -a configure_flags

configure_flags_append() {
  configure_flags+=("${@:?}")
}

configure_flags_append_if_not_null() {
  declare var="${1:?}"
  if [[ -n "${!var:-}" ]]; then
    shift
    configure_flags+=("${@:?}")
  fi
}

declare install_dir="${mongoc_dir}/install-dir"

configure_flags_append "-DCMAKE_INSTALL_PREFIX=$(to_windows_path "${install_dir}")"
configure_flags_append "-DCMAKE_PREFIX_PATH=$(to_windows_path "${install_dir}")"
configure_flags_append "-DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF"
configure_flags_append "-DENABLE_BSON=ON"
configure_flags_append "-DENABLE_MAINTAINER_FLAGS=ON"

if [[ "${RELEASE}" == "ON" ]]; then
  # Build from the release tarball.
  mkdir build-dir
  tar xf ../mongoc.tar.gz -C build-dir --strip-components=1
  cd build-dir
fi

configure_flags_append_if_not_null C_STD_VERSION "-DCMAKE_C_STANDARD=${C_STD_VERSION}"
configure_flags_append_if_not_null SASL "-DENABLE_SASL=${SASL}"
configure_flags_append_if_not_null SNAPPY "-DENABLE_SNAPPY=${SNAPPY}"
configure_flags_append_if_not_null SRV "-DENABLE_SRV=${SRV}"
configure_flags_append_if_not_null ZLIB "-DENABLE_ZLIB=${ZLIB}"

if [[ "${DEBUG}" == "ON" ]]; then
  configure_flags_append "-DCMAKE_BUILD_TYPE=Debug"
else
  configure_flags_append "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
fi

if [ "${SSL}" == "OPENSSL_STATIC" ]; then
  configure_flags_append "-DENABLE_SSL=OPENSSL" "-DOPENSSL_USE_STATIC_LIBS=ON"
else
  configure_flags_append "-DENABLE_SSL=${SSL}"
fi

declare -a extra_configure_flags
IFS=' ' read -ra extra_configure_flags <<<"${EXTRA_CONFIGURE_FLAGS:-}"

if [[ "${CC}" =~ mingw ]]; then
  # MinGW has trouble compiling src/cpp-check.cpp without some assistance.
  configure_flags_append "-DCMAKE_CXX_STANDARD=11"

  env \
    CONFIGURE_FLAGS="${configure_flags[*]} ${extra_configure_flags[*]}" \
    INSTALL_DIR="${install_dir}" \
    NJOBS="$(nproc)" \
    cmd.exe /c "$(to_windows_path "${script_dir}/compile-windows-mingw.bat")"
  exit
fi

declare build_config

if [[ "${RELEASE}" == "ON" ]]; then
  build_config="RelWithDebInfo"
else
  build_config="Debug"
  configure_flags_append "-DENABLE_DEBUG_ASSERTIONS=ON"
fi

declare cmake_binary
if [[ "${BYPASS_FIND_CMAKE}" == "OFF" ]]; then
  # shellcheck source=.evergreen/scripts/find-cmake-version.sh
  . "${script_dir}/find-cmake-latest.sh"

  cmake_binary="$(find_cmake_latest)"
else
  cmake_binary="cmake"
fi

"${cmake_binary:?}" --version

declare compile_flags=(
  "/m" # Number of concurrent processes. No value=# of cpus
)

if [ "${COMPILE_LIBMONGOCRYPT}" = "ON" ]; then
  echo "Installing libmongocrypt..."
  # shellcheck source=.evergreen/scripts/compile-libmongocrypt.sh
  "${script_dir}/compile-libmongocrypt.sh" "${cmake_binary}" "$(to_windows_path "${mongoc_dir}")" "${install_dir}" >/dev/null
  echo "Installing libmongocrypt... done."

  # Fail if the C driver is unable to find the installed libmongocrypt.
  configure_flags_append "-DENABLE_CLIENT_SIDE_ENCRYPTION=ON"
fi

"${cmake_binary}" -G "$CC" "${configure_flags[@]}" "${extra_configure_flags[@]}"
"${cmake_binary}" --build . --target ALL_BUILD --config "${build_config}" -- "${compile_flags[@]}"
"${cmake_binary}" --build . --target INSTALL --config "${build_config}" -- "${compile_flags[@]}"
