#!/bin/bash
#
# MassOS Stage 3 build script (Xfce).
# Copyright (C) 2022 MassOS Developers.
#
# Exit on error.
set -e
# Change to the sources directory.
pushd /root/mbs/work
# Set up basic environment variables, same as Stage 2.
. ../build.env
# === IF RESUMING A FAILED BUILD, ONLY REMOVE LINES BELOW THIS ONE.
# Install Rust to a temporary directory to support building some packages.
tar -xf ../sources/rust-1.86.0-x86_64-unknown-linux-gnu.tar.gz
pushd rust-1.86.0-x86_64-unknown-linux-gnu
./install.sh --prefix=/root/mbs/extras/rust --without=rust-docs
popd
rm -rf rust-1.86.0-x86_64-unknown-linux-gnu
# elementary-icon-theme.
tar -xf ../sources/elementary-icon-theme-8.1.0.tar.gz
pushd icons-8.1.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dvolume_icons=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/elementary-icon-theme -Dm644 COPYING
popd
rm -rf icons-8.1.0
# arc-theme.
tar --no-same-owner -xf ../sources/arc-theme-20220102.tar.xz
tar --no-same-owner -xf ../sources/arc-theme-openbox.tar.gz -C arc-theme-20220102/usr/share/themes --strip-components=1
rm -rf arc-theme-20220102/usr/share/themes/{README.md,screens,*.obt}
install -dm755 arc-theme-20220102/usr/share/licenses/arc-theme
mv arc-theme-20220102/usr/share/{themes,licenses/arc-theme}/LICENSE
cp -r arc-theme-20220102/usr /
gtk-update-icon-cache /usr/share/icons/Arc
gtk4-update-icon-cache /usr/share/icons/Arc
install -dm755 /etc/gtk-{2,3,4}.0
cat > /etc/gtk-2.0/gtkrc << "END"
gtk-theme-name = "Arc-Dark"
gtk-icon-theme-name = "Arc"
gtk-cursor-theme-name = "Adwaita"
gtk-font-name = "Noto Sans 10"
END
cat > /etc/gtk-3.0/settings.ini << "END"
[Settings]
gtk-theme-name = Arc-Dark
gtk-icon-theme-name = Arc
gtk-font-name = Noto Sans 10
gtk-cursor-theme-size = 0
gtk-toolbar-style = GTK_TOOLBAR_ICONS
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintnone
gtk-xft-rgba = rgb
gtk-cursor-theme-name = Adwaita
END
cat > /etc/gtk-4.0/settings.ini << "END"
[Settings]
gtk-theme-name = Arc-Dark
gtk-icon-theme-name = Arc
gtk-font-name = Noto Sans 10
gtk-cursor-theme-name = Adwaita
END
cat > /etc/profile.d/arc-theme.sh << "END"
export GTK_THEME="Arc-Dark"
END
flatpak install -y runtime/org.gtk.Gtk3theme.Arc{,-Dark}/x86_64/3.22
rm -rf arc-theme-20220102
# xfce4-dev-tools.
tar -xf ../sources/xfce4-dev-tools-4.20.0.tar.bz2
pushd xfce4-dev-tools-4.20.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/xfce4-dev-tools -Dm644 COPYING
popd
rm -rf xfce4-dev-tools-4.20.0
# libxfce4util.
tar -xf ../sources/libxfce4util-4.20.1.tar.bz2
pushd libxfce4util-4.20.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/libxfce4util -Dm644 COPYING
popd
rm -rf libxfce4util-4.20.1
# libxfce4windowing.
tar -xf ../sources/libxfce4windowing-4.20.2.tar.bz2
pushd libxfce4windowing-4.20.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dwayland=enabled -Dx11=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libxfce4windowing -Dm644 COPYING
popd
rm -rf libxfce4windowing-4.20.2
# xfconf.
tar -xf ../sources/xfconf-4.20.0.tar.bz2
pushd xfconf-4.20.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/xfconf -Dm644 COPYING
popd
rm -rf xfconf-4.20.0
# libxfce4ui.
tar -xf ../sources/libxfce4ui-4.20.1.tar.bz2
pushd libxfce4ui-4.20.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-wayland --enable-x11 --with-vendor-info=MassOS
make
make install
install -t /usr/share/licenses/libxfce4ui -Dm644 COPYING
popd
rm -rf libxfce4ui-4.20.1
# catfish.
tar -xf ../sources/catfish-4.20.0.tar.bz2
pushd catfish-4.20.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/catfish -Dm644 COPYING
popd
rm -rf catfish-4.20.0
# Exo.
tar -xf ../sources/exo-4.20.0.tar.bz2
pushd exo-4.20.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/exo -Dm644 COPYING
popd
rm -rf exo-4.20.0
# Garcon.
tar -xf ../sources/garcon-4.20.0.tar.bz2
pushd garcon-4.20.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/garcon -Dm644 COPYING
popd
rm -rf garcon-4.20.0
# Thunar.
tar -xf ../sources/thunar-4.20.2.tar.bz2
pushd thunar-4.20.2
./configure --prefix=/usr --sysconfdir=/etc --enable-exif --enable-gio-unix --enable-gudev --enable-notifications
make
make install
install -t /usr/share/licenses/thunar -Dm644 COPYING
popd
rm -rf thunar-4.20.2
# thunar-volman.
tar -xf ../sources/thunar-volman-4.20.0.tar.bz2
pushd thunar-volman-4.20.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/thunar-volman -Dm644 COPYING
popd
rm -rf thunar-volman-4.20.0
# Tumbler.
tar -xf ../sources/tumbler-4.20.0.tar.bz2
pushd tumbler-4.20.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/tumbler -Dm644 COPYING
popd
rm -rf tumbler-4.20.0
# xfce4-appfinder.
tar -xf ../sources/xfce4-appfinder-4.20.0.tar.bz2
pushd xfce4-appfinder-4.20.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xfce4-appfinder -Dm644 COPYING
popd
rm -rf xfce4-appfinder-4.20.0
# xfce4-panel.
tar -xf ../sources/xfce4-panel-4.20.4.tar.bz2
pushd xfce4-panel-4.20.4
./configure --prefix=/usr --sysconfdir=/etc --enable-gio-unix --enable-wayland --enable-x11
make
make install
install -t /usr/share/licenses/xfce4-panel -Dm644 COPYING
popd
rm -rf xfce4-panel-4.20.4
# xfce4-power-manager.
tar -xf ../sources/xfce4-power-manager-4.20.0.tar.bz2
pushd xfce4-power-manager-4.20.0
./configure --prefix=/usr --sysconfdir=/etc --enable-polkit --enable-wayland --enable-x11
make
make install
install -t /usr/share/licenses/xfce4-power-manager -Dm644 COPYING
popd
rm -rf xfce4-power-manager-4.20.0
# xfce4-settings.
tar -xf ../sources/xfce4-settings-4.20.1.tar.bz2
pushd xfce4-settings-4.20.1
./configure --prefix=/usr --sysconfdir=/etc --enable-libxklavier --enable-libnotify --enable-pluggable-dialogs --enable-sound-settings --enable-wayland --enable-x11 --enable-xcursor --enable-xrandr
make
make install
install -t /usr/share/licenses/xfce4-settings -Dm644 COPYING
popd
rm -rf xfce4-settings-4.20.1
# xfdesktop.
tar -xf ../sources/xfdesktop-4.20.1.tar.bz2
pushd xfdesktop-4.20.1
./configure --prefix=/usr --sysconfdir=/etc --enable-notifications --enable-thunarx --enable-wayland --enable-x11 --with-default-backdrop-filename=/usr/share/backgrounds/MassOS-Futuristic-Dark.png
make
make install
install -t /usr/share/licenses/xfdesktop -Dm644 COPYING
popd
rm -rf xfdesktop-4.20.1
# xfwm4.
tar -xf ../sources/xfwm4-4.20.0.tar.bz2
pushd xfwm4-4.20.0
./configure --prefix=/usr --sysconfdir=/etc --enable-compositor --enable-randr --enable-startup-notification --enable-xsync
make
make install
sed -i 's/Default/Arc-Dark/' /usr/share/xfwm4/defaults
install -t /usr/share/licenses/xfwm4 -Dm644 COPYING
popd
rm -rf xfwm4-4.20.0
# LabWC.
tar -xf ../sources/labwc-0.8.3.tar.gz
pushd labwc-0.8.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/labwc -Dm644 LICENSE
popd
rm -rf labwc-0.8.3
# xfce4-session.
tar -xf ../sources/xfce4-session-4.20.2.tar.bz2
pushd xfce4-session-4.20.2
./configure --prefix=/usr --sysconfdir=/etc --enable-wayland --enable-x11
make
make install
install -t /usr/share/licenses/xfce4-session -Dm644 COPYING
popd
rm -rf xfce4-session-4.20.2
# Parole.
tar -xf ../sources/parole-4.18.2.tar.bz2
pushd parole-4.18.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/parole -Dm644 COPYING
popd
rm -rf parole-4.18.2
# Orage.
tar -xf ../sources/orage-4.20.1.tar.bz2
pushd orage-4.20.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libexecdir=/usr/lib/xfce4 --disable-debug --disable-static
make
make install
install -t /usr/share/licenses/orage -Dm644 COPYING
popd
rm -rf orage-4.20.1
# Xfburn.
tar -xf ../sources/xfburn-0.7.2.tar.bz2
pushd xfburn-0.7.2
./configure --prefix=/usr --enable-gstreamer --disable-debug --disable-static
make
make install
install -t /usr/share/licenses/xfburn -Dm644 COPYING
popd
rm -rf xfburn-0.7.2
# xfce4-terminal.
tar -xf ../sources/xfce4-terminal-1.1.5.tar.xz
pushd xfce4-terminal-1.1.5
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xfce4-terminal -Dm644 COPYING
popd
rm -rf xfce4-terminal-1.1.5
# Shotwell.
tar -xf ../sources/shotwell-shotwell-0.32.10.tar.bz2
pushd shotwell-shotwell-0.32.10
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/shotwell -Dm644 COPYING
popd
rm -rf shotwell-shotwell-0.32.10
# xfce4-notifyd.
tar -xf ../sources/xfce4-notifyd-0.9.7.tar.bz2
pushd xfce4-notifyd-0.9.7
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xfce4-notifyd -Dm644 COPYING
popd
rm -rf xfce4-notifyd-0.9.7
# xfce4-pulseaudio-plugin.
tar -xf ../sources/xfce4-pulseaudio-plugin-0.5.1.tar.xz
pushd xfce4-pulseaudio-plugin-0.5.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xfce4-pulseaudio-plugin -Dm644 COPYING
popd
rm -rf xfce4-pulseaudio-plugin-0.5.1
# pavucontrol.
tar -xf ../sources/pavucontrol-5.0.tar.xz
pushd pavucontrol-5.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/pavucontrol -Dm644 LICENSE
popd
rm -rf pavucontrol-5.0
# Blueman.
tar -xf ../sources/blueman-2.4.4.tar.xz
pushd blueman-2.4.4
sed -i '/^dbusdir =/ s/sysconfdir/datadir/' data/configs/Makefile.{am,in}
./configure --prefix=/usr --sysconfdir=/etc --with-dhcp-config=/etc/dhcp/dhcpd.conf
make
make install
cp -af /etc/xdg/autostart/blueman.desktop /usr/share/blueman/autostart.desktop
cat > /usr/bin/blueman-autostart << "END"
#!/bin/bash

not_root() {
  echo "Error: $(basename "$0") must be run as root." >&2
  exit 1
}

usage() {
  echo "$(basename "$0"): Control whether Blueman will autostart on login." >&2
  echo "Usage: $(basename "$0") [enable|disable]" >&2
  exit 1
}

[ $EUID -eq 0 ] || not_root

[ ! -z "$1" ] || usage

case "$1" in
  enable) cp -af /usr/share/blueman/autostart.desktop /etc/xdg/autostart/blueman.desktop ;;
  disable) rm -f /etc/xdg/autostart/blueman.desktop ;;
  *) usage ;;
esac
END
chmod 755 /bin/blueman-autostart
install -t /usr/share/licenses/blueman -Dm644 COPYING
popd
rm -rf blueman-2.4.4
# xfce4-screenshooter.
tar -xf ../sources/xfce4-screenshooter-1.11.1.tar.bz2
pushd xfce4-screenshooter-1.11.1
patch -Np1 -i ../../patches/xfce4-screenshooter-1.11.1-upstreamfix.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libexecdir=/usr/lib --disable-static --disable-debug --enable-wayland --enable-x11
make
make -j1 install
install -t /usr/share/licenses/xfce4-screenshooter -Dm644 COPYING
popd
rm -rf xfce4-screenshooter-1.11.1
# xfce4-taskmanager.
tar -xf ../sources/xfce4-taskmanager-1.5.8.tar.bz2
pushd xfce4-taskmanager-1.5.8
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-taskmanager -Dm644 COPYING
popd
rm -rf xfce4-taskmanager-1.5.8
# xfce4-clipman-plugin.
tar -xf ../sources/xfce4-clipman-plugin-1.6.7.tar.bz2
pushd xfce4-clipman-plugin-1.6.7
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-clipman-plugin -Dm644 COPYING
popd
rm -rf xfce4-clipman-plugin-1.6.7
# xfce4-mount-plugin.
tar -xf ../sources/xfce4-mount-plugin-1.1.7.tar.bz2
pushd xfce4-mount-plugin-1.1.7
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-mount-plugin -Dm644 COPYING
popd
rm -rf xfce4-mount-plugin-1.1.7
# xfce4-whiskermenu-plugin.
tar -xf ../sources/xfce4-whiskermenu-plugin-2.9.2.tar.bz2
pushd xfce4-whiskermenu-plugin-2.9.2
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -Wno-dev -G Ninja -B build -S .
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xfce4-whiskermenu-plugin -Dm644 COPYING
popd
rm -rf xfce4-whiskermenu-plugin-2.9.2
# xfce4-screensaver.
tar -xf ../sources/xfce4-screensaver-4.18.4.tar.bz2
pushd xfce4-screensaver-4.18.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-screensaver -Dm644 COPYING
popd
rm -rf xfce4-screensaver-4.18.4
# xarchiver.
tar -xf ../sources/xarchiver-0.5.4.25.tar.gz
pushd xarchiver-0.5.4.25
./configure  --prefix=/usr --libexecdir=/usr/lib/xfce4
make
make install
install -t /usr/share/licenses/xarchiver -Dm644 COPYING
popd
rm -rf xarchiver-0.5.4.25
# thunar-archive-plugin.
tar -xf ../sources/thunar-archive-plugin-0.5.3.tar.bz2
pushd thunar-archive-plugin-0.5.3
./configure --prefix=/usr --sysconfdir=/etc  --libexecdir=/usr/lib/xfce4 --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/thunar-archive-plugin -Dm644 COPYING
popd
rm -rf thunar-archive-plugin-0.5.3
# Mousepad.
tar -xf ../sources/mousepad-0.6.5.tar.xz
pushd mousepad-0.6.5
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dkeyfile-settings=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/mousepad -Dm644 COPYING
popd
rm -rf mousepad-0.6.5
# GNOME-Calculator.
tar -xf ../sources/gnome-calculator-48.1.tar.bz2
pushd gnome-calculator-48.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gnome-calculator -Dm644 COPYING
popd
rm -rf gnome-calculator-48.1
# GParted.
tar -xf ../sources/gparted-GPARTED_1_7_0.tar.bz2
pushd gparted-GPARTED_1_7_0
autoreconf -fi
./configure --prefix=/usr --disable-doc --disable-static --enable-libparted-dmraid --enable-online-resize --enable-xhost-root
make
make install
install -t /usr/share/licenses/gparted -Dm644 COPYING
popd
rm -rf gparted-GPARTED_1_7_0
# gnome-disk-utility.
tar -xf ../sources/gnome-disk-utility-46.1.tar.bz2
pushd gnome-disk-utility-46.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gnome-disk-utility -Dm644 COPYING
popd
rm -rf gnome-disk-utility-46.1
# Popsicle.
tar -xf ../sources/popsicle-1.3.3.tar.gz
pushd popsicle-1.3.3
make
make prefix=/usr install
install -t /usr/share/licenses/popsicle -Dm644 LICENSE
popd
rm -rf popsicle-1.3.3
# Mugshot.
tar -xf ../sources/mugshot-0.4.3.tar.gz
pushd mugshot-0.4.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/mugshot -Dm644 COPYING
popd
rm -rf mugshot-0.4.3
# Claws-Mail.
tar -xf ../sources/claws-mail-4.3.1.tar.xz
pushd claws-mail-4.3.1
./configure --prefix=/usr --disable-static --enable-bogofilter-plugin --enable-crash-dialog --enable-enchant --enable-fancy-plugin --enable-gnutls --enable-ldap --enable-manual --enable-pgpmime-plugin --enable-spamassassin-plugin
make
make install
install -t /usr/share/licenses/claws-mail -Dm644 COPYING
popd
rm -rf claws-mail-4.3.1
# Evince.
tar -xf ../sources/evince-48.0.tar.gz
pushd evince-48.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dnautilus=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/evince -Dm644 COPYING
popd
rm -rf evince-48.0
# Baobab.
tar -xf ../sources/baobab-48.0.tar.bz2
pushd baobab-48.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/baobab -Dm644 COPYING
popd
rm -rf baobab-48.0
# GNOME-Firmware.
tar -xf ../sources/gnome-firmware-47.0.tar.bz2
pushd gnome-firmware-47.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gnome-firmware -Dm644 COPYING
popd
rm -rf gnome-firmware-47.0
# GNOME-Software.
tar -xf ../sources/gnome-software-48.0.tar.bz2
pushd gnome-software-48.0
tar -xf ../../sources/gnome-pwa-list-48ac9f7.tar.bz2 -C subprojects/gnome-pwa-list --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddkms=true -Dexternal_appstream=true -Dpackagekit=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gnome-software -Dm644 COPYING
popd
rm -rf gnome-software-48.0
# MassOS-Welcome.
tar -xf ../sources/massos-welcome-002.tar.gz
pushd massos-welcome-f978ef71ca6f58156969860d34a706943b79db79
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
install -Dm755 build/target/release/gnome-tour /usr/bin/massos-welcome
cat > /usr/libexec/firstlogin << "END"
#!/bin/sh
massos-welcome
rm -f ~/.config/autostart/firstlogin.desktop
END
chmod 755 /usr/libexec/firstlogin
install -dm755 /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/firstlogin.desktop << "END"
[Desktop Entry]
Type=Application
Name=First Login Welcome Program
Exec=/usr/libexec/firstlogin
END
install -t /usr/share/licenses/massos-welcome -Dm644 LICENSE.md
popd
rm -rf massos-welcome-f978ef71ca6f58156969860d34a706943b79db79
# LightDM.
tar -xf ../sources/lightdm-1.32.0.tar.xz
pushd lightdm-1.32.0
echo 'u lightdm - "LightDM Daemon" /var/lib/lightdm' > /usr/lib/sysusers.d/lightdm.conf
systemd-sysusers
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libexecdir=/usr/lib/lightdm --sbindir=/usr/bin --disable-static --disable-tests --with-greeter-user=lightdm --with-greeter-session=lightdm-gtk-greeter
make
make install
install -t /usr/bin -Dm755 tests/src/lightdm-session
sed -i '1 s/sh/bash --login/' /usr/bin/lightdm-session
sed -i 's/#user-session=default/user-session=xfce/' /etc/lightdm/lightdm.conf
rm -rf /etc/init
install -dm755 -o lightdm -g lightdm /var/lib/lightdm
install -dm755 -o lightdm -g lightdm /var/lib/lightdm-data
install -dm755 -o lightdm -g lightdm /var/cache/lightdm
install -dm770 -o lightdm -g lightdm /var/log/lightdm
install -t /usr/share/licenses/lightdm -Dm644 COPYING.GPL3 COPYING.LGPL2 COPYING.LGPL3
popd
rm -rf lightdm-1.32.0
# lightdm-gtk-greeter.
tar -xf ../sources/lightdm-gtk-greeter-2.0.9.tar.gz
pushd lightdm-gtk-greeter-2.0.9
./configure --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib/lightdm --sbindir=/usr/bin --disable-libido --disable-libindicator --disable-maintainer-mode --disable-static --enable-kill-on-sigterm --with-libxklavier
make
make install
sed -i 's|#background=|background = /usr/share/backgrounds/MassOS-Futuristic-Dark.png|' /etc/lightdm/lightdm-gtk-greeter.conf
install -t /usr/share/licenses/lightdm-gtk-greeter -Dm644 COPYING
systemctl enable lightdm
popd
rm -rf lightdm-gtk-greeter-2.0.9
# Firefox.
tar --no-same-owner -xf ../sources/firefox-138.0.1.tar.xz -C /usr/lib
mkdir -p /usr/lib/firefox/distribution
cat > /usr/lib/firefox/distribution/policies.json << "END"
{
  "policies": {
    "DisableAppUpdate": true
  }
}
END
ln -sr /usr/lib/firefox/firefox /usr/bin/firefox
mkdir -p /usr/share/{applications,pixmaps}
cat > /usr/share/applications/firefox.desktop << "END"
[Desktop Entry]
Encoding=UTF-8
Name=Firefox Web Browser
Comment=Browse the World Wide Web
GenericName=Web Browser
Exec=firefox %u
Terminal=false
Type=Application
Icon=firefox
Categories=GNOME;GTK;Network;WebBrowser;
MimeType=application/xhtml+xml;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
END
ln -sr /usr/lib/firefox/browser/chrome/icons/default/default128.png /usr/share/pixmaps/firefox.png
install -dm755 /usr/share/licenses/firefox
cat > /usr/share/licenses/firefox/LICENSE << "END"
Please type 'about:license' in the Firefox URL box to view the Firefox license.
END
# Goodbye, finalize.sh will do the rest.
popd
