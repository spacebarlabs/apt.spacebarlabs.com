#!/bin/bash
# Build all Debian packages

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities and build modules
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/build-flatpak-packages.sh
source "$SCRIPT_DIR/lib/build-flatpak-packages.sh"
# shellcheck source=scripts/lib/build-regular-packages.sh
source "$SCRIPT_DIR/lib/build-regular-packages.sh"
# shellcheck source=scripts/lib/build-whisper-cpp.sh
source "$SCRIPT_DIR/lib/build-whisper-cpp.sh"
# shellcheck source=scripts/lib/build-chawan.sh
source "$SCRIPT_DIR/lib/build-chawan.sh"
# shellcheck source=scripts/lib/build-handy.sh
source "$SCRIPT_DIR/lib/build-handy.sh"

# Get workspace and version
WORKSPACE=$(get_workspace)
VERSION=$(get_version)

# Create dist directory
mkdir -p "$WORKSPACE/dist"

echo "Using version: $VERSION"

# Build all package types
build_flatpak_packages "$WORKSPACE" "$VERSION"
build_regular_packages "$WORKSPACE" "$VERSION"
build_whisper_cpp "$WORKSPACE"
build_chawan "$WORKSPACE"
build_handy "$WORKSPACE"

echo "✅ All packages built successfully"
