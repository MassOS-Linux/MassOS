# Welcome To MassOS
Welcome to **MassOS**, a [free](https://www.gnu.org/philosophy/free-sw.html) GNU/Linux operating system for x86_64 devices, which aims to be minimal and lightweight. It uses the [Xfce](https://xfce.org) desktop environment.
![](massos-desktop-screenshot.png)
The MassOS system itself is under 5 gigabytes. Quite impressive for a GNU/Linux distribution containing a full desktop environment and common programs, as well as development tools/headers. Some distributions are able to achieve minimalism by using smaller replacements for common GNU software, such as musl and busybox, at the cost of some features. With MassOS, you get the minimal size, without compromising the advanced features exclusive to GNU software.
# About This Repo
This repo contains the scripts which are used to build the complete MassOS system. Most people won't want to run these. Instead, you can download the latest release tarball of MassOS from the [releases page](https://github.com/TheSonicMaster/MassOS/releases).
# Is MassOS Based On Any Existing Distro?
No, MassOS is completely independent and compiled from _source_. It does not use a "traditional" package manager (like DPKG or RPM).

The MassOS base system itself already contains a large selection of software which should suit most users. Instead of using a traditional package manager, the universal **Flatpak** package manager (complemented by the GUI Gnome Software centre) can be used to install GUI-based software. Additionally, developer-orientated users may also wish to compile software themselves, since the necessary development tools/headers are retained in the system.
# Installing MassOS
Unlike most GNU/Linux distributions, MassOS is not installed from a live CD. Instead, you download the root filesystem tarball and extract/install it manually. The latest release can be found on the [releases page](https://github.com/TheSonicMaster/MassOS/releases). If this seems complicated, don't worry! The [installation guide](https://github.com/TheSonicMaster/MassOS/blob/development/installation-guide.md) has step-by-step instructions on how to install MassOS.
# Releases
The latest release of MassOS is **2021.09**.

Release numbers follow the format **YYYY.MM**. For example: the August 2021 release will be **2021.08**. On a working MassOS system, you can check the version by running `cat /etc/massos-release`. There is a new release of MassOS roughly once every 1-2 months. New releases will usually include updated software. A new release in the same month as an existing release will be in the format **YYYY.MM.2**. You can upgrade an existing MassOS installation by extracting the updated rootfs tarball over the existing installation, however do note that this may overwrite any system configuration files you've modified, so it's generally easier and safer to do a fresh installation.

Developers who wish to test out some of the latest and greatest in-development features in MassOS can take a look at the [development branch](https://github.com/TheSonicMaster/MassOS/tree/development).
# Building MassOS
MassOS is built entirely using the scripts in this repo. Here's how to build MassOS yourself.

**NOTE: The full MassOS system will take no longer than a few hours on the fastest systems, but may take several days on slower systems! Compiling on a relatively powerful CPU is strongly recommended, and even if you do have a powerful CPU, patience is crucial.**
1. Clone the repo:
```
git clone https://github.com/TheSonicMaster/MassOS.git
cd MassOS
```
By default, you will build the stable version of MassOS. If you instead want to build the *development version*, which contains unreleased changes which are being developed for the next version of MassOS, check out the "development" branch with the following command:
```
git checkout development
```
2. Retrieve the sources:
```
./retrieve-sources.sh
```
3. Build the temporary bootstrap system:
```
./stage1.sh
```
4. Build the full MassOS system (**REQUIRES ROOT ACCESS!**):
```
sudo ./stage2.sh
```
When the MassOS system is completely build and finished, an output tarball labelled `massos-<VERSION>-rootfs-x86_64.tar.xz` will be created. **It is highly recommended that you change ownership of the final output tarball back to the original user. You can do this with the following commands:**
```
non_root_user=$(whoami)
sudo chown $non_root_user:$non_root_user massos-$(cat utils/massos-release)-rootfs-x86_64.tar.xz
unset non_root_user
```
