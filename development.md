# Progress in MassOS GNOME:

## GNOME Wallpapers

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-backgrounds/41/gnome-backgrounds-41.0.tar.xz
tar -xf gnome-backgrounds-41.0.tar.xz
cd gnome-backgrounds-41.0
mkdir build && cd build
meson --prefix=/usr
ninja
ninja install
cd ../..
rm -r gnome-backgrounds-41.0
rm gnome-backgrounds-41.0.tar.xz
```

## Gedit

Install Libpeas:

```
wget https://download.gnome.org/sources/libpeas/1.30/libpeas-1.30.0.tar.xz
tar -xf libpeas-1.30.0.tar.xz 
cd libpeas-1.30.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r libpeas-1.30.0
rm libpeas-1.30.0.tar.xz
```

Now, we can install Gedit.

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gedit/41/gedit-41.alpha.tar.xz
tar -xf gedit-41.alpha.tar.xz
cd gedit-41.alpha
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gedit-41.alpha
rm gedit-41.alpha.tar.xz
```

## Calculator

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-calculator/41/gnome-calculator-41.1.tar.xz
tar -xf gnome-calculator-41.1.tar.xz
cd gnome-calculator-41.1
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gnome-calculator-41.1
rm gnome-calculator-41.1.tar.xz
```

## Screenshot

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-screenshot/41/gnome-screenshot-41.0.tar.xz
tar -xf gnome-screenshot-41.0.tar.xz
cd gnome-screenshot-41.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gnome-screenshot-41.0
rm gnome-screenshot-41.0.tar.xz
```

## System Monitor

Install Libgtop:

```
wget https://ftp.acc.umu.se/pub/gnome/sources/libgtop/2.40/libgtop-2.40.0.tar.xz
tar -xf libgtop-2.40.0.tar.xz
cd libgtop-2.40.0
./configure --prefix=/usr --disable-static
make
make install
cd ../..
rm -r libgtop-2.40.0
rm libgtop-2.40.0.tar.xz
```
Now, we can install System Monitor.

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-system-monitor/41/gnome-system-monitor-41.0.tar.xz
tar -xf gnome-system-monitor-41.0.tar.xz
cd gnome-system-monitor-41.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gnome-system-monitor-41.0
rm gnome-system-monitor-41.0.tar.xz
```
## Totem, GNOME's video player

Install Grilo

```
wget https://ftp.acc.umu.se/pub/gnome/sources/grilo/0.3/grilo-0.3.14.tar.xz
tar -xf grilo-0.3.14.tar.xz
cd grilo-0.3.14
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Denable-gtk-doc=false
ninja
ninja install
cd ../..
rm -r grilo-0.3.14
rm grilo-0.3.14.tar.xz
```

Install GNOME Desktop

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-desktop/41/gnome-desktop-41.2.tar.xz
tar -xf gnome-desktop-41.2.tar.xz
cd gnome-desktop-41.2
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dgnome_distributor="MassOS"
ninja
ninja install
cd ../..
rm -r gnome-desktop-41.2
rm gnome-desktop-41.2.tar.xz
```

Install Clutter-gst

```
wget https://ftp.acc.umu.se/pub/gnome/sources/clutter-gst/3.0/clutter-gst-3.0.27.tar.xz
tar -xf clutter-gst-3.0.27.tar.xz
cd clutter-gst-3.0.27
./configure --prefix=/usr
make
make install
cd ..
rm -r clutter-gst-3.0.27
rm clutter-gst-3.0.27.tar.xz
```

Install Totem-pl-parser

```
wget https://ftp.acc.umu.se/pub/gnome/sources/totem-pl-parser/3.26/totem-pl-parser-3.26.6.tar.xz
tar -xf totem-pl-parser-3.26.6.tar.xz
cd totem-pl-parser-3.26.6
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r totem-pl-parser-3.26.6
rm totem-pl-parser-3.26.6.tar.xz
```

Now, we can install Totem.

```
wget https://ftp.acc.umu.se/pub/gnome/sources/totem/3.38/totem-3.38.2.tar.xz
tar -xf totem-3.38.2.tar.xz
cd totem-3.38.2
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r totem-3.38.2
rm totem-3.38.2.tar.xz
```
# File Roller

```
wget https://ftp.acc.umu.se/pub/gnome/sources/file-roller/3.40/file-roller-3.40.0.tar.xz
tar -xf file-roller-3.40.0.tar.xz
cd file-roller-3.40.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dpackagekit=false
ninja
ninja install
cd ../..
rm -r file-roller-3.40.0
rm file-roller-3.40.0.tar.xz
```

# Nautilus
Install GNOME Autoar

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-autoar/0.4/gnome-autoar-0.4.1.tar.xz
tar -xf gnome-autoar-0.4.1.tar.xz
cd gnome-autoar-0.4.1
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dvapi=true -Dtests=true
ninja
ninja install
cd ../..
rm -r gnome-autoar-0.4.1
rm gnome-autoar-0.4.1.tar.xz
```
Install Libportal

```
wget https://github.com/flatpak/libportal/releases/download/0.4/libportal-0.4.tar.xz
tar -xf libportal-0.4.tar.xz
cd libportal-0.4
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dgtk_doc=false
ninja
ninja install
cd ../..
rm -r libportal-0.4
rm libportal-0.4.tar.xz
```
Install Tracker
```
wget https://ftp.acc.umu.se/pub/gnome/sources/tracker/3.2/tracker-3.2.1.tar.xz
tar -xf tracker-3.2.1.tar.xz
cd tracker-3.2.1
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Ddocs=false -Dman=false
ninja
ninja install
cd ../..
rm -r tracker-3.2.1
rm tracker-3.2.1.tar.xz
```

Now, we can install Nautilus

```
wget https://ftp.acc.umu.se/pub/gnome/sources/nautilus/41/nautilus-41.1.tar.xz
tar -xf nautilus-41.1.tar.xz
cd nautilus-41.1
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dselinux=false -Dpackagekit=false
ninja
ninja install
cd ../..
rm -r nautilus-41.1
rm nautilus-41.1.tar.xz
```

## GNOME Bluetooth

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-bluetooth/3.34/gnome-bluetooth-3.34.5.tar.xz
tar -xf gnome-bluetooth-3.34.5.tar.xz
cd gnome-bluetooth-3.34.5
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gnome-bluetooth-3.34.5
rm gnome-bluetooth-3.34.5.tar.xz
```
## GNOME Session

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-session/40/gnome-session-40.1.tar.xz
tar -xf gnome-session-40.1.tar.xz
cd gnome-session-40.1
sed 's@/bin/sh@/bin/sh -l@' -i gnome-session/gnome-session.in
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
mv -v /usr/share/doc/gnome-session{,-40.1.1}
cd ../..
rm -r gnome-session-40.1
rm gnome-session-40.1.tar.xz
```
## Dconf

```
wget https://ftp.acc.umu.se/pub/gnome/sources/dconf/0.40/dconf-0.40.0.tar.xz
tar -xf dconf-0.40.0.tar.xz
cd dconf-0.40.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dbash_completion=false
ninja
ninja install
cd ../..
rm -r dconf-0.40.0
rm dconf-0.40.0.tar.xz
```
## GNOME Shell
Install Evolution Data Server
```
wget https://ftp.acc.umu.se/pub/gnome/sources/evolution-data-server/3.41/evolution-data-server-3.41.3.tar.xz
tar -xf evolution-data-server-3.41.3.tar.xz
cd evolution-data-server-3.41.3
cmake -DCMAKE_INSTALL_PREFIX=/usr   \
      -DSYSCONF_INSTALL_DIR=/etc    \
      -DENABLE_VALA_BINDINGS=ON     \
      -DENABLE_INSTALLED_TESTS=ON   \
      -DENABLE_GOOGLE=ON            \
      -DWITH_OPENLDAP=OFF           \
      -DWITH_KRB5=OFF               \
      -DENABLE_INTROSPECTION=ON     \
      -DENABLE_GTK_DOC=OFF          \
      -DWITH_LIBDB=OFF              \
      -DENABLE_WEATHER=OFF
make
make install
cd ..
rm -r evolution-data-server-3.41.3
rm evolution-data-server-3.41.3.tar.xz
```
Install Geocode Glib
```
wget https://ftp.acc.umu.se/pub/gnome/sources/geocode-glib/3.26/geocode-glib-3.26.2.tar.xz
tar -xf geocode-glib-3.26.2.tar.xz
cd geocode-glib-3.26.2
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Denable-gtk-doc=false
ninja
ninja install
cd ../..
rm -r geocode-glib-3.26.2
rm geocode-glib-3.26.2.tar.xz
```
Install LibGweather
```
wget https://ftp.acc.umu.se/pub/gnome/sources/libgweather/40/libgweather-40.0.tar.xz
tar -xf libgweather-40.0.tar.xz
cd libgweather-40.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r libgweather-40.0
rm libgweather-40.0.tar.xz
```

Install GNOME Settings Daemon
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-settings-daemon/41/gnome-settings-daemon-41.0.tar.xz
tar -xf gnome-settings-daemon-41.0.tar.xz
cd gnome-settings-daemon-41.0
rm -fv /usr/lib/systemd/user/gsd-*
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gnome-settings-daemon-41.0
rm gnome-settings-daemon-41.0.tar.xz
```
Install Pipewire
```
wget https://github.com/PipeWire/pipewire/archive/0.3.42/pipewire-0.3.42.tar.gz
tar -xf pipewire-0.3.42.tar.gz
cd pipewire-0.3.42
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dsession-managers=
ninja
ninja install
cd ../..
rm -r pipewire-0.3.42
rm pipewire-0.3.42.tar.gz
```

Install Mutter
```
wget https://ftp.acc.umu.se/pub/gnome/sources/mutter/41/mutter-41.2.tar.xz
tar -xf mutter-41.2.tar.xz
cd mutter-41.2
sed -i '/libmutter_dep = declare_dependency(/a sources: mutter_built_sources,' src/meson.build
wget https://raw.githubusercontent.com/archlinux/svntogit-packages/packages/xorg-server/trunk/xvfb-run
install -m755 xvfb-run /usr/bin/xvfb-run
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r mutter-41.2
rm mutter-41.2.tar.xz
```
Install GJS
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gjs/1.70/gjs-1.70.0.tar.xz
tar -xf gjs-1.70.0.tar.xz
cd gjs-1.70.0
wget https://cdn.discordapp.com/attachments/845964267520917545/921711644915146772/gjs-1.70.0-meson-0.60.2.patch
patch -Np1 -i gjs-1.70.0-meson-0.60.2.patch
mkdir gjs-build && cd gjs-build
meson --prefix=/usr --buildtype=release
ninja
ninja install
ln -sfv gjs-console /usr/bin/gjs
cd ../..
rm -r gjs-1.70.0
rm gjs-1.70.0.tar.xz
```
Install GTK4
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gtk/4.5/gtk-4.5.1.tar.xz
tar -xf gtk-4.5.1.tar.xz
cd gtk-4.5.1
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dbroadway-backend=true -Dcolord=enabled -Dsysprof=enabled -Dmedia-gstreamer=enabled -Dmedia-ffmpeg=enabled
ninja
ninja install
cd ../..
rm -r gtk-4.5.1
rm gtk-4.5.1.tar.xz
```
Install iBus
```
wget https://github.com/ibus/ibus/releases/download/1.5.25/ibus-1.5.25.tar.gz
tar -xf ibus-1.5.25.tar.gz
cd ibus-1.5.25
sed -i 's@/desktop/ibus@/org/freedesktop/ibus@g' \
    data/dconf/org.freedesktop.ibus.gschema.xml
./configure --prefix=/usr --sysconfdir=/etc --disable-unicode-dict --disable-emoji-dict
rm -f tools/main.c
make
make install
gzip -dfv /usr/share/man/man{{1,5}/ibus*.gz,5/00-upstream-settings.5.gz}
cd ..
rm -r ibus-1.5.25
rm ibus-1.5.25.tar.gz
```

Now, we can install GNOME Shell
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-shell/41/gnome-shell-41.2.tar.xz
tar -xf gnome-shell-41.2.tar.xz
cd gnome-shell-41.2
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gnome-shell-41.2
rm gnome-shell-41.2.tar.xz
```
## GDM

```
groupadd -g 21 gdm &&
useradd -c "GDM Daemon Owner" -d /var/lib/gdm -u 21 \
        -g gdm -s /bin/false gdm &&
passwd -ql gdm
wget https://ftp.acc.umu.se/pub/gnome/sources/gdm/41/gdm-41.0.tar.xz
tar -xf gdm-41.0.tar.xz
cd gdm-41.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gdm-41.0
rm gdm-41.0.tar.xz
```
To set GDM as the default display manager:
`systemctl enable gdm`

## GNOME Terminal

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-terminal/3.41/gnome-terminal-3.41.90.tar.xz
tar -xf gnome-terminal-3.41.90.tar.xz
cd gnome-terminal-3.41.90
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dsearch_provider=false
ninja
ninja install
cd ../..
rm -r gnome-terminal-3.41.90
rm gnome-terminal-3.41.90.tar.xz
```

## GNOME Tweaks

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-tweaks/40/gnome-tweaks-40.0.tar.xz
tar -xf gnome-tweaks-40.0.tar.xz
cd gnome-tweaks-40.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gnome-tweaks-40.0
rm gnome-tweaks-40.0.tar.xz
```
## Set theme

```
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita"
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans Regular 10'
gsettings set org.gnome.desktop.interface font-name 'Noto Sans Regular 10'
gsettings set org.gnome.desktop.interface monospace-font-name 'Noto Sans Mono Regular 11'
```
