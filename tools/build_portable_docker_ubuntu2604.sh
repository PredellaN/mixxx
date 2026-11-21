#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export TARGET_DISTRO="ubuntu-26.04"
export DISTRO_LABEL="Ubuntu 26.04"
export IMAGE_NAME="mixxx-builder-ubuntu-26.04:latest"
export DOCKERFILE="$SCRIPT_DIR/docker/Dockerfile.ubuntu2604"
export BUILD_DIR_NAME="build-ubuntu-2604"

exec "$SCRIPT_DIR/build_portable_docker_common.sh" "$@"
