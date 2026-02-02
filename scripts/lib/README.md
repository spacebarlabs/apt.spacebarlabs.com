# Build Scripts Library

This directory contains modular build scripts for generating Debian packages.

## Structure

- **common.sh**: Shared utility functions used across all build scripts
  - `get_workspace()`: Returns the workspace directory
  - `get_version()`: Returns the current package version
  - `create_temp_dir()`: Creates a temporary directory
  - `cleanup_temp_dir()`: Cleans up a temporary directory
  - `pkg_name_to_title()`: Converts package name to title case
  - `add_version_to_control()`: Adds version to a control file

- **build-flatpak-packages.sh**: Builds flatpak meta-packages from flatpaks.txt
  - Reads flatpak app IDs from flatpaks.txt
  - Generates packages that install apps via flatpak

- **build-regular-packages.sh**: Builds regular file-based packages from packages/
  - Handles both directory-based packages (with DEBIAN/ structure)
  - Handles simple file-based meta-packages

- **build-whisper-cpp.sh**: Builds sbl-github-whisper-cpp-native package
  - Fetches latest whisper.cpp source from GitHub
  - Creates package that compiles locally for optimal performance

- **build-chawan.sh**: Builds sbl-chawan package
  - Downloads official Chawan browser binary from sourcehut
  - Repackages with sbl- prefix

- **build-handy.sh**: Builds sbl-handy package
  - Downloads official Handy speech-to-text app from GitHub releases
  - Repackages with sbl- prefix

## Usage

Each script can be sourced and called as a function, or executed directly:

```bash
# As a function (preferred in build-packages.sh)
source scripts/lib/build-flatpak-packages.sh
build_flatpak_packages "$WORKSPACE" "$VERSION"

# As a standalone script
./scripts/lib/build-flatpak-packages.sh
```

## Main Build Script

The main `scripts/build-packages.sh` orchestrates all the build modules:

1. Sources all library functions
2. Calls each build function in sequence
3. Ensures all packages are built to the dist/ directory
