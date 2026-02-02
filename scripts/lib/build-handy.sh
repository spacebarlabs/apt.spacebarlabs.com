#!/bin/bash
# Build sbl-handy package (Handy speech-to-text application)

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/common.sh"

build_handy() {
  local workspace="$1"
  
  echo "Building sbl-handy package..."
  
  # Try to fetch latest tag from GitHub API
  echo "Fetching latest Handy version from GitHub..."
  HANDY_LATEST_TAG=$(curl -s https://api.github.com/repos/cjpais/Handy/releases/latest 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  
  # If API fails (blocked or unavailable), try scraping the releases page
  if [ -z "$HANDY_LATEST_TAG" ]; then
    echo "GitHub API unavailable, trying to fetch from releases page..."
    HANDY_LATEST_TAG=$(curl -s https://github.com/cjpais/Handy/releases 2>/dev/null | grep -o '/cjpais/Handy/releases/tag/v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' | head -1 | sed 's/.*\/\(v[0-9.]*\)$/\1/')
  fi
  
  if [ -z "$HANDY_LATEST_TAG" ]; then
    echo "❌ Failed to determine latest Handy version from GitHub"
    echo "   This package will be skipped."
    return 1
  fi
  
  # Remove 'v' prefix from tag to get clean version
  HANDY_VERSION="${HANDY_LATEST_TAG#v}"
  echo "Latest Handy version: $HANDY_VERSION (tag: $HANDY_LATEST_TAG)"
  
  # Prepare temporary workspace
  HANDY_TMP=$(create_temp_dir)
  cd "$HANDY_TMP" || return
  
  # Download the .deb file from GitHub releases
  # The file is named like: Handy_0.7.1_amd64.deb (note capital H)
  DEB_URL="https://github.com/cjpais/Handy/releases/download/${HANDY_LATEST_TAG}/Handy_${HANDY_VERSION}_amd64.deb"
  DEB_FILE="Handy_${HANDY_VERSION}_amd64.deb"
  
  echo "Downloading from: $DEB_URL"
  if ! curl -L -f -s "$DEB_URL" -o "$DEB_FILE"; then
    echo "❌ Failed to download Handy .deb from: $DEB_URL"
    echo "   This package will be skipped."
    cd "$workspace" || return
    cleanup_temp_dir "$HANDY_TMP"
    return 1
  fi
  
  echo "Successfully downloaded Handy .deb"
  
  # Create package structure for repackaging
  mkdir -p repackage/DEBIAN
  
  # Extract the original .deb
  dpkg-deb -x "$DEB_FILE" repackage/
  dpkg-deb -e "$DEB_FILE" repackage/DEBIAN/
  
  # Extract dependencies from original control file
  ORIGINAL_DEPENDS=$(grep "^Depends:" repackage/DEBIAN/control | sed 's/^Depends: //')
  
  # Create new control file with sbl- prefix
  # Only include Depends field if original package had dependencies
  if [ -n "$ORIGINAL_DEPENDS" ]; then
    cat > repackage/DEBIAN/control <<EOF
Package: sbl-handy
Version: 1:${HANDY_VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Benjamin Oakes <apt@spacebarlabs.com>
Depends: ${ORIGINAL_DEPENDS}
Description: Handy Speech-to-Text Application
 Handy is a free, open source, and extensible speech-to-text application
 that works completely offline. Built with Tauri (Rust + React/TypeScript),
 it provides simple, privacy-focused speech transcription.
 .
 Features:
  - Press a shortcut, speak, and have your words appear in any text field
  - Completely offline - your voice stays on your computer
  - Uses Whisper models with GPU acceleration when available
  - Works on Linux with various desktop environments
 .
 Original package from https://github.com/cjpais/Handy
EOF
  else
    cat > repackage/DEBIAN/control <<EOF
Package: sbl-handy
Version: 1:${HANDY_VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Benjamin Oakes <apt@spacebarlabs.com>
Description: Handy Speech-to-Text Application
 Handy is a free, open source, and extensible speech-to-text application
 that works completely offline. Built with Tauri (Rust + React/TypeScript),
 it provides simple, privacy-focused speech transcription.
 .
 Features:
  - Press a shortcut, speak, and have your words appear in any text field
  - Completely offline - your voice stays on your computer
  - Uses Whisper models with GPU acceleration when available
  - Works on Linux with various desktop environments
 .
 Original package from https://github.com/cjpais/Handy
EOF
  fi
  
  # Build the repackaged .deb
  dpkg-deb --build repackage "$workspace/dist/sbl-handy_1:${HANDY_VERSION}_amd64.deb"
  
  # Clean up
  cd "$workspace" || return
  cleanup_temp_dir "$HANDY_TMP"
  
  echo "✅ sbl-handy package built successfully"
}

# If script is executed directly (not sourced), run the function
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  WORKSPACE=$(get_workspace)
  build_handy "$WORKSPACE"
fi
