#!/bin/bash
# Build sbl-chawan package (Chawan TUI browser)

# Source common utilities
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
if [ -z "${_COMMON_SH_LOADED:-}" ]; then
  source "$_SCRIPT_DIR/common.sh"
fi

build_chawan() {
  local workspace="$1"
  
  echo "Building sbl-chawan package..."
  
  # Fetch latest version from the news page
  echo "Fetching latest Chawan version from https://chawan.net/news/index.html..."
  CHAWAN_VERSION=$(curl -s https://chawan.net/news/index.html | grep -oP 'Chawan \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  
  if [ -z "$CHAWAN_VERSION" ]; then
    echo "❌ Failed to determine latest Chawan version from news page"
    echo "   This package will be skipped."
    return 1
  fi
  
  echo "Latest Chawan version: $CHAWAN_VERSION"
  
  # Prepare temporary workspace
  CHAWAN_TMP=$(create_temp_dir)
  cd "$CHAWAN_TMP" || return
  
  # Create a hyphenated version string (e.g., convert 0.3.3 to 0-3-3)
  # This is required for the Sourcehut filename format
  VERSION_HYPHENS="${CHAWAN_VERSION//./-}"
  
  # Updated URL pattern pointing to git.sr.ht
  DEB_URLS=(
    "https://git.sr.ht/~bptato/chawan/refs/download/v${CHAWAN_VERSION}/chawan-${VERSION_HYPHENS}-amd64.deb"
  )
  
  DEB_FILE=""
  for url in "${DEB_URLS[@]}"; do
    echo "Trying to download from: $url"
    # We save it as the standard dotted name to keep the rest of your script compatible
    if curl -L -f -s "$url" -o "chawan_${CHAWAN_VERSION}_amd64.deb"; then
      DEB_FILE="chawan_${CHAWAN_VERSION}_amd64.deb"
      echo "Successfully downloaded from: $url"
      break
    fi
  done
  
  if [ -z "$DEB_FILE" ]; then
    echo "❌ Failed to download Chawan .deb from any known URL"
    echo "   This package will be skipped. Please check https://git.sr.ht/~bptato/chawan for the correct download URL."
    cd "$workspace" || return
    cleanup_temp_dir "$CHAWAN_TMP"
    return 1
  fi
  
  # Create package structure for repackaging
  mkdir -p repackage/DEBIAN
  
  # Extract the original .deb
  dpkg-deb -x "$DEB_FILE" repackage/
  dpkg-deb -e "$DEB_FILE" repackage/DEBIAN/
  
  # Create new control file with sbl- prefix
  cat > repackage/DEBIAN/control <<EOF
Package: sbl-chawan
Version: 1:${CHAWAN_VERSION}
Section: web
Priority: optional
Architecture: amd64
Maintainer: Benjamin Oakes <apt@spacebarlabs.com>
Description: Chawan TUI Browser
 Chawan is a terminal-based web browser with support for modern web standards.
 This package provides the official Chawan binary distribution.
 .
 Original package from https://chawan.net
EOF
  
  # Build the repackaged .deb
  dpkg-deb --build repackage "$workspace/dist/sbl-chawan_1:${CHAWAN_VERSION}_amd64.deb"
  
  # Clean up
  cd "$workspace" || return
  cleanup_temp_dir "$CHAWAN_TMP"
  
  echo "✅ sbl-chawan package built successfully"
}

# If script is executed directly (not sourced), run the function
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  WORKSPACE=$(get_workspace)
  build_chawan "$WORKSPACE"
fi
