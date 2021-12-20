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
```

Now, we may install Gedit.

```
wget https://ftp.acc.umu.se/pub/gnome/sources/gedit/41/gedit-41.alpha.tar.xz
tar -xf gedit-41.alpha.tar.xz
cd gedit-41.alpha
mkdir build && cd build
meson --prefix=/usr --buildtype=release
ninja
ninja install
```
