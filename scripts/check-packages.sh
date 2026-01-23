#!/bin/bash
# Script to verify that all packages referenced in Depends fields exist in Ubuntu

set -e

FOUND_ERROR=0

echo "=========================================="
echo "Checking package availability in Ubuntu"
echo "=========================================="

# Loop through all package files
for FILE_PATH in packages/*; do
  # Skip if it's a directory or doesn't exist
  [ -f "$FILE_PATH" ] || continue
  
  echo ""
  echo "---------------------------------------------------"
  echo "🔍 Checking $(basename "$FILE_PATH")..."
  echo "---------------------------------------------------"
  
  # Function to check packages from a field
  check_packages_from_field() {
    local FIELD_NAME=$1
    local FIELD_LINE=$2
    
    if [ -z "$FIELD_LINE" ]; then
      return
    fi
    
    echo "   📦 Checking $FIELD_NAME packages..."
    
    # Extract packages from the field line (remove field prefix and split by comma)
    # This handles both comma-separated and space-separated package lists
    PACKAGES=$(echo "$FIELD_LINE" | sed "s/^$FIELD_NAME://" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check each package
    while IFS= read -r PACKAGE; do
      # Skip empty lines
      [ -z "$PACKAGE" ] && continue
      
      # Remove version constraints (e.g., "package (>= 1.0)" -> "package")
      PACKAGE_NAME=$(echo "$PACKAGE" | sed 's/[[:space:]]*(.*)//' | awk '{print $1}')
      
      # Skip if package name is empty
      [ -z "$PACKAGE_NAME" ] && continue
      
      # Skip packages that are from external repositories
      if [ "$PACKAGE_NAME" = "mise" ] || [ "$PACKAGE_NAME" = "sbl-apt-repos" ] || [ "$PACKAGE_NAME" = "google-chrome-stable" ] || [ "$PACKAGE_NAME" = "signal-desktop" ]; then
        echo "      Skipping '$PACKAGE_NAME' (external repository)"
        continue
      fi
      
      # Skip internal sbl-* packages (they're defined in this repo)
      if [[ "$PACKAGE_NAME" == sbl-* ]]; then
        echo "      Skipping '$PACKAGE_NAME' (internal package)"
        continue
      fi
      
      echo -n "      Checking '$PACKAGE_NAME'... "
      
      # Use apt-cache policy to check if package exists
      if apt-cache policy "$PACKAGE_NAME" 2>/dev/null | grep -q "Candidate:"; then
        # Check if there's actually a candidate version available
        CANDIDATE=$(apt-cache policy "$PACKAGE_NAME" 2>/dev/null | grep "Candidate:" | awk '{print $2}')
        if [ "$CANDIDATE" = "(none)" ]; then
          echo "❌ NOT FOUND"
          echo "         ERROR: Package '$PACKAGE_NAME' does not exist in Ubuntu repositories"
          FOUND_ERROR=1
        else
          echo "✅ Found (version: $CANDIDATE)"
        fi
      else
        echo "❌ NOT FOUND"
        echo "         ERROR: Package '$PACKAGE_NAME' does not exist in Ubuntu repositories"
        FOUND_ERROR=1
      fi
    done <<< "$PACKAGES"
  }
  
  # Extract the Depends field
  DEPENDS_LINE=$(grep "^Depends:" "$FILE_PATH" | head -n 1)
  
  if [ -z "$DEPENDS_LINE" ]; then
    echo "   ⚠️  No 'Depends:' field found."
  else
    check_packages_from_field "Depends" "$DEPENDS_LINE"
  fi
  
  # Extract the Recommends field
  RECOMMENDS_LINE=$(grep "^Recommends:" "$FILE_PATH" | head -n 1)
  
  if [ -n "$RECOMMENDS_LINE" ]; then
    check_packages_from_field "Recommends" "$RECOMMENDS_LINE"
  fi
done

echo ""
echo "=========================================="
if [ "$FOUND_ERROR" -eq "1" ]; then
  echo "❌ FAILURE: Some packages do not exist in Ubuntu"
  echo "=========================================="
  exit 1
else
  echo "✅ SUCCESS: All packages exist in Ubuntu"
  echo "=========================================="
fi
