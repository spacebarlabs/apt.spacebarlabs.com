#!/bin/bash
# Generate APT index and metadata files

set -e

cd dist

# 1. Generate the Package Index
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# 2. Generate a Release file
{
  echo "Origin: Space Bar Labs"
  echo "Label: Infrastructure"
  echo "Suite: stable"
  echo "Codename: all"
  echo "Architectures: all"
  echo "Components: main"
  echo "Description: Meta-packages for my setups"
  echo "Date: $(date -Ru)"
} > Release

# 3. Create CNAME for Custom Domain
echo "apt.spacebarlabs.com" > CNAME

# 4. Generate package list for index.html
# Create a temporary file with the package list
PACKAGE_LIST_FILE=$(mktemp -t apt-packages.XXXXXX)

# Ensure cleanup on exit
trap 'rm -f "$PACKAGE_LIST_FILE"' EXIT ERR INT TERM

# Enable nullglob to handle case when no .deb files exist
shopt -s nullglob
for deb_file in *.deb; do
  echo "            <li>${deb_file}</li>" >> "$PACKAGE_LIST_FILE"
done
shopt -u nullglob

# Copy index.html and replace package list placeholder
if ! cp "../index.html" .; then
  echo "❌ Failed to copy index.html"
  exit 1
fi

if [ -s "$PACKAGE_LIST_FILE" ]; then
  # Use sed to replace the placeholder with the contents of the file
  # Note: -i works differently on macOS vs Linux, but this runs in Ubuntu CI
  if ! sed -i -e "/<!-- PACKAGE_LIST_PLACEHOLDER -->/r $PACKAGE_LIST_FILE" -e "/<!-- PACKAGE_LIST_PLACEHOLDER -->/d" index.html; then
    echo "❌ Failed to update index.html with package list"
    exit 1
  fi
else
  # If no packages found, show a message (should not happen in production)
  if ! sed -i 's/<!-- PACKAGE_LIST_PLACEHOLDER -->/<li>No packages available<\/li>/g' index.html; then
    echo "❌ Failed to update index.html with fallback message"
    exit 1
  fi
fi

echo "✅ APT index generated successfully"
