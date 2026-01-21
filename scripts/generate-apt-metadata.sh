#!/bin/bash

# Generate APT repository metadata files

set -e

cd dist

# 1. Generate the Package Index
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# 2. Generate a Release file
# This gives your repo a nice name when users run 'apt update'
echo "Origin: Space Bar Labs" > Release
echo "Label: Infrastructure" >> Release
echo "Suite: stable" >> Release
echo "Codename: all" >> Release
echo "Architectures: all" >> Release
echo "Components: main" >> Release
echo "Description: Meta-packages for my setups" >> Release
echo "Date: $(date -Ru)" >> Release

# 3. Create CNAME for Custom Domain
echo "apt.spacebarlabs.com" > CNAME
cp "../index.html" .

echo "✅ APT metadata generated successfully"
