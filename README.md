# apt.spacebarlabs.com

Debian packages.  Meta packages to make it easy to install preferred tools on Debian-based machines.

## Usage

### Initial Setup (Bootstrap)

To use packages from apt.spacebarlabs.com, first install the repository configuration package:

```bash
# Download and install the repository configuration package
wget -qO /tmp/sbl-apt-repos.deb https://apt.spacebarlabs.com/sbl-apt-repos.deb
sudo apt install -y /tmp/sbl-apt-repos.deb
rm /tmp/sbl-apt-repos.deb

# Update package lists to see newly available packages
sudo apt update
```

This bootstrap package (`sbl-apt-repos`) configures APT repositories for all Space Bar Labs dependencies.

### Installing Packages

After the initial setup, you can install any Space Bar Labs package:

```bash
# Install CLI utilities (includes mise and other tools)
sudo apt install -y sbl-cli-utils

# Or install the full suite
sudo apt install -y sbl-full
```

### Upgrading

To upgrade all installed packages:

```bash
sudo apt update
sudo apt upgrade
```
