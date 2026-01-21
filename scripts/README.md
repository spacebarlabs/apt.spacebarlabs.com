# CI Scripts

This directory contains scripts that are used by GitHub Actions CI workflows. These scripts can also be run locally for testing and development.

## Scripts

### lint.sh
Validates package files have required fields (Package and Maintainer).

**Usage:**
```bash
./scripts/lint.sh
```

### check-packages.sh
Verifies that all packages referenced in Depends fields exist in Ubuntu repositories.

**Prerequisites:**
- Update apt cache: `sudo apt-get update`

**Usage:**
```bash
./scripts/check-packages.sh
```

### build-packages.sh
Builds Debian packages from configuration files in the `packages/` directory.

**Prerequisites:**
- Install build tools: `sudo apt-get install -y equivs dpkg-dev`

**Usage:**
```bash
./scripts/build-packages.sh
```

**Output:**
- Built packages are placed in the `dist/` directory

### generate-apt-metadata.sh
Generates APT repository metadata files (Packages.gz, Release, CNAME, etc.) in the `dist/` directory.

**Prerequisites:**
- Build packages first using `build-packages.sh`

**Usage:**
```bash
./scripts/generate-apt-metadata.sh
```

**Output:**
- `dist/Packages.gz` - Package index
- `dist/Release` - Repository metadata
- `dist/CNAME` - Custom domain configuration
- `dist/index.html` - Repository homepage

## Testing Locally

To test the complete build and publish workflow locally:

```bash
# 1. Install build tools
sudo apt-get update
sudo apt-get install -y equivs dpkg-dev

# 2. Validate package files
./scripts/lint.sh

# 3. Check package dependencies
./scripts/check-packages.sh

# 4. Build packages
./scripts/build-packages.sh

# 5. Generate APT metadata
./scripts/generate-apt-metadata.sh

# 6. Verify the output
ls -la dist/
```

## CI Integration

These scripts are used by the following GitHub Actions workflows:

- `.github/workflows/lint.yml` - Uses `lint.sh`
- `.github/workflows/check-packages.yml` - Uses `check-packages.sh`
- `.github/workflows/publish.yml` - Uses `build-packages.sh` and `generate-apt-metadata.sh`
