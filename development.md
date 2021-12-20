# Progress in MassOS GNOME:

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
rm libpeas-1.30.0.tar.xz
rm -r libpeas-1.30.0
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
rm gedit-41.alpha.tar.xz
rm -r gedit-41.alpha
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
rm gnome-calculator-41.1.tar.xz
rm -r gnome-calculator-41.1
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
rm gnome-screenshot-41.0.tar.xz
rm -r gnome-screenshot-41.0
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
rm libgtop-2.40.0.tar.xz
rm -r libgtop-2.40.0
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
rm gnome-system-monitor-41.0.tar.xz
rm -r gnome-system-monitor-41.0
```
