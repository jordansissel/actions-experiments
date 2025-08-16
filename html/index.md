---
layout: home
title: Package Repository Configuration
---

Table of Contents:

* [Debian and Ubuntu](#debian-and-ubuntu)
* [Fedora and Rocky Linux](#fedora-and-rocky-linux)

# Debian and Ubuntu

## Install the repository public key

You will need to download the [public GPG key](packages/repository.asc) and store it on your system as `/usr/share/keyrings/fpm-archive-keyring.pgp`.

To achieve this, the following script can be copied into a terminal. The script requires `curl`, `gpg`, and `sudo` to be available.

```
curl -Ls https://jordansissel.github.io/actions-experiments/packages/repository.asc | gpg --dearmor | sudo tee /usr/share/keyrings/fpm-archive-keyring.pgp > /dev/null
```

## Add the repository to apt

```
sudo tee /etc/apt/sources.list.d/fpm.sources <<SOURCES > /dev/null
Types: deb
URIs: https://jordansissel.github.io/actions-experiments/packages/$(sed -rne 's/^ID="?([^"]+)"?$/\1/p' /etc/os-release)
Suites: $(sed -rne 's/^VERSION_CODENAME="?([^"]+)"?$/\1/p' /etc/os-release)
Components: main
Signed-By: /usr/share/keyrings/fpm-archive-keyring.pgp
SOURCES
```

## Add a pinning configuration

This pin configuration should prevent this repository from providing packages that override anything in the base OS.

```
sudo tee /etc/apt/preferences.d/fpm.pref <<PREFS > /dev/null
Package: *
Pin: origin jordansissel.github.io
Pin-Priority: 100
PREFS
```

# Fedora and Rocky Linux

You may download the dnf/yum repo configuration or use the installation recipe below:

## Yum/DNF Repo files

* [Fedora](fedora.repo)
* [Rocky](rocky.repo)

## Full Installation Recipe

Install the `dnf config-manager` plugin:

```
sudo dnf install -y dnf-plugins-core
```

Add the package repository:

```
distro="$(sed -rne 's/^ID="?([^"]+)"?/\1/p' /etc/os-release)"
sudo dnf config-manager addrepo --from-repofile=https://jordansissel.github.io/actions-experiments/${distro}.repo
```

Install fpm:

```
sudo dnf install fpm
```

