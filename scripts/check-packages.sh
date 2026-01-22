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
  
  # Extract the Depends field
  DEPENDS_LINE=$(grep "^Depends:" "$FILE_PATH" | head -n 1)
  
  if [ -z "$DEPENDS_LINE" ]; then
    echo "   ⚠️  No 'Depends:' field found. Skipping."
    continue
  fi
  
  # Extract packages from the Depends line (remove "Depends:" prefix and split by comma)
  # This handles both comma-separated and space-separated package lists
  PACKAGES=$(echo "$DEPENDS_LINE" | sed 's/^Depends://' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Check each package
  while IFS= read -r PACKAGE; do
    # Skip empty lines
    [ -z "$PACKAGE" ] && continue
    
    # Remove version constraints (e.g., "package (>= 1.0)" -> "package")
    PACKAGE_NAME=$(echo "$PACKAGE" | sed 's/[[:space:]]*(.*)//' | awk '{print $1}')
    
    # Skip if package name is empty
    [ -z "$PACKAGE_NAME" ] && continue
    
    # Skip packages that are from external repositories
    if [ "$PACKAGE_NAME" = "mise" ] || [ "$PACKAGE_NAME" = "sbl-apt-repos" ]; then
      echo "   Skipping '$PACKAGE_NAME' (external repository)"
      continue
    fi
    
    echo -n "   Checking '$PACKAGE_NAME'... "
    
    # Use apt-cache policy to check if package exists
    if apt-cache policy "$PACKAGE_NAME" 2>/dev/null | grep -q "Candidate:"; then
      # Check if there's actually a candidate version available
      CANDIDATE=$(apt-cache policy "$PACKAGE_NAME" 2>/dev/null | grep "Candidate:" | awk '{print $2}')
      if [ "$CANDIDATE" = "(none)" ]; then
        echo "❌ NOT FOUND"
        echo "      ERROR: Package '$PACKAGE_NAME' does not exist in Ubuntu repositories"
        FOUND_ERROR=1
      else
        echo "✅ Found (version: $CANDIDATE)"
      fi
    else
      echo "❌ NOT FOUND"
      echo "      ERROR: Package '$PACKAGE_NAME' does not exist in Ubuntu repositories"
      FOUND_ERROR=1
    fi
  done <<< "$PACKAGES"
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
