# Installation Guide
This guide aims to guide you through the installation of MassOS.

**NOTE:** You can upgrade an existing installation of MassOS by using the [Release Upgrade Utility](https://github.com/TheSonicMaster/massos-upgrade).
# System Requirements
- At least 8GB of free disk space (16GB recommended).
- At least 1GB of RAM (2GB recommended).
- MassOS must be installed from an existing ("host") GNU/Linux system. We recommend using another distro's LiveCD (e.g. Ubuntu). The live filesystem must be large enough to download the MassOS image (~1.2GB of free space).
# Release Notes
This is the development version of MassOS. It contains the upcoming changes for the next version of MassOS, however it is subject to change before the final release:

- Added xfsprogs (for XFS filesystem support).
- Fixed AppArmor Python bindings with Python 3.10+.
- Added MassOS ASCII art for Neofetch.
- Added MassOS container tool, which is a utility for creating/managing containers for several GNU/Linux distributions.

It also includes the following upgraded software:

- btrfs-progs: `5.14.2 --> 5.15`
- Firefox: `93.0 --> 94.0.1`
- GLib: `2.70.0 --> 2.70.1`
- gnome-online-accounts: `3.40.0 --> 3.40.1`
- Harfbuzz: `3.0.0 --> 3.1.0`
- HPLIP: `3.21.8 --> 3.21.10`
- IPRoute2: `5.14.0 --> 5.15.0`
- ISO-Codes: `4.7.0 --> 4.8.0`
- libgpg-error: `1.42 --> 1.43`
- Linux Kernel: `5.15.0 --> 5.15.1`
- Poppler: `21.10.0 --> 21.11.0`
- Thunderbird: `91.2.1 --> 91.3.0`
- Tcl: `8.6.11 --> 8.6.12`
- Tk: `8.6.11 --> 8.6.12`
- VTE: `0.66.0 --> 0.66.1`
- Xorg-Server: `1.20.13 --> 21.1.1`

# Installing MassOS Using The Installation Program
Starting from version **2021.11**, MassOS has a guided installation program which can be used to easily install MassOS.

If you'd rather install MassOS manually, skip this section and proceed below to "Installing MassOS Manually"

You can download and run the installer with the following commands:
```
curl -Os https://raw.githubusercontent.com/TheSonicMaster/MassOS/development/massos-installer.sh
chmod 755 massos-installer.sh
sudo ./massos-installer.sh
```
This will walk you through the installation. After the installation is complete, you can restart and boot straight into your new installation of MassOS. You can either graphically restart, or use the following command:
```
sudo shutdown -r now
```
## What next?
For general information on how to make the most out of your new installation, check out the [Post-installation guide](https://github.com/TheSonicMaster/MassOS/blob/main/postinst.md). It contains information on how to do things like install software, customise your desktop, amongst other useful tips.
## Installation Program Notes
- Advanced options like setting up swap space or using non-ext4 filesystems are not yet supported by the installer. If you require these, install MassOS manually, as shown below.
- By default, the program will download and install the stable version of MassOS. If you want to install a development branch build, or another custom build of MassOS, you must pass the custom rootfs image as an argument to `massos-installer.sh`, e.g. `sudo ./massos-installer.sh /path/to/my/custom/package.tar.xz`. Due to how frequently the development branch is updated, we do not provide downloadable rootfs tarballs for it. If you must install a development branch build, you may [build MassOS yourself](building.md).
# Installing MassOS Manually
While the installation program is great for most users, you may want to install MassOS manually to be able to fine-tweak your installation or use custom options which the installation program doesn't support, such as swap or non-ext4 filesystems.
## Downloading The MassOS Rootfs
Due to how frequently the development branch is updated, we do not provide downloadable rootfs tarballs for it.

You can either [install the stable version](https://github.com/TheSonicMaster/MassOS/blob/main/installation-guide.md) or [build MassOS yourself](building.md).
## Partitioning the disk
Like every other operating system, MassOS needs to be installed on a partition. Only EXT4, BTRFS and XFS filesystems are currently supported, and only EXT4 has been tested.

You must have a root filesystem of at least 8GB, and must be formatted EXT4, BTRFS or XFS.

You may optionally have a Swap partition. This acts as a backup to prevent the system from crashing if it runs out of memory.

If you're using UEFI, you must also have a small EFI system partition to store the UEFI bootloader files. The EFI system partition must be FAT32. If another operating system uses an existing EFI partition, MassOS can use it too, without conflicting, and you don't need to format it.

You can partition your disks using a command-line partition editor like `fdisk` or a GUI partition editor such as Gparted.
## Formatting the partitions
To format the root filesystem, run the following command, replacing `XY` with your actual partition, such as `a1` for `/dev/sda1`:
```
sudo mkfs.ext4 /dev/sdXY
```
If you chose to create a swap partition, format this too:
```
sudo mkswap /dev/sdXY
```
If you're using UEFI and don't have an existing EFI system partition, format the new one:
```
sudo mkfs.fat -F32 /dev/sdXY
```
**Do NOT run this command if you have an existing ESP used by another OS!**
## Mounting the partitions
Create a clean directory for the MassOS partition to be mounted to:
```
sudo mkdir -p /mnt/massos
```
Mount the ext4/btrfs/xfs root filesystem:
```
sudo mount /dev/sdXY /mnt/massos
```
If you're using a swap partition, enable it:
```
sudo swapon /dev/sdXY
```
If you're using UEFI, create the necessary directory and mount the ESP:
```
sudo mkdir -p /mnt/massos/boot/efi
sudo mount /dev/sdXY /mnt/massos/boot/efi
```
## Installing the base system
Run this command to install the base system onto your MassOS partition:
```
sudo tar -xJpf massos-development-rootfs-x86_64.tar.xz -C /mnt/massos
```
**NOTE: This command will produce no output and the extraction may take a long time on slower systems, so be patient.**
## Generating the /etc/fstab file
The `/etc/fstab` file contains a list of filesystems to be automounted on boot.

You must edit the `/mnt/massos/etc/fstab` file and enter the correct entries for your partitions. For each partition you need, uncomment the line beginning `UUID=`, and then replace the placeholder `x` characters with the UUID of your disk. **You can use `sudo blkid` to view the UUIDs of partitions.**

An example /etc/fstab file for a Legacy system without swap might look like this (notice how only the partitions needed have the UUID line uncommented):
```
# Root filesystem:
UUID=539db496-6dfc-4c80-91b6-11cd278ba43c / ext4 defaults 1 1

# Swap (optional):
#UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx swap swap pri=1 0 0

# EFI system (UEFI only):
#UUID=xxxx-xxxx /boot/efi vfat umask=0077 0 1
```
An example /etc/fstab file for a UEFI system with swap might look like this:
```
# Root filesystem:
UUID=539db496-6dfc-4c80-91b6-11cd278ba43c / ext4 defaults 1 1

# Swap (optional):
UUID=6d31d057-df1e-4784-a287-019b310992a8 swap swap pri=1 0 0

# EFI system (UEFI only):
UUID=2712-B165 /boot/efi vfat umask=0077 0 1
```
When you're finished, save and close the file. It may be worth double-checking you're entries are correct by running `cat /mnt/massos/etc/fstab` to view them. Mistakes in this file could prevent your system from booting.
## Entering the chroot environment
While your system has a built-in `chroot` tool, you should use `mass-chroot` from this repo. It's a wrapper around `chroot` which ensures all virtual kernel file systems are mounted correctly.
```
wget -nc https://raw.githubusercontent.com/TheSonicMaster/MassOS/main/utils/mass-chroot
chmod 755 mass-chroot
sudo ./mass-chroot /mnt/massos
```
## Set the path correctly.
Entering the chroot by default keeps the same PATH as whatever your host system uses. This may be incorrect for MassOS, so set the path correctly now:
```
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin
```
## Setting the system locale and keyboard layout
A list of locales can be found in the `/etc/locales` file. Edit this file using `nano` or `vim`, and uncomment the lines of any locales you need. Note that if you're a US user that only requires the `en_US.UTF-8` locale, you don't need to edit this file since `en_US.UTF-8` is uncommented by default.

Generate the locales by running the following command:
```
mklocales
```
If you require the default locale to be something other than `en_US.UTF-8`, edit the `/etc/locale.conf` file and replace `LANG=en_US.UTF-8` with your desired locale.

The default keyboard layout is `us`, which is ideal for US residents. If you require a different layout, edit `/etc/vconsole.conf` and replace `KEYMAP=us` with any other keymap. A full list of available keymaps can be found with the following command:
```
ls /usr/share/keymaps/i386/qwerty | sed 's/.map.gz//'
```
For example: The keymap for British users is `uk`, so the entry would be `KEYMAP=uk`.
## Setting the timezone
You can run `tzselect` to find your timezone in the *Region/City* format. It will ask you a few questions about where you live, and return your timezone.

Set the timezone with the following command:
```
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
```
For example: For *America/New_York*:
```
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
```
## Setting the hardware clock
```
hwclock --systohc
```
## Setting the root password
Decide on a secure password, and set it with the following command:
```
passwd
```
A combination of letters, numbers and symbols, and 8+ characters is recommended for a secure password. If you can't think of a secure password, running `pwmake 64` will generate a reasonably secure one for you.
## Adding a new user
Adding a separate user is strongly recommended for desktop use since logging in as root means that a single bad action could cause irreversable damage to your system. Add a user with the following interactive program:
```
adduser
```
It will ask you a few questions, including whether the account should be an administrator or not. If you're the main user of the system, you should answer `y` here. By default, administrators are added to the `wheel`, `netdev` and `lpadmin` groups. Users in `wheel` can run commands as root with `sudo`. Users in `netdev` can manage network interfaces and connections with NetworkManager. Users in `lpadmin` can manage printing with CUPS.
## Enabling Bluetooth support
If your machine supports Bluetooth, the **Blueman** graphical utility and applet can help you manage it in the graphical environment. If you wish for the Blueman system tray applet to be auto-started when you login to the desktop, run the following command:
```
blueman-autostart enable
```
You don't need to (and probably shouldn't) run this command if your system does not support Bluetooth, or you wish not to use Bluetooth capability. If you previously enabled it and now want to disable it, simply replace `enable` with `disable` in the above command.
## Installing additional firmware
Some hardware, such as wireless or graphics cards, may require non-free firmware "blobs" in order to function properly. If you are the owner of such a device, you can install the most common non-free firmware using the following commands:
```
pushd /usr/lib/firmware
git clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git .
rm -rf .git
popd
```
### Adding support for CPU Microcode.
Modern Intel and AMD CPUs support Microcode. While they are usually loaded by the system's BIOS firmware, loading it in the operating system can allow you to have updated versions which the BIOS may not have.

**Loading Microcode in the operating system is not required, the system should still be functional without it.**

If you have an AMD CPU, the above commands to install non-free firmware will automatically install the AMD Microcode firmware.

If you have an Intel CPU, you must install the CPU microcode manually, by running these commands:
```
MVER=20210608
pushd /tmp
wget https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files/archive/microcode-$MVER.tar.gz
tar -xf microcode-$MVER.tar.gz
install -d /usr/lib/firmware/intel-ucode
install -m644 Intel-Linux-Processor-Microcode-Data-Files-microcode-$MVER/intel-ucode{,-with-caveats}/* /usr/lib/firmware/intel-ucode
rm -rf Intel-Linux-Processor-Microcode-Data-Files-microcode-$MVER microcode-$MVER.tar.gz
popd
unset MVER
```
## Generating the initramfs
An initramfs is a temporary filesystem used to load any necessary drivers and mount the real root filesystem. Generate an initramfs by running this command:
```
mkinitramfs 5.15.1-massos
```
If you installed firmware and/or Microcode at the above step, this command will automatically include them when generating the initramfs.
## Installing the GRUB bootloader
**WARNING: Incorrectly configuring GRUB can leave your system unbootable. Make sure you have a backup boot device available to be able to recover your system in case this happens.**
### Legacy BIOS systems
On legacy systems, run the following command to install the GRUB bootloader, where `X` is your actual hard disk (NOT individual partition):
```
grub-install /dev/sdX
```
No further steps are required for legacy BIOS systems. Proceed to "Generating grub.cfg" below.
### UEFI systems
**NOTE: Secure Boot must be disabled in the UEFI firmware settings to be able to boot MassOS.**

On UEFI systems, you must first make sure `/sys/firmware/efi/efivars` is mounted in the chroot environment. If it isn't, the `grub-install` command below will fail:
```
mountpoint -q /sys/firmware/efi/efivars || (mount -t efivarfs efivarfs /sys/firmware/efi/efivars && touch /tmp/beforemounted)
```
Now install GRUB with the following command:
```
grub-install
```
This installs the UEFI bootloader `EFI\massos\grubx64.efi` to the EFI system partition and creates a UEFI bootorder entry called `massos`.

Alternatively (or as well as), you can install GRUB to the fallback location, `EFI\BOOT\BOOTX64.EFI`. This is only needed if you're installing MassOS to a removable drive, or if your UEFI firmware is buggy and doesn't support UEFI bootorder variables. Do not run this if another OS depends on the fallback bootloader:
```
grub-install --removable
```
## Generating grub.cfg
You can customise your GRUB bootloader by editing the `/etc/default/grub` file. Comments in that file explain what the options do. Alternatively, leave it and use the MassOS recommended defaults.

Generate `/boot/grub/grub.cfg` by running the following command:
```
grub-mkconfig -o /boot/grub/grub.cfg
```
## Unmounting and rebooting
First unmount `/sys/firmware/efi/efivars` if it was manually mounted at the "Installing the GRUB bootloader":
```
test ! -f /tmp/beforemounted || (umount /sys/firmware/efi/efivars && rm -f /tmp/beforemounted)
```
Exit the chroot:
```
exit
```
Now, unmount the filesystems:
```
sudo umount -R /mnt/massos
```
Optionally remove the mountpoint directory:
```
sudo rmdir /mnt/massos
```
Now reboot your system, either graphically or with the following command:
```
sudo shutdown -r now
```
Congratulations, MassOS is installed! We hope you enjoy your MassOS experience!
## What next?
For general information on how to make the most out of your new installation, check out the [Post-installation guide](https://github.com/TheSonicMaster/MassOS/blob/main/postinst.md). It contains information on how to do things like install software, customise your desktop, amongst other useful tips.
