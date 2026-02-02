#!/bin/bash
# Build flatpak packages from flatpaks.txt

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/common.sh"

build_flatpak_packages() {
  local workspace="$1"
  local version="$2"
  
  if [ ! -f "$workspace/flatpaks.txt" ]; then
    echo "No flatpaks.txt found, skipping flatpak packages..."
    return 0
  fi
  
  echo "Building flatpak packages from flatpaks.txt..."
  
  while IFS=':' read -r pkg_name app_id || [ -n "$pkg_name" ]; do
    # Skip empty lines and comments
    [[ -z "$pkg_name" || "$pkg_name" =~ ^# ]] && continue
    
    # Trim whitespace
    pkg_name=$(echo "$pkg_name" | xargs)
    app_id=$(echo "$app_id" | xargs)
    
    package_name="sbl-flatpak-$pkg_name"
    echo "Building $package_name ($app_id)..."
    
    # Create temporary directory for package
    temp_dir=$(create_temp_dir)
    cd "$temp_dir" || return
    
    # Convert package name to title (e.g., "emergency-alerts" -> "Emergency Alerts")
    app_title=$(pkg_name_to_title "$pkg_name")
    
    # Generate control file from template
    sed -e "s|{{PACKAGE_NAME}}|$package_name|g" \
        -e "s|{{APP_ID}}|$app_id|g" \
        -e "s|{{APP_TITLE}}|$app_title|g" \
        "$workspace/templates/control.template" > control
    
    # Generate postinst script from template
    sed "s|{{APP_ID}}|$app_id|g" \
        "$workspace/templates/postinst.template" > postinst
    chmod +x postinst
    
    # Generate prerm script from template
    sed "s|{{APP_ID}}|$app_id|g" \
        "$workspace/templates/prerm.template" > prerm
    chmod +x prerm
    
    # Add version to control file
    temp_config=$(mktemp)
    add_version_to_control control "$version" "$temp_config"
    
    # Build package
    equivs-build "$temp_config"
    
    # Clean up temp config immediately
    rm -f "$temp_config"
    
    # Move to dist directory
    find . -maxdepth 1 -name '*.deb' -exec mv {} "$workspace/dist/" \;
    
    # Clean up temp directory
    cd "$workspace" || return
    cleanup_temp_dir "$temp_dir"
  done < "$workspace/flatpaks.txt"
}

# If script is executed directly (not sourced), run the function
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  WORKSPACE=$(get_workspace)
  VERSION=$(get_version)
  build_flatpak_packages "$WORKSPACE" "$VERSION"
fi
