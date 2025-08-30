#!/usr/bin/env bash
set -e

# Script to remove Live CD features after the installation using osinstallgui.
# Also does a few needed post-installation steps not done by osinstallgui.

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

# Set up machine-id for this installation.
systemd-machine-id-setup

# Auto-generate a Machine Owner Key (MOK) for the new system.
# This is to support signing of out of tree kernel modules and similar.
# Follow the formatting of Ubuntu/Debian, as VirtualBox also expects that.
openssl req -new -x509 -newkey rsa:2048 -nodes -keyout /var/lib/shim-signed/mok/MOK.priv -out /var/lib/shim-signed/mok/MOK.der -outform DER -days 3650 -subj "/CN=Auto-generated MOK for $(cat /etc/hostname) on $(date +%Y-%m-%d)/"
openssl x509 -in /var/lib/shim-signed/mok/MOK.der -inform DER -out /var/lib/shim-signed/mok/MOK.crt -outform PEM
chmod 0600 /var/lib/shim-signed/mok/MOK.priv

# Self destruct.
rm -f /tmp/{livecd-cleanup.sh,{post,pre}upgrade{,_ng}}
