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

    # Create a generic alias for the bootstrap package
    if [ "$package_name" = "sbl-apt-repos" ]; then
      cp "dist/${package_name}_${VERSION//:/}_all.deb" "dist/${package_name}.deb"
      echo "   Created alias: dist/${package_name}.deb"
    fi
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

# ---------------------------------------------------------
# Build whisper-cpp from GitHub Releases
# ---------------------------------------------------------
echo "Building sbl-github-release-whisper-cpp package from GitHub Releases..."

# 1. Fetch the latest tag name (removes 'v' prefix if present)
LATEST_TAG=$(curl -s https://api.github.com/repos/ggml-org/whisper.cpp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
CLEAN_VERSION="${LATEST_TAG#v}"

echo "   Found version: $CLEAN_VERSION"

# 2. Prepare temporary workspace
WHISPER_TMP=$(mktemp -d)
mkdir -p "$WHISPER_TMP/usr/bin"
mkdir -p "$WHISPER_TMP/DEBIAN"

# 3. Download the x64 binary zip
DOWNLOAD_URL="https://github.com/ggml-org/whisper.cpp/releases/download/${LATEST_TAG}/whisper-bin-x64.zip"
echo "   Downloading from $DOWNLOAD_URL..."

if curl -L -s -o "$WHISPER_TMP/whisper.zip" "$DOWNLOAD_URL"; then

    # 4. Extract and Install
    unzip -q "$WHISPER_TMP/whisper.zip" -d "$WHISPER_TMP/extract"

    # Move 'main' binary to /usr/bin/whisper-cpp
    if [ -f "$WHISPER_TMP/extract/main" ]; then
        mv "$WHISPER_TMP/extract/main" "$WHISPER_TMP/usr/bin/whisper-cpp"
        chmod +x "$WHISPER_TMP/usr/bin/whisper-cpp"

        # Optional: Grab 'quantize' tool if available
        if [ -f "$WHISPER_TMP/extract/quantize" ]; then
             mv "$WHISPER_TMP/extract/quantize" "$WHISPER_TMP/usr/bin/whisper-quantize"
             chmod +x "$WHISPER_TMP/usr/bin/whisper-quantize"
        fi

        # 5. Generate Control File
        cat > "$WHISPER_TMP/DEBIAN/control" <<EOF
Package: sbl-github-release-whisper-cpp
Version: 1:${CLEAN_VERSION}
Section: sound
Priority: optional
Architecture: amd64
Maintainer: Benjamin Oakes <apt@spacebarlabs.com>
Depends: ffmpeg
Description: Whisper.cpp (Pre-built)
 High-performance inference of OpenAI's Whisper automatic speech
 recognition (ASR) model.
 .
 This package packages the official pre-built 'main' binary
 from GitHub Releases as 'whisper-cpp'.
EOF

        # 6. Build the .deb
        dpkg-deb --build "$WHISPER_TMP" "dist/sbl-github-release-whisper-cpp_1:${CLEAN_VERSION}_amd64.deb"
        echo "   ✅ Built dist/sbl-github-release-whisper-cpp_1:${CLEAN_VERSION}_amd64.deb"
    else
        echo "   ❌ ERROR: Could not find 'main' binary in zip. Release structure may have changed."
    fi
else
    echo "   ❌ ERROR: Failed to download whisper release."
fi

# Clean up
rm -rf "$WHISPER_TMP"

echo "✅ All packages built successfully"
