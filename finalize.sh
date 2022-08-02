#!/bin/bash
#
# Finalize the MassOS build. Stage 3 will run this in chroot once the Stage 3
# build is finished.
set -e
# Ensure we're running in the MassOS chroot.
if [ $EUID -ne 0 ] || [ ! -d /sources ]; then
  echo "This script should not be run manually." >&2
  echo "stage3.sh will automatically run it in a chroot environment." >&2
  exit 1
fi
# Uninstall Rust.
if [ -x /usr/lib/rustlib/uninstall.sh ]; then
  /usr/lib/rustlib/uninstall.sh
fi
# Compress manual pages.
zman /usr/share/man
# Remove leftover junk in /root.
rm -rf /root/.{cache,cargo,cmake}
# Remove Debian stuff.
rm -rf /etc/kernel
# Move any misplaced files.
if [ -d /usr/etc ]; then
  cp -r /usr/etc /
  rm -rf /usr/etc
fi
if [ -d /usr/man ]; then
  cp -r /usr/man /usr/share
  rm -rf /usr/man
fi
# Remove static documentation to free up space.
rm -rf /usr/share/doc/*
rm -rf /usr/doc
rm -rf /usr/docs
rm -rf /usr/share/gtk-doc/html/*
# Remove libtool archives.
find /usr/lib /usr/libexec -name \*.la -delete
# Remove any temporary files.
rm -rf /tmp/*
# As a finishing touch, run ldconfig and other misc commands.
ldconfig
glib-compile-schemas /usr/share/glib-2.0/schemas
gtk-update-icon-cache -q -t -f --include-image-data /usr/share/icons/hicolor
update-desktop-database
# Clean up and self-destruct.
rm -rf /sources
