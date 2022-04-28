# Full Changelog History
This document contains the full changelog for every previous versions of MassOS, as well as the changes currently in development for the next upcoming version of MassOS (which may be subject to change before the version is finally released).
# Current Development
Changes:

- Added TPM2 support. This allows programs like systemd to utilise TPM2 chips. It **does not** make TPM2 a system requirement.
- The default initramfs filename is now `initramfs-<kernelversion>.img` instead of `initrd.img-<kernelversion>`. This fixes the `lsinitrd` program.
- Added libglvnd to provide additional graphics libraries which some packages depend on. It also provides some existing Mesa libs, however does not conflict with Mesa.
- Fixed issues with zlib and GTK3.

Upgraded software:

- AppStream: `0.15.2 --> 0.15.3`
- at-spi2-core: `2.44.0 --> 2.44.1`
- bc: `5.2.3 --> 5.2.4`
- BIND Utils: `9.18.1 --> 9.18.2`
- Boost: `1.78.0 --> 1.79.0`
- btrfs-progs: `5.16.2 --> 5.17`
- Coreutils: `9.0 --> 9.1`
- curl: `7.82.0 --> 7.83.0`
- dialog: `1.3-20220117 --> 1.3-20220414`
- elfutils: `0.186 --> 0.187`
- Enchant: `2.3.2 --> 2.3.3`
- Evince: `42.1 --> 42.2`
- FFmpeg: `5.0 --> 5.0.1`
- Fribidi: `1.0.11 --> 1.0.12`
- GCC: `11.2.0 --> 11.3.0`
- Git: `2.35.3 --> 2.36.0`
- GLib: `2.72.0 --> 2.72.1`
- GNUPG: `2.3.4 --> 2.3.6`
- gptfdisk: `1.0.8 --> 1.0.9`
- gspell: `1.9.1 --> 1.10.0`
- GVFS: `1.50.0 --> 1.50.1`
- HarfBuzz: `4.2.0 --> 4.2.1`
- iana-etc: `20220401 --> 20220414`
- libhandy: `1.6.1 --> 1.6.2`
- libinput: `1.20.0 --> 1.20.1`
- libmbim: `1.26.2 --> 1.26.4`
- libnl: `3.5.0 --> 3.6.0`
- libnotify: `0.7.9 --> 0.7.11`
- libpipeline: `1.5.5 --> 1.5.6`
- librsvg: `2.54.0 --> 2.54.1`
- libseccomp: `2.5.3 --> 2.5.4`
- Linux Kernel: `5.17.3 --> 5.17.5`
- LLVM/CLang/LLD: `14.0.1 --> 14.0.2`
- JACK2: `1.9.20 --> 1.9.21`
- JSON-C: `0.15 --> 0.16`
- Mesa: `22.0.1 --> 22.0.2`
- Meson: `0.62.0 --> 0.62.1`
- Nano: `6.2 --> 6.3`
- Pango: `1.50.6 --> 1.50.7`
- Parted: `3.4 --> 3.5`
- pciutils: `3.7.0 --> 3.8.0`
- PCRE2: `10.39 --> 10.40`
- pkcs11-helper: `1.28.0 --> 1.29.0`
- Pygments: `2.11.2 --> 2.12.0`
- PyGObject: `3.42.0 --> 3.42.1`
- rsync: `3.2.3 --> 3.2.4`
- Ruby: `3.1.1 --> 3.1.2`
- SDL2: `2.0.20 --> 2.0.22`
- SQLite: `3.38.2 --> 3.38.3`
- Thunderbird: `91.7.0 --> 91.8.1`
- Unifont: `14.0.02 --> 14.0.03`
- Vala: `0.56.0 --> 0.56.1`
- Vim: `8.2.4700 --> 8.2.4826`
- xauth: `1.1.1 --> 1.1.2`
- xdg-desktop-portal: `1.14.2 --> 1.14.3`
- xfce4-panel: `4.16.3 --> 4.16.4`
- xfce4-terminal: `1.0.1 --> 1.0.2`
- xorgproto: `2021.5 --> 2022.1`

# MassOS 2022.04.2
Changes:

- Added `lsof` utility.
- Added Orage calendar program.
- Fixed app category icon issue (e84a375).
- Replaced the systemd timers with hwdata package to provide lspci/lsusb data.
- Removed FFmpeg 5.0 workaround for Firefox (Firefox 99+ supports FFmpeg 5.0).
- GTK-Doc documentation is no longer removed.
- Added LLD as part of the LLVM/Clang toolchain.
- Added Xfburn optical disc burning application.

Upgraded software:

- adwaita-icon-theme: `42.0 --> 41.0` (rollback, see commit e84a375)
- AppArmor: `3.0.3 --> 3.0.4`
- Audit: `3.0.7 --> 3.0.8`
- bc: `5.2.2 --> 5.2.3`
- CMake: `3.23.0-rc5 --> 3.23.1`
- cups-filters: `1.28.13 --> 1.28.15`
- Evince: `41.4 --> 42.1`
- Expat: `2.4.7 --> 2.4.8`
- fcron: `3.2.1 --> 3.3.1`
- Firefox: `98.0.2 --> 99.0.1`
- Fontconfig: `2.13.96 --> 2.14.0`
- FreeType: `2.11.1 --> 2.12.0`
- Gedit: `41.0 --> 42.0`
- Ghostscript: `9.55.0 --> 9.56.1`
- Git: `2.35.1 --> 2.35.3`
- glslang: `11.8.0 --> 11.9.0`
- gnome-online-accounts: `3.40.1 --> 3.44.0`
- GNUPG: `2.2.34 --> 2.3.4`
- gsettings-desktop-schemas: `41.0 --> 42.0`
- GVFS: `1.48.1 --> 1.50.0`
- Gzip: `1.11 --> 1.12`
- HarfBuzz: `4.1.0 --> 4.2.0`
- iana-etc: `20220325 --> 20220401`
- iceauth: `1.0.8 --> 1.0.9`
- ICU: `70.1 --> 71.1`
- Jinja2: `3.0.3 --> 3.1.1`
- JS91: `91.7.1 --> 91.8.0`
- less: `590 --> 600`
- libaio: `0.3.112 --> 0.3.113`
- libarchive: `3.6.0 --> 3.6.1`
- libcap: `2.63 --> 2.64`
- libgpg-error: `1.44 --> 1.45`
- libnma: `1.8.36 --> 1.8.38`
- libsndfile: `1.0.31 --> 1.1.0`
- libstemmer: `2.1.0 --> 2.2.0`
- libusb: `1.0.25 --> 1.0.26`
- libX11: `1.7.3 --> 1.7.5`
- libXcursor: `1.2.0 --> 1.2.1`
- libxfce4ui: `4.17.4 --> 4.17.6`
- Linux Kernel: `5.17.1 --> 5.17.3`
- LLVM/Clang/LLD: `13.0.1 --> 14.0.1`
- Mesa: `22.0.0 --> 22.0.1`
- mkfontscale: `1.2.1 --> 1.2.2`
- mobile-broadband-provider-info: `20210805 --> 20220315`
- Moreutils: `0.66 --> 0.67`
- mtools: `4.0.38 --> 4.0.39`
- MuPDF: `1.18.0 --> 1.19.1`
- NSS: `3.76 --> 3.77`
- OpenSSH: `8.9p1 --> 9.0p1`
- Procps-NG: `3.3.17 --> 4.0.0`
- PyParsing: `3.0.6 --> 3.0.7`
- setxkbmap: `1.3.2 --> 1.3.3`
- SPIRV-Headers: `1.3.204.0 --> 1.3.204.1`
- SPIRV-Tools: `2022.1 --> 2022.2`
- Systemd: `250.4 --> 251-rc1`
- Thunar: `4.17.7 --> 4.17.8`
- Vim: `8.2.4626 --> 8.2.4700`
- VTE: `0.67.90 --> 0.68.0`
- Vulkan-Headers: `1.3.208 --> 1.3.211`
- Vulkan-Loader: `1.3.208 --> 1.3.211`
- whois: `5.5.12 --> 5.5.13`
- xdg-desktop-portal: `1.14.1 --> 1.14.2`
- xdpyinfo: `1.3.2 --> 1.3.3`
- xfce4-terminal: `0.9.1 --> 1.0.0`
- xfsprogs: `5.14.2 --> 5.15.0`
- Xwayland: `21.1.4 --> 22.1.1`

# MassOS 2022.04
Changes:

- Started migration of documentation to the MassOS wiki.
- Added a template for issues and bug reports opened on the MassOS repository.
- Kernel modules are now compressed with XZ, taking the total space consumed by modules from ~310MB to ~80MB.
- Added Android ashmem and binder support to the kernel.
- Replaced Python tldr client for [tealdeer](https://github.com/dbrgn/tealdeer), a faster tldr client written in Rust.
- Migrated from JS78 to JS91.
- Switched Wget from OpenSSL to GNUTLS (which is the upstream default).
- Dropped OpenSSL Legacy (1.1.x).

Upgraded software:

- adwaita-icon-theme: `41.0 --> 42.0`
- Asciidoc: `10.1.1 --> 10.1.4`
- at-spi2-core: `2.42.0 --> 2.44.0`
- ATK: `2.36.0 --> 2.38.0`
- BIND Utils: `9.16.25 --> 9.18.1`
- BlueZ: `5.63 --> 5.64`
- Cairo: `1.17.4 --> 1.17.6`
- CMake: `3.23.0-rc2 --> 3.23.0-rc5`
- cups-filters: `1.28.12 --> 1.28.13`
- curl: `7.81.0 --> 7.82.0`
- Cyrus SASL: `2.1.27 --> 2.1.28`
- D-Bus: `1.12.22 --> 1.14.0`
- dhclient: `4.4.2-P1 --> 4.4.3`
- Evince: `41.3 --> 41.4`
- Expat: `2.4.6 --> 2.4.7`
- Fakeroot: `1.27 --> 1.28`
- Firefox: `97.0.1 --> 98.0.2`
- Flatpak: `1.12.6 --> 1.13.2`
- GDK-Pixbuf: `2.42.6 --> 2.42.8`
- GLib: `2.70.4 --> 2.72.0`
- glib-networking: `2.70.1 --> 2.72.0`
- gtksourceview4: `4.8.2 --> 4.8.3`
- GNOME Software: `41.4 --> 41.5`
- GNUTLS: `3.7.3 --> 3.7.4`
- gobject-introspection: `1.70.0 --> 1.72.0`
- GParted: `1.3.1 --> 1.4.0`
- GPGME: `1.17.0 --> 1.17.1`
- Graphene: `1.10.6 --> 1.10.8`
- Graphviz: `2.50.0 --> 3.0.0`
- gst-libav: `1.20.0 --> 1.20.1`
- gst-plugins-bad: `1.20.0 --> 1.20.1`
- gst-plugins-base: `1.20.0 --> 1.20.1`
- gst-plugins-good: `1.20.0 --> 1.20.1`
- gst-plugins-ugly: `1.20.0 --> 1.20.1`
- GStreamer: `1.20.0 --> 1.20.1`
- GTK3: `3.24.31 --> 3.24.33`
- HarfBuzz: `3.4.0 --> 4.1.0`
- iana-etc: `20220222 --> 20220325`
- inih: `53 --> 55`
- IPRoute2: `5.16.0 --> 5.17.0`
- krb5: `1.19.2 --> 1.19.3`
- libdazzle: `3.42.0 --> 3.44.0`
- libepoxy: `1.5.9 --> 1.5.10`
- libevdev: `1.12.0 --> 1.12.1`
- libgcrypt: `1.10.0 --> 1.10.1`
- libglib-testing: `0.1.0 --> 0.1.1`
- libgphoto2: `2.5.27 --> 2.5.29`
- libhandy: `1.5.0 --> 1.6.1`
- libnma: `1.8.32 --> 1.8.36`
- libostree: `2022.1 --> 2022.2`
- libpeas: `1.30.0 --> 1.32.0`
- libportal: `0.5 --> 0.6`
- libportal-gtk3: `0.5 --> 0.6`
- librsvg: `2.52.6 --> 2.54.0`
- libtool: `2.4.6 --> 2.4.7`
- libuv: `1.43.0 --> 1.44.1`
- libva: `2.13.0 --> 2.14.0`
- libvdpau: `1.4 --> 1.5`
- libwacom: `2.1.0 --> 2.2.0`
- libwebp: `1.2.1 --> 1.2.2`
- libXvMC: `1.0.12 --> 1.0.13`
- Linux Kernel: `5.16.12 --> 5.17.1`
- Mako: `1.1.6 --> 1.2.0`
- Man-DB: `2.10.1 --> 2.10.2`
- MarkupSafe: `2.0.1 --> 2.1.1`
- Mesa: `21.3.7 --> 22.0.0`
- Meson: `0.61.2 --> 0.62.0`
- minizip: `1.2.11 --> 1.2.12`
- mtools: `4.0.37 --> 4.0.38`
- network-manager-applet: `1.24.0 --> 1.26.0`
- NetworkManager: `1.36.0 --> 1.36.4`
- NetworkManager-openvpn: `1.8.16 --> 1.8.18`
- NSS: `3.75 --> 3.76`
- OpenSSL: `3.0.1 --> 3.0.2`
- OpenVPN: `2.5.5 --> 2.5.6`
- Pango: `1.50.4 --> 1.50.6`
- Poppler: `22.02.0 --> 22.03.0`
- PyCairo: `1.20.1 --> 1.21.0`
- Python: `3.10.2 --> 3.10.4`
- Qpdf: `10.6.2 --> 10.6.3`
- Ruby: `3.1.0 --> 3.1.1`
- shared-mime-info: `2.1 --> 2.2`
- Shotwell: `0.30.14 --> 0.31.3-133-gd55abab2`
- smbclient: `4.15.5 --> 4.16.0`
- SQLite: `3.38.0 --> 3.38.2`
- Sudo: `1.9.9 --> 1.9.10`
- Sysprof: `3.42.1 --> 3.44.0`
- systemd: `250.3 --> 250.4`
- Thunderbird: `91.6.1 --> 91.7.0`
- tzdata: `2021e --> 2022a`
- Unifont: `14.0.01 --> 14.0.02`
- UPower: `0.99.16 --> 0.99.17`
- util-linux: `2.37.4 --> 2.38`
- Vala: `0.54.7 --> 0.56.0`
- Vim: `8.2.4482 --> 8.2.4626`
- VTE: `0.66.2 --> 0.67.90`
- Vulkan-Headers: `1.3.206 --> 1.3.208`
- Vulkan-Loader: `1.3.206 --> 1.3.208`
- Wget: `1.21.2 --> 1.21.3`
- x264: `0.164.3086 --> 0.164.3094`
- xdg-desktop-portal: `1.12.1 --> 1.14.1`
- xdg-desktop-portal-gtk: `1.12.0 --> 1.14.0`
- xfce4-screenshooter: `1.9.9 --> 1.9.10`
- zlib: `1.2.11 --> 1.2.12`

# MassOS 2022.03
Changes:

- Fixed some minor bugs in the installer.
- Added DJVU and XPS support to Evince.
- Added dvd+rw-tools and wireless-tools.
- Replaced Mousepad with Gedit, a more advanced text editor supporting additional features like syntax highlighting.
- Only the client portion of Samba (smbclient) is now installed, to save some space.
- Added a workaround to fix the current of Firefox with FFmpeg 5.
- Added some extra multimedia codec libraries.
- Add a few extra desktop backgrounds, and a note about the backgrounds.
- Removed gsasl (unneeded package).

Upgraded software:

- AccountsService: `22.04.62 --> 22.08.8`
- AppStream: `0.15.1 --> 0.15.2`
- btrfs-progs: `5.16 --> 5.16.2`
- Bubblewrap: `0.5.0 --> 0.6.1`
- CMake: `3.22.2 --> 3.23.0-rc2`
- cups-filters: `1.28.11 --> 1.28.12`
- D-Bus: `1.12.20 --> 1.12.22`
- dracut: `055 --> 056`
- efivar: `37 --> 38`
- Expat: `2.4.3 --> 2.4.6`
- Firefox: `97.0 --> 97.0.1`
- FLAC: `1.3.3 --> 1.3.4`
- Flatpak: `1.12.5 --> 1.12.6`
- GeoClue: `2.5.7 --> 2.6.0`
- HPLIP: `3.21.12 --> 3.22.2`
- iana-etc: `20220207 --> 20220222`
- libdrm: `2.4.109 --> 2.4.110`
- libinput: `1.19.3 --> 1.20.0`
- libjpeg-turbo: `2.1.2 --> 2.1.3`
- librsvg: `2.52.5 --> 2.52.6`
- libsecret: `0.20.4 --> 0.20.5`
- libwnck: `40.0 --> 40.1`
- libxfce4ui: `4.17.3 --> 4.17.4`
- libxfce4util: `4.17.1 --> 4.17.2`
- libxml2: `2.9.12 --> 2.9.13`
- Linux Kernel: `5.16.10 --> 5.16.12`
- lxml: `4.7.1 --> 4.8.0`
- Mesa: `21.3.6 --> 21.3.7`
- Nano: `6.1 --> 6.2`
- NetworkManager: `1.34.0 --> 1.36.0`
- OpenSSH: `8.8p1 --> 8.9p1`
- Qpdf: `10.6.0 --> 10.6.2`
- SQLite: `3.37.2 --> 3.38.0`
- Thunderbird: `91.6.0 --> 91.6.1`
- tree: `2.0.1 --> 2.0.2`
- Unifont: `13.0.06 --> 14.0.01`
- UPower: `0.99.15 --> 0.99.16`
- Vim: `8.2.4398 --> 8.2.4482`
- Vulkan-Headers: `1.3.204 --> 1.3.206`
- Vulkan-Loader: `1.3.204 --> 1.3.206`
- WebKitGTK: `2.34.5 --> 2.34.6`
- whois: `5.5.11 --> 5.5.12`
- x264: `0.164.3081 --> 0.164.3086`
- x265: `3.5-19-g747a079f7 --> 3.5-35-g7a5709048`

# MassOS 2022.02.2
Changes:

- The core C library (glibc) has been upgraded to the latest version (`2.35`).
- Manual pages are now compressed by default to save space.
- Added Mugshot to allow changing of user settings such as profile picture.
- Added OpenVPN support, including a plugin for NetworkManager to allow easy creation/management of OpenVPN connections.
- Added Evince - PDF viewer program.
- Added Samba support.
- Added `zman` and `unzman`, small utilities for bulk compressing/decompressing manual pages.
- Added `set-default-tar`, a small helper utility allowing you to set the default tar program.

Upgraded software:

- AccountsService: `0.6.55 --> 22.04.62`
- bc: `5.2.1 --> 5.2.2`
- Binutils: `2.37 --> 2.38`
- Ed: `1.17 --> 1.18`
- Exo: `4.16.3 --> 4.17.1`
- Findutils: `4.8.0 --> 4.9.0`
- Firefox: `96.0.3 --> 97.0`
- Flatpak: `1.12.4 --> 1.12.5`
- Fontconfig: `2.13.1 --> 2.13.96`
- FreeGLUT: `3.2.1 --> 3.2.2`
- GDBM: `1.22 --> 1.23`
- GLib: `2.70.3 --> 2.70.4`
- glibc: `2.34 --> 2.35`
- GNOME Software: `41.3 --> 41.4`
- GNUPG: `2.2.32 --> 2.2.34`
- GPGME: `1.16.0 --> 1.17.0`
- gst-libav: `1.18.5 --> 1.20.0`
- gst-plugins-bad: `1.18.5 --> 1.20.0`
- gst-plugins-base: `1.18.5 --> 1.20.0`
- gst-plugins-good: `1.18.5 --> 1.20.0`
- gst-plugins-ugly: `1.18.5 --> 1.20.0`
- GStreamer: `1.18.5 --> 1.20.0`
- HarfBuzz: `3.2.0 --> 3.4.0`
- iana-etc: `20220128 --> 20220207`
- lcms2: `2.12 --> 2.13.1`
- libarchive: `3.5.2 --> 3.6.0`
- libgcrypt: `1.9.4 --> 1.10.0`
- libgee: `0.20.4 --> 0.20.5`
- libical: `3.0.13 --> 3.0.14`
- libqmi: `1.30.2 --> 1.30.4`
- libsigc++: `2.10.7 --> 2.10.8`
- libusb: `1.0.24 --> 1.0.25`
- libwacom: `2.0.0 --> 2.1.0`
- libxfce4ui: `4.16.1 --> 4.17.3`
- libxfce4util: `4.16.0 --> 4.17.1`
- libxkbcommon: `1.3.1 --> 1.4.0`
- Linux Kernel: `5.16.4 --> 5.16.10`
- LLVM/Clang: `13.0.0 --> 13.0.1`
- LVM2: `2.03.14 --> 2.03.15`
- Man-DB: `2.9.4 --> 2.10.1`
- Mesa: `21.3.5 --> 21.3.6`
- Meson: `0.61.1 --> 0.61.2`
- ModemManager: `1.18.4 --> 1.18.6`
- Nano: `6.0 --> 6.1`
- NSS: `3.74 --> 3.75`
- OpenLDAP: `2.6.0 --> 2.6.1`
- Pango: `1.50.3 --> 1.50.4`
- Poppler: `22.01.0 --> 22.02.0`
- Qpdf: `10.5.0 --> 10.6.0`
- slang: `pre2.3.3-64 --> pre2.3.3-66`
- Thunar: `4.16.10 --> 4.17.7`
- Thunderbird: `91.5.1 --> 91.6.0`
- Tumbler: `4.16.0 --> 4.17.0`
- UPower: `0.99.13 --> 0.99.15`
- util-linux: `2.37.3 --> 2.37.4`
- Vala: `0.54.6 --> 0.54.7`
- Vim: `8.2.4250 --> 8.2.4398`
- WebKitGTK: `2.34.4 --> 2.34.5`
- xf86-input-wacom: `0.40.0 --> 1.0.0`
- xfce4-appfinder: `4.16.1 --> 4.17.0`
- xfce4-notifyd: `0.6.2 --> 0.6.3`
- xfce4-terminal: `0.8.10 --> 0.9.1`
- XKeyboard-Config: `2.34 --> 2.35.1`


# MassOS 2022.02
Changes:

- MassOS now has a live ISO image which can be used to try out MassOS, and install MassOS more easily. See below for more information.
- The original rootfs-based installation guide has been moved to [old-installation-guide.md](https://github.com/TheSonicMaster/MassOS/blob/main/old-installation-guide.md).
- Most MassOS repositories are now found in the [MassOS-Linux](https://github.com/MassOS-Linux) organisation. Old repository links will automatically redirect to the new ones.
- Added Fakeroot.
- Added libisoburn, for xorriso utility.

Upgraded software:

- Audit: `3.0.6 --> 3.0.7`
- BIND Utilities: `9.16.24 --> 9.16.25`
- CMake: `3.22.1 --> 3.22.2`
- CUPS: `2.4.0 --> 2.4.1`
- dialog: `1.3-20211214 --> 1.3-20220117`
- FFmpeg: `4.4.1 --> 5.0`
- Firefox: `96.0.1 --> 96.0.3`
- Flatpak: `1.12.3 --> 1.12.4`
- Git: `2.34.1 --> 2.35.1`
- GLib: `2.70.2 --> 2.70.3`
- GNUTLS: `3.7.2 --> 3.7.3`
- iana-etc: `20211229 --> 20220128`
- libcap: `2.62 --> 2.63`
- libgpg-error: `1.43 --> 1.44`
- libical: `3.0.12 --> 3.0.13`
- libwacom: `1.12 --> 2.0.0`
- Linux Kernel: `5.16.1 --> 5.16.4`
- Mesa: `21.3.4 --> 21.3.5`
- p11-kit: `0.24.0 --> 0.24.1`
- SANE: `1.0.32 --> 1.1.1`
- Sudo: `1.9.8p2 --> 1.9.9`
- systemd: `250.2 --> 250.3`
- Thunderbird: `91.5.0 --> 91.5.1`
- util-linux: `2.37.2 --> 2.37.3`
- Vim: `8.2.4100 --> 8.2.4250`
- Vulkan-Headers: `1.2.203 --> 1.3.204`
- Vulkan-Loader: `1.2.203 --> 1.3.204`
- wayland-protocols: `1.24 --> 1.25`
- WebKitGTK: `2.34.3 --> 2.34.4`
- wpa_supplicant: `2.9 --> 2.10`
- x264: `0.164.3075 --> 0.164.3081`
- xf86-input-libinput: `1.2.0 --> 1.2.1`
- ZSTD: `1.5.1 --> 1.5.2`

# MassOS 2022.01.2
Changes:

- Improved Vulkan graphics support by including Vulkan-Headers and Vulkan-Loader.
- Added screensaver capability (xfce4-screensaver).
- Replaced cdrtools with cdrkit due to license incompatibility with the GPL.
- Made the licenses for included software easier to find (in `/usr/share/licenses`).
- Prepended a notice about software licensing to the [LICENSE](LICENSE) file.

Upgraded software:

- Arc Theme: `20211018 --> 20220102`
- Bash: `5.1.12 --> 5.1.16`
- BlueZ: `5.62 --> 5.63`
- btrfs-progs: `5.15.1 --> 5.16`
- Busybox: `1.34.1 --> 1.35.0`
- cryptsetup: `2.4.2 --> 2.4.3`
- cups-filters: `1.28.10 --> 1.28.11`
- curl: `7.80.0 --> 7.81.0`
- Expat: `2.4.2 --> 2.4.3`
- Firefox: `95.0.2 --> 96.0.1`
- Flatpak: `1.12.2 --> 1.12.3`
- GNOME Software: `41.2 --> 41.3`
- iana-etc: `20211112 --> 20211229`
- IPRoute2: `5.15.0 --> 5.16.0`
- ISO-Codes: `4.8.0 --> 4.9.0`
- JACK2: `1.9.19 --> 1.9.20`
- libgusb: `0.3.8 --> 0.3.10`
- libhandy: `1.4.0 --> 1.5.0`
- libostree: `2021.6 --> 2022.1`
- libpipeline: `1.5.4 --> 1.5.5`
- libsigsegv: `2.13 --> 2.14`
- libunistring: `0.9.10 --> 1.0`
- Linux Kernel: `5.15.12 --> 5.16.1`
- mdadm: `4.1 --> 4.2`
- Mesa: `21.3.3 --> 21.3.4`
- Meson: `0.60.3 --> 0.61.1`
- mtools: `4.0.36 --> 4.0.37`
- NetworkManager: `1.32.12 --> 1.34.0`
- NSS: `3.73.1 --> 3.74`
- Poppler: `21.12.0 --> 22.01.0`
- Pygments: `2.10.0 --> 2.11.2`
- Python: `3.10.1 --> 3.10.2`
- Readline: `8.1 --> 8.1.2`
- rpcsvc-proto: `1.4.2 --> 1.4.3`
- SDL2: `2.0.18 --> 2.0.20`
- Shadow: `4.9 --> 4.11.1`
- SQLite: `3.37.0 --> 3.37.2`
- Sysprof: `3.40.1 --> 3.42.1`
- systemd: `250 --> 250.2`
- Thunderbird: `91.4.0 --> 91.5.0`
- tree: `2.0.0 --> 2.0.1`
- Vala: `0.54.5 --> 0.54.6`
- Vim: `8.2.3950 --> 8.2.4100`
- whois: `5.4.3 --> 5.5.11`
- Xorg-Server: `21.1.2 --> 21.1.3`

# MassOS 2022.01
Changes:

- Parole now supports MP4 playback via OpenH264 and FAAD2 in GStreamer.
- Added OpenAL, JACK2 and gst-libav.
- Optimised the initramfs better by excluding some unnecessary modules.
- Added FUSE support for ext2/ext3/ext4 filesystems.
- Firmware for some Intel sound cards (sof-bin) is now installed alongside other firmware if the user answers 'y' in the MassOS installer.
- (Re-)added rtmpdump (patched to work with OpenSSL), for RTMP protocol support in curl and FFmpeg.
- The `adduser` utility can now (optionally) have the username of the new user passed an argument.
- Added the `pv` utility.
- Fixed minor bugs in some packages with OpenSSL 3.

Upgraded software:

- AppStream: `0.15.0 --> 0.15.1`
- Asciidoc: `9.1.1 --> 10.1.1`
- BIND Utilities: `9.16.23 --> 9.16.24`
- DKMS: `3.0.2 --> 3.0.3`
- e2fsprogs: `1.46.4 --> 1.46.5`
- Expat: `2.4.1 --> 2.4.2`
- Firefox: `95.0 --> 95.0.2`
- GTK3: `3.24.30 --> 3.24.31`
- HPLIP: `3.21.10 --> 3.21.12`
- librsvg: `2.52.4 --> 2.52.5`
- Linux Kernel: `5.15.8 --> 5.15.12`
- Mesa: `21.3.1 --> 21.3.3`
- Meson: `0.60.2 --> 0.60.3`
- NSPR: `4.32 --> 4.33`
- NSS: `3.73 --> 3.73.1`
- OpenSSL: `3.0.0 --> 3.0.1`
- OpenSSL Legacy: `1.1.1l --> 1.1.1m`
- Pango: `1.50.1 --> 1.50.3`
- Qpdf: `10.4.0 --> 10.5.0`
- Ruby: `3.0.3 --> 3.1.0`
- Shadow: `4.8.1 --> 4.9`
- slang: `pre2.3.3-59 --> pre2.3.3-64`
- systemd: `250-rc2 --> 250`
- tree: `1.8.0 --> 2.0.0`
- Vala: `0.54.4 --> 0.54.5`
- Vim: `8.2.3808 --> 8.2.3950`
- WebKitGTK: `2.34.2 --> 2.34.3`
- ZSTD: `1.5.0 --> 1.5.1`

# MassOS 2021.12.2
Changes:

- Migrated MassOS programs to OpenSSL 3. Retained OpenSSL 1.1 libraries for compatibility with binary-only programs which depend on the OpenSSL 1.1 libraries.
- Added OpenH264 for better H264 support in GStreamer/FFmpeg.

Upgraded software:

- alsa-lib: `1.2.5.1 --> 1.2.6.1`
- AppStream: `0.14.6 --> 0.15.0`
- Boost: `1.77.0 --> 1.78.0`
- CMake: `3.22.0 --> 3.22.1`
- dialog: `1.3-20210621 --> 1.3-20211214`
- Enchant: `2.3.0 --> 2.3.2`
- Exo: `4.16.2 --> 4.16.3`
- Firefox: `94.0.2 --> 95.0`
- FreeType: `2.11.0 --> 2.11.1`
- HarfBuzz: `3.1.2 --> 3.2.0`
- GLib: `2.70.1 --> 2.70.2`
- glib-networking: `2.70.0 --> 2.70.1`
- GNOME Software: `41.0 --> 41.2`
- Graphviz: `2.49.3 --> 2.50.0`
- libcap: `2.61 --> 2.62`
- libical: `3.0.11 --> 3.0.12`
- libinput: `1.19.2 --> 1.19.3`
- libX11: `1.7.2 --> 1.7.3`
- libxmlb: `0.3.3 --> 0.3.6`
- Linux: `5.15.6 --> 5.15.8`
- Mesa: `21.3.0 --> 21.3.1`
- mpg123: `1.29.2 --> 1.29.3`
- Nano: `5.9 --> 6.0`
- NSS: `3.72 --> 3.73`
- OpenSSL: `1.1.1l --> 3.0.0`
- Pahole: `1.22-5-ge38e89e --> 1.23`
- Pango: `1.48.10 --> 1.50.1`
- Pangomm: `2.46.1 --> 2.46.2`
- Poppler: `21.11.0 --> 21.12.0`
- PyParsing: `2.4.7 --> 3.0.6`
- systemd: `249 --> 250-rc2`
- Thunderbird: `91.3.2 --> 91.4.0`
- Vim: `8.2.3715 --> 8.2.3808`
- VTE: `0.66.1 --> 0.66.2`
- Wayland: `1.19.0 --> 1.20.0`
- xfsprogs: `5.14.0 --> 5.14.2`
- Xorg-Server: `21.1.1 --> 21.1.2`
- Xwayland: `21.1.3 --> 21.1.4`

# MassOS 2021.12
Changes:

- The MassOS installer now supports setting up Swap space.
- Switched the default application menu to Whisker Menu.
- Set the default fonts to Noto and removed the trivial Xorg fallback fonts.
- Updated the first login welcome program.
- Added xfsprogs (for XFS filesystem support).
- Fixed AppArmor Python bindings with Python 3.10+.
- Added MassOS ASCII art for Neofetch.
- Added MassOS container tool, which is a utility for creating/managing containers for several GNU/Linux distributions.
- Updated some of the included landscape wallpapers.
- Added cdrtools, dmg2img, tree.
- Added a clipboard manager and plugin for the Xfce panel (xfce4-clipman-plugin).
- Replaced Ristretto with Shotwell as default image viewer.

Upgraded software:

- Arc (GTK Theme): `20210412 --> 20211018`
- Bash: `5.1.8 --> 5.1.12`
- bc: `5.1.1 --> 5.2.1`
- BIND Utilities: `9.16.22 --> 9.16.23`
- btrfs-progs: `5.14.2 --> 5.15.1`
- CMake: `3.22.0-rc2 --> 3.22.0`
- cryptsetup: `2.4.1 --> 2.4.2`
- CUPS: `2.3.3op2 --> 2.4.0`
- curl: `7.79.1 --> 7.80.0`
- DKMS: `3.0.1 --> 3.0.2`
- elfutils: `0.185 --> 0.186`
- exfatprogs: `1.1.2 --> 1.1.3`
- Firefox: `93.0 --> 94.0.2`
- Git: `2.33.1 --> 2.34.1`
- GLib: `2.70.0 --> 2.70.1`
- glslang: `11.6.0 --> 11.7.1`
- gnome-online-accounts: `3.40.0 --> 3.40.1`
- Harfbuzz: `3.0.0 --> 3.1.2`
- HPLIP: `3.21.8 --> 3.21.10`
- htop: `3.1.1 --> 3.1.2`
- iana-etc: `20211004 --> 20211112`
- ICU: `69.1 --> 70.1`
- IPRoute2: `5.14.0 --> 5.15.0`
- ISO-Codes: `4.7.0 --> 4.8.0`
- Jinja2: `3.0.1 --> 3.0.3`
- libcap: `2.60 --> 2.61`
- libdrm: `2.4.107 --> 2.4.109`
- libevdev: `1.11.0 --> 1.12.0`
- libgpg-error: `1.42 --> 1.43`
- libjpeg-turbo: `2.1.1 --> 2.1.2`
- libmbim: `1.26.0 --> 1.26.2`
- libostree: `2021.4 --> 2021.6`
- libpipeline: `1.5.3 --> 1.5.4`
- librsvg: `2.52.3 --> 2.52.4`
- libseccomp: `2.5.2 --> 2.5.3`
- libsoup: `2.74.1 --> 2.74.2`
- libtasn1: `4.17.0 --> 4.18.0`
- Linux Kernel: `5.15.0 --> 5.15.6`
- lxml: `4.6.3 --> 4.6.4`
- Mako: `1.1.5 --> 1.1.6`
- Mesa: `21.2.5 --> 21.3.0`
- Meson: `0.59.2 --> 0.60.2`
- ModemManager: `1.18.2 --> 1.18.4`
- Mousepad: `0.5.7 --> 0.5.8`
- mtools: `4.0.35 --> 4.0.36`
- Ncurses: `6.2 --> 6.3`
- OpenLDAP: `2.5.8 --> 2.6.0`
- PCRE2: `10.37 --> 10.39`
- Poppler: `21.10.0 --> 21.11.0`
- Qpdf: `10.3.2 --> 10.4.0`
- Ruby: `3.0.2 --> 3.0.3`
- SDL2: `2.0.16 --> 2.0.18`
- SQLite: `3.36.0 --> 3.37.0`
- Thunderbird: `91.2.1 --> 91.3.2`
- Tcl: `8.6.11 --> 8.6.12`
- Tk: `8.6.11 --> 8.6.12`
- Vala: `0.54.3 --> 0.54.4`
- Vim: `8.2.3565 --> 8.2.3715`
- VTE: `0.66.0 --> 0.66.1`
- wayland-protocols: `1.23 --> 1.24`
- WebKitGTK: `2.34.1 --> 2.34.2`
- xauth: `1.1 --> 1.1.1`
- Xorg-Server: `1.20.13 --> 21.1.1`

# MassOS 2021.11
Changes:

- MassOS now has a guided installer! You can use this to install MassOS.
- Added a welcome/introduction program which is run on the user's first login.
- Added a graphical boot splash screen (Plymouth).
- Updated the default MassOS wallpaper.
- Added Vulkan support to Mesa.
- Added FFmpeg, for MP4/H264/H265 support/playback in Firefox.
- Added some very small command-line games (bsd-games and vitetris).
- Added the 'dig', 'host' and 'nslookup' utilities from ISC BIND.
- Patched krb5 against security vulnerability CVE-2021-37750.
- Switched to using a precompiled for LVM2 (for now), to avoid a segfault which occurred at runtime if the package was built in chroot.

Upgraded software:

- Audit: `3.0.5 --> 3.0.6`
- c-ares: `1.17.2 --> 1.18.1`
- CMake: `3.22.0-rc1 --> 3.22.0-rc2`
- File: `5.40 --> 5.41`
- GDBM: `1.21 --> 1.22`
- GNUPG: `2.2.29 --> 2.2.32`
- Graphviz: `2.49.1 --> 2.49.3`
- htop: `3.1.0 --> 3.1.1`
- iana-etc: `20210924 --> 20211004`
- libcap: `2.59 --> 2.60`
- libdrm: `2.4.107 --> 2.4.107-32-gd77ccdf3`
- libinput: `1.19.1 --> 1.19.2`
- librsvg: `2.52.0 --> 2.52.3`
- libsoup: `2.74.0 --> 2.74.1`
- libwpe: `1.10.1 --> 1.12.0`
- Linux Kernel: `5.14.12 --> 5.15.0`
- LVM2: `2.03.13 --> 2.03.14`
- Mesa: `21.2.3 --> 21.2.5`
- mpg123: `1.29.0 --> 1.29.2`
- nghttp2: `1.45.1 --> 1.46.0`
- NSS: `3.71 --> 3.72`
- Python: `3.9.7 --> 3.10.0`
- slang: `2.3.2 --> 2.3.2-60-g3d8eb6c`
- Thunderbird: `91.2.0 --> 91.2.1`
- tzdata: `2021c --> 2021e`
- Vala: `0.54.2 --> 0.54.3`
- Vim: `8.2.3496 --> 8.2.3565`
- WebKitGTK: `2.34.0 --> 2.34.1`
- wpebackend-fdo: `1.10.0 --> 1.12.0`

# MassOS 2021.10.2
Changes:

- Added acpi, AppStream, Baobab, dmidecode, fcron, laptop-detect, libimobiledevice, lm-sensors, thunar-archive-plugin.
- Added HP printer support in CUPS (HPLIP).
- Added scanning capability (SANE).
- Added a wrapper tool to generate an initramfs: `mkinitramfs`.
- Fixed a possible DNS-resolve bug with NetworkManager.
- Added Microcode information/installation instructions.
- Tried to center windows by default.
- Use `bsdtar` (from `libarchive`) as the default `tar` implementation. It supports far more compression formats (even non-tar ones) than GNU tar. GNU tar will still be installed (as `gtar`) however, in case it is needed.
- Added Linux-Headers and DKMS (custom kernel modules) support.
- Added support for additional media codecs.

Upgraded software:

- adwaita-icon-theme: `40.1.1 --> 41.0`
- at-spi2-core: `2.40.3 --> 2.42.0`
- Automake: `1.16.4 --> 1.16.5`
- bc: `5.0.2 --> 5.1.1`
- Bluez: `5.61 --> 5.62`
- btrfs-progs: `5.14.1 --> 5.14.2`
- Busybox: `1.34.0 --> 1.34.1`
- CMake: `3.21.3 --> 3.22.0-rc1`
- Firefox: `92.0.1 --> 93.0`
- Flatpak: `1.11.3 --> 1.12.2`
- Fribidi: `1.0.9 --> 1.0.11`
- Gcr: `3.40.0 --> 3.41.0`
- Git: `2.33.0 --> 2.33.1`
- GLibmm: `2.66.1 --> 2.66.2`
- JS78: `78.14.0 --> 78.15.0`
- libgusb: `0.3.7 --> 0.3.8`
- libical: `3.0.10 --> 3.0.11`
- libvpx: `1.10.0 --> 1.11.0`
- Linux Kernel: `5.14.9 --> 5.14.12`
- LLVM/Clang: `12.0.1 --> 13.0.0`
- Nano: `5.8 --> 5.9`
- OpenLDAP: `2.5.7 --> 2.5.8`
- OpenSSH: `8.7p1 --> 8.8p1`
- Polkit: `0.119 --> 0.120`
- PyGObject: `3.40.1 --> 3.42.0`
- Ristretto: `0.11.0 --> 0.12.0`
- SoundTouch: `2.3.0 --> 2.3.1`
- Thunar: `4.16.9 --> 4.16.10`
- Thunderbird: `91.1.2 --> 91.2.0`
- tzdata: `2021b --> 2021c`
- Vala: `0.54.1 --> 0.54.2`
- Vim: `8.2.3458 --> 8.2.3496`
- xf86-video-intel: `20210222 --> 20211007`
- XKeyboard-Config: `2.33 --> 2.34`

# MassOS 2021.10
Changes:

- Prefer the libinput driver over the evdev and synaptics drivers. Fixes buggy Elan touchpads.
- Fixed the defult cursor theme.
- Added Bubblewrap, Ed, libgphoto2, libmtp, libnfs, libsigsegv, LZ4, Netcat, ppp, squashfs-tools, squashfuse, xdg-dbus-proxy.
- Build kmod after OpenSSL, so kmod can be built with OpenSSL support.
- Added Audit and AppArmor support.
- Build CMake packages with `-DCMAKE_BUILD_TYPE=MinSizeRel`

Upgraded software:

- Asciidoc: `9.1.0 --> 9.1.1`
- bc: `5.0.0 --> 5.0.2`
- Bison: `3.8.1 --> 3.8.2`
- btrfs-progs: `5.14 --> 5.14.1`
- cryptsetup: `2.3.6 --> 2.4.1`
- CMake: `3.21.2 --> 3.21.3`
- Coreutils: `8.32 --> 9.0`
- curl: `7.78.0 --> 7.79.1`
- Firefox: `92.0 --> 92.0.1`
- Ghostscript: `9.54.0 --> 9.55.0`
- GLib: `2.68.4 --> 2.70.0`
- glib-networking: `2.68.2 --> 2.70.0`
- gnome-software: `40.4 --> 41.0`
- gobject-introspection: `1.68.0 --> 1.70.0`
- Graphviz: `2.49.0 --> 2.49.1`
- gsettings-desktop-schemas: `40.0 --> 41.0`
- gst-plugins-bad: `1.18.4 --> 1.18.5`
- gst-plugins-base: `1.18.4 --> 1.18.5`
- gst-plugins-good: `1.18.4 --> 1.18.5`
- gstreamer: `1.18.4 --> 1.18.5`
- HarfBuzz: `2.9.1 --> 3.0.0`
- htop: `3.0.5 --> 3.1.0`
- iana-etc: `20210611 --> 20210924`
- IPRoute2: `5.13.0 --> 5.14.0`
- itstool: `2.0.6 --> 2.0.7`
- libcap: `2.57 --> 2.59`
- libinput: `1.18.1 --> 1.19.1`
- librsvg: `2.50.7 --> 2.52.0`
- libva: `2.12.0 --> 2.13.0`
- libXi: `1.7.10 --> 1.8`
- Linux Kernel: `5.14.4 --> 5.14.9`
- make-ca: `1.8.1 --> 1.9`
- Mesa: `21.2.1 --> 21.2.3`
- Meson: `0.59.1 --> 0.59.2`
- ModemManager: `1.18.0 --> 1.18.2`
- Mousepad: `0.5.6 --> 0.5.7`
- NetworkManager: `1.32.10 --> 1.32.12`
- nghttp2: `1.44.0 --> 1.45.1`
- NSS: `3.70 --> 3.71`
- Poppler: `21.08.0 --> 21.09.0`
- Sudo: `1.9.8 --> 1.9.8p2`
- Thunderbird: `91.1.0 --> 91.1.2`
- tzdata: `2021a --> 2021b`
- UDisks: `2.9.3 --> 2.9.4`
- UPower: `0.99.12 --> 0.99.13`
- Vala: `0.52.5 --> 0.54.1`
- Vim: `8.2.3424 --> 8.2.3458`
- VTE: `0.64.2 --> 0.66.0`
- wayland-protocols: `1.22 --> 1.23`
- WebKitGTK: `2.32.3 --> 2.34.0`
- xf86-input-libinput: `1.1.0 --> 1.2.0`
- xorgproto: `2021.4 --> 2021.5`

# MassOS 2021.09.2
Changes:

- Added Flatpak package manager and GUI Gnome Software program.
- Complete theme overhaul, to make MassOS look cleaner and more modern.
- Removed Qt-based CMake GUI.
- The `adduser` utility now copies all files present in `/etc/skel` to the new user's home directory.
- exfatprogs is now used instead of exfat-utils (allows exFAT support in Gparted).
- Patched Ghostscript to fix security vulnerability CVE-2021-3781.
- Added Busybox (will ***NOT*** replace any of the better GNU alternatives, however the standalone binary will be installed).

Upgraded software:

- btrfs-progs: `5.13.1 --> 5.14`
- Firefox: `91.0.2 --> 92.0`
- FUSE3: `3.10.4 --> 3.10.5`
- GDBM: `1.20 --> 1.21`
- Graphviz: `2.48.0 --> 2.49.0`
- gtksourceview: `4.8.1 --> 4.8.2`
- Gzip: `1.10 --> 1.11`
- HarfBuzz: `2.9.0 --> 2.9.1`
- Inetutils: `2.1 --> 2.2`
- JS78: `78.13.0 --> 78.14.0`
- libcap: `2.53 --> 2.57`
- libexif: `0.6.22 --> 0.6.23`
- libhandy: `1.2.3 --> 1.4.0`
- libqmi: `1.30.0 --> 1.30.2`
- libseccomp: `2.5.1 --> 2.5.2`
- libssh2: `1.9.0 --> 1.10.0`
- libwacom: `1.11 --> 1.12`
- libxfce4ui: `4.16.0 --> 4.16.1`
- libxkbcommon: `1.3.0 --> 1.3.1`
- Linux Kernel: `5.14.0 --> 5.14.4`
- Linux-PAM: `1.5.1 --> 1.5.2`
- make-ca: `1.7 --> 1.8.1`
- mobile-broadband-provider-info: `20201225 --> 20210805`
- ModemManager: `1.16.10 --> 1.18.0`
- mpg123: `1.28.2 --> 1.29.0`
- NSS: `3.69 --> 3.70`
- Pango: `1.48.9 --> 1.48.10`
- Sudo: `1.9.7p2 --> 1.9.8`
- Thunar: `4.16.8 --> 4.16.9`
- Thunderbird: `91.0.3 --> 91.1.0`
- Vim: `8.2.3377 --> 8.2.3424`
- wayland-protocols: `1.21 --> 1.22`
- Wget: `1.21.1 --> 1.21.2`

# MassOS 2021.09
Changes:

- Fixed bug in `/etc/vimrc` causing an annoying warning.
- Added the following software: CMatrix, cowsay, figlet, Galculator, Gparted, Gutenprint, htop, pavucontrol, Thunderbird, xfce4-taskmanager, sl.
- Libtool archives (*.la) are now removed after the MassOS system is built.
- The bootstrap compiler built in stage1 is now removed after the full compiler is built.
- Switch sourceforge sources to cdn.thesonicmaster.net to avoid connection timeouts and other download problems.
- Fixed incorrect permissions which prevented `fusermount` from working.
- Syntax highlighting is now enabled in Nano by default.

Upgraded software:

- BlueZ: `5.6.0 --> 5.6.1`
- CMake: `3.21.1 --> 3.21.2`
- Cups Filters: `1.28.9 --> 1.28.10`
- e2fsprogs: `1.46.3 --> 1.46.4`
- Firefox: `91.0.1 --> 91.0.2`
- GLib: `2.68.3 --> 2.68.4`
- HarfBuzz: `2.8.2 --> 2.9.0`
- ISO-Codes: `4.6.0 --> 4.7.0`
- json-glib: `1.6.2 --> 1.6.6`
- libarchive: `3.5.1 --> 3.5.2`
- libcap: `2.52 --> 2.53`
- libgcrypt: `1.9.3 --> 1.9.4`
- libnma: `1.8.30 --> 1.8.32`
- libsoup: `2.72.0 --> 2.74.0`
- Linux Kernel: `5.13.12 --> 5.14.0`
- Mako: `1.1.4 --> 1.1.5`
- man-pages: `5.12 --> 5.13`
- Mesa: `21.1.6 --> 21.2.1`
- Meson: `0.59.0 --> 0.59.1`
- network-manager-applet: `1.22.0 --> 1.24.0`
- NetworkManager: `1.32.8 --> 1.32.10`
- ntfs-3g: `2017.3.23 --> 2021.8.22`
- OpenSSH: `8.6p1 --> 8.7p1`
- OpenSSL: `1.1.1k --> 1.1.1l`
- pinentry: `1.1.1 --> 1.2.0`
- Python: `3.9.6 --> 3.9.7`
- SoundTouch: `2.2 --> 2.3.0`
- Util-Linux: `2.37.1 --> 2.37.2`
- Vim: `8.2.3338 --> 8.2.3377`

# MassOS 2021.08.2
Changes:

- Fixed authentication errors with `sudo` and `polkit`.
- Added CUPS support.
- Binaries are now correctly stripped.

Upgraded software:

- Firefox: `91.0 --> 91.0.1`
- Git: `2.32.0 --> 2.33.0`
- Grep: `3.6 --> 3.7`
- libepoxy: `1.5.8 --> 1.5.9`
- libgudev: `236 --> 237`
- libwebp: `1.2.0 --> 1.2.1`
- Linux Kernel: `5.13.11 --> 5.13.12`
- Pango: `1.48.8 --> 1.48.9`
- Vala: `0.52.4 --> 0.52.5`

# MassOS 2021.08
First official release of MassOS.
