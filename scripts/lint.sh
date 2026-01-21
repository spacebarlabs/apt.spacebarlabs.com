#!/bin/bash

# Basic validation of package files

set -e

FOUND_ERROR=0

for FILE_PATH in packages/*; do
  # Skip if it's a directory or doesn't exist
  [ -f "$FILE_PATH" ] || continue

  echo "---------------------------------------------------"
  echo "🔍 Validating $FILE_PATH..."

  # Check for required fields
  if ! grep -q "^Package:" "$FILE_PATH"; then
    echo "   ❌ ERROR: Missing 'Package:' field"
    FOUND_ERROR=1
  fi

  if ! grep -q "^Maintainer:" "$FILE_PATH"; then
    echo "   ❌ ERROR: Missing 'Maintainer:' field"
    FOUND_ERROR=1
  fi
done

if [ "$FOUND_ERROR" -eq "1" ]; then
  echo ""
  echo "❌ Package validation failed"
  exit 1
fi

echo ""
echo "✅ All package files are valid"
