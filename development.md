# Progress in MassOS GNOME:

## GNOME Wallpapers

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-backgrounds/42/gnome-backgrounds-42.beta.tar.xz
tar -xf gnome-backgrounds-42.beta.tar.xz
cd gnome-backgrounds-42.beta
mkdir build && cd build
meson --prefix=/usr
ninja
ninja install
cd ..
install -t /usr/share/licenses/gnome-backgrounds -Dm644 COPYING COPYING_CCBY2 COPYING_CCBYSA2 COPYING_CCBYSA3
cd ..
rm -r gnome-backgrounds-42.beta
rm gnome-backgrounds-42.beta.tar.xz
```
## Install GTK4
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gtk/4.6/gtk-4.6.1.tar.xz
tar -xf gtk-4.6.1.tar.xz
cd gtk-4.6.1
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dbroadway-backend=true -Dcolord=enabled -Dsysprof=enabled -Dmedia-gstreamer=enabled -Dmedia-ffmpeg=enabled -Ddemos=false
ninja
ninja install
install -t /usr/share/licenses/gtk4 -Dm644 ../COPYING
cd ../..
rm -r gtk-4.6.1
rm gtk-4.6.1.tar.xz
```
## Libadwaita
```
wget https://ftp.acc.umu.se/pub/gnome/sources/libadwaita/1.1/libadwaita-1.1.beta.tar.xz
tar -xf libadwaita-1.1.beta.tar.xz
cd libadwaita-1.1.beta
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/libadwaita -Dm644 ../COPYING
cd ../..
rm -r libadwaita-1.1.beta
rm libadwaita-1.1.beta.tar.xz
```
## GNOME Text Editor

Install GTK Source View
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gtksourceview/5.3/gtksourceview-5.3.2.tar.xz
tar -xf gtksourceview-5.3.2.tar.xz
cd gtksourceview-5.3.2
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gtksourceview -Dm644 ../COPYING
cd ../..
rm -r gtksourceview-5.3.2 
rm gtksourceview-5.3.2.tar.xz
```

Now, we can install GNOME Text Editor

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-text-editor/42/gnome-text-editor-42.beta1.tar.xz
tar -xf gnome-text-editor-42.beta1.tar.xz
cd gnome-text-editor-42.beta1
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-text-editor -Dm644 ../COPYING
cd ../..
rm -r gnome-text-editor-42.beta1
rm gnome-text-editor-42.beta1.tar.xz
```

## Calculator

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-calculator/42/gnome-calculator-42.rc.tar.xz
tar -xf gnome-calculator-42.rc.tar.xz
cd gnome-calculator-42.rc
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-calculator -Dm644 ../COPYING
cd ../..
rm -r gnome-calculator-42.rc
rm gnome-calculator-42.rc.tar.xz
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
install -t /usr/share/licenses/libgtop -Dm644 COPYING
cd ..
rm -r libgtop-2.40.0
rm libgtop-2.40.0.tar.xz
```
Now, we can install System Monitor.

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-system-monitor/42/gnome-system-monitor-42.rc.tar.xz
tar -xf gnome-system-monitor-42.rc.tar.xz
cd gnome-system-monitor-42.rc
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-system-monitor -Dm644 ../COPYING
cd ../..
rm -r gnome-system-monitor-42.rc
rm gnome-system-monitor-42.rc.tar.xz
```
## Totem, GNOME's video player

Install Totem-pl-parser

```
wget https://ftp.acc.umu.se/pub/gnome/sources/totem-pl-parser/3.26/totem-pl-parser-3.26.6.tar.xz
tar -xf totem-pl-parser-3.26.6.tar.xz
cd totem-pl-parser-3.26.6
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/totem-pl-parser -Dm644 ../COPYING.LIB
cd ../..
rm -r totem-pl-parser-3.26.6
rm totem-pl-parser-3.26.6.tar.xz
```

Install GNOME Desktop

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-desktop/42/gnome-desktop-42.beta.tar.xz
tar -xf gnome-desktop-42.beta.tar.xz
cd gnome-desktop-42.beta
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dgnome_distributor="MassOS"
ninja
ninja install
install -t /usr/share/licenses/gnome-desktop -Dm644 ../COPYING
cd ../..
rm -r gnome-desktop-42.beta
rm gnome-desktop-42.beta.tar.xz
```

Install Clutter-gst

```
wget https://ftp.acc.umu.se/pub/gnome/sources/clutter-gst/3.0/clutter-gst-3.0.27.tar.xz
tar -xf clutter-gst-3.0.27.tar.xz
cd clutter-gst-3.0.27
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/clutter-gst -Dm644 COPYING
cd ..
rm -r clutter-gst-3.0.27
rm clutter-gst-3.0.27.tar.xz
```
Install Grilo

```
wget https://ftp.acc.umu.se/pub/gnome/sources/grilo/0.3/grilo-0.3.14.tar.xz
tar -xf grilo-0.3.14.tar.xz
cd grilo-0.3.14
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Denable-gtk-doc=false
ninja
ninja install
install -t /usr/share/licenses/grilo -Dm644 ../COPYING
cd ../..
rm -r grilo-0.3.14
rm grilo-0.3.14.tar.xz
```
Install Libpeas
```
wget https://ftp.acc.umu.se/pub/gnome/sources/libpeas/1.30/libpeas-1.30.0.tar.xz
tar -xf libpeas-1.30.0.tar.xz 
cd libpeas-1.30.0
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/libpeas -Dm644 ../COPYING
cd ../..
rm -r libpeas-1.30.0
rm libpeas-1.30.0.tar.xz
```
Now, we can install Totem. (not working at the moment)

```
wget https://ftp.acc.umu.se/pub/gnome/sources/totem/42/totem-42.beta.tar.xz
tar -xf totem-42.beta.tar.xz
cd totem-42.beta
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/totem -Dm644 ../COPYING
cd ../..
rm -r totem-42.beta
rm totem-42.beta.tar.xz
```
# File Roller

```
wget https://ftp.acc.umu.se/pub/gnome/sources/file-roller/3.41/file-roller-3.41.90.tar.xz
tar -xf file-roller-3.41.90.tar.xz
cd file-roller-3.41.90
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dpackagekit=false
ninja
ninja install
install -t /usr/share/licenses/file-roller -Dm644 ../COPYING
cd ../..
rm -r file-roller-3.41.90
rm file-roller-3.41.90.tar.xz
```

# Nautilus
Install GNOME Autoar

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-autoar/0.4/gnome-autoar-0.4.3.tar.xz
tar -xf gnome-autoar-0.4.3.tar.xz
cd gnome-autoar-0.4.3
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dvapi=true -Dtests=true
ninja
ninja install
install -t /usr/share/licenses/gnome-autoar -Dm644 ../COPYING
cd ../..
rm -r gnome-autoar-0.4.3
rm gnome-autoar-0.4.3.tar.xz
```
Install Libportal

```
wget https://github.com/flatpak/libportal/releases/download/0.5/libportal-0.5.tar.xz
tar -xf libportal-0.5.tar.xz
cd libportal-0.5
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Ddocs=false -Dbackends=gtk4
ninja
ninja install
install -t /usr/share/licenses/libportal -Dm644 ../COPYING
cd ../..
rm -r libportal-0.5
rm libportal-0.5.tar.xz
```
Install Tracker
```
wget https://ftp.acc.umu.se/pub/gnome/sources/tracker/3.3/tracker-3.3.0.rc.tar.xz
tar -xf tracker-3.3.0.rc.tar.xz
cd tracker-3.3.0.rc
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Ddocs=false -Dman=false
ninja
ninja install
install -t /usr/share/licenses/tracker -Dm644 ../COPYING
cd ../..
rm -r tracker-3.3.0.rc
rm tracker-3.3.0.rc.tar.xz
```

Now, we can install Nautilus

```
wget https://ftp.acc.umu.se/pub/gnome/sources/nautilus/42/nautilus-42.rc.tar.xz
tar -xf nautilus-42.rc.tar.xz
cd nautilus-42.rc
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dselinux=false -Dpackagekit=false
ninja
ninja install
install -t /usr/share/licenses/nautilus -Dm644 ../COPYING
cd ../..
rm -r nautilus-42.rc
rm nautilus-42.rc.tar.xz
```
## GSound
```
wget ftp://ftp.acc.umu.se/pub/gnome/sources/gsound/1.0/gsound-1.0.3.tar.xz
tar -xf gsound-1.0.3.tar.xz
cd gsound-1.0.3
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gsound -Dm644 ../COPYING
cd ../..
rm -r gsound-1.0.3
rm gsound-1.0.3.tar.xz
```

## GNOME Bluetooth

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-bluetooth/42/gnome-bluetooth-42.beta.tar.xz
tar -xf gnome-bluetooth-42.beta.tar.xz
cd gnome-bluetooth-42.beta
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-bluetooth -Dm644 ../COPYING
cd ../..
rm -r gnome-bluetooth-42.beta
rm gnome-bluetooth-42.beta.tar.xz
```
## GNOME Session

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-session/41/gnome-session-41.3.tar.xz
tar -xf gnome-session-41.3.tar.xz
cd gnome-session-41.3
sed 's@/bin/sh@/bin/sh -l@' -i gnome-session/gnome-session.in
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-session -Dm644 ../COPYING
mv -v /usr/share/doc/gnome-session{,-41.3}
cd ../..
rm -r gnome-session-41.3
rm gnome-session-41.3.tar.xz
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
install -t /usr/share/licenses/dconf -Dm644 ../COPYING
cd ../..
rm -r dconf-0.40.0
rm dconf-0.40.0.tar.xz
```
## GNOME Shell
Install Evolution Data Server
```
wget https://ftp.acc.umu.se/pub/gnome/sources/evolution-data-server/3.43/evolution-data-server-3.43.3.tar.xz
tar -xf evolution-data-server-3.43.3.tar.xz
cd evolution-data-server-3.43.3
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
install -t /usr/share/licenses/evolution-data-server -Dm644 COPYING
cd ..
rm -r evolution-data-server-3.43.3
rm evolution-data-server-3.43.3.tar.xz
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
install -t /usr/share/licenses/geocode-glib -Dm644 ../COPYING
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
install -t /usr/share/licenses/libgweather -Dm644 ../COPYING
cd ../..
rm -r libgweather-40.0
rm libgweather-40.0.tar.xz
```

Install GNOME Settings Daemon
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-settings-daemon/42/gnome-settings-daemon-42.rc.tar.xz
tar -xf gnome-settings-daemon-42.rc.tar.xz
cd gnome-settings-daemon-42.rc
rm -fv /usr/lib/systemd/user/gsd-*
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-settings-daemon -Dm644 ../COPYING
cd ../..
rm -r gnome-settings-daemon-42.rc
rm gnome-settings-daemon-42.rc.tar.xz
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
install -t /usr/share/licenses/pipewire -Dm644 ../COPYING
cd ../..
rm -r pipewire-0.3.42
rm pipewire-0.3.42.tar.gz
```

Install Mutter
```
wget https://ftp.acc.umu.se/pub/gnome/sources/mutter/42/mutter-42.beta.tar.xz
tar -xf mutter-42.beta.tar.xz
cd mutter-42.beta
sed -i '/libmutter_dep = declare_dependency(/a sources: mutter_built_sources,' src/meson.build
wget https://raw.githubusercontent.com/archlinux/svntogit-packages/packages/xorg-server/trunk/xvfb-run
install -m755 xvfb-run /usr/bin/xvfb-run
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/mutter -Dm644 ../COPYING
cd ../..
rm -r mutter-42.beta
rm mutter-42.beta.tar.xz
```
Install GJS
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gjs/1.71/gjs-1.71.90.tar.xz
tar -xf gjs-1.71.90.tar.xz
cd gjs-1.71.90
wget https://cdn.discordapp.com/attachments/845964267520917545/921711644915146772/gjs-1.70.0-meson-0.60.2.patch
patch -Np1 -i gjs-1.71.90-meson-0.60.2.patch
mkdir gjs-build && cd gjs-build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gjs -Dm644 ../COPYING
ln -sfv gjs-console /usr/bin/gjs
cd ../..
rm -r gjs-1.71.90
rm gjs-1.71.90.tar.xz
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
install -t /usr/share/licenses/ibus -Dm644 ../COPYING
gzip -dfv /usr/share/man/man{{1,5}/ibus*.gz,5/00-upstream-settings.5.gz}
cd ..
rm -r ibus-1.5.25
rm ibus-1.5.25.tar.gz
```

Now, we can install GNOME Shell
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-shell/42/gnome-shell-42.beta.tar.xz
tar -xf gnome-shell-42.beta.tar.xz
cd gnome-shell-42.beta
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-shell -Dm644 ../COPYING
cd ../..
rm -r gnome-shell-42.beta
rm gnome-shell-42.beta.tar.xz
```
## GDM

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gdm/41/gdm-41.3.tar.xz
tar -xf gdm-41.3.tar.xz
cd gdm-41.3
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dplymouth=enabled -Dgdm-xsession=true -Ddefault-pam-config=massos
ninja
ninja install
install -t /usr/share/licenses/gdm -Dm644 ../COPYING
groupadd -g 21 gdm &&
useradd -c "GDM Daemon Owner" -d /var/lib/gdm -u 21 \
        -g gdm -s /bin/false gdm &&
passwd -ql gdm
systemctl enable gdm
cd ../..
rm -r gdm-41.3
rm gdm-41.3.tar.xz
```
To set GDM as the default display manager:
`systemctl enable gdm`

## GNOME Terminal

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-terminal/3.43/gnome-terminal-3.43.90.tar.xz
tar -xf gnome-terminal-3.43.90.tar.xz
cd gnome-terminal-3.43.90
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dsearch_provider=false
ninja
ninja install
install -t /usr/share/licenses/gnome-terminal -Dm644 ../COPYING
cd ../..
rm -r gnome-terminal-3.43.90
rm gnome-terminal-3.43.90.tar.xz
```

## GNOME Tweaks

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-tweaks/42/gnome-tweaks-42.beta.tar.xz
tar -xf gnome-tweaks-42.beta.tar.xz
cd gnome-tweaks-42.beta
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
install -t /usr/share/licenses/gnome-tweaks -Dm644 ../COPYING
cd ../..
rm -r gnome-tweaks-42.beta
rm gnome-tweaks-42.beta.tar.xz
```
## GNOME Settings
Install Colord GTK
```
wget https://www.freedesktop.org/software/colord/releases/colord-gtk-0.3.0.tar.xz
tar -xf colord-gtk-0.3.0.tar.xz
cd colord-gtk-0.3.0
mkdir build && cd build
meson --prefix=/usr       \
      --buildtype=release \
      -Dgtk2=true         \
      -Dvapi=true         \
      -Ddocs=false        \
      -Dman=false
ninja
ninja install
install -t /usr/share/licenses/colord-gtk -Dm644 ../COPYING
cd ../..
rm -r colord-gtk-0.3.0
rm colord-gtk-0.3.0.tar.xz
```
Install Parse-Yapp module
```
wget https://www.cpan.org/authors/id/W/WB/WBRASWELL/Parse-Yapp-1.21.tar.gz
tar -xf Parse-Yapp-1.21.tar.gz
cd Parse-Yapp-1.21
perl Makefile.PL
make
make install
cd ..
rm -r Parse-Yapp-1.21
rm Parse-Yapp-1.21.tar.gz
```

Install Samba
```
wget https://download.samba.org/pub/samba/stable/samba-4.15.5.tar.gz
tar -xf samba-4.15.5.tar.gz
cd samba-4.15.5
python3 -m venv pyvenv &&
./pyvenv/bin/pip3 install cryptography pyasn1 iso8601
echo "^samba4.rpc.echo.*on.*ncacn_np.*with.*object.*nt4_dc" >> selftest/knownfail
sed -e 's/!is_allowed/secure_channel_type == SEC_CHAN_NULL \&\& &/' \
    -i source3/winbindd/winbindd_util.c
PYTHON=$PWD/pyvenv/bin/python3             \
CPPFLAGS="-I/usr/include/tirpc"            \
LDFLAGS="-ltirpc"                          \
./configure                                \
    --prefix=/usr                          \
    --sysconfdir=/etc                      \
    --localstatedir=/var                   \
    --with-piddir=/run/samba               \
    --with-pammodulesdir=/usr/lib/security \
    --enable-fhs                           \
    --without-ad-dc                        \
    --enable-selftest
make
sed '1s@^.*$@#!/usr/bin/python3@' \
    -i ./bin/default/source4/scripting/bin/samba-gpupdate.inst
make install
install -v -m644    examples/smb.conf.default /etc/samba
sed -e "s;log file =.*;log file = /var/log/samba/%m.log;" \
    -e "s;path = /usr/spool/samba;path = /var/spool/samba;" \
    -i /etc/samba/smb.conf.default
mkdir -pv /etc/openldap/schema
install -v -m644    examples/LDAP/README              \
                    /etc/openldap/schema/README.LDAP
install -v -m644    examples/LDAP/samba*              \
                    /etc/openldap/schema
install -v -m755    examples/LDAP/{get*,ol*} \
                    /etc/openldap/schema
install -t /usr/share/licenses/samba -Dm644 ../COPYING
cd ..
rm -r samba-4.15.5
rm samba-4.15.5.tar.gz
```
Install gsound
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gsound/1.0/gsound-1.0.3.tar.xz
tar -xf gsound-1.0.3.tar.xz
cd gsound-1.0.3
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
cd ../..
rm -r gsound-1.0.3
rm gsound-1.0.3.tar.xz
```

Now, we can install GNOME Settings
```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-control-center/42/gnome-control-center-42.beta.tar.xz
tar -xf gnome-control-center-42.beta.tar.xz
cd ggnome-control-center-42.beta
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dcheese=false
ninja
ninja install
install -t /usr/share/licenses/gnome-control-center -Dm644 ../COPYING
cd ../..
rm -r gnome-control-center-42.beta
rm gnome-control-center-42.beta.tar.xz
```
## GNOME Themes Extra

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gnome-themes-extra/3.28/gnome-themes-extra-3.28.tar.xz
tar -xf gnome-themes-extra-3.28.tar.xz 
cd gnome-themes-extra-3.28
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gnome-themes-extra -Dm644 COPYING
cd ..
rm -r gnome-themes-extra-3.28
rm gnome-themes-extra-3.28.tar.xz 
```

## Set theme

```
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans Regular 10'
gsettings set org.gnome.desktop.interface font-name 'Noto Sans Regular 10'
gsettings set org.gnome.desktop.interface monospace-font-name 'Noto Sans Mono Regular 11'
```
