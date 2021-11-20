#!/bin/bash
#
# MassOS guided installation program.
# Copyright (C) 2021 The Sonic Master.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Ensure we are root.
if [ $EUID -ne 0 ]; then
  echo "Error: $(basename $0) must be run as root." >&2
  exit 1
fi
# Detect download tool.
which curl &>/dev/null
if [ $? -eq 0 ]; then
  dltool="curl"
else
  which wget &>/dev/null
  if [ $? -eq 0 ]; then
    dltool="wget"
  else
    echo "Neither curl nor wget was found. Please install one of them." >&2
    exit 1
  fi
fi
# Check for a UEFI system.
if [ -e /sys/firmware/efi/systab ]; then
  efisys="y"
else
  efisys="n"
fi
# Unmount and cleanup anything from previous installations.
umount -R /var/tmp/massos-install* &>/dev/null || true
rm -rf /var/tmp/massos-{dl,install}*
# Welcome message.
echo "Welcome to MassOS! This program will guide you through the installation."
# Check if a custom MassOS rootfs image is specified
if [ ! -z "$1" ]; then
  if [ ! -f "$1" ]; then
    printf "\nError: Specified rootfs image $1 does not exist.\n" >&2
    exit 1
  elif [ $(file -b "$1" | cut -d" " -f1) != "XZ" ]; then
    printf "\nError: Specified rootfs image $1 is not valid.\n" >&2
    exit 1
  else
    printf "\nYou have specified a custom MassOS rootfs image, $1.\n"
    echo "This will be used instead of downloading the latest version."
    read -p "Is this OK? [Y/n] " ok_custom_pkg
    ok_custom_pkg="${ok_custom_pkg:0:1}"
    ok_custom_pkg=$(echo "$ok_custom_pkg" | tr '[:upper:]' '[:lower:]')
    if [ "$ok_custom_pkg" = "n" ]; then
      exit 1
    fi
    custompkg="yes"
  fi
else
  custompkg="no"
fi
# Select the install disk.
printf "\nDisks available on your system:\n\n"
fdisk -l | grep "Disk /dev" | sed '/loop/d' | cut -d"," -f1
printf "\n"
read -p "Which disk do you wish to partition for MassOS? (e.g. /dev/sda) " disk
if [ ! -b "$disk" ]; then
  echo "Error: $disk is not a valid disk." >&2
  exit 1
fi
# Check if the disk has any mounted partitions.
mount | grep "$disk" &>/dev/null
if [ $? -eq 0 ]; then
  printf "\nSelected disk $disk has mounted partitions.\n" >&2
  echo "All partitions must be unmounted before I can work on it." >&2
  read -p "Press ENTER to continue, and I'll try to unmount them for you: "
  umount "$disk*" &>/dev/null
  # Check if they're still mounted (in case the operation failed).
  mount | grep "$disk" &>/dev/null
  if [ $? -eq 0 ]; then
    echo "Error: Could not unmount all partitions. Please unmount them" >&2
    echo "manually, or restart the installer and choose another disk." >&2
    exit 1
  fi
fi
# Option 1 (below).
option_1() {
  printf "\nWARNING: THE ENTIRE DISK $disk WILL BE ERASED!\n"
  read -p "Are you sure you want to continue [y/N] " confirmerase
  confirmerase="${confirmerase:0:1}"
  confirmerase=$(echo "$confirmerase" | tr '[:upper:]' '[:lower:]')
  if [ "$confirmerase" != "y" ]; then
    exit 1
  fi
  printf "Writing zeroes to the start of $disk... "
  dd if=/dev/zero of="$disk" bs="4M" count=1 &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Failed!"
    echo "Error erasing the disk $disk." >&2
    exit 1
  fi
  echo "Done!"
  if [ "$efisys" = "y" ]; then
    # Create a 100M EFI system partition and give the rest to root.
    operations='g\nn\n\n\n+100M\nt\n1\nn\n\n\n\nw\n'
  else
    # Just create the root partition.
    operations='o\nn\n\n\n\n\nw\n'
  fi
  # Create the partitions.
  printf "Creating partitions on $disk... "
  echo -e "$operations" | fdisk "$disk" &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Failed!"
    echo "Error creating the partitions on disk $disk." >&2
    exit 1
  fi
  echo "Done!"
  if [ "$efisys" != "y" ]; then
    rootpar="$(fdisk -l "$disk" | tail -n1 | cut -d" " -f1)"
    printf "Formatting $rootpar as Linux ext4... "
    yes | mkfs.ext4 "$rootpar" &>/dev/null
    if [ $? -ne 0 ]; then
      echo "Failed!"
      echo "Error formatting $rootpar as Linux ext4." >&2
      exit 1
    fi
    echo "Done!"
  else
    efipar="$(fdisk -l "$disk" | tail -n2 | head -n1 | cut -d" " -f1)"
    rootpar="$(fdisk -l "$disk" | tail -n1 | cut -d" " -f1)"
    printf "Formatting EFI system partition $efipar as FAT32... "
    mkfs.fat -F32 "$efipar" &>/dev/null
    if [ $? -ne 0 ]; then
      echo "Failed!"
      echo "Error formatting $efipar as FAT32." >&2
      exit 1
    fi
    echo "Done!"
    printf "Formatting $rootpar as Linux ext4... "
    yes | mkfs.ext4 "$rootpar" &>/dev/null
    if [ $? -ne 0 ]; then
      echo "Failed!"
      echo "Error formatting $rootpar as Linux ext4." >&2
      exit 1
    fi
    echo "Done!"
  fi
}
# Option 2 (below).
option_2() {
  printf "Available partitions:\n\n"
  fdisk -l "$disk"
  printf "\n"
  read -p "Which partition do I format for MassOS? (e.g. /dev/sda1) " rootpar
  if [ ! -b "$rootpar" ]; then
    echo "Error: $rootpar is not a valid partition." >&2
    exit 1
  fi
  if [ "$efisys" = "y" ]; then
    echo "We also need a ~100M EFI system partition. I won't format this, but"
    echo "it must be a FAT32 partition, to be able to boot in UEFI mode."
    printf "It must NOT be the same as the root partition selected above.\n\n"
    read -p "Which partition should I use for the EFI system? " efipar
    if [ ! -b "$efipar" ]; then
      echo "Error: $efipar is not a valid partition." >&2
      exit 1
    elif [ "$efipar" = "$rootpar" ]; then
      echo "Error: EFI system partition MUST differ from root partition." >&2
      exit 1
    fi
  fi
  echo "WARNING: ALL DATA ON PARTITION $rootpar WILL BE LOST."
  read -p "Are you sure you want to continue [y/N] " confirmform
  confirmform="${confirmform:0:1}"
  confirmform=$(echo "$confirmform" | tr '[:upper:]' '[:lower:]')
  if [ "$confirmform" != "y" ]; then
    exit 1
  fi
  printf "Formatting $rootpar as Linux ext4... "
  yes | mkfs.ext4 "$rootpar" &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Failed!"
    echo "Error formatting $rootpar as Linux ext4." >&2
    exit 1
  fi
  echo "Done!"
}
# Decide what to do.
printf "\nPossible partitioning methods for this disk:\n\n"
echo "1) Erase the disk and install MassOS."
echo "2) Install MassOS to an existing partition."
printf "3) Manually create/modify partitions (and then invoke option 2).\n\n"
read -p "Please enter your choice (0 to abort): " method
method="${method:0:1}"
if [ "$method" = "1" ]; then
  option_1
elif [ "$method" = "2" ]; then
  printf "\n"
  option_2
elif [ "$method" = "3" ]; then
  printf "\nPress ENTER to open the partition manager. The installer will\n"
  read -p "automatically continue when you've finished partitioning: "
  cfdisk "$disk"
  # Now go to option 2.
  option_2
elif [ "$method" = "0" ]; then
  printf "\nInstallation aborted. No changes were made to your system.\n" >&2
  exit 1
else
  printf "\nAn invalid option was provided. Aborting installation.\n" >&2
  exit 1
fi
# Exit on error from here on.
set -e
# Mount partitions.
printf "\nMounting partitions... "
mountdir="/var/tmp/massos-install$(date "+%Y%m%d%H%M%S")"
mkdir -p "$mountdir"
mount "$rootpar" "$mountdir"
if [ "$efisys" = "y" ]; then
  mkdir -p "$mountdir"/boot/efi
  mount "$efipar" "$mountdir"/boot/efi
fi
echo "Done!"
# Download MassOS rootfs image.
if [ "$custompkg" != "yes" ]; then
  if [ "$dltool" = "curl" ]; then
    ver="$(curl -s https://raw.githubusercontent.com/TheSonicMaster/MassOS/main/utils/massos-release)"
    echo "Downloading rootfs image for MassOS version $ver..."
    curl -L "https://github.com/TheSonicMaster/MassOS/releases/download/v$ver/massos-$ver-rootfs-x86_64.tar.xz" -o "$mountdir"/massos.tar.xz
  else
    ver="$(wget -q https://raw.githubusercontent.com/TheSonicMaster/MassOS/main/utils/massos-release -O -)"
    echo "Downloading rootfs image for MassOS version $ver..."
    wget "https://github.com/TheSonicMaster/MassOS/releases/download/v$ver/massos-$ver-rootfs-x86_64.tar.xz" -O "$mountdir"/massos.tar.xz
  fi
fi
# Extract MassOS rootfs image to the target root partition.
printf "Installing MassOS to the target partition (may take a while)... "
if [ "$custompkg" = "yes" ]; then
  tar -xJpf "$1" -C "$mountdir"
else
  tar -xJpf "$mountdir"/massos.tar.xz -C "$mountdir"
fi
echo "Done!"
# Get filesystem UUIDs.
rootuuid="$(blkid -o value -s UUID "$rootpar")"
if [ "$efisys" = "y" ]; then
  efiuuid="$(blkid -o value -s UUID "$efipar")"
fi
# Write /etc/fstab.
echo "# Automatically generated by MassOS installer." > "$mountdir"/etc/fstab
echo "UUID=$rootuuid / ext4 defaults 1 1" >> "$mountdir"/etc/fstab
if [ "$efisys" = "y" ]; then
  echo "UUID=$efiuuid /boot/efi vfat umask=0077 0 1" >> "$mountdir"/etc/fstab
fi
# Will be used during in-chroot setup.
export efisys disk
# Write the in-chroot setup script.
cat > "$mountdir"/tmp/massos-installer-stage2.sh << "END"
#!/bin/bash
#
# MassOS guided installation program.
# Copyright (C) 2021 The Sonic Master.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Ensure we are root.
if [ $EUID -ne 0 ]; then
  echo "Error: $(basename $0) must be run as root." >&2
  exit 1
fi
# Set path correctly.
export PATH=/usr/bin:/usr/sbin
# Setup locales.
echo "The default system locale is en_US.UTF-8 (US English)."
read -p "Would you like to one or more custom locale(s)? [y/N] " localechoice
localechoice="${localechoice:0:1}"
localechoice=$(echo "$localechoice" | tr '[:upper:]' '[:lower:]')
if [ "$localechoice" = "y" ]; then
  echo "I will now open /etc/locales in the 'nano' text editor. Use this to"
  echo "uncomment any extra locales you need. When you're done, save the file"
  printf "and exit the editor (by pressing Ctrl+S followed by Ctrl+X).\n\n"
  read -p "Press ENTER to open the editor now: "
  nano /etc/locales
fi
mklocales
if [ "$localechoice" = "y" ]; then
  printf "\nYour installed locales are the following:\n\n"
  cat /etc/locales | sed '/#/d' | cut -d" " -f1
  printf "\nType the locale which you'd like to make the system default, or\n"
  read -p "press ENTER without entering anything to keep as en_US.UTF-8: " loc
  # Ignore if previously set.
  unset changedlocale
  if [ ! -z "$loc" ]; then
    for i in $(cat /etc/locales | sed '/#/d' | cut -d" " -f1); do
      if [ "$loc" = "$i" ]; then
        echo "LANG=$loc" > /etc/locale.conf
        echo "$loc was set as the default system locale."
        changedlocale="y"
      fi
    done
  fi
  if [ "$changedlocale" != "y" ]; then
    echo "Default system locale was kept as en_US.UTF-8."
  fi
fi
# Setup keyboard layout.
printf "\nThe default console keymap is 'us', which is ideal for US users.\n"
read -p "Would you like to change this? [y/N] " keymapchoice
keymapchoice="${keymapchoice:0:1}"
keymapchoice=$(echo "$keymapchoice" | tr '[:upper:]' '[:lower:]')
if [ "$keymapchoice" = "y" ]; then
  printf "Here are the available keymaps:\n\n"
  ls /usr/share/keymaps/i386/qwerty | sed 's/.map.gz//' | column
  printf "\nType the keymap which you'd like to make the system default, or\n"
  read -p "press ENTER without entering anything to keep as 'us': " keymap
  # Ignore if previously set.
  unset changedkeymap
  if [ ! -z "$keymap" ]; then
    for i in $(ls /usr/share/keymaps/i386/qwerty | sed 's/.map.gz//'); do
      if [ "$keymap" = "$i" ]; then
        echo "KEYMAP=$keymap" > /etc/vconsole.conf
        printf "\n$keymap was set as the default system keymap.\n"
        changedkeymap="y"
      fi
    done
  fi
  if [ "$changedkeymap" != "y" ]; then
    printf "\nDefault system keymap was kept as 'us'.\n"
  fi
fi
# Setup timezone.
printf "\n"
timezone="$(tzselect | tail -n1)"
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc
# Set root password.
printf "\nNow setting the root password. For best security, please use a\n"
printf "mix of letters, numbers and symbols which is not easily guessable.\n\n"
return=1
while [ $return = 1 ]; do
  passwd
  if [ $? -ne 0 ]; then
    return=1
  else
    return=0
  fi
done
# Add a new user.
printf "\nI will now add a new account for the primary user. You can add any\n"
printf "additional users later by running 'adduser'.\n\n"
return=1
while [ $return = 1 ]; do
  adduser
  if [ $? -ne 0 ]; then
    return=1
  else
    return=0
  fi
done
# Exit on error from here on.
set -e
# Decide whether to install some additional wallpapers.
printf "\nMassOS already includes a selection of background images, however\n"
echo "an optional collection of 30 extra landscape wallpapers are available."
printf "Downloading and installing these will take ~80 MiB of disk space.\n\n"
read -p "Would you like to download and install them now? [y/N] " wpchs
wpchs="${wpchs:0:1}"
wpchs=$(echo "$wpchs" | tr '[:upper:]' '[:lower:]')
if [ "$wpchs" = "y" ]; then
  for i in 1 2 3 4 5 6; do
    curl -o /tmp/wp-$i.tar.zst -L \
    https://cdn.thesonicmaster.net/wallpapers/MassOS-Wallpapers-Pack$i.tar.zst
  done
  for i in 1 2 3 4 5 6; do
    tar --no-same-owner --strip-components=1 -xf /tmp/wp-$i.tar.zst -C \
    /usr/share/backgrounds/xfce
  done
  rm -f /tmp/wp-{1,2,3,4,5,6}.tar.zst
fi
# Decide whether Bluetooth shall be autostarted on boot.
printf "\nIf your system supports Bluetooth, the Blueman graphical utility\n"
echo "and applet can help you manage it in a graphical environment. Note that"
echo "you don't need to (and probably shouldn't) enable this if your system"
printf "does not support Bluetooth.\n\n"
read -p "Would you like Blueman to be autostarted on login? [y/N] " bmanchoice
bmanchoice="${bmanchoice:0:1}"
bmanchoice=$(echo "$bmanchoice" | tr '[:upper:]' '[:lower:]')
if [ "$bmanchoice" = "y" ]; then
  blueman-autostart enable
fi
# Decide whether to install additional firmware.
printf "\nSome hardware, such as wireless or graphics cards, may require\n"
echo "non-free firmware 'blobs' in order to function properly. If you answer"
echo "'y' here, the latest non-free firmware will be downloaded and installed."
printf "This requires ~660 MiB of disk space.\n\n"
read -p "Would you like to download and install the firmware now? [y/N] " nonfr
nonfr="${nonfr:0:1}"
nonfr=$(echo "$nonfr" | tr '[:upper:]' '[:lower:]')
if [ "$nonfr" = "y" ]; then
  git clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git /usr/lib/firmware
  rm -rf /usr/lib/firmware/.git
  MVER=$(curl -s https://raw.githubusercontent.com/TheSonicMaster/MassOS/main/installation-guide.md | grep "MVER=" | cut -d'=' -f2)
  curl -L https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files/archive/microcode-$MVER.tar.gz -o /tmp/mcode.tar.gz
  mkdir /tmp/mcode
  tar -xf /tmp/mcode.tar.gz -C /tmp/mcode --strip-components=1
  install -d /usr/lib/firmware/intel-ucode
  install -m644 /tmp/mcode/intel-ucode{,-with-caveats}/* /usr/lib/firmware/intel-ucode
  rm -rf /tmp/mcode{,.tar.gz}
  unset MVER
fi
# Generate initramfs.
printf "\n"
KVER="$(ls /usr/lib/modules)"
mkinitramfs "$KVER"
unset KVER
# Install GRUB bootloader.
printf "\n"
if [ "$efisys" = "y" ]; then
  # Ensure /sys/firmware/efi/efivars is mounted for grub-install to wprk.
  mountpoint -q /sys/firmware/efi/efivars || (mount -t efivarfs efivarfs /sys/firmware/efi/efivars && touch /tmp/beforemounted)
  read -p "Are you installing MassOS to a removable drive? [y/N] " removable
  removable="${removable:0:1}"
  removable=$(echo "$removable" | tr '[:upper:]' '[:lower:]')
  if [ "$removable" = "y" ]; then
    echo "Running 'grub-install --removable'..."
    grub-install --removable
  else
    echo "Running 'grub-install'..."
    grub-install
  fi
else
  echo "Running 'grub-install $disk'..."
  grub-install "$disk"
fi
printf "\nWe now need to generate the GRUB configuration file. If you wish,\n"
echo "you may customise your GRUB config by editing '/etc/default/grub'."
printf "Replying with 'n' will leave it as is and use the MassOS defaults.\n\n"
read -p "Would you like to edit '/etc/default/grub'? [y/N] " editgrubcfg
editgrubcfg="${editgrubcfg:0:1}"
editgrubcfg=$(echo "$editgrubcfg" | tr '[:upper:]' '[:lower:]')
if [ "$editgrubcfg" = "y" ]; then
  printf "\n'/etc/default/grub' will now be opened in text editor 'nano'.\n"
  echo "When you're done, save and exit (by pressing Ctrl+S, then Ctrl+X)."
  read -p "Press ENTER to open the editor now: "
  nano /etc/default/grub
fi
printf "\nRunning 'grub-mkconfig -o /boot/grub/grub.cfg'...\n"
grub-mkconfig -o /boot/grub/grub.cfg
printf "\n"
# Unmount /sys/firmware/efi/efivars if we had to manually mount it earlier.
test ! -f /tmp/beforemounted || (umount /sys/firmware/efi/efivars && rm -f /tmp/beforemounted)
exit 0
END
chmod 755 "$mountdir"/tmp/massos-installer-stage2.sh
"$mountdir"/usr/sbin/mass-chroot "$mountdir" /tmp/massos-installer-stage2.sh
printf "\nUnmounting filesystems and cleaning up... "
umount -R "$mountdir"
rm -rf "$mountdir"
test ! -f "$mountdir"/massos.tar.xz || rm -f "$mountdir"/massos.tar.xz
echo "Done!"
printf "\nThe installation of MassOS was successful! You may now reboot into\n"
echo "your new installation. We hope you enjoy using MassOS!"
