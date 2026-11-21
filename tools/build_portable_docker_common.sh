#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
MIXXX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DISTRO="${TARGET_DISTRO:-ubuntu-24.04}"
DISTRO_LABEL="${DISTRO_LABEL:-Ubuntu 24.04}"
IMAGE_NAME="${IMAGE_NAME:-mixxx-builder-ubuntu-24.04:latest}"
DOCKERFILE="${DOCKERFILE:-$SCRIPT_DIR/docker/Dockerfile.ubuntu2404}"
BUILD_DIR_NAME="${BUILD_DIR_NAME:-build-ubuntu-2404}"
BUILD_DIR="$MIXXX_ROOT/$BUILD_DIR_NAME"

echo "=========================================================="
echo " Mixxx Standalone $DISTRO_LABEL Portable Package Builder"
echo "=========================================================="
echo "Mixxx Root: $MIXXX_ROOT"
echo "Build Dir:  $BUILD_DIR"

# Check Docker availability
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: 'docker' command not found. Please install Docker." >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running or user lacks permission." >&2
    echo "Try running 'sudo usermod -aG docker \$USER' or starting dockerd." >&2
    exit 1
fi

REBUILD_IMAGE=false
CLEAN_BUILD=false
PACKAGE_FORMAT="both"
OPTIMIZE_MODE="portable"
BUILD_TYPE="Release"
JOBS="${BUILD_JOBS:-$(nproc)}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild-image)
            REBUILD_IMAGE=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --tarball-only)
            PACKAGE_FORMAT="tarball"
            shift
            ;;
        --appimage-only)
            PACKAGE_FORMAT="appimage"
            shift
            ;;
        --native)
            OPTIMIZE_MODE="native"
            shift
            ;;
        --debug)
            BUILD_TYPE="RelWithDebInfo"
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --tarball-only    Build only the standalone portable .tar.gz"
            echo "  --appimage-only   Build only the standalone .AppImage"
            echo "  --native          Optimize for the host CPU architecture (-march=native)"
            echo "  --clean           Clean previous build directory before building"
            echo "  --rebuild-image   Force rebuild of the builder Docker image"
            echo "  --debug           Build with RelWithDebInfo instead of Release"
            echo "  -j, --jobs N      Specify number of parallel compile jobs (default: all cores)"
            echo "  --help, -h        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
    esac
done

if [ "$CLEAN_BUILD" = true ]; then
    echo "--> Cleaning previous build directory ($BUILD_DIR)..."
    rm -rf "$BUILD_DIR/build" "$BUILD_DIR/staging" "$BUILD_DIR/output"
fi

mkdir -p "$BUILD_DIR/ccache"
mkdir -p "$BUILD_DIR/output"

# Check if docker image exists or rebuild requested
if [ "$REBUILD_IMAGE" = true ] || ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "--> Building Docker image '$IMAGE_NAME' from $DOCKERFILE..."
    docker build -t "$IMAGE_NAME" -f "$DOCKERFILE" "$SCRIPT_DIR/docker"
else
    echo "--> Using Docker image '$IMAGE_NAME' (pass --rebuild-image to rebuild)"
fi

echo "--> Launching build inside $DISTRO_LABEL container..."
INTERACTIVE_FLAGS=""
if [ -t 0 ] && [ -t 1 ]; then
    INTERACTIVE_FLAGS="-it"
fi

docker run --rm $INTERACTIVE_FLAGS \
    -v "$MIXXX_ROOT:/workspace/mixxx:z" \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -e TARGET_DISTRO="$TARGET_DISTRO" \
    -e DISTRO_LABEL="$DISTRO_LABEL" \
    -e BUILD_DIR="/workspace/mixxx/$BUILD_DIR_NAME/build" \
    -e OUTPUT_DIR="/workspace/mixxx/$BUILD_DIR_NAME/output" \
    -e STAGING_DIR="/workspace/mixxx/$BUILD_DIR_NAME/staging" \
    -e CCACHE_DIR="/workspace/mixxx/$BUILD_DIR_NAME/ccache" \
    -e BUILD_JOBS="$JOBS" \
    -e BUILD_TYPE="$BUILD_TYPE" \
    -e OPTIMIZE_MODE="$OPTIMIZE_MODE" \
    -e PACKAGE_FORMAT="$PACKAGE_FORMAT" \
    "$IMAGE_NAME" \
    /workspace/mixxx/tools/docker/build_portable_inside_docker.sh

echo ""
echo "=========================================================="
echo " Build & Packaging Complete!"
echo "=========================================================="
echo "Artifacts located in: $BUILD_DIR/output"
if [ "$PACKAGE_FORMAT" = "both" ] || [ "$PACKAGE_FORMAT" = "tarball" ]; then
    echo " Tarball:  $BUILD_DIR/output/Mixxx-x86_64-$TARGET_DISTRO.tar.gz"
    echo "   To extract & run:"
    echo "     tar -xzf $BUILD_DIR/output/Mixxx-x86_64-$TARGET_DISTRO.tar.gz"
    echo "     ./Mixxx-portable/mixxx.sh"
fi
if [ "$PACKAGE_FORMAT" = "both" ] || [ "$PACKAGE_FORMAT" = "appimage" ]; then
    echo " AppImage: $BUILD_DIR/output/Mixxx-x86_64-$TARGET_DISTRO.AppImage"
    echo "   To run:"
    echo "     chmod +x $BUILD_DIR/output/Mixxx-x86_64-$TARGET_DISTRO.AppImage"
    echo "     $BUILD_DIR/output/Mixxx-x86_64-$TARGET_DISTRO.AppImage"
fi
echo "=========================================================="
