# Scripts

This directory contains scripts extracted from the GitHub Actions CI workflows. These scripts can be run locally for testing and development, and are used by the CI workflows.

## Available Scripts

### `check-packages.sh`

Verifies that all packages referenced in `Depends:` fields exist in Ubuntu repositories.

**Requirements:**
- `apt-cache` must be available
- Package lists should be up-to-date (`sudo apt-get update`)

**Usage:**
```bash
sudo apt-get update
./scripts/check-packages.sh
```

### `lint-packages.sh`

Validates the format of package files in the `packages/` directory.

**Checks:**
- Required `Package:` field exists
- Required `Maintainer:` field exists

**Usage:**
```bash
./scripts/lint-packages.sh
```

### `shellcheck.sh`

Runs ShellCheck on all shell scripts in the repository to check for syntax errors and best practices.

**Requirements:**
- `shellcheck` must be installed (`sudo apt-get install shellcheck`)
- `file` command must be available

**Usage:**
```bash
sudo apt-get install shellcheck
./scripts/shellcheck.sh
```

### `build-packages.sh`

Builds all Debian packages from:
- Flatpak wrappers defined in `flatpaks.txt`
- File-based packages in `packages/`
- Directory-based packages with `DEBIAN/` control directories

**Requirements:**
- `equivs` must be installed (`sudo apt-get install equivs`)
- `dpkg-dev` must be installed (`sudo apt-get install dpkg-dev`)

**Usage:**
```bash
sudo apt-get install equivs dpkg-dev
./scripts/build-packages.sh
```

**Output:** Built `.deb` packages in `dist/` directory

### `generate-apt-index.sh`

Generates APT repository metadata and index files.

**Requirements:**
- Packages must be built first (run `build-packages.sh`)
- `dpkg-scanpackages` must be available

**Usage:**
```bash
# First build packages
./scripts/build-packages.sh

# Then generate index
./scripts/generate-apt-index.sh
```

**Output:** Creates in `dist/`:
- `Packages.gz` - Package index
- `Release` - Repository metadata
- `CNAME` - Custom domain file
- `index.html` - Copy of repository homepage

## Running All Checks Locally

To run all validation checks before pushing:

```bash
# Update package cache
sudo apt-get update

# Install dependencies
sudo apt-get install shellcheck equivs dpkg-dev

# Run all checks
./scripts/lint-packages.sh
./scripts/check-packages.sh
./scripts/shellcheck.sh

# Build packages (optional)
./scripts/build-packages.sh
./scripts/generate-apt-index.sh
```

## CI Integration

These scripts are used by GitHub Actions workflows:

- `.github/workflows/check-packages.yml` - Uses `check-packages.sh`
- `.github/workflows/lint.yml` - Uses `lint-packages.sh`
- `.github/workflows/shellcheck.yml` - Uses `shellcheck.sh`
- `.github/workflows/publish.yml` - Uses `build-packages.sh` and `generate-apt-index.sh`
