#!/bin/bash
# This script works with Fedora. While not tested, it may also work with its
# derivatives (CentOS, RHEL) or even other RPM-based distros, contributions
# fixing any deviations in package naming are welcome here.
# shellcheck disable=SC1091
set -o pipefail

case "$1" in
    name)
        echo "No build environment name required for RPM-based distros." >&2
        echo "This script installs the build dependencies via dnf using the \"setup\" option." >&2
        ;;

    setup)
        SUDO_CMD="sudo"
        if [ "$EUID" -ne 0 ]; then
            if ! sudo -n true 2>/dev/null && command -v pkexec >/dev/null 2>&1; then
                SUDO_CMD="pkexec"
            fi
        else
            SUDO_CMD=""
        fi

        if grep -qP '^NAME=.*Fedora.*' /etc/os-release; then
            # Add RPM Fusion repository (required for faad2 and patent-encumbered formats)
            $SUDO_CMD dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" || true
        else
            echo "Warning: You are not running Fedora and may have to set up RPM Fusion manually if there are missing packages!"
        fi

        # Install the build dependencies.
        # Mixxx 2.5+ in Fedora uses Qt 6, so `dnf builddep mixxx` works directly.
        # Fall back to explicit dnf install if builddep is unavailable.
        if $SUDO_CMD dnf builddep -y mixxx 2>/dev/null; then
            $SUDO_CMD dnf install -y \
                ccache \
                chrpath \
                cmake \
                mold \
                ninja-build \
                qt6-qtbase-private-devel
        else
            $SUDO_CMD dnf install -y --allowerasing \
                appstream \
                ccache \
                chrpath \
                cmake \
                desktop-file-utils \
                faad2 \
                ffmpeg-free-devel \
                fftw-devel \
                flac-devel \
                gcc-c++ \
                gmock-devel \
                google-benchmark-devel \
                gtest-devel \
                guidelines-support-library-devel \
                hidapi-devel \
                lame-devel \
                libchromaprint-devel \
                libebur128-devel \
                libid3tag-devel \
                libmad-devel \
                libmodplug-devel \
                libmp4v2-devel \
                libsndfile-devel \
                libusb1-devel \
                libvorbis-devel \
                lilv-devel \
                mesa-libGL-devel \
                mesa-libGLU-devel \
                mold \
                ninja-build \
                opus-devel \
                opusfile-devel \
                portaudio-devel \
                portmidi-devel \
                protobuf-compiler \
                protobuf-devel \
                qt6-qt{5compat,base,base-private,declarative,shadertools,svg}-devel \
                qtkeychain-qt6-devel \
                rubberband-devel \
                soundtouch-devel \
                sqlite-devel \
                taglib-devel \
                upower-devel \
                wavpack-devel \
                zlib-ng-compat-devel
        fi
        ;;
    *)
        echo "Usage: $0 [options]"
        echo ""
        echo "options:"
        echo "   help       Displays this help."
        echo "   name       Displays the name of the required build environment."
        echo "   setup      Installs the build environment."
        ;;
esac
