#!/usr/bin/env bash
#
# MassOS Live CD (ISO) Creation Script - Copyright (C) 2025 Daniel Massey.
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
# shellcheck disable=SC1091,SC2046,SC2086,SC2154
#
# Exit on error.
set -e
# Ensure we are running as root.
if test $EUID -ne 0; then
  echo "ERROR: $(basename "$0") must be run as root."
  exit 1
fi
# Add the MassOS programs directory to our path, in case we're not on MassOS.
export PATH="$PATH:$PWD/utils/programs"
# Ensure dependencies are present.
command -v curl &>/dev/null || { echo "Error: curl is required." >&2; exit 1; }
command -v mass-chroot &>/dev/null || { echo "Error: mass-chroot (from MassOS) is required." >&2; exit 1; }
command -v mkfs.fat &>/dev/null || { echo "Error: mkfs.fat from dosfstools is required." >&2; exit 1; }
command -v mksquashfs &>/dev/null || { echo "Error: mksquashfs from squashfs-tools is required." >&2; exit 1; }
command -v parallel &>/dev/null || { echo "Error: parallel (GNU - not moreutils) is required." >&2; exit 1; }
command -v sbsign &>/dev/null || { echo "Error: sbsign from sbsigntools is required." >&2; exit 1; }
command -v rdfind &>/dev/null || { echo "Error: rdfind is required." >&2; exit 1; }
command -v unzip &>/dev/null || { echo "Error: unzip is required." >&2; exit 1; }
command -v xorriso &>/dev/null || { echo "Error: xorriso from libisoburn is required." >&2; exit 1; }
# Ensure that the rootfs file is specified and exists.
if test -z "$1"; then
  echo "Error: No rootfs file was specified." >&2
  echo "Usage: $(basename "$0") <rootfs-tarball-file>" >&2
  exit 1
fi
if test ! -f "$1"; then
  echo "Error: Specified file $1 does not exist." >&2
  exit 1
fi
# Ensure the rootfs file is a MassOS image and is a new enough version.
if ! tar tf "$1" 2>/dev/null | grep -q '^usr/lib/massos-release$'; then
  echo "Error: The specified file $1 is not a valid MassOS rootfs." >&2
  echo "Note: $(basename "$0") does not support MassOS 2022.10 or older." >&2
  exit 1
fi
# Check if an existing directory exists.
if test -e "iso-workdir"; then
  echo "The working directory 'iso-workdir' already exists, please remove" >&2
  echo "it before running $(basename "$0")." >&2
  exit 1
fi
# Create directories.
mkdir -p iso-workdir/{firmware,iso-root,massos-rootfs,mcode,mnt,mt86plus,osinstallgui,sof,squashfs-tmp,syslinux}
mkdir -p iso-workdir/iso-root/EFI/{BOOT,tools}
mkdir -p iso-workdir/iso-root/isolinux
mkdir -p iso-workdir/iso-root/LICENSES
mkdir -p iso-workdir/iso-root/LiveOS
mkdir -p iso-workdir/squashfs-tmp/LiveOS
mkdir -p iso-workdir/efitmp
# Get information from the rootfs (before extracting the whole thing).
echo "Getting information from the rootfs..."
# Get firmware versions.
tar -xf "$1" -C iso-workdir --strip-components=3 usr/share/massos/firmwareversions
FW_VER="$(grep -m1 "^linux-firmware:" iso-workdir/firmwareversions | cut -d' ' -f2-)"
MVER="$(grep -m1 "^intel-microcode:" iso-workdir/firmwareversions | cut -d' ' -f2-)"
SOF_VER="$(grep -m1 "^sof-firmware:" iso-workdir/firmwareversions | cut -d' ' -f2-)"
# Get osinstallgui version.
tar -xf "$1" -C iso-workdir --strip-components=3 usr/share/massos/.osinstallguiver
OSINSTALLGUI_VER="$(cat iso-workdir/.osinstallguiver)"
# Download stuff.
echo "Downloading osinstallgui..."
curl -fL "https://github.com/DanielMYT/osinstallgui/archive/$OSINSTALLGUI_VER/osinstallgui-$OSINSTALLGUI_VER.tar.gz" -o iso-workdir/osinstallgui.tar.gz
tar -xf iso-workdir/osinstallgui.tar.gz -C iso-workdir/osinstallgui --strip-components=1
echo "Downloading SYSLINUX..."
curl -fL https://cdn.kernel.org/pub/linux/utils/boot/syslinux/Testing/6.04/syslinux-6.04-pre1.tar.xz -o iso-workdir/syslinux.tar.xz
tar --no-same-owner -xf iso-workdir/syslinux.tar.xz -C iso-workdir/syslinux --strip-components=1
echo "Downloading Memtest86+..."
curl -fL https://www.memtest.org/download/v7.20/mt86plus_7.20.binaries.zip -o iso-workdir/mt86plus.zip
unzip -q iso-workdir/mt86plus.zip -d iso-workdir/mt86plus
echo "Downloading IPXE..."
curl -fL https://github.com/DanielMYT/ipxe-nightly/releases/download/nightly-20250525/ipxe.efi -o iso-workdir/ipxe.efi
curl -fL https://github.com/DanielMYT/ipxe-nightly/releases/download/nightly-20250525/ipxe.lkrn -o iso-workdir/ipxe.lkrn
echo "Downloading UEFI Interactive Shell..."
curl -fL https://github.com/pbatard/UEFI-Shell/releases/download/24H2/shellx64.efi -o iso-workdir/shellx64.efi
echo "Downloading firmware..."
curl -fL "https://cdn.kernel.org/pub/linux/kernel/firmware/linux-firmware-$FW_VER.tar.xz" -o iso-workdir/firmware.tar.xz
curl -fL "https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files/archive/microcode-$MVER.tar.gz" -o iso-workdir/mcode.tar.gz
curl -fL "https://github.com/thesofproject/sof-bin/releases/download/v$SOF_VER/sof-bin-$SOF_VER.tar.gz" -o iso-workdir/sof.tar.gz
tar --no-same-owner -xf iso-workdir/firmware.tar.xz -C iso-workdir/firmware --strip-components=1
tar --no-same-owner -xf iso-workdir/mcode.tar.gz -C iso-workdir/mcode --strip-components=1
tar --no-same-owner -xf iso-workdir/sof.tar.gz -C iso-workdir/sof --strip-components=1
# Extract rootfs.
echo "Extracting rootfs..."
tar -xpf "$1" -C iso-workdir/massos-rootfs
ver="$(cat iso-workdir/massos-rootfs/etc/massos-release)"
# Prepare the live system.
echo "Preparing the live system..."
chroot iso-workdir/massos-rootfs /usr/sbin/groupadd -r autologin
chroot iso-workdir/massos-rootfs /usr/sbin/useradd -c "Live User" -G wheel,lpadmin,autologin -ms /usr/bin/bash massos
echo "massos:massos" | chroot iso-workdir/massos-rootfs /usr/sbin/chpasswd -c YESCRYPT
echo "massos ALL=(ALL) NOPASSWD: ALL" > iso-workdir/massos-rootfs/etc/sudoers.d/live
cat > iso-workdir/massos-rootfs/etc/polkit-1/rules.d/49-live.rules << "END"
// Allow elevation without password prompt in the live environment.
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("massos")) {
        return polkit.Result.YES;
    }
});
END
# Install osinstallgui.
echo "Installing osinstallgui..."
make -C iso-workdir/osinstallgui
make -C iso-workdir/osinstallgui DESTDIR="$PWD"/iso-workdir/massos-rootfs install
install -t iso-workdir/massos-rootfs/usr/share/osinstallgui -Dm644 livecd-data/osinstallgui.conf
sed -e "s|<Your Distro Name Here>|MassOS $ver|g" -e "s|<name-of-live-user>|massos|g" -e "s|</path/to/your/distro/logo>|/usr/share/massos/massos-logo.png|g" iso-workdir/osinstallgui/osinstallgui.desktop.example > iso-workdir/massos-rootfs/usr/share/applications/osinstallgui.desktop
chroot iso-workdir/massos-rootfs /usr/bin/install -o massos -g massos -dm755 /home/massos/Desktop
chroot iso-workdir/massos-rootfs /usr/bin/install -o massos -g massos -m755 /usr/share/applications/osinstallgui.desktop /home/massos/Desktop/osinstallgui.desktop
# Ensure the installer desktop icon is not untrusted on Xfce.
install -Dm644 livecd-data/trust-osinstallgui.desktop iso-workdir/massos-rootfs/home/massos/.config/autostart/trust-osinstallgui.desktop
chroot iso-workdir/massos-rootfs /usr/bin/chown -R massos:massos /home/massos/.config/autostart
# Set up desktop-specific autologin configuration.
. livecd-data/autologin/autologin.sh
# Install firmware.
echo "Installing firmware (this may take a while)..."
pushd iso-workdir/firmware
sed -i 's/zstd --compress --quiet --stdout/zstd --ultra -22 --compress --quiet --stdout/' copy-firmware.sh
./copy-firmware.sh -j$(nproc) --zstd "$PWD"/../massos-rootfs/usr/lib/firmware
./dedup-firmware.sh "$PWD"/../massos-rootfs/usr/lib/firmware
## Remove firmware which is useless on x86_64 systems.
rm -rf "$PWD"/../massos-rootfs/usr/lib/firmware/{mellanox,qcom}
rm -f "$PWD"/../massos-rootfs/usr/lib/firmware/mrvl/prestera/mvsw_prestera_fw_arm64-v4.1.img.zst
install -t "$PWD"/../massos-rootfs/usr/share/licenses/linux-firmware -Dm644 GPL-2 GPL-3 LICENCE* LICENSE* WHENCE
popd
install -dm755 iso-workdir/massos-rootfs/usr/lib/firmware/intel-ucode
install -m644 iso-workdir/mcode/intel-ucode{,-with-caveats}/* iso-workdir/massos-rootfs/usr/lib/firmware/intel-ucode
install -t iso-workdir/massos-rootfs/usr/share/licenses/intel-microcode -Dm644 iso-workdir/mcode/license
pushd iso-workdir/sof
cp -at "$PWD"/../massos-rootfs/usr/lib/firmware/intel sof*
install -t "$PWD"/../massos-rootfs/usr/share/licenses/sof-firmware -Dm644 LICENCE.Intel LICENCE.NXP Notice.NXP
popd
cat > iso-workdir/massos-rootfs/usr/share/massos/builtins.d/firmware << "END"
intel-microcode
linux-firmware
sof-firmware
END
# Create squashfs image.
echo "Creating squashfs image..."
cd iso-workdir/massos-rootfs
mksquashfs ./* ../iso-root/LiveOS/squashfs.img -comp zstd -Xcompression-level 22 -quiet
cd ../..
# Install kernel and generate initramfs.
echo "Installing kernel..."
cp iso-workdir/massos-rootfs/boot/vmlinuz-* iso-workdir/iso-root/vmlinuz
echo "Generating initramfs..."
mass-chroot iso-workdir/massos-rootfs /usr/sbin/mkinitramfs "$(cat iso-workdir/massos-rootfs/usr/share/massos/.krel)" >/dev/null
mv iso-workdir/massos-rootfs/boot/initramfs-*.img iso-workdir/iso-root/initramfs.img
# Install bootloader files.
echo "Setting up bootloader..."
## Legacy BIOS.
cp iso-workdir/syslinux/bios/core/isolinux.bin iso-workdir/iso-root/isolinux/isolinux.bin
cp iso-workdir/syslinux/bios/com32/elflink/ldlinux/ldlinux.c32 iso-workdir/iso-root/isolinux/ldlinux.c32
cp iso-workdir/syslinux/bios/com32/lib/libcom32.c32 iso-workdir/iso-root/isolinux/libcom32.c32
cp iso-workdir/syslinux/bios/com32/libutil/libutil.c32 iso-workdir/iso-root/isolinux/libutil.c32
cp iso-workdir/syslinux/bios/com32/menu/vesamenu.c32 iso-workdir/iso-root/isolinux/vesamenu.c32
cp iso-workdir/syslinux/bios/com32/chain/chain.c32 iso-workdir/iso-root/isolinux/chain.c32
cp iso-workdir/syslinux/bios/com32/modules/reboot.c32 iso-workdir/iso-root/isolinux/reboot.c32
cp iso-workdir/syslinux/bios/com32/modules/poweroff.c32 iso-workdir/iso-root/isolinux/poweroff.c32
cp iso-workdir/syslinux/bios/mbr/isohdpfx.bin iso-workdir/iso-root/isolinux/isohdpfx.bin
cp iso-workdir/syslinux/COPYING iso-workdir/iso-root/LICENSES/ISOLINUX.txt
cp livecd-data/isolinux.cfg iso-workdir/iso-root/isolinux/isolinux.cfg
cp livecd-data/splash.png iso-workdir/iso-root/isolinux/splash.png
## UEFI.
mkdir -p iso-workdir/massos-rootfs/boot/grub
cp livecd-data/grub.cfg iso-workdir/massos-rootfs/boot/grub/grub.cfg
mass-chroot iso-workdir/massos-rootfs /usr/bin/grub-mkstandalone -d /usr/lib/grub/x86_64-efi -O x86_64-efi -o BOOTX64.EFI --compress=xz /boot/grub/grub.cfg >/dev/null
rm -f iso-workdir/massos-rootfs/boot/grub/grub.cfg
rmdir iso-workdir/massos-rootfs/boot/grub 2>/dev/null || true
cp iso-workdir/massos-rootfs/BOOTX64.EFI iso-workdir/iso-root/EFI/BOOT/BOOTX64.EFI
chmod +x iso-workdir/iso-root/EFI/BOOT/BOOTX64.EFI
cp iso-workdir/massos-rootfs/usr/share/grub/unicode.pf2 iso-workdir/iso-root/unicode.pf2
cp iso-workdir/massos-rootfs/usr/share/licenses/grub/COPYING iso-workdir/iso-root/LICENSES/GRUB.txt
cp livecd-data/splash2.png iso-workdir/iso-root/splash2.png
# Install Memtest86+, IPXE and UEFI EDK2 Shell.
cp iso-workdir/mt86plus/memtest64.bin iso-workdir/iso-root/isolinux/memtest64.bin
cp iso-workdir/mt86plus/memtest64.efi iso-workdir/iso-root/EFI/tools/memtest64.efi
cp iso-workdir/ipxe.efi iso-workdir/iso-root/EFI/tools/ipxe.efi
cp iso-workdir/ipxe.lkrn iso-workdir/iso-root/isolinux/ipxe.lkrn
cp iso-workdir/shellx64.efi iso-workdir/iso-root/EFI/tools/shellx64.efi
# Sign EFI executables if (and only if) the rootfs's certificate matches ours.
if test -e iso-workdir/massos-rootfs/usr/share/massos/certs/secureboot/db.crt; then
  if test -e keys/secureboot/db.crt; then
    if diff -q iso-workdir/massos-rootfs/usr/share/massos/certs/secureboot/db.crt keys/secureboot/db.crt &>/dev/null; then
      echo "Rootfs and local SB certs match - EFI binaries will be SB signed."
      # Sign each executable.
      for e in BOOT/BOOTX64.EFI tools/{ipxe,memtest64,shellx64}.efi; do
        sbsign --key keys/secureboot/db.key --cert keys/secureboot/db.crt iso-workdir/iso-root/EFI/"$e"
        rm -f iso-workdir/iso-root/EFI/"$e"
        mv iso-workdir/iso-root/EFI/"$e".signed iso-workdir/iso-root/EFI/"$e"
      done
      # Copy over the certs from the rootfs to the live CD.
      cp -r iso-workdir/massos-rootfs/usr/share/massos/certs/secureboot iso-workdir/iso-root
      # Copy secure boot README to the top level of the live CD.
      cp livecd-data/README.SECUREBOOT.txt iso-workdir/iso-root/README.SECUREBOOT.txt
    else
      echo "WARNING: SB signing disabled due to rootfs/local cert mismatch." >&2
    fi
  else
    echo "WARNING: SB signing disabled due to missing local SB cert." >&2
  fi
else
  echo "WARNING: SB signing disabled due to lack of SB cert in rootfs." >&2
fi
# Create a small FAT12 image containing BOOTX64.EFI, to use for UEFI cdboot.
# This is required as most UEFI firmwares don't support the ISO9660 filesystem.
# This was previously done earlier, but has been moved to after SB signing.
fallocate -l $(($(du -bc iso-workdir/iso-root/EFI/BOOT/BOOTX64.EFI | tail -n1 | cut -f1) + 80000)) iso-workdir/iso-root/EFI/BOOT/efiboot.img
mkfs.fat -F12 iso-workdir/iso-root/EFI/BOOT/efiboot.img -n "MASSOS_EFI"
mount -o loop iso-workdir/iso-root/EFI/BOOT/efiboot.img iso-workdir/efitmp
mkdir -p iso-workdir/efitmp/EFI/BOOT
cp iso-workdir/iso-root/EFI/BOOT/BOOTX64.EFI iso-workdir/efitmp/EFI/BOOT/BOOTX64.EFI
sync
umount iso-workdir/efitmp
# Copy additional files.
cp livecd-data/autorun.ico iso-workdir/iso-root/autorun.ico
cp livecd-data/autorun.inf iso-workdir/iso-root/autorun.inf
cp livecd-data/README.txt iso-workdir/iso-root/README.txt
for l in LICENSE CC-BY-SA-4.0 GPL-3.0; do cp "$l" iso-workdir/iso-root/"$l".txt; done
cp livecd-data/LICENSES/*.txt iso-workdir/iso-root/LICENSES/
touch iso-workdir/iso-root/THIS_IS_THE_MASSOS_LIVECD
# Create the ISO image.
echo "Creating ISO image..."
xorrisofs -iso-level 3 -d -J -N -R -max-iso9660-filenames -relaxed-filenames -allow-lowercase -V "MASSOS" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e EFI/BOOT/efiboot.img -isohybrid-gpt-basdat -no-emul-boot -isohybrid-mbr iso-workdir/iso-root/isolinux/isohdpfx.bin -o "massos-$ver-livecd-x86_64-$variant.iso" iso-workdir/iso-root
# Clean up.
echo "Cleaning up..."
rm -rf iso-workdir
# Finishing message.
echo "All done! Output image written to massos-$ver-livecd-x86_64-$variant.iso."
# Generate Blake-2 checksum.
b2sum "massos-$ver-livecd-x86_64-$variant.iso" > "massos-$ver-livecd-x86_64-$variant.iso.b2"
echo "Blake-2 checksum written to massos-$ver-livecd-x86_64-$variant.iso.b2."
