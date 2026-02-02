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
# Build sbl-github-whisper-cpp-native (Source + Performance + Clean)
# ---------------------------------------------------------
echo "Building sbl-github-whisper-cpp-native package..."

# 1. Fetch latest tag and version
LATEST_TAG=$(curl -s https://api.github.com/repos/ggml-org/whisper.cpp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
CLEAN_VERSION="${LATEST_TAG#v}"

# 2. Prepare temporary workspace
WHISPER_TMP=$(mktemp -d)
SRC_DIR="$WHISPER_TMP/usr/src/whisper.cpp"
mkdir -p "$SRC_DIR"
mkdir -p "$WHISPER_TMP/DEBIAN"

# 3. Bundle SOURCE code
SOURCE_URL="https://github.com/ggml-org/whisper.cpp/archive/refs/tags/${LATEST_TAG}.tar.gz"
if ! curl -L -s "$SOURCE_URL" | tar xz -C "$SRC_DIR" --strip-components=1; then
  echo "❌ Failed to download whisper.cpp source. Skipping this package."
  rm -rf "$WHISPER_TMP"
else

# 4. Create Control File
cat > "$WHISPER_TMP/DEBIAN/control" <<EOF
Package: sbl-github-whisper-cpp-native
Version: 1:${CLEAN_VERSION}
Section: misc
Priority: optional
Architecture: all
Maintainer: Benjamin Oakes <apt@spacebarlabs.com>
Depends: build-essential, cmake, git, ffmpeg
Description: Whisper.cpp (Locally Optimized)
 This package bundles source and compiles locally for maximum performance.
 Correctly maps binaries following the Dec 2024 migration.
EOF

# 5. Updated Postinst (Official Migration Mapping)
cat > "$WHISPER_TMP/DEBIAN/postinst" <<EOF
#!/bin/bash
set -e
echo "Building whisper.cpp natively..."
cd /usr/src/whisper.cpp
cmake -B build -DGGML_NATIVE=ON
cmake --build build --config Release -j\$(nproc)

# Install official renamed binaries (Migration Dec 2024)
install -m 755 build/bin/main /usr/local/bin/whisper-cli
install -m 755 build/bin/server /usr/local/bin/whisper-server
install -m 755 build/bin/bench /usr/local/bin/whisper-bench
install -m 755 build/bin/stream /usr/local/bin/whisper-stream

# Space Bar Labs convenience aliases
ln -sf /usr/local/bin/whisper-cli /usr/local/bin/whisper-cpp
ln -sf /usr/local/bin/whisper-cli /usr/local/bin/whisper-whisper-cpp
EOF

# 6. Updated Prerm (Cleanup Symlinks)
cat > "$WHISPER_TMP/DEBIAN/prerm" <<EOF
#!/bin/bash
set -e
case "\$1" in
    remove|upgrade)
        rm -f /usr/local/bin/whisper-cli /usr/local/bin/whisper-server \
              /usr/local/bin/whisper-bench /usr/local/bin/whisper-stream \
              /usr/local/bin/whisper-cpp /usr/local/bin/whisper-whisper-cpp
        ;;
esac
EOF

# 7. NEW Postrm (Cleanup Compile Artifacts)
cat > "$WHISPER_TMP/DEBIAN/postrm" <<EOF
#!/bin/bash
set -e
case "\$1" in
    purge|remove)
        # Wipe the entire source/build directory to prevent "not empty" warnings
        if [ -d "/usr/src/whisper.cpp" ]; then
            rm -rf /usr/src/whisper.cpp
        fi
        ;;
esac
EOF

chmod 755 "$WHISPER_TMP/DEBIAN/"*
dpkg-deb --build "$WHISPER_TMP" "dist/sbl-github-whisper-cpp-native_1:${CLEAN_VERSION}_all.deb"
rm -rf "$WHISPER_TMP"
echo "✅ sbl-github-whisper-cpp-native package built successfully"
fi

# ---------------------------------------------------------
# Build sbl-chawan (Chawan TUI browser)
# ---------------------------------------------------------
echo "Building sbl-chawan package..."

# Fetch latest version from the news page
echo "Fetching latest Chawan version from https://chawan.net/news/index.html..."
CHAWAN_VERSION=$(curl -s https://chawan.net/news/index.html | grep -oP 'Chawan \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -z "$CHAWAN_VERSION" ]; then
  echo "❌ Failed to determine latest Chawan version from news page"
  echo "   This package will be skipped."
else
  echo "Latest Chawan version: $CHAWAN_VERSION"
fi

# Only proceed if we successfully fetched a version
if [ -n "$CHAWAN_VERSION" ]; then
  # Prepare temporary workspace
  CHAWAN_TMP=$(mktemp -d)
  cd "$CHAWAN_TMP"
  
  # Try multiple possible URL patterns for the .deb file
  DEB_URLS=(
    "https://chawan.net/releases/chawan_${CHAWAN_VERSION}_amd64.deb"
    "https://chawan.net/releases/chawan_${CHAWAN_VERSION}-1_amd64.deb"
    "https://chawan.net/releases/${CHAWAN_VERSION}/chawan_${CHAWAN_VERSION}_amd64.deb"
  )
  
  DEB_FILE=""
  for url in "${DEB_URLS[@]}"; do
    echo "Trying to download from: $url"
    if curl -L -f -s "$url" -o "chawan_${CHAWAN_VERSION}_amd64.deb"; then
      DEB_FILE="chawan_${CHAWAN_VERSION}_amd64.deb"
      echo "Successfully downloaded from: $url"
      break
    fi
  done
  
  if [ -z "$DEB_FILE" ]; then
    echo "❌ Failed to download Chawan .deb from any known URL"
    echo "   This package will be skipped. Please check https://chawan.net for the correct download URL."
    cd "$WORKSPACE"
    rm -rf "$CHAWAN_TMP"
  else
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
    dpkg-deb --build repackage "$WORKSPACE/dist/sbl-chawan_1:${CHAWAN_VERSION}_amd64.deb"
    
    # Clean up
    cd "$WORKSPACE"
    rm -rf "$CHAWAN_TMP"
    
    echo "✅ sbl-chawan package built successfully"
  fi

fi  # End of CHAWAN_VERSION check

# ---------------------------------------------------------
# Build sbl-handy (Handy speech-to-text application)
# ---------------------------------------------------------
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
else
  # Remove 'v' prefix from tag to get clean version
  HANDY_VERSION="${HANDY_LATEST_TAG#v}"
  echo "Latest Handy version: $HANDY_VERSION (tag: $HANDY_LATEST_TAG)"
  
  # Prepare temporary workspace
  HANDY_TMP=$(mktemp -d)
  cd "$HANDY_TMP"
  
  # Download the .deb file from GitHub releases
  # The file is named like: Handy_0.7.1_amd64.deb (note capital H)
  DEB_URL="https://github.com/cjpais/Handy/releases/download/${HANDY_LATEST_TAG}/Handy_${HANDY_VERSION}_amd64.deb"
  DEB_FILE="Handy_${HANDY_VERSION}_amd64.deb"
  
  echo "Downloading from: $DEB_URL"
  if curl -L -f -s "$DEB_URL" -o "$DEB_FILE"; then
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
    dpkg-deb --build repackage "$WORKSPACE/dist/sbl-handy_1:${HANDY_VERSION}_amd64.deb"
    
    # Clean up
    cd "$WORKSPACE"
    rm -rf "$HANDY_TMP"
    
    echo "✅ sbl-handy package built successfully"
  else
    echo "❌ Failed to download Handy .deb from: $DEB_URL"
    echo "   This package will be skipped."
    cd "$WORKSPACE"
    rm -rf "$HANDY_TMP"
  fi
fi  # End of HANDY_LATEST_TAG check

echo "✅ All packages built successfully"
