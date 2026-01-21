#!/bin/bash

# Build Debian packages from configuration files

set -e

mkdir -p dist
# Generate version from git commit timestamp
VERSION=$(git show -s --format=%cd --date=format:'%Y%m%d%H%M' HEAD)
echo "Using version: $VERSION"

# Set up trap to clean up temporary files
temp_files=()
trap 'rm -f "${temp_files[@]}"' EXIT

# Loop through all config files in packages/
for config in packages/*; do
  if [ -f "$config" ]; then
    echo "Building $config with version $VERSION..."

    # Create temporary config with injected version
    # Insert Version field after Package field for proper ordering
    temp_config=$(mktemp)
    temp_files+=("$temp_config")
    awk -v version="$VERSION" '
      /^Package:/ {
        print
        print "Version: " version
        next
      }
      { print }
    ' "$config" > "$temp_config"

    # Build package from temporary config
    equivs-build "$temp_config"

    # Move .deb files to dist/ if they exist
    if ls *.deb 1> /dev/null 2>&1; then
      mv *.deb dist/
    fi
  fi
done

echo "✅ Packages built successfully in dist/"
