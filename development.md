# Progress in MassOS GNOME:

# GNOME Wallpapers

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

*I will add dependencies later.*

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
