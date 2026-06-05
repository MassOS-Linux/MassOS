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
# Ensure we are running on a supported architecture.
if test "$(uname -m)" != "x86_64" && test "$(uname -m)" != "aarch64"; then
  echo "Error: The architecture $(uname -m) is currently unsupported." >&2
  echo "Note: Only x86_64 and aarch64 are currently supported by MassOS." >&2
fi
# The compatibility level of this script with MassOS rootfs images.
# Increment when this script needs to be modified due to build system changes.
SCRIPT_COMPAT=6
# Set up default umask, in case host umask differs.
umask 0022
# Add the MassOS programs directory to our path, in case we're not on MassOS.
export PATH="$PATH:$PWD/utils/programs"
# Ensure dependencies are present.
command -v curl &>/dev/null || { echo "Error: curl is required." >&2; exit 1; }
command -v mass-chroot &>/dev/null || { echo "Error: mass-chroot (from MassOS) is required." >&2; exit 1; }
command -v mkfs.fat &>/dev/null || { echo "Error: mkfs.fat from dosfstools is required." >&2; exit 1; }
command -v mksquashfs &>/dev/null || { echo "Error: mksquashfs from squashfs-tools is required." >&2; exit 1; }
command -v mcopy &>/dev/null || { echo "Error: mcopy from mtools is required." >&2; exit 1; }
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
if ! tar -tf "$1" 2>/dev/null | grep -q '^usr/lib/massos-release$'; then
  echo "Error: The specified file $1 is not a valid MassOS rootfs." >&2
  echo "Note: $(basename "$0") does not support MassOS 2022.10 or older." >&2
  exit 1
fi
# Check that the rootfs compatibility number matches this script's one.
ROOTFS_COMPAT="$(tar -xOf "$1" usr/share/massos/.rootfs_compat 2>/dev/null || echo 0)"
if test "$ROOTFS_COMPAT" != "$SCRIPT_COMPAT"; then
  echo "Error: Rootfs is incompatible with this $(basename "$0") version." >&2
  echo "Info: Need compat number $SCRIPT_COMPAT but got $ROOTFS_COMPAT." >&2
  echo "Note: This rootfs may require an older $(basename "$0") version." >&2
  exit 1
fi
# Check if an existing directory exists.
if test -e "iso-workdir"; then
  echo "The working directory 'iso-workdir' already exists, please remove" >&2
  echo "it before running $(basename "$0")." >&2
  exit 1
fi
# Create directories.
mkdir -p iso-workdir/{iso-root,massos-rootfs,osinstallgui}
mkdir -p iso-workdir/iso-root/EFI/{BOOT,tools}
mkdir -p iso-workdir/iso-root/{LICENSES,LiveOS}
# x86_64 specific directories (Legacy BIOS support).
if test "$(uname -m)" = "x86_64"; then
  mkdir -p iso-workdir/{syslinux,iso-root/isolinux}
fi
# Get osinstallgui version from the rootfs before extracting the whole thing.
echo "Getting information from the rootfs..."
OSINSTALLGUI_VER="$(tar -xOf "$1" usr/share/massos/.osinstallguiver)"
OSINSTALLGUI_SUM="$(tar -xOf "$1" usr/share/massos/.osinstallguisum)"
# Download stuff.
echo "Downloading osinstallgui..."
curl -fL "https://github.com/DanielMYT/osinstallgui/archive/$OSINSTALLGUI_VER/osinstallgui-$OSINSTALLGUI_VER.tar.gz" -o iso-workdir/osinstallgui.tar.gz
echo "$OSINSTALLGUI_SUM iso-workdir/osinstallgui.tar.gz" | sha256sum -c
tar -xf iso-workdir/osinstallgui.tar.gz -C iso-workdir/osinstallgui --strip-components=1
# Only download SYSLINUX on x86_64 (Legacy BIOS is unsupported elsewhere).
if test "$(uname -m)" = "x86_64"; then
  echo "Downloading SYSLINUX..."
  curl -fL https://cdn.kernel.org/pub/linux/utils/boot/syslinux/Testing/6.04/syslinux-6.04-pre1.tar.xz -o iso-workdir/syslinux.tar.xz
  echo "3f6d50a57f3ed47d8234fd0ab4492634eb7c9aaf7dd902f33d3ac33564fd631d iso-workdir/syslinux.tar.xz" | sha256sum -c
  tar --no-same-owner -xf iso-workdir/syslinux.tar.xz -C iso-workdir/syslinux --strip-components=1
fi
# Extract rootfs.
echo "Extracting rootfs..."
tar -xpf "$1" -C iso-workdir/massos-rootfs
sync
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
cp iso-workdir/massos-rootfs/usr/share/massos/.osinstallguicfg iso-workdir/massos-rootfs/usr/share/osinstallgui/osinstallgui.conf
sed -e "s|<Your Distro Name Here>|MassOS $ver|g" -e "s|</path/to/your/distro/logo>|/usr/share/massos/massos-logo.png|g" iso-workdir/osinstallgui/osinstallgui.desktop.example.unprivileged > iso-workdir/massos-rootfs/usr/share/applications/osinstallgui.desktop
chroot iso-workdir/massos-rootfs /usr/bin/install -o massos -g massos -dm755 /home/massos/Desktop
chroot iso-workdir/massos-rootfs /usr/bin/install -o massos -g massos -m755 /usr/share/applications/osinstallgui.desktop /home/massos/Desktop/osinstallgui.desktop
# Ensure the installer desktop icon is not untrusted on Xfce.
install -Dm644 livecd-data/trust-osinstallgui.desktop iso-workdir/massos-rootfs/home/massos/.config/autostart/trust-osinstallgui.desktop
chroot iso-workdir/massos-rootfs /usr/bin/chown -R massos:massos /home/massos/.config/autostart
# Set up desktop-specific autologin configuration.
. livecd-data/autologin/autologin.sh
sync
# Set ISO file name for bootloader configs, now we know version and variant.
isoname="massos-$ver-livecd-$(uname -m)-$variant.iso"
# Create squashfs image.
echo "Creating squashfs image..."
cd iso-workdir/massos-rootfs
mksquashfs ./* ../iso-root/LiveOS/squashfs.img -comp zstd -Xcompression-level 22 -quiet
cd ../..
sync
# Install kernel and generate initramfs.
echo "Installing kernel..."
cp iso-workdir/massos-rootfs/boot/vmlinuz-* iso-workdir/iso-root/vmlinuz
echo "Generating initramfs..."
mass-chroot iso-workdir/massos-rootfs /usr/sbin/mkinitramfs "$(cat iso-workdir/massos-rootfs/usr/share/massos/.krel)" >/dev/null
mv iso-workdir/massos-rootfs/boot/initramfs-*.img iso-workdir/iso-root/initramfs.img
# Install DTBs if we are on an architecture which ships them.
if test -d iso-workdir/massos-rootfs/boot/dtbs-"$(cat iso-workdir/massos-rootfs/usr/share/massos/.krel)"; then
  # Copy /boot/dtbs-KERNELVERSION to (iso)/dtbs
  echo "Installing DTBs..."
  cp -r iso-workdir/massos-rootfs/boot/dtbs-"$(cat iso-workdir/massos-rootfs/usr/share/massos/.krel)" iso-workdir/iso-root/dtbs
elif test -d iso-workdir/massos-rootfs/boot/dtbs/"$(cat iso-workdir/massos-rootfs/usr/share/massos/.krel)"; then
  # Copy /boot/dtbs/KERNELVERSION to (iso)/dtbs
  echo "Installing DTBs..."
  cp -r iso-workdir/massos-rootfs/boot/dtbs/"$(cat iso-workdir/massos-rootfs/usr/share/massos/.krel)" iso-workdir/iso-root/dtbs
fi
# Install bootloader files.
echo "Setting up bootloader..."
## Legacy BIOS (ISOLINUX) (x86_64 only).
if test "$(uname -m)" = "x86_64"; then
  cp iso-workdir/syslinux/bios/core/isolinux.bin iso-workdir/iso-root/isolinux/isolinux.bin
  cp iso-workdir/syslinux/bios/com32/elflink/ldlinux/ldlinux.c32 iso-workdir/iso-root/isolinux/ldlinux.c32
  cp iso-workdir/syslinux/bios/com32/lib/libcom32.c32 iso-workdir/iso-root/isolinux/libcom32.c32
  cp iso-workdir/syslinux/bios/com32/libutil/libutil.c32 iso-workdir/iso-root/isolinux/libutil.c32
  cp iso-workdir/syslinux/bios/com32/menu/vesamenu.c32 iso-workdir/iso-root/isolinux/vesamenu.c32
  cp iso-workdir/syslinux/bios/com32/chain/chain.c32 iso-workdir/iso-root/isolinux/chain.c32
  cp iso-workdir/syslinux/bios/com32/modules/reboot.c32 iso-workdir/iso-root/isolinux/reboot.c32
  cp iso-workdir/syslinux/bios/com32/modules/poweroff.c32 iso-workdir/iso-root/isolinux/poweroff.c32
  cp iso-workdir/syslinux/bios/mbr/isohdpfx.bin iso-workdir/iso-root/isolinux/isohdpfx.bin
  sed "s|@@ISOFILE@@|$isoname|g" livecd-data/isolinux.cfg.in > iso-workdir/iso-root/isolinux/isolinux.cfg
  cp livecd-data/splash.png iso-workdir/iso-root/isolinux/splash.png
  cp iso-workdir/syslinux/COPYING iso-workdir/iso-root/LICENSES/ISOLINUX.txt
fi
## UEFI (shim + GRUB).
if test "$(uname -m)" = "x86_64"; then
  cp iso-workdir/massos-rootfs/usr/lib/shim/shimx64.efi.signed iso-workdir/iso-root/EFI/BOOT/BOOTX64.EFI
  cp iso-workdir/massos-rootfs/usr/lib/shim/mmx64.efi iso-workdir/iso-root/EFI/BOOT/mmx64.efi
  cp iso-workdir/massos-rootfs/usr/lib/grub/x86_64-efi-signed/glcdx64.efi.signed iso-workdir/iso-root/EFI/BOOT/grubx64.efi
  chmod +x iso-workdir/iso-root/EFI/BOOT/{BOOTX64.EFI,{grubx64,mmx64}.efi}
else
  cp iso-workdir/massos-rootfs/usr/lib/shim/shimaa64.efi.signed iso-workdir/iso-root/EFI/BOOT/BOOTAA64.EFI
  cp iso-workdir/massos-rootfs/usr/lib/shim/mmaa64.efi iso-workdir/iso-root/EFI/BOOT/mmaa64.efi
  cp iso-workdir/massos-rootfs/usr/lib/grub/arm64-efi-signed/glcdaa64.efi.signed iso-workdir/iso-root/EFI/BOOT/grubaa64.efi
  chmod +x iso-workdir/iso-root/EFI/BOOT/{BOOTAA64.EFI,{grubaa64,mmaa64}.efi}
fi
sed "s|@@ISOFILE@@|$isoname|g" livecd-data/grub.cfg.in > iso-workdir/iso-root/grub.cfg
cp iso-workdir/massos-rootfs/usr/share/licenses/shim/copyright iso-workdir/iso-root/LICENSES/shim.txt
cp iso-workdir/massos-rootfs/usr/share/licenses/grub/COPYING iso-workdir/iso-root/LICENSES/GRUB.txt
cp livecd-data/splash2.png iso-workdir/iso-root/splash2.png
# Install Memtest86+, IPXE and UEFI EDK2 Shell.
# Some of these won't be installed depending on architecture (if unsupported).
cp iso-workdir/massos-rootfs/usr/lib/ipxe/ipxe.efi.signed iso-workdir/iso-root/EFI/tools/ipxe.efi
cp iso-workdir/massos-rootfs/usr/share/licenses/ipxe/COPYING.GPLv2 iso-workdir/iso-root/LICENSES/IPXE.txt
cp iso-workdir/massos-rootfs/usr/share/licenses/edk2-shell/License.txt iso-workdir/iso-root/LICENSES/UEFI-EDK2-Shell.txt
if test "$(uname -m)" = "x86_64"; then
  cp iso-workdir/massos-rootfs/usr/lib/memtest86+/memtest.bin iso-workdir/iso-root/isolinux/memtest64.bin
  cp iso-workdir/massos-rootfs/usr/lib/memtest86+/memtest.efi.signed iso-workdir/iso-root/EFI/tools/memtest64.efi
  cp iso-workdir/massos-rootfs/usr/share/licenses/memtest86+/LICENSE iso-workdir/iso-root/LICENSES/Memtest86+.txt
  cp iso-workdir/massos-rootfs/usr/lib/ipxe/ipxe.lkrn iso-workdir/iso-root/isolinux/ipxe.lkrn
  cp iso-workdir/massos-rootfs/usr/lib/edk2-shell/shellx64.efi iso-workdir/iso-root/EFI/tools/shellx64.efi
else
  cp iso-workdir/massos-rootfs/usr/lib/edk2-shell/shellaa64.efi iso-workdir/iso-root/EFI/tools/shellaa64.efi
fi
# Copy over secure boot certs from the rootfs to the live CD.
cp -r iso-workdir/massos-rootfs/usr/share/massos/certs/secureboot iso-workdir/iso-root
# Copy db.der as ENROLLME.cer, for easier MokManager import.
cp iso-workdir/iso-root/secureboot/db.der iso-workdir/iso-root/ENROLLME.cer
# Copy secure boot README to the top level of the live CD.
cp livecd-data/README.SECUREBOOT.txt iso-workdir/iso-root/README.SECUREBOOT.txt
# Create a small FAT12 image containing BOOTX64.EFI, to use for UEFI cdboot.
# This is required as most UEFI firmwares don't support the ISO9660 filesystem.
# Also install SB certs here, to allow importing into firmware from FAT volume.
dd if=/dev/zero of=iso-workdir/efiboot.img bs=$(($(du -bc iso-workdir/iso-root/EFI/BOOT | tail -n1 | cut -f1) + 80000)) count=1
mkfs.fat -F12 iso-workdir/efiboot.img -n "MASSOS_EFI"
mmd -i iso-workdir/efiboot.img ::/EFI
mcopy -i iso-workdir/efiboot.img -s iso-workdir/iso-root/EFI/BOOT ::/EFI
mcopy -i iso-workdir/efiboot.img -s iso-workdir/iso-root/secureboot ::
mcopy -i iso-workdir/efiboot.img -s iso-workdir/iso-root/ENROLLME.cer ::
mv iso-workdir/efiboot.img iso-workdir/iso-root/EFI/BOOT/efiboot.img
# Copy additional files.
cp livecd-data/autorun.ico iso-workdir/iso-root/autorun.ico
cp livecd-data/autorun.inf iso-workdir/iso-root/autorun.inf
cp livecd-data/README.txt iso-workdir/iso-root/README.txt
for l in LICENSE CC-BY-SA-4.0 GPL-3.0; do cp "$l" iso-workdir/iso-root/"$l".txt; done
touch iso-workdir/iso-root/THIS_IS_THE_MASSOS_LIVECD
sync
# Create the ISO image.
# Note that the volume label should not be more than 11 characters.
# Because label gets truncated if on a FAT32 volume (i.e. Rufus with ISO mode).
# And the boot process depends on the volume name, so it must not be changed.
echo "Creating ISO image..."
if test "$(uname -m)" = "x86_64"; then
  xorriso -as mkisofs -iso-level 3 -d -J -N -R -max-iso9660-filenames -relaxed-filenames -allow-lowercase -V "MASSOS_LIVE" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e EFI/BOOT/efiboot.img -isohybrid-gpt-basdat -no-emul-boot -isohybrid-mbr iso-workdir/iso-root/isolinux/isohdpfx.bin -o "$isoname" iso-workdir/iso-root
else
  # Non-x86_64 ISOs do not need any Legacy BIOS boot functionality.
  xorriso -as mkisofs -iso-level 3 -d -J -N -R -max-iso9660-filenames -relaxed-filenames -allow-lowercase -V "MASSOS_LIVE" -e EFI/BOOT/efiboot.img -no-emul-boot -o "$isoname" iso-workdir/iso-root
fi
# Clean up.
echo "Cleaning up..."
rm -rf iso-workdir
sync
# Finishing message.
echo "All done! Output image written to $isoname."
# Generate Blake-2 checksum.
b2sum "$isoname" > "$isoname.b2"
echo "Blake-2 checksum written to $isoname.b2."
# Try to change ownership of ISO image to top-level directory owner.
chown -v "$(stat -c "%U:%G" .)" "$isoname" "$isoname.b2" || true
# Finishing message.
echo
echo "To produce a detached GPG signature for your ISO image, run:"
echo
echo "  gpg --detach-sign --armor '$isoname'"
echo
echo "The detached signature will be written to '$isoname.asc'."
