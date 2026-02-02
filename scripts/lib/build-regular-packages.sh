#!/bin/bash
# Build regular file-based packages from packages/

# Source common utilities
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
if [ -z "${_COMMON_SH_LOADED:-}" ]; then
  source "$_SCRIPT_DIR/common.sh"
fi

build_regular_packages() {
  local workspace="$1"
  local version="$2"
  
  echo "Building regular packages from packages/..."
  
  for item in "$workspace/packages"/*; do
    if [ -d "$item" ]; then
      # Directory-based package (with DEBIAN/ control directory)
      local package_name
      package_name=$(basename "$item")
      echo "Building directory-based package $package_name with version $version..."
      
      # Update version in control file
      if [ -f "$item/DEBIAN/control" ]; then
        sed -i "s/^Version:.*/Version: $version/" "$item/DEBIAN/control"
      fi
      
      # Build package with dpkg-deb
      dpkg-deb --build "$item" "$workspace/dist/${package_name}_${version//:/}_all.deb"
      
      # Create a generic alias for the bootstrap package
      if [ "$package_name" = "sbl-apt-repos" ]; then
        cp "$workspace/dist/${package_name}_${version//:/}_all.deb" "$workspace/dist/${package_name}.deb"
        echo "   Created alias: dist/${package_name}.deb"
      fi
    elif [ -f "$item" ]; then
      # File-based package (simple meta-package)
      echo "Building file-based package $item with version $version..."
      
      # Create temporary config with injected version
      temp_config=$(mktemp)
      add_version_to_control "$item" "$version" "$temp_config"
      
      # Build package from temporary config
      equivs-build "$temp_config"
      
      # Clean up temp config immediately
      rm -f "$temp_config"
      
      find . -maxdepth 1 -name '*.deb' -exec mv {} "$workspace/dist/" \;
    fi
  done
}

# If script is executed directly (not sourced), run the function
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  WORKSPACE=$(get_workspace)
  VERSION=$(get_version)
  build_regular_packages "$WORKSPACE" "$VERSION"
fi
