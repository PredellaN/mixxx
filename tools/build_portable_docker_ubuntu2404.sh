#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export TARGET_DISTRO="ubuntu-24.04"
export DISTRO_LABEL="Ubuntu 24.04"
export IMAGE_NAME="mixxx-builder-ubuntu-24.04:latest"
export DOCKERFILE="$SCRIPT_DIR/docker/Dockerfile.ubuntu2404"
export BUILD_DIR_NAME="build-ubuntu-2404"

exec "$SCRIPT_DIR/build_portable_docker_common.sh" "$@"
