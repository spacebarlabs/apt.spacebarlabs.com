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
PACKAGE_LIST_FILE=$(mktemp)
for deb_file in *.deb; do
  if [ -f "$deb_file" ]; then
    echo "            <li>${deb_file}</li>" >> "$PACKAGE_LIST_FILE"
  fi
done

# Copy index.html and replace package list placeholder
cp "../index.html" .
if [ -s "$PACKAGE_LIST_FILE" ]; then
  # Use sed to replace the placeholder with the contents of the file
  sed -i -e "/<!-- PACKAGE_LIST_PLACEHOLDER -->/r $PACKAGE_LIST_FILE" -e "/<!-- PACKAGE_LIST_PLACEHOLDER -->/d" index.html
else
  # If no packages found, show a message
  sed -i 's/<!-- PACKAGE_LIST_PLACEHOLDER -->/<li>No packages available<\/li>/g' index.html
fi

# Clean up temporary file
rm -f "$PACKAGE_LIST_FILE"

echo "✅ APT index generated successfully"
