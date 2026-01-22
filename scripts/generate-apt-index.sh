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
cp "../index.html" .

echo "✅ APT index generated successfully"
