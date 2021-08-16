# Welcome To MassOS
Welcome to **MassOS**, a [free](https://www.gnu.org/philosophy/free-sw.html) GNU/Linux operating system which aims to be small, lightweight and uses the Xfce desktop environment. **It is currently only available for x86_64 and the build scripts will need editing for other architectures.**
# About This Repo
This repo contains the scripts which are used to build the complete MassOS system. Most people won't want to run these. Instead, you can download the latest release tarball of MassOS from the [releases page](https://github.com/TheSonicMaster/MassOS/releases).
# Installing MassOS
Unlike most GNU/Linux distributions, MassOS is not installed from a live CD. Instead, you download the root filesystem tarball and extract/install it manually. The latest release can be found on the [releases page](https://github.com/TheSonicMaster/MassOS/releases). If this seems complicated, don't worry! The [installation guide](https://github.com/TheSonicMaster/MassOS/blob/main/installation-guide.md) has step-by-step instructions on how to install MassOS.
# Releases
Release numbers follow the format **YYYY.MM**. For example: the August 2021 release will be **2021.08**. On a working MassOS system, you can check the version by running `cat /etc/massos-release`. There is a new release of MassOS roughly once every 1-2 months. New releases will usually include updated software. You can upgrade an existing MassOS installation by extracting the updated rootfs tarball over the existing installation, however do note that this may overwrite any system configuration files you've modified, so it's generally easier and safer to do a fresh installation.
# Building MassOS.
MassOS is built entirely using the scripts in this repo. Here's how to build MassOS yourself. **WARNING: At stage 2, the entire MassOS system will be built. This could take hours or even days to complete! Ensure you have enough time available.**
1. Clone the repo:
```
git clone https://github.com/TheSonicMaster/MassOS.git
cd MassOS
```
2. Retrieve the sources:
```
./retrieve-sources.sh
```
3. Build the temporary bootstrap system:
```
./stage1.sh
```
4. Build the full MassOS system (REQUIRES ROOT ACCESS):
```
sudo ./stage2.sh
```
When the MassOS system is completely build and finished, an output tarball labelled **massos-YYYY.MM-rootfs-x86_64.tar.xz** will be created.
