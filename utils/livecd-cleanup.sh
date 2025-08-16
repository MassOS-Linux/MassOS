#!/usr/bin/env bash
set -e

# Script to remove Live CD features after the installation using osinstallgui.

# Ensure we are root, warn about running standalone.
if test $EUID -ne 0; then
  echo "Error: This script is not intended to be run standalone." >&2
fi

# Remove live user and autologin group.
userdel -rf massos
groupdel -f autologin

# Restore original display manager configuration, depending on which is in use.
if test -f /etc/lightdm/lightdm.conf.orig; then
  mv /etc/lightdm/lightdm.conf{.orig,}
fi
if test -f /etc/gdm/custom.conf.orig; then
  mv /etc/gdm/custom.conf{.orig,}
fi
if test -f /etc/sddm.conf.orig; then
  mv /etc/sddm.conf{.orig,}
fi

# Remove no password rules from polkit and sudo.
rm -f /etc/polkit-1/rules.d/49-live.rules
rm -f /etc/sudoers.d/live

# Remove osinstallgui.
rm -f /usr/bin/osinstallgui
rm -f /usr/share/applications/osinstallgui.desktop
rm -rf /usr/share/osinstallgui

# Remove legacy livecd-installer, if for some reason it still exists.
rm -f /usr/bin/livecd-installer
rm -f /usr/share/applications/livecd-installer.desktop
rm -f /etc/xdg/autostart/trust-livecd-installer.desktop

# Self destruct.
rm -f /tmp/{livecd-cleanup.sh,{post,pre}upgrade}
