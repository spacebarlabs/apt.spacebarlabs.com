# apt.spacebarlabs.com

Debian packages.  Meta packages to make it easy to install preferred tools on Debian-based machines.

## Usage

```bash
echo "deb [trusted=yes] https://apt.spacebarlabs.com/ ./" | sudo tee /etc/apt/sources.list.d/spacebarlabs.list
sudo apt update
```

Then pick a package to install, such as:

```bash
sudo apt install sbl-full
```
