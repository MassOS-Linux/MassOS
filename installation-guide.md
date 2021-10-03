# Installation Guide
This guide aims to guide you through the installation of MassOS.
# System Requirements
- At least 8GB of free disk space (16GB recommended).
- At least 1GB of RAM (2GB recommended).
- MassOS must be installed from an existing ("host") GNU/Linux system. If you don't have one installed, you can use another distro's LiveCD instead.
# Release Notes
This is the development version of MassOS. It contains the upcoming changes for the next version of MassOS, however it is subject to change before the final release:

- Added AppStream.
- Use external `dhclient` for DHCP in NetworkManager

It also includes the following upgraded software:

- LLVM/Clang: `12.0.1 --> 13.0.0`
- tzdata: `2021b --> 2021c`

# Downloading The MassOS Rootfs
Due to how frequently the development branch is updated, we do not provide downloadable rootfs tarballs for it.

You can either [Install the stable version](https://github.com/TheSonicMaster/MassOS/blob/main/installation-guide.md), or [Build MassOS yourself](building.md).
# Partitioning the disk
Like every other operating system, MassOS needs to be installed on a partition. Only EXT4 and BTRFS filesystems are currently supported, and only EXT4 has been tested.

You must have a root filesystem of at least 8GB, and must be formatted EXT4 or BTRFS.

You may optionally have a Swap partition. This acts as a backup to prevent the system from crashing if it runs out of memory.

If you're using UEFI, you must also have a small EFI system partition to store the UEFI bootloader files. The EFI system partition must be FAT32. If another operating system uses an existing EFI partition, MassOS can use it too, without conflicting, and you don't need to format it.

You can partition your disks using a command-line partition editor like `fdisk` or a GUI partition editor such as Gparted.
# Formatting the partitions
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
# Mounting the partitions
Create a clean directory for the MassOS partition to be mounted to:
```
sudo mkdir -p /mnt/massos
```
Mount the ext4/btrfs root filesystem:
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
# Installing the base system
Run this command to install the base system onto your MassOS partition:
```
sudo tar -xJpf massos-development-rootfs-x86_64.tar.xz -C /mnt/massos
```
**NOTE: This command will produce no output and the extraction may take a long time on slower systems, so be patient.**
# Generating the /etc/fstab file
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
# Entering the chroot environment
While your system has a built-in `chroot` tool, you should use `mass-chroot` from this repo. It's a wrapper around `chroot` which ensures all virtual kernel file systems are mounted correctly.
```
wget -nc https://raw.githubusercontent.com/TheSonicMaster/MassOS/main/utils/mass-chroot
chmod 755 mass-chroot
sudo ./mass-chroot /mnt/massos
```
# Set the path correctly.
Entering the chroot by default keeps the same PATH as whatever your host system uses. This may be incorrect for MassOS, so set the path correctly now:
```
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin
```
# Setting the system locale and keyboard layout
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
# Setting the timezone
You can run `tzselect` to find your timezone in the *Region/City* format. It will ask you a few questions about where you live, and return your timezone.

Set the timezone with the following command:
```
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
```
For example: For *America/New_York*:
```
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
```
# Setting the hardware clock
```
hwclock --systohc
```
# Setting the root password
Decide on a secure password, and set it with the following command:
```
passwd
```
A combination of letters, numbers and symbols, and 8+ characters is recommended for a secure password. If you can't think of a secure password, running `pwmake 64` will generate a reasonably secure one for you.
# Adding a new user
Adding a separate user is strongly recommended for desktop use since logging in as root means that a single bad action could cause irreversable damage to your system. Add a user with the following interactive program:
```
adduser
```
It will ask you a few questions, including whether the account should be an administrator or not. If you're the main user of the system, you should answer `y` here. By default, administrators are added to the `wheel`, `netdev` and `lpadmin` groups. Users in `wheel` can run commands as root with `sudo`. Users in `netdev` can manage network interfaces and connections with NetworkManager. Users in `lpadmin` can manage printing with CUPS.
# Installing additional firmware
Some hardware, such as wireless or graphics cards, may require non-free firmware "blobs" in order to function properly. If you are the owner of such a device, you can install the most common non-free firmware using the following commands:
```
pushd /usr/lib/firmware
git clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git .
rm -rf .git
popd
```
# Generating the initramfs
An initramfs is a temporary filesystem used to load any necessary drivers and mount the real root filesystem. Generate an initramfs by running this command:
```
dracut --force /boot/initrd.img-5.14.9-massos 5.14.9-massos
```
# Installing the GRUB bootloader
**WARNING: Incorrectly configuring GRUB can leave your system unbootable. Make sure you have a backup boot device available to be able to recover your system in case this happens.**
## Legacy BIOS systems
On legacy systems, run the following command to install the GRUB bootloader, where `X` is your actual hard disk (NOT individual partition):
```
grub-install /dev/sdX
```
No further steps are required for legacy BIOS systems. Proceed to "Generating grub.cfg" below.
## UEFI systems
On UEFI systems, no additional parameters need to be passed. Install GRUB with the following command:
```
grub-install
```
This installs the UEFI bootloader `EFI\massos\grubx64.efi` to the EFI system partition and creates a UEFI bootorder entry called `massos`.

Alternatively (or as well as), you can install GRUB to the fallback location, `EFI\BOOT\BOOTX64.EFI`. This is only needed if you're installing MassOS to a removable drive, or if your UEFI firmware is buggy and doesn't support UEFI bootorder variables. Do not run this if another OS depends on the fallback bootloader:
```
grub-install --removable
```
NOTE: If the installation of GRUB fails, you need to mount `/sys/firmware/efi/efivars` first. Do so by running the following command:
```
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
```
Then re-run the `grub-install` command above.
# Generating grub.cfg
You can customise your GRUB bootloader by editing the `/etc/default/grub` file. Comments in that file explain what the options do. Alternatively, leave it and use the MassOS recommended defaults.

Generate `/boot/grub/grub.cfg` by running the following command:
```
grub-mkconfig -o /boot/grub/grub.cfg
```
# Unmounting and rebooting
If you manually mounted `/sys/firmware/efi/efivars` to be able to successfully install GRUB for UEFI, unmount it before proceeding:
```
umount /sys/firmware/efi/efivars
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
# What next?
For general information on how to make the most out of your new installation, check out the [Post-installation guide](https://github.com/TheSonicMaster/MassOS/blob/main/postinst.md). It contains information on how to do things like install software, customise your desktop, amongst other useful tips.
