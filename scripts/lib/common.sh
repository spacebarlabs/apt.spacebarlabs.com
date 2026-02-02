#!/bin/bash
# Common utility functions for package building

# Ensure script fails on any error
set -e

# Get the workspace directory
get_workspace() {
  echo "${GITHUB_WORKSPACE:-$(pwd)}"
}

# Get the version string used for all packages
get_version() {
  # Manual version control with Epoch
  # We use "1:" to force apt to upgrade over the old timestamp versions (e.g. 2024...)
  # Future updates should be 1:1.1, 1:1.2, etc.
  echo "1:1.0"
}

# Create temporary directory and echo its path
create_temp_dir() {
  mktemp -d
}

# Clean up temporary directory
cleanup_temp_dir() {
  local temp_dir="$1"
  if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
  fi
}

# Convert package name to title (e.g., "emergency-alerts" -> "Emergency Alerts")
pkg_name_to_title() {
  local pkg_name="$1"
  echo "$pkg_name" | awk '{ gsub(/-/, " "); for(i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print }'
}

# Add version to control file
add_version_to_control() {
  local control_file="$1"
  local version="$2"
  local output_file="$3"
  
  awk -v version="$version" '
    /^Package:/ {
      print
      print "Version: " version
      next
    }
    { print }
  ' "$control_file" > "$output_file"
}
