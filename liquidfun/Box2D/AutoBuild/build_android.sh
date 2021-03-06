#!/bin/bash -eu
# Copyright (c) 2013 Google, Inc.
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 1. The origin of this software must not be misrepresented; you must not
# claim that you wrote the original software. If you use this software
# in a product, an acknowledgment in the product documentation would be
# appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
# misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#
# Build the project for Android on Linux or OSX.

declare -r project_name=LiquidFun
declare -r script_name=$(basename $0)
declare -r script_directory="$(cd "$(dirname "$0")"; pwd)"
declare -r project_root="$(cd "${script_directory}/../.."; pwd)"

# Build the project in the current working directory.
build_apk() {
  ${project_root}/Box2D/AndroidUtil/build_apk.sh DEPLOY=0 LAUNCH=0 "$@"
}

# Find all projects to build.
find_projects() {
  (
    IFS=$'\n'
    for manifest in $(find Box2D -type f -name AndroidManifest.xml | sort); do
      target_dir=$(dirname "${manifest}")
      if [[ ! -d "${target_dir}/jni" ]]; then
        continue
      fi
      echo "${target_dir}"
    done
  )
}

# Parse arguments.
build_config=release
if [[ $# -gt 0 ]]; then
  case "${1}" in
    debug|release) build_config="${1}" ;;
    *) echo "\
Build all ${project_name} libraries and applications.

Usage: $(basename $0) [build_configuration]

build_configuration: Type of build to perform.  This can be either \"debug\" or
\"release\".  If this isn't specified the build configuration defaults to
\"${build_config}\".
"
      exit 1 ;;
  esac
fi

# Enable / disable NDK_DEBUG.
ndk_debug=
if [[ "${build_config}" == "debug" ]]; then
  ndk_debug="NDK_DEBUG=1"
fi

(
  IFS=$'\n'
  # Find each NDK project in the tree and build it.
  failed_builds=
  build_failed=0
  pushd "${project_root}" >/dev/null
  projects_to_build="$(find_projects)"

  # Parallel clean is flakey on OSX, so limit the number of tasks "make" can
  # execute to 1.
  for target_dir in ${projects_to_build}; do
    pushd "${target_dir}" >/dev/null
    build_apk clean ${ndk_debug} APP_ABI=all -j1
    popd >/dev/null
  done

  # Build all projects.
  for target_dir in ${projects_to_build}; do
    pushd "${target_dir}" >/dev/null
    echo "Building ${target_dir}..." >&2
    if ! build_apk ${ndk_debug} APP_ABI=all; then
      failed_builds="${failed_builds} ${target_dir}"
      build_failed=1
    fi
    popd >/dev/null
  done

  popd >/dev/null
  # Display a list of projects that failed to build.
  if [[ "${failed_builds}" != "" ]]; then
    echo "ERROR: One or more projects failed to build:" >&2
    IFS=' '
    for failed in ${failed_builds}; do
      echo "  ${failed}" >&2
    done
  fi
  exit ${build_failed}
)
