#!/bin/bash
# Build sbl-github-whisper-cpp-native package

# Source common utilities
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
if [ -z "${_COMMON_SH_LOADED:-}" ]; then
  source "$_SCRIPT_DIR/common.sh"
fi

build_whisper_cpp() {
  local workspace="$1"
  
  echo "Building sbl-github-whisper-cpp-native package..."
  
  # 1. Fetch latest tag and version
  LATEST_TAG=$(curl -s https://api.github.com/repos/ggml-org/whisper.cpp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  CLEAN_VERSION="${LATEST_TAG#v}"
  
  # 2. Prepare temporary workspace
  WHISPER_TMP=$(create_temp_dir)
  SRC_DIR="$WHISPER_TMP/usr/src/whisper.cpp"
  mkdir -p "$SRC_DIR"
  mkdir -p "$WHISPER_TMP/DEBIAN"
  
  # 3. Bundle SOURCE code
  SOURCE_URL="https://github.com/ggml-org/whisper.cpp/archive/refs/tags/${LATEST_TAG}.tar.gz"
  if ! curl -L -s "$SOURCE_URL" | tar xz -C "$SRC_DIR" --strip-components=1; then
    echo "❌ Failed to download whisper.cpp source. Skipping this package."
    cleanup_temp_dir "$WHISPER_TMP"
    return 1
  fi
  
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
  cat > "$WHISPER_TMP/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e
echo "Building whisper.cpp natively..."
cd /usr/src/whisper.cpp
cmake -B build -DGGML_NATIVE=ON
cmake --build build --config Release -j$(nproc)

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
  cat > "$WHISPER_TMP/DEBIAN/prerm" <<'EOF'
#!/bin/bash
set -e
case "$1" in
    remove|upgrade)
        rm -f /usr/local/bin/whisper-cli /usr/local/bin/whisper-server \
              /usr/local/bin/whisper-bench /usr/local/bin/whisper-stream \
              /usr/local/bin/whisper-cpp /usr/local/bin/whisper-whisper-cpp
        ;;
esac
EOF
  
  # 7. NEW Postrm (Cleanup Compile Artifacts)
  cat > "$WHISPER_TMP/DEBIAN/postrm" <<'EOF'
#!/bin/bash
set -e
case "$1" in
    purge|remove)
        # Wipe the entire source/build directory to prevent "not empty" warnings
        if [ -d "/usr/src/whisper.cpp" ]; then
            rm -rf /usr/src/whisper.cpp
        fi
        ;;
esac
EOF
  
  chmod 755 "$WHISPER_TMP/DEBIAN/"*
  dpkg-deb --build "$WHISPER_TMP" "$workspace/dist/sbl-github-whisper-cpp-native_1:${CLEAN_VERSION}_all.deb"
  cleanup_temp_dir "$WHISPER_TMP"
  echo "✅ sbl-github-whisper-cpp-native package built successfully"
}

# If script is executed directly (not sourced), run the function
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  WORKSPACE=$(get_workspace)
  build_whisper_cpp "$WORKSPACE"
fi
