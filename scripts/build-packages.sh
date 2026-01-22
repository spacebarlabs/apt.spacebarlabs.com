#!/bin/bash
# Build all Debian packages

set -e

# Store the workspace directory
WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"

mkdir -p dist

# Manual version control with Epoch
# We use "1:" to force apt to upgrade over the old timestamp versions (e.g. 2024...)
# Future updates should be 1:1.1, 1:1.2, etc.
VERSION="1:1.0"
echo "Using version: $VERSION"

# Build flatpak packages from flatpaks.txt
if [ -f "flatpaks.txt" ]; then
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
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Convert package name to title (e.g., "emergency-alerts" -> "Emergency Alerts")
    app_title=$(echo "$pkg_name" | awk '{ gsub(/-/, " "); for(i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print }')
    
    # Generate control file from template
    sed -e "s|{{PACKAGE_NAME}}|$package_name|g" \
        -e "s|{{APP_ID}}|$app_id|g" \
        -e "s|{{APP_TITLE}}|$app_title|g" \
        "$WORKSPACE/templates/control.template" > control
    
    # Generate postinst script from template
    sed "s|{{APP_ID}}|$app_id|g" \
        "$WORKSPACE/templates/postinst.template" > postinst
    chmod +x postinst
    
    # Generate prerm script from template
    sed "s|{{APP_ID}}|$app_id|g" \
        "$WORKSPACE/templates/prerm.template" > prerm
    chmod +x prerm
    
    # Add version to control file
    temp_config=$(mktemp)
    awk -v version="$VERSION" '
      /^Package:/ {
        print
        print "Version: " version
        next
      }
      { print }
    ' control > "$temp_config"
    
    # Build package
    equivs-build "$temp_config"
    
    # Clean up temp config immediately
    rm -f "$temp_config"
    
    # Move to dist directory
    find . -maxdepth 1 -name '*.deb' -exec mv {} "$WORKSPACE/dist/" \;
    
    # Clean up temp directory
    cd "$WORKSPACE"
    rm -rf "$temp_dir"
  done < flatpaks.txt
fi

# Build regular file-based packages from packages/
for item in packages/*; do
  if [ -d "$item" ]; then
    # Directory-based package (with DEBIAN/ control directory)
    package_name=$(basename "$item")
    echo "Building directory-based package $package_name with version $VERSION..."
    
    # Update version in control file
    if [ -f "$item/DEBIAN/control" ]; then
      sed -i "s/^Version:.*/Version: $VERSION/" "$item/DEBIAN/control"
    fi
    
    # Build package with dpkg-deb
    dpkg-deb --build "$item" "dist/${package_name}_${VERSION//:/}_all.deb"
  elif [ -f "$item" ]; then
    # File-based package (simple meta-package)
    echo "Building file-based package $item with version $VERSION..."

    # Create temporary config with injected version
    temp_config=$(mktemp)
    awk -v version="$VERSION" '
      /^Package:/ {
        print
        print "Version: " version
        next
      }
      { print }
    ' "$item" > "$temp_config"

    # Build package from temporary config
    equivs-build "$temp_config"
    
    # Clean up temp config immediately
    rm -f "$temp_config"

    find . -maxdepth 1 -name '*.deb' -exec mv {} dist/ \;
  fi
done

echo "✅ All packages built successfully"
