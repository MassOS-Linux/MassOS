#!/bin/bash
#
# Builds the core MassOS system (Stage 2) in a chroot environment.
# Copyright (C) 2021-2025 Daniel Massey / MassOS Developers.
#
# This script is part of the MassOS build system. It is licensed under GPLv3+.
# See the 'LICENSE' file for the full license text. On a MassOS system, this
# document can also be found at '/usr/share/massos/LICENSE'.
#
# shellcheck disable=SC1091,SC2016,SC2046,SC2086,SC2154
#
# Exit if something goes wrong.
set -e
# Disabling hashing is useful so the newly built tools are detected.
set +h
# Ensure we're running in the MassOS chroot.
if [ $EUID -ne 0 ] || [ ! -d /root/mbs/sources ]; then
  echo "This script should not be run manually." >&2
  echo "stage2.sh will automatically run it in a chroot environment." >&2
  exit 1
fi
# Change to the source tarballs directory and set up the environment.
pushd /root/mbs/work
. ../build.env
# === REMOVE LINES BELOW THIS FOR RESUMING A FAILED BUILD ===
# Mark the build as started, for Stage 2 resume.
touch ../.BUILD_HAS_STARTED
# Setup the full filesystem structure.
mkdir -p /{boot{,/efi},etc/{opt,sysconfig},home,mnt,opt,srv}
mkdir -p /usr/{,local/}{bin,include,lib,libexec,share/{color,dict,doc,info,locale,man,misc,terminfo,zoneinfo},src}
mkdir -p /var/{cache,lib/{color,hwclock,misc,locate},local,log,mail,opt,spool}
mkdir -p /usr/lib/firmware
ln -sf bin /usr/local/sbin
ln -sf lib /usr/local/lib64
ln -sfr /run /var/run
ln -sfr /run/lock /var/lock
ln -sfr /run/media /media
install -dm1777 /tmp /var/tmp
touch /var/log/{btmp,lastlog,faillog,wtmp}
chmod 664 /var/log/lastlog
chmod 600 /var/log/btmp
# Correctly set the permissions of the root user's home directory.
chmod 0750 /root
# Set the locale correctly (note that it is normal for a warning to be given).
mkdir -p /usr/lib/locale
mklocales
# Install Rust, Go and GYP to temporary directories for building some packages.
tar -xf ../sources/rust-1.96.0-"$MBS_ARCH"-unknown-linux-gnu.tar.gz
pushd rust-1.96.0-"$MBS_ARCH"-unknown-linux-gnu
./install.sh --prefix=/root/mbs/extras/rust --without=rust-docs
tar -xf ../../sources/rust-src-1.96.0.tar.gz -C /root/mbs/extras/rust/lib --strip-components=3
tar -xf ../../sources/cargo-c-"$MBS_ARCH"-unknown-linux-musl.tar.gz -C /root/mbs/extras/rust/bin
tar -xf ../../sources/bindgen-0.72.1-cbindgen-0.29.4-massos-precompiled-multiarch.tar.xz -C /root/mbs/extras/rust/bin --strip-components=2 bindgen-0.72.1-cbindgen-0.29.4-massos-precompiled-multiarch/"$MBS_ARCH"/{,c}bindgen
popd
rm -rf rust-1.96.0-"$MBS_ARCH"-unknown-linux-gnu
[ "$MBS_ARCH" != "x86_64" ] || tar -xf ../sources/go1.26.4.linux-amd64.tar.gz -C /root/mbs/extras
[ "$MBS_ARCH" != "aarch64" ] || tar -xf ../sources/go1.26.4.linux-arm64.tar.gz -C /root/mbs/extras
install -dm755 /root/mbs/extras/gyp
tar -xf ../sources/gyp-1615ec.tar.gz -C /root/mbs/extras/gyp --strip-components=1
# Bison (circular deps; rebuilt later).
tar -xf ../sources/bison-3.8.2.tar.xz
pushd bison-3.8.2
./configure --prefix=/usr
make
make install
popd
rm -rf bison-3.8.2
# Ncurses (circular deps; rebuilt later).
tar -xf ../sources/ncurses-6.6.tar.gz
pushd ncurses-6.6
mkdir -p build; pushd build
../configure
make -C include
make -C progs tic
popd
./configure --prefix=/usr --mandir=/usr/share/man --with-cxx-shared --with-manpage-format=normal --with-shared --without-ada --without-debug --without-normal --enable-widec --disable-stripping
make
make TIC_PATH="$PWD"/build/progs/tic install
ln -sf libncursesw.so /usr/lib/libncurses.so
sed -i 's/^#if.*XOPEN.*$/#if 1/' /usr/include/curses.h
popd
rm -rf ncurses-6.6
# Perl (circular deps; rebuilt later).
tar -xf ../sources/perl-5.42.2.tar.xz
pushd perl-5.42.2
./Configure -des -Doptimize="$CFLAGS" -Dprefix=/usr -Dvendorprefix=/usr -Duseshrplib -Dprivlib=/usr/lib/perl5/5.42/core_perl -Darchlib=/usr/lib/perl5/5.42/core_perl -Dsitelib=/usr/lib/perl5/5.42/site_perl -Dsitearch=/usr/lib/perl5/5.42/site_perl -Dvendorlib=/usr/lib/perl5/5.42/vendor_perl -Dvendorarch=/usr/lib/perl5/5.42/vendor_perl -Dmyuname="linux massos default $(uname -m) gnulinux" -Dosvers=default
make
make install
popd
rm -rf perl-5.42.2
# Python (circular deps; rebuilt later).
tar -xf ../sources/Python-3.14.6.tar.xz
pushd Python-3.14.6
patch -Np1 -i ../../patches/python-3.14.5-openssl4.patch
./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython --disable-test-modules
make
make install
popd
rm -rf Python-3.14.6
# Texinfo (circular deps; rebuilt later).
tar -xf ../sources/texinfo-7.3.tar.xz
pushd texinfo-7.3
./configure --prefix=/usr
make
make install
popd
rm -rf texinfo-7.3
# util-linux (circular deps; rebuilt later).
tar -xf ../sources/util-linux-2.42.2.tar.xz
pushd util-linux-2.42.2
patch -Np1 -i ../../patches/util-linux-2.42.2-hardcode-uid.patch
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run --bindir=/usr/bin --libdir=/usr/lib --sbindir=/usr/bin --disable-static --disable-chfn-chsh --disable-liblastlog2 --disable-login --disable-nologin --disable-pylibmount --disable-runuser --disable-setpriv --disable-su --disable-use-tty-group --without-python
make
make install
popd
rm -rf util-linux-2.42.2
# man-pages.
tar -xf ../sources/man-pages-6.18.tar.xz
pushd man-pages-6.18
rm -rf man3/crypt*
make -R prefix=/usr GIT=false install
install -t /usr/share/licenses/man-pages -Dm644 LICENSES/*
popd
rm -rf man-pages-6.18
# iana-etc.
tar -xf ../sources/iana-etc-20260617.tar.gz
install -t /etc -Dm644 iana-etc-20260617/{protocols,services}
install -dm755 /usr/share/licenses/iana-etc
cat > /usr/share/licenses/iana-etc/LICENSE << "END"
Copyright 2017 Jörg Thalheim

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
END
rm -rf iana-etc-20260617
# Glibc.
tar -xf ../sources/glibc-2.44.tar.xz
pushd glibc-2.44
patch -Np1 -i ../../patches/glibc-2.40-vardirectories.patch
mkdir -p build; pushd build
echo "rootsbindir=/usr/bin" > configparms
CFLAGS="" CPPFLAGS="" CXXFLAGS="" LDFLAGS="" ../configure --prefix=/usr --with-pkgversion="MassOS Glibc 2.44" --with-bugurl="https://github.com/MassOS-Linux/MassOS/issues" --enable-kernel=5.10 --enable-stack-protector=strong --disable-nscd --disable-werror libc_cv_slibdir=/usr/lib
make
sed -i '/test-installation/s@$(PERL)@echo not running@' ../Makefile
make -j1 install
sed -i '/RTLDLIST=/s@/usr@@g' /usr/bin/ldd
sed -e '/#/d' -e '/SUPPORTED-LOCALES/d' -e 's|\\||g' -e 's|/| |g' -e 's|^|#|g' -e 's|#en_US.UTF-8|en_US.UTF-8|' ../localedata/SUPPORTED >> /etc/locales
mklocales
install -t /usr/share/licenses/glibc -Dm644 ../COPYING* ../LICENSES
popd; popd
rm -rf glibc-2.44
# tzdata.
mkdir -p tzdata; pushd tzdata
tar -xf ../../sources/tzdata2026c.tar.gz
mkdir -p /usr/share/zoneinfo/{posix,right}
for r in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do zic -L /dev/null -d /usr/share/zoneinfo $r; zic -L /dev/null -d /usr/share/zoneinfo/posix $r; zic -L leapseconds -d /usr/share/zoneinfo/right $r; done
install -t /usr/share/zoneinfo -Dm644 {iso3166,zone{,1970}}.tab
zic -d /usr/share/zoneinfo -p America/New_York
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
install -t /usr/share/licenses/tzdata -Dm644 LICENSE
popd
rm -rf tzdata
# zlib.
tar -xf ../sources/zlib-1.3.2.tar.xz
pushd zlib-1.3.2
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libz.a
head -n28 zlib.h | tail -n25 | install -Dm644 /dev/stdin /usr/share/licenses/zlib/LICENSE
popd
rm -rf zlib-1.3.2
# bzip2.
tar -xf ../sources/bzip2-1.0.8.tar.gz
pushd bzip2-1.0.8
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so CFLAGS="$CFLAGS -fPIC"
make clean
make CFLAGS="$CFLAGS"
make PREFIX=/usr install
cp -a libbz2.so.* /usr/lib
ln -sf libbz2.so.1.0.8 /usr/lib/libbz2.so
ln -sf libbz2.so.1.0.8 /usr/lib/libbz2.so.1
install -Dm755 bzip2-shared /usr/bin/bzip2
ln -sf bzip2 /usr/bin/bzcat
ln -sf bzip2 /usr/bin/bunzip2
rm -f /usr/lib/libbz2.a
install -t /usr/share/licenses/bzip2 -Dm644 LICENSE
popd
rm -rf bzip2-1.0.8
# xz.
tar -xf ../sources/xz-5.8.2.tar.xz
pushd xz-5.8.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xz -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1
popd
rm -rf xz-5.8.2
# LZ4.
tar -xf ../sources/lz4-1.10.0.tar.gz
pushd lz4-1.10.0
make PREFIX=/usr BUILD_STATIC=no CFLAGS="$CFLAGS"
make PREFIX=/usr BUILD_STATIC=no install
install -t /usr/share/licenses/lz4 -Dm644 LICENSE
popd
rm -rf lz4-1.10.0
# ZSTD.
tar -xf ../sources/zstd-1.5.7.tar.gz
pushd zstd-1.5.7
make prefix=/usr CFLAGS="$CFLAGS -fPIC"
make prefix=/usr install
rm -f /usr/lib/libzstd.a
install -t /usr/share/licenses/zstd -Dm644 COPYING LICENSE
popd
rm -rf zstd-1.5.7
# pigz.
tar -xf ../sources/pigz-2.8.tar.gz
pushd pigz-2.8
make CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
install -t /usr/bin -Dm755 pigz unpigz
install -t /usr/share/man/man1 -Dm644 pigz.1
ln -sf pigz.1 /usr/share/man/man1/unpigz.1
install -dm755 /usr/share/licenses/pigz
tail -n18 README > /usr/share/licenses/pigz/LICENSE
popd
rm -rf pigz-2.8
# lzip.
tar -xf ../sources/lzip-1.25.tar.gz
pushd lzip-1.25
./configure CXXFLAGS="$CXXFLAGS" --prefix=/usr
make
make install
install -t /usr/share/licenses/lzip -Dm644 COPYING
popd
rm -rf lzip-1.25
# Readline.
tar -xf ../sources/readline-8.3.tar.gz
pushd readline-8.3
./configure --prefix=/usr --disable-static --with-curses
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
install -t /usr/share/licenses/readline -Dm644 COPYING
popd
rm -rf readline-8.3
# m4.
tar -xf ../sources/m4-1.4.21.tar.xz
pushd m4-1.4.21
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/m4 -Dm644 COPYING
popd
rm -rf m4-1.4.21
# bc.
tar -xf ../sources/bc-7.0.3.tar.xz
pushd bc-7.0.3
CC="gcc -std=c99" ./configure.sh --prefix=/usr --disable-generated-tests --enable-readline
make
make install
install -t /usr/share/licenses/bc -Dm644 LICENSE.md
popd
rm -rf bc-7.0.3
# Flex.
tar -xf ../sources/flex-2.6.4.tar.gz
pushd flex-2.6.4
./configure --prefix=/usr --disable-static
make
make install
ln -sf flex /usr/bin/lex
ln -sf flex.1 /usr/share/man/man1/lex.1
ln -sf flex.info /usr/share/info/lex.info
install -t /usr/share/licenses/flex -Dm644 COPYING
popd
rm -rf flex-2.6.4
# pkconf (replaces pkg-config).
tar -xf ../sources/pkgconf-3.0.2.tar.xz
pushd pkgconf-3.0.2
./configure --prefix=/usr --disable-static
make
make install
ln -sf pkgconf /usr/bin/pkg-config
ln -sf pkgconf.1 /usr/share/man/man1/pkg-config.1
install -t /usr/share/licenses/pkgconf -Dm644 COPYING
ln -sf pkgconf /usr/share/licenses/pkg-config
popd
rm -rf pkgconf-3.0.2
# Binutils.
tar -xf ../sources/binutils-2.47.tar.xz
pushd binutils-2.47
tar -xf ../../sources/binutils-with-gold-2.46.1.tar.xz binutils-with-gold-2.46.1/{elfcpp,gold} -C . --strip-components=1
patch -Np1 -i ../../patches/binutils-2.47-releaseindicator.patch
mkdir -p build; pushd build
CFLAGS="" CPPFLAGS="" CXXFLAGS="" LDFLAGS="" ../configure --prefix=/usr --sysconfdir=/etc --with-pkgversion="MassOS Binutils 2.47" --with-bugurl="https://github.com/MassOS-Linux/MassOS/issues" --with-system-zlib --enable-default-hash-style=gnu --enable-gold --enable-install-libiberty --enable-ld=default --enable-new-dtags --enable-plugins --enable-relro --enable-shared --disable-werror
make tooldir=/usr
make -j1 tooldir=/usr install
rm -f /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
install -t /usr/share/licenses/binutils -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB
popd; popd
rm -rf binutils-2.47
# GMP.
tar -xf ../sources/gmp-6.3.0.tar.xz
pushd gmp-6.3.0
patch -Np1 -i ../../patches/gmp-6.3.0-gcc15.patch
./configure --prefix=/usr --enable-cxx --disable-static
make
make install
install -t /usr/share/licenses/gmp -Dm644 COPYING COPYINGv2 COPYINGv3 COPYING.LESSERv3
popd
rm -rf gmp-6.3.0
# MPFR.
tar -xf ../sources/mpfr-4.2.2.tar.xz
pushd mpfr-4.2.2
./configure --prefix=/usr --disable-static --enable-thread-safe
make
make install
install -t /usr/share/licenses/mpfr -Dm644 COPYING COPYING.LESSER
popd
rm -rf mpfr-4.2.2
# MPC.
tar -xf ../sources/mpc-1.4.1.tar.xz
pushd mpc-1.4.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/mpc -Dm644 COPYING.LESSER
popd
rm -rf mpc-1.4.1
# ISL.
tar -xf ../sources/isl-0.27.tar.xz
pushd isl-0.27
./configure --prefix=/usr --disable-static
make
make install
install -dm755 /usr/share/gdb/auto-load/usr/lib
mv /usr/lib/libisl.so*-gdb.py /usr/share/gdb/auto-load/usr/lib
install -t /usr/share/licenses/isl -Dm644 LICENSE
popd
rm -rf isl-0.27
# Attr.
tar -xf ../sources/attr-2.6.0.tar.xz
pushd attr-2.6.0
./configure --prefix=/usr --disable-static --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/attr -Dm644 doc/COPYING doc/COPYING.LGPL
popd
rm -rf attr-2.6.0
# Acl.
tar -xf ../sources/acl-2.4.0.tar.xz
pushd acl-2.4.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/acl -Dm644 doc/COPYING doc/COPYING.LGPL
popd
rm -rf acl-2.4.0
# libxcrypt.
tar -xf ../sources/libxcrypt-4.5.2.tar.xz
pushd libxcrypt-4.5.2
patch -Np1 -i ../../patches/libxcrypt-4.5.2-glibc243.patch
mkdir -p build-normal build-compat
pushd build-normal
../configure --prefix=/usr --enable-hashes=glibc,strong --enable-obsolete-api=no --disable-failure-tokens --disable-static
popd
pushd build-compat
../configure --prefix=/usr --enable-hashes=glibc,strong --enable-obsolete-api=glibc --disable-failure-tokens --disable-static
popd
make -C build-normal
make -C build-compat
make -C build-normal install
install -t /usr/lib -Dm755 build-compat/.libs/libcrypt.so.1.1.0
ln -sf libcrypt.so.1.1.0 /usr/lib/libcrypt.so.1
ldconfig
install -t /usr/share/licenses/libxcrypt -Dm644 COPYING.LIB LICENSING
popd
rm -rf libxcrypt-4.5.2
# Libcap.
tar -xf ../sources/libcap-2.78.tar.xz
pushd libcap-2.78
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib sbin=bin GO_BUILD_FLAGS="-buildmode=pie"
make prefix=/usr lib=lib sbin=bin install
install -t /usr/share/licenses/libcap -Dm644 License
popd
rm -rf libcap-2.78
# CrackLib.
tar -xf ../sources/cracklib-2.10.3.tar.bz2
pushd cracklib-2.10.3
CPPFLAGS="$CPPFLAGS -I/usr/include/$(readlink /usr/bin/python3)" ./configure --prefix=/usr --sbindir=/usr/bin --disable-static --with-python --with-default-dict=/usr/lib/cracklib/pw_dict
make
make install
install -dm755 /usr/lib/cracklib
bzip2 -cd ../../sources/cracklib-words-2.10.3.bz2 > /usr/share/dict/cracklib-words
ln -sf cracklib-words /usr/share/dict/words
echo "massos" > /usr/share/dict/cracklib-extra-words
create-cracklib-dict /usr/share/dict/cracklib-words /usr/share/dict/cracklib-extra-words
install -t /usr/share/licenses/cracklib -Dm644 COPYING.LIB
popd
rm -rf cracklib-2.10.3
# Linux-PAM (older autotools version - new Meson version will be built later).
tar -xf ../sources/Linux-PAM-1.6.1.tar.xz
pushd Linux-PAM-1.6.1
patch -Np1 -i ../../patches/Linux-PAM-1.6.1-pamconfig.patch
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --sbindir=/usr/bin --enable-securedir=/usr/lib/security --disable-doc
make
make install
chmod 4755 /usr/bin/unix_chkpwd
install -t /etc/pam.d -Dm644 pam.d/*
popd
rm -rf Linux-PAM-1.6.1
# libpwquality (Python bindings will be built later).
tar -xf ../sources/libpwquality-1.4.5.tar.bz2
pushd libpwquality-1.4.5
./configure --prefix=/usr --disable-static --with-securedir=/usr/lib/security --disable-python-bindings
make
make install
install -t /usr/share/licenses/libpwquality -Dm644 COPYING
popd
rm -rf libpwquality-1.4.5
# Libcap (PAM module only, which could not be built before).
tar -xf ../sources/libcap-2.78.tar.xz
pushd libcap-2.78
make CFLAGS="$CFLAGS -fPIC" -C pam_cap
install -t /usr/lib/security -Dm755 pam_cap/pam_cap.so
install -t /etc/security -Dm644 pam_cap/capability.conf
popd
rm -rf libcap-2.78
# Shadow (initial build; will be rebuilt later to support systemd and AUDIT).
tar -xf ../sources/shadow-4.19.4.tar.xz
pushd shadow-4.19.4
patch -Np1 -i ../../patches/shadow-4.19.4-MassOS.patch
touch /usr/bin/passwd
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-static --with-bcrypt --with-group-name-max-length=32 --with-libcrack --with-yescrypt --without-libbsd --disable-logind
make
make exec_prefix=/usr pamdir= install
make -C man install-man
chmod 0600 /etc/default/useradd
pwconv
grpconv
install -t /etc/pam.d -Dm644 pam.d/*
rm -f /etc/{limits,login.access}
install -t /usr/share/licenses/shadow -Dm644 COPYING
popd
rm -rf shadow-4.19.4
# GCC.
tar -xf ../sources/gcc-16.1.0.tar.xz
pushd gcc-16.1.0
sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64
sed -i '/lp64=/s/lib64/lib/' gcc/config/aarch64/t-aarch64-linux
mkdir -p build; pushd build
CFLAGS="" CPPFLAGS="" CXXFLAGS="" LDFLAGS="" ../configure LD=ld --prefix=/usr --with-pkgversion="MassOS GCC 16.1.0" --with-bugurl="https://github.com/MassOS-Linux/MassOS/issues" --with-system-zlib --enable-languages=c,c++ --enable-default-pie --enable-default-ssp --enable-host-pie --enable-linker-build-id --disable-fixincludes --disable-multilib
make
make -j1 install
ln -sfr /usr/bin/cpp /usr/lib
ln -sf "../../libexec/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion)/liblto_plugin.so" /usr/lib/bfd-plugins/
ln -sf gcc.1 /usr/share/man/man1/cc.1
mkdir -p /usr/share/gdb/auto-load/usr/lib
mv /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
find /usr -depth -name "$MBS_ARCH"-stage1-linux-gnu\* -exec rm -rf {} +
install -t /usr/share/licenses/gcc -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB ../COPYING.RUNTIME
popd; popd
rm -rf gcc-16.1.0
# unifdef.
tar -xf ../sources/unifdef-2.12.tar.gz
pushd unifdef-2.12
patch -Np1 -i ../../patches/unifdef-2.12-gcc15.patch
make
make prefix=/usr install
install -t /usr/share/licenses/unifdef -Dm644 COPYING
popd
rm -rf unifdef-2.12
# Ncurses.
tar -xf ../sources/ncurses-6.6.tar.gz
pushd ncurses-6.6
mkdir -p build; pushd build
../configure --prefix=/usr --mandir=/usr/share/man --enable-pc-files --with-shared --with-cxx-shared --without-debug --without-normal --with-pkg-config-libdir=/usr/lib/pkgconfig
make
make DESTDIR=$PWD/temp install
install -t /usr/lib -Dm755 temp/usr/lib/libncursesw.so.6.6
rm -f temp/usr/lib/libncursesw.so.6.6
sed -i 's/^#if.*XOPEN.*$/#if 1/' temp/usr/include/curses.h
cp -a temp/* /
for lib in ncurses form panel menu; do
  ln -sf lib${lib}w.so /usr/lib/lib${lib}.so
  ln -sf ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
done
ln -sf libncursesw.so /usr/lib/libcurses.so
ln -sf libncursesw.so /usr/lib/libtinfo.so
ldconfig
install -t /usr/share/licenses/ncurses -Dm644 ../COPYING
popd; popd
rm -rf ncurses-6.6
# libedit.
tar -xf ../sources/libedit-20250104-3.1.tar.gz
pushd libedit-20250104-3.1
sed -i 's/history.3//g' doc/Makefile.in
./configure --prefix=/usr --disable-static
make
make install
cp /usr/share/man/man3/e{ditline,l}.3
install -t /usr/share/licenses/libedit -Dm644 COPYING
popd
rm -rf libedit-20250104-3.1
# libsigsegv.
tar -xf ../sources/libsigsegv-2.15.tar.gz
pushd libsigsegv-2.15
./configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/libsigsegv -Dm644 COPYING
popd
rm -rf libsigsegv-2.15
# Sed.
tar -xf ../sources/sed-4.10.tar.xz
pushd sed-4.10
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sed -Dm644 COPYING
popd
rm -rf sed-4.10
# Gettext.
tar -xf ../sources/gettext-0.26.tar.xz
pushd gettext-0.26
patch -Np1 -i ../../patches/gettext-0.26-glibc243.patch
./configure --prefix=/usr --disable-static
make
make install
chmod 0755 /usr/lib/preloadable_libintl.so
install -t /usr/share/licenses/gettext -Dm644 COPYING
popd
rm -rf gettext-0.26
# Bison.
tar -xf ../sources/bison-3.8.2.tar.xz
pushd bison-3.8.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/bison -Dm644 COPYING
popd
rm -rf bison-3.8.2
# PCRE2.
tar -xf ../sources/pcre2-10.47.tar.bz2
pushd pcre2-10.47
./configure --prefix=/usr --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline --disable-static
make
make install
install -t /usr/share/licenses/pcre2 -Dm644 LICENCE.md
popd
rm -rf pcre2-10.47
# Grep.
tar -xf ../sources/grep-3.12.tar.xz
pushd grep-3.12
./configure --prefix=/usr
make
make install
popd
rm -rf grep-3.12
# Bash.
tar -xf ../sources/bash-5.3.tar.gz
pushd bash-5.3
patch -Np1 -i ../../patches/bash-5.3-upstreamlevel9.patch
./configure --prefix=/usr --without-bash-malloc --with-installed-readline
make
make install
ln -sf bash.1 /usr/share/man/man1/sh.1
install -t /usr/share/licenses/bash -Dm644 COPYING
popd
rm -rf bash-5.3
# bash-completion.
tar -xf ../sources/bash-completion-2.16.0.tar.xz
pushd bash-completion-2.16.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/bash-completion -Dm644 COPYING
popd
rm -rf bash-completion-2.16.0
# libtool.
tar -xf ../sources/libtool-2.5.4.tar.xz
pushd libtool-2.5.4
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libltdl.a
install -t /usr/share/licenses/libtool -Dm644 COPYING
popd
rm -rf libtool-2.5.4
# GDBM.
tar -xf ../sources/gdbm-1.25.tar.gz
pushd gdbm-1.25
./configure --prefix=/usr --disable-static --enable-libgdbm-compat
make
make install
install -t /usr/share/licenses/gdbm -Dm644 COPYING
popd
rm -rf gdbm-1.25
# gperf.
tar -xf ../sources/gperf-3.3.tar.gz
pushd gperf-3.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gperf -Dm644 COPYING
popd
rm -rf gperf-3.3
# Expat.
tar -xf ../sources/expat-2.8.2.tar.xz
pushd expat-2.8.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/expat -Dm644 COPYING
popd
rm -rf expat-2.8.2
# confuse.
tar -xf ../sources/confuse-3.3.tar.xz
pushd confuse-3.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/confuse -Dm644 LICENSE
popd
rm -rf confuse-3.3
# libmetalink.
tar -xf ../sources/libmetalink-0.1.3.tar.bz2
pushd libmetalink-0.1.3
./configure --prefix=/usr --enable-static=no
make
make install
install -t /usr/share/licenses/libmetalink -Dm644 COPYING
popd
rm -rf libmetalink-0.1.3
# Inetutils.
tar -xf ../sources/inetutils-2.8.tar.gz
pushd inetutils-2.8
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" ./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var --disable-ifconfig --disable-logger --disable-servers --disable-traceroute --disable-whois
make
make install
install -t /usr/share/licenses/inetutils -Dm644 COPYING
popd
rm -rf inetutils-2.8
# net-tools.
tar -xf ../sources/net-tools-2.10.tar.xz
pushd net-tools-2.10
sed -e 's/I18N n/I18N y/' -e 's/HAVE_HOSTNAME_TOOLS y/HAVE_HOSTNAME_TOOLS n/' -e 's/HAVE_HOSTNAME_SYMLINKS y/HAVE_HOSTNAME_SYMLINKS n/' -e 's/HAVE_AFROSE y/HAVE_AFROSE n/' -e 's/HAVE_HWROSE y/HAVE_HWROSE n/' -i config.in
yes "" | ./configure.sh config.in
make BINDIR=/usr/bin SBINDIR=/usr/bin
make BINDIR=/usr/bin SBINDIR=/usr/bin install
install -t /usr/share/licenses/net-tools -Dm644 COPYING
popd
rm -rf net-tools-2.10
# traceroute.
tar -xf ../sources/traceroute-2.1.6.tar.gz
pushd traceroute-2.1.6
make CFLAGS="$CFLAGS"
make prefix=/usr install
install -t /usr/share/licenses/traceroute -Dm644 COPYING{,.LIB}
popd
rm -rf traceroute-2.1.6
# Less.
tar -xf ../sources/less-704.tar.gz
pushd less-704
./configure --prefix=/usr --sysconfdir=/etc --with-regex=pcre2
make
make install
install -t /usr/share/licenses/less -Dm644 COPYING LICENSE
popd
rm -rf less-704
# Lua.
tar -xf ../sources/lua-5.4.8.tar.gz
pushd lua-5.4.8
patch -Np1 -i ../../patches/lua-5.4.4-sharedlib+pkgconfig.patch
make MYCFLAGS="$CFLAGS -fPIC" linux-readline
make INSTALL_DATA="cp -d" INSTALL_TOP=/usr INSTALL_MAN=/usr/share/man/man1 TO_LIB="liblua.so liblua.so.5.4 liblua.so.5.4.8" install
install -t /usr/lib/pkgconfig -Dm644 lua.pc
tail -n24 src/lua.h | head -n20 | sed -e 's/* //g' -e 's/*//g' > COPYING
install -t /usr/share/licenses/lua -Dm644 COPYING
popd
rm -rf lua-5.4.8
# Perl.
tar -xf ../sources/perl-5.42.2.tar.xz
pushd perl-5.42.2
BUILD_ZLIB=False BUILD_BZIP2=0 ./Configure -des -Doptimize="$CFLAGS" -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.42/core_perl -Darchlib=/usr/lib/perl5/5.42/core_perl -Dsitelib=/usr/lib/perl5/5.42/site_perl -Dsitearch=/usr/lib/perl5/5.42/site_perl -Dvendorlib=/usr/lib/perl5/5.42/vendor_perl -Dvendorarch=/usr/lib/perl5/5.42/vendor_perl -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 -Dpager="/usr/bin/less -isR" -Dmyuname="linux massos default $(uname -m) gnulinux" -Dosvers=default -Duseshrplib -Dusethreads
BUILD_ZLIB=False BUILD_BZIP2=0 make
BUILD_ZLIB=False BUILD_BZIP2=0 make install
install -t /usr/share/licenses/perl -Dm644 Copying
popd
rm -rf perl-5.42.2
# SGMLSpm
tar -xf ../sources/SGMLSpm-1.1.tar.gz
pushd SGMLSpm-1.1
chmod +w MYMETA.yml
perl Makefile.PL INSTALLDIRS=vendor
make
make install
rm -f /usr/lib/perl5/5.42/core_perl/perllocal.pod
ln -sf sgmlspl.pl /usr/bin/sgmlspl
install -t /usr/share/licenses/sgmlspm -Dm644 COPYING
popd
rm -rf SGMLSpm-1.1
# Class-Inspector.
tar -xf ../sources/Class-Inspector-1.36.tar.gz
pushd Class-Inspector-1.36
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -t /usr/share/licenses/class-inspector -Dm644 LICENSE
popd
rm -rf Class-Inspector-1.36
# File-ShareDir.
tar -xf ../sources/File-ShareDir-1.118.tar.gz
pushd File-ShareDir-1.118
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -t /usr/share/licenses/file-sharedir -Dm644 LICENSE
popd
rm -rf File-ShareDir-1.118
# File-ShareDir-Install.
tar -xf ../sources/File-ShareDir-Install-0.14.tar.gz
pushd File-ShareDir-Install-0.14
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -t /usr/share/licenses/file-sharedir-install -Dm644 LICENSE
popd
rm -rf File-ShareDir-Install-0.14
# XML-Parser.
tar -xf ../sources/XML-Parser-2.59.tar.gz
pushd XML-Parser-2.59
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -t /usr/share/licenses/xml-parser -Dm644 LICENSE
popd
rm -rf XML-Parser-2.59
# File-Slurp.
tar -xf ../sources/File-Slurp-9999.32.tar.gz
pushd File-Slurp-9999.32
perl Makefile.PL INSTALLDIRS=vendor
make
make install
tail -n4 README.md | install -Dm644 /dev/stdin /usr/share/licenses/file-slurp/LICENSE
popd
rm -rf File-Slurp-9999.32
# IO-Tty.
tar -xf ../sources/IO-Tty-1.20.tar.gz
pushd IO-Tty-1.20
perl Makefile.PL INSTALLDIRS=vendor
make
make install
tail -n43 README | install -Dm644 /dev/stdin /usr/share/licenses/io-tty/LICENSE
popd
rm -rf IO-Tty-1.20
# IPC-Run.
tar -xf ../sources/IPC-Run-20231003.0.tar.gz
pushd IPC-Run-20231003.0
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -t /usr/share/licenses/ipc-run -Dm644 LICENSE
popd
rm -rf IPC-Run-20231003.0
# Intltool.
tar -xf ../sources/intltool-0.51.0.tar.gz
pushd intltool-0.51.0
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/intltool -Dm644 COPYING
popd
rm -rf intltool-0.51.0
# Autoconf.
tar -xf ../sources/autoconf-2.73.tar.xz
pushd autoconf-2.73
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/autoconf -Dm644 COPYING COPYINGv3 COPYING.EXCEPTION
popd
rm -rf autoconf-2.73
# Autoconf213.
tar -xf ../sources/autoconf-2.13.tar.gz
pushd autoconf-2.13
patch -Np1 -i ../../patches/autoconf-2.13-consolidated_fixes-1.patch
mv autoconf.texi autoconf213.texi
rm -f autoconf.info
./configure --prefix=/usr --infodir=/usr/share/info --program-suffix=2.13
make
make install
install -m644 autoconf213.info /usr/share/info
install-info --info-dir=/usr/share/info autoconf213.info
install -t /usr/share/licenses/autoconf213 -Dm644 COPYING
popd
rm -rf autoconf-2.13
# Automake.
tar -xf ../sources/automake-1.18.1.tar.xz
pushd automake-1.18.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/automake -Dm644 COPYING
popd
rm -rf automake-1.18.1
# autoconf-archive.
tar -xf ../sources/autoconf-archive-2024.10.16.tar.xz
pushd autoconf-archive-2024.10.16
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/autoconf-archive -Dm644 COPYING{,.EXCEPTION}
popd
rm -rf autoconf-archive-2024.10.16
# dotconf.
tar -xf ../sources/dotconf-1.4.1.tar.gz
pushd dotconf-1.4.1
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/dotconf -Dm644 COPYING
popd
rm -rf dotconf-1.4.1
# libmd.
tar -xf ../sources/libmd-1.1.0.tar.bz2
pushd libmd-1.1.0
echo "1.1.0" > .dist-version
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libmd -Dm644 COPYING
popd
rm -rf libmd-1.1.0
# libbsd.
tar -xf ../sources/libbsd-0.12.2.tar.bz2
pushd libbsd-0.12.2
echo "0.12.2" > .dist-version
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libbsd -Dm644 COPYING
popd
rm -rf libbsd-0.12.2
# Netcat.
tar -xf ../sources/netcat-openbsd-upstream-1.229.tar.bz2
pushd netcat-openbsd-upstream-1.229
patch -Np1 -i ../../patches/netcat-1.229-fixes.patch
make CFLAGS="$CFLAGS"
install -t /usr/bin -Dm755 nc
install -t /usr/share/man/man1 -Dm644 nc.1
ln -sf nc /usr/bin/netcat
ln -sf nc.1 /usr/share/man/man1/netcat.1
install -t /usr/share/licenses/netcat -Dm644 copyright
popd
rm -rf netcat-openbsd-upstream-1.229
# PSmisc.
tar -xf ../sources/psmisc-v23.7.tar.bz2
pushd psmisc-v23.7
sed -i 's/UNKNOWN/23.7/g' misc/git-version-gen
./autogen.sh
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/psmisc -Dm644 COPYING
popd
rm -rf psmisc-v23.7
# elfutils.
tar -xf ../sources/elfutils-0.195.tar.bz2
pushd elfutils-0.195
CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" ./configure --prefix=/usr --sysconfdir=/etc --program-prefix="eu-" --disable-debuginfod --enable-libdebuginfod=dummy
make
make install
rm -f /usr/lib/lib{asm,dw,elf}.a
install -t /usr/share/licenses/elfutils -Dm644 COPYING COPYING-GPLV2 COPYING-LGPLV3
popd
rm -rf elfutils-0.195
# libbpf.
tar -xf ../sources/libbpf-1.6.2.tar.gz
pushd libbpf-1.6.2/src
make
make LIBSUBDIR=lib install
rm -f /usr/lib/libbpf.a
install -t /usr/share/licenses/libbpf -Dm644 ../LICENSE{,.BSD-2-Clause,.LGPL-2.1}
popd
rm -rf libbpf-1.6.2
# patchelf.
tar -xf ../sources/patchelf-0.19.1.tar.bz2
pushd patchelf-0.19.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/patchelf -Dm644 COPYING
popd
rm -rf patchelf-0.19.1
# strace.
tar -xf ../sources/strace-7.0.0.84.ce6af.tar.xz
pushd strace-7.0.0.84.ce6af
./configure --prefix=/usr --with-libdw --enable-mpers=check
make
make install
install -t /usr/share/licenses/strace -Dm644 COPYING LGPL-2.1-or-later
popd
rm -rf strace-7.0.0.84.ce6af
# libffi.
tar -xf ../sources/libffi-3.7.1.tar.gz
pushd libffi-3.7.1
./configure --prefix=/usr --disable-static --disable-exec-static-tramp --disable-multi-os-directory --enable-pax_emutramp
make
make install
install -t /usr/share/licenses/libffi -Dm644 LICENSE
popd
rm -rf libffi-3.7.1
# OpenSSL.
tar -xf ../sources/openssl-4.0.1.tar.gz
pushd openssl-4.0.1
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
install -t /usr/share/licenses/openssl -Dm644 LICENSE.txt
popd
rm -rf openssl-4.0.1
# OpenSSL (3.x compat libs - to be removed once VMware is updated to 4.x).
tar -xf ../sources/openssl-3.6.3.tar.gz
pushd openssl-3.6.3
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic no-docs
make
install -t /usr/lib -Dm755 lib{crypto,ssl}.so.3
ldconfig
popd
rm -rf openssl-3.6.3
# easy-rsa.
tar -xf ../sources/EasyRSA-3.2.6.tgz
pushd EasyRSA-3.2.6
install -Dm755 easyrsa /usr/bin/easyrsa
install -Dm644 openssl-easyrsa.cnf /etc/easy-rsa/openssl-easyrsa.cnf
install -Dm644 vars.example /etc/easy-rsa/vars
install -dm755 /etc/easy-rsa/x509-types/
install -m644 x509-types/* /etc/easy-rsa/x509-types/
install -t /usr/share/licenses/easy-rsa -Dm644 COPYING.md gpl-2.0.txt
popd
rm -rf EasyRSA-3.2.6
# mpdecimal.
tar -xf ../sources/mpdecimal-4.0.1.tar.gz
pushd mpdecimal-4.0.1
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libmpdec{,++}.a
install -t /usr/share/licenses/mpdecimal -Dm644 COPYRIGHT.txt
popd
rm -rf mpdecimal-4.0.1
# scdoc.
tar -xf ../sources/scdoc-1.11.0.tar.gz
pushd scdoc-1.11.0
sed -i 's/-Werror //g' Makefile
make PREFIX=/usr LDFLAGS="$LDFLAGS"
make PREFIX=/usr LDFLAGS="$LDFLAGS" install
install -t /usr/share/licenses/scdoc -Dm644 COPYING
popd
rm -rf scdoc-1.11.0
# kmod.
tar -xf ../sources/kmod-34.2.tar.xz
pushd kmod-34.2
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --with-module-directory=/usr/lib/modules --with-openssl --with-xz --with-zlib --with-zstd
make
make install
for t in {dep,ins,ls,rm}mod mod{info,probe}; do ln -sf kmod /usr/bin/$t; done
install -t /usr/share/licenses/kmod -Dm644 COPYING
popd
rm -rf kmod-34.2
# Python (initial build; will be rebuilt later to support SQLite and Tk).
tar -xf ../sources/Python-3.14.6.tar.xz
pushd Python-3.14.6
patch -Np1 -i ../../patches/python-3.14.5-openssl4.patch
./configure --prefix=/usr --enable-shared --enable-optimizations --with-system-expat --with-system-libmpdec --with-ensurepip --without-static-libpython --disable-test-modules
make
make install
ln -sf python3 /usr/bin/python
ln -sf pydoc3 /usr/bin/pydoc
ln -sf idle3 /usr/bin/idle
ln -sf python3-config /usr/bin/python-config
ln -sf pip3 /usr/bin/pip
install -t /usr/share/licenses/python -Dm644 LICENSE
popd
rm -rf Python-3.14.6
# flit-core.
tar -xf ../sources/flit_core-3.12.0.tar.gz
pushd flit_core-3.12.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist flit_core
install -t /usr/share/licenses/flit-core -Dm644 LICENSE
popd
rm -rf flit_core-3.12.0
# packaging.
tar -xf ../sources/packaging-26.2.tar.gz
pushd packaging-26.2
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist packaging
install -t /usr/share/licenses/packaging -Dm644 LICENSE{,.APACHE,.BSD}
popd
rm -rf packaging-26.2
# wheel.
tar -xf ../sources/wheel-0.47.0.tar.gz
pushd wheel-0.47.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist wheel
install -t /usr/share/licenses/wheel -Dm644 LICENSE.txt
popd
rm -rf wheel-0.47.0
# setuptools.
tar -xf ../sources/setuptools-83.0.0.tar.gz
pushd setuptools-83.0.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist setuptools
install -t /usr/share/licenses/setuptools -Dm644 LICENSE
popd
rm -rf setuptools-83.0.0
# pip.
tar -xf ../sources/pip-26.1.2.tar.gz
pushd pip-26.1.2
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist pip --upgrade
install -t /usr/share/licenses/pip -Dm644 LICENSE.txt
popd
rm -rf pip-26.1.2
# pyproject-hooks.
tar -xf ../sources/pyproject_hooks-1.2.0.tar.gz
pushd pyproject_hooks-1.2.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist pyproject-hooks
install -t /usr/share/licenses/pyproject-hooks -Dm644 LICENSE
popd
rm -rf pyproject_hooks-1.2.0
# installer.
tar -xf ../sources/installer-1.0.0.tar.gz
pushd installer-1.0.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist installer
install -t /usr/share/licenses/installer -Dm644 LICENSE
popd
rm -rf installer-1.0.0
# build.
tar -xf ../sources/build-1.5.0.tar.gz
pushd build-1.5.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist build
install -t /usr/share/licenses/build -Dm644 LICENSE
popd
rm -rf build-1.5.0
# Sphinx (required to build man pages of some packages).
mkdir -p /root/mbs/extras/sphinx
tar --no-same-owner --same-permissions -xf ../sources/sphinx-py3.14-20260430-"$MBS_ARCH"-venv-mbs.tar.xz -C /root/mbs/extras/sphinx --strip-components=1
# Ninja.
tar -xf ../sources/ninja-1.13.2.tar.gz
pushd ninja-1.13.2
python configure.py --bootstrap
install -t /usr/bin -Dm755 ninja
install -Dm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -Dm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja
install -t /usr/share/licenses/ninja -Dm644 COPYING
popd
rm -rf ninja-1.13.2
# Meson.
tar -xf ../sources/meson-1.11.2.tar.gz
pushd meson-1.11.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/bash-completion/completions -Dm644 data/shell-completions/bash/meson
install -t /usr/share/zsh/site-functions -Dm644 data/shell-completions/zsh/_meson
install -t /usr/share/licenses/meson -Dm644 COPYING
popd
rm -rf meson-1.11.2
# calver.
tar -xf ../sources/calver-2025.04.02.tar.gz
pushd calver-2025.04.02
echo "Version: 2025.04.02" > PKG-INFO
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/calver -Dm644 LICENSE
popd
rm -rf calver-2025.04.02
# tomli.
tar -xf ../sources/tomli-2.2.1.tar.gz
pushd tomli-2.2.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/tomli -Dm644 LICENSE
popd
rm -rf tomli-2.2.1
# PyParsing.
tar -xf ../sources/pyparsing-3.3.2.tar.gz
pushd pyparsing-3.3.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyparsing -Dm644 LICENSE
popd
rm -rf pyparsing-3.3.2
# pycparser.
tar -xf ../sources/pycparser-release_v2.23.tar.gz
pushd pycparser-release_v2.23
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pycparser -Dm644 LICENSE
popd
rm -rf pycparser-release_v2.23
# editables.
tar -xf ../sources/editables-0.6.tar.gz
pushd editables-0.6
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/editables -Dm644 LICENSE.txt
popd
rm -rf editables-0.6
# pyproject-metadata.
tar -xf ../sources/pyproject_metadata-0.11.0.tar.gz
pushd pyproject_metadata-0.11.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyproject-metadata -Dm644 LICENSE
popd
rm -rf pyproject_metadata-0.11.0
# typing-extensions
tar -xf ../sources/typing_extensions-4.13.1.tar.gz
pushd typing_extensions-4.13.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/typing-extensions -Dm644 LICENSE
popd
rm -rf typing_extensions-4.13.1
# vcs-versioning.
tar -xf ../sources/vcs_versioning-2.2.2.tar.gz
pushd vcs_versioning-2.2.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/vcs-versioning -Dm644 LICENSE.txt
popd
rm -rf vcs_versioning-2.2.2
# setuptools-scm.
tar -xf ../sources/setuptools_scm-10.1.2.tar.gz
pushd setuptools_scm-10.1.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/setuptools-scm -Dm644 LICENSE
popd
rm -rf setuptools_scm-10.1.2
# pytz.
tar -xf ../sources/pytz-2026.2.tar.gz
pushd pytz-2026.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pytz -Dm644 LICENSE.txt
popd
rm -rf pytz-2026.2
# pathspec.
tar -xf ../sources/pathspec-1.1.1.tar.gz
pushd pathspec-1.1.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pathspec -Dm644 LICENSE
popd
rm -rf pathspec-1.1.1
# pluggy.
tar -xf ../sources/pluggy-1.6.0.tar.gz
pushd pluggy-1.6.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pluggy -Dm644 LICENSE
popd
rm -rf pluggy-1.6.0
# trove-classifiers.
tar -xf ../sources/trove-classifiers-2026.1.14.14.tar.gz
pushd trove-classifiers-2026.1.14.14
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
popd
rm -rf trove-classifiers-2026.1.14.14
# hatchling.
tar -xf ../sources/hatchling-1.30.1.tar.gz
pushd hatchling-1.30.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/hatching -Dm644 LICENSE.txt
popd
rm -rf hatchling-1.30.1
# hatch-vcs.
tar -xf ../sources/hatch-vcs-0.5.0.tar.gz
pushd hatch-vcs-0.5.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/hatch-vcs -Dm644 LICENSE.txt
popd
rm -rf hatch-vcs-0.5.0
# legacy-cgi.
tar -xf ../sources/legacy-cgi-2.6.3.tar.gz
pushd legacy-cgi-2.6.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/legacy-cgi -Dm644 LICENSE
popd
rm -rf legacy-cgi-2.6.3
# termcolor.
tar -xf ../sources/termcolor-3.1.0.tar.gz
pushd termcolor-3.1.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/termcolor -Dm644 COPYING.txt
popd
rm -rf termcolor-3.1.0
# psutil.
tar -xf ../sources/psutil-7.2.2.tar.gz
pushd psutil-7.2.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/psutil -Dm644 LICENSE
popd
rm -rf psutil-7.2.2
# six.
tar -xf ../sources/six-1.17.0.tar.gz
pushd six-1.17.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/six -Dm644 LICENSE
popd
rm -rf six-1.17.0
# distro.
tar -xf ../sources/distro-1.9.0.tar.gz
pushd distro-1.9.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/distro -Dm644 LICENSE
popd
rm -rf distro-1.9.0
# libpwquality (Python bindings only, which could not be built before).
tar -xf ../sources/libpwquality-1.4.5.tar.bz2
pushd libpwquality-1.4.5
python -m build -nw -o dist python
python -m installer --compile-bytecode 1 dist/*.whl
popd
rm -rf libpwquality-1.4.5
# libsfdo.
tar -xf ../sources/libsfdo-v0.1.4.tar.bz2
pushd libsfdo-v0.1.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsfdo -Dm644 LICENSE
popd
rm -rf libsfdo-v0.1.4
# libmspack + cabextract.
tar -xf ../sources/libmspack-1.11.tar.gz
pushd libmspack-1.11
pushd libmspack
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libmspack -Dm644 COPYING.LIB
popd
pushd cabextract
sed -i '/^AM_ICONV$/d' configure.ac
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc
sed -i 's/@LIBICONV@//' Makefile
make
make install
install -t /usr/share/licenses/cabextract -Dm644 COPYING
popd; popd
rm -rf libmspack-1.11
# libseccomp.
tar -xf ../sources/libseccomp-2.6.1.tar.gz
pushd libseccomp-2.6.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libseccomp -Dm644 LICENSE
popd
rm -rf libseccomp-2.6.1
# File.
tar -xf ../sources/file-5.48.tar.gz
pushd file-5.48
mkdir -p bootstrap; pushd bootstrap
../configure --prefix=/usr --enable-libseccomp
make
popd
./configure --prefix=/usr --enable-libseccomp
make FILE_COMPILE="$PWD"/bootstrap/src/file
make install
install -t /usr/share/licenses/file -Dm644 COPYING
popd
rm -rf file-5.48
# Coreutils.
tar -xf ../sources/coreutils-9.11.tar.xz
pushd coreutils-9.11
./configure --prefix=/usr --enable-no-install-program=hostname,kill,uptime --with-packager=MassOS
make
make install
mv /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
dircolors -p > /etc/dircolors
install -t /usr/share/licenses/coreutils -Dm644 COPYING
popd
rm -rf coreutils-9.11
# Diffutils.
tar -xf ../sources/diffutils-3.12.tar.xz
pushd diffutils-3.12
./configure --prefix=/usr --with-packager=MassOS
make
make install
install -t /usr/share/licenses/diffutils -Dm644 COPYING
popd
rm -rf diffutils-3.12
# Gawk.
tar -xf ../sources/gawk-5.4.1.tar.xz
pushd gawk-5.4.1
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/gawk -Dm644 COPYING
popd
rm -rf gawk-5.4.1
# Findutils.
tar -xf ../sources/findutils-4.11.0.tar.xz
pushd findutils-4.11.0
./configure --prefix=/usr --localstatedir=/var/lib/locate --with-packager=MassOS
make
make install
install -t /usr/share/licenses/findutils -Dm644 COPYING
popd
rm -rf findutils-4.11.0
# Groff.
tar -xf ../sources/groff-1.24.1.tar.gz
pushd groff-1.24.1
./configure --prefix=/usr
make -j1
make install
install -t /usr/share/licenses/groff -Dm644 COPYING LICENSES
popd
rm -rf groff-1.24.1
# Gzip.
tar -xf ../sources/gzip-1.14.tar.xz
pushd gzip-1.14
grep -rl bug-gzip@gnu.org | xargs sed -i 's|bug-gzip@gnu.org|https://github.com/MassOS-Linux/MassOS/issues|g'
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gzip -Dm644 COPYING
popd
rm -rf gzip-1.14
# Texinfo.
tar -xf ../sources/texinfo-7.3.tar.xz
pushd texinfo-7.3
./configure --prefix=/usr
make
make install
make TEXMF=/usr/share/texmf install-tex
install -t /usr/share/licenses/texinfo -Dm644 COPYING
popd
rm -rf texinfo-7.3
# Sharutils.
tar -xf ../sources/sharutils-4.15.2.tar.xz
pushd sharutils-4.15.2
patch -Np1 -i ../../patches/sharutils-4.15.2-buildfixes.patch
CFLAGS="$CFLAGS -std=gnu17" ./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sharutils -Dm644 COPYING
popd
rm -rf sharutils-4.15.2
# LMDB.
tar -xf ../sources/LMDB_1.0.0.tar.bz2
pushd openldap-LMDB_1.0.0-2562c3297402d82bbc049c7e645515edb4079eba/libraries/liblmdb
make CFLAGS="$CFLAGS"
sed -i 's| liblmdb.a||' Makefile
make prefix=/usr install
install -t /usr/share/licenses/lmdb -Dm644 COPYRIGHT LICENSE
popd
rm -rf openldap-LMDB_1.0.0-2562c3297402d82bbc049c7e645515edb4079eba
# Cyrus-SASL (will be rebuilt later to support krb5 and OpenLDAP).
tar -xf ../sources/cyrus-sasl-2.1.28.tar.gz
pushd cyrus-sasl-2.1.28
patch -Np1 -i ../../patches/cyrus-sasl-2.1.28-gcc15.patch
sed -i '/saslint/a #include <time.h>' lib/saslutil.c
sed -i '/plugin_common/a #include <time.h>' plugins/cram.c
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
install -t /usr/share/licenses/cyrus-sasl -Dm644 COPYING
popd
rm -rf cyrus-sasl-2.1.28
# libmnl.
tar -xf ../sources/libmnl-1.0.5.tar.bz2
pushd libmnl-1.0.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libmnl -Dm644 COPYING
popd
rm -rf libmnl-1.0.5
# libnftnl.
tar -xf ../sources/libnftnl-1.2.8.tar.xz
pushd libnftnl-1.2.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libnftnl -Dm644 COPYING
popd
rm -rf libnftnl-1.2.8
# libnfnetlink.
tar -xf ../sources/libnfnetlink-1.0.2.tar.bz2
pushd libnfnetlink-1.0.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libnfnetlink -Dm644 COPYING
popd
rm -rf libnfnetlink-1.0.2
# nftables (will be rebuilt after Jansson for JSON support).
tar -xf ../sources/nftables-1.1.1.tar.xz
pushd nftables-1.1.1
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-debug --without-json
make
python -m build -nw -o dist py
make install
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/nftables -Dm644 COPYING
popd
rm -rf nftables-1.1.1
# iptables.
tar -xf ../sources/iptables-1.8.13.tar.xz
pushd iptables-1.8.13
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-libipq --enable-nftables
make
make install
install -t /usr/share/licenses/iptables -Dm644 COPYING
popd
rm -rf iptables-1.8.13
# IPRoute2.
tar -xf ../sources/iproute2-7.1.0.tar.xz
pushd iproute2-7.1.0
make
make SBINDIR=/usr/bin install
install -t /usr/share/licenses/iproute2 -Dm644 COPYING
popd
rm -rf iproute2-7.1.0
# ethtool.
tar -xf ../sources/ethtool-6.14.tar.xz
pushd ethtool-6.14
./configure --prefix=/usr --sbindir=/usr/bin
make
make install
install -t /usr/share/licenses/ethtool -Dm644 COPYING LICENSE
popd
rm -rf ethtool-6.14
# Kbd.
tar -xf ../sources/kbd-2.10.0.tar.xz
pushd kbd-2.10.0
patch -Np1 -i ../../patches/kbd-2.4.0-backspace-1.patch
sed -i 's/RESIZECONS_PROGS=yes/RESIZECONS_PROGS=no/g' configure
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-tests
make
make install
rm -f /usr/share/man/man8/resizecons.8
install -t /usr/share/licenses/kbd -Dm644 COPYING
popd
rm -rf kbd-2.10.0
# libpipeline.
tar -xf ../sources/libpipeline-1.5.8.tar.gz
pushd libpipeline-1.5.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libpipeline -Dm644 COPYING
popd
rm -rf libpipeline-1.5.8
# libunwind.
tar -xf ../sources/libunwind-1.8.3.tar.gz
pushd libunwind-1.8.3
./configure --prefix=/usr --disable-static --disable-tests
make
make install
install -t /usr/share/licenses/libunwind -Dm644 COPYING
popd
rm -rf libunwind-1.8.3
# libuv.
tar -xf ../sources/libuv-v1.52.1.tar.gz
pushd libuv-v1.52.1
./autogen.sh
./configure --prefix=/usr --disable-static
make
make -C docs man
make install
install -t /usr/share/man/man1 -Dm644 docs/build/man/libuv.1
install -t /usr/share/licenses/libuv -Dm644 LICENSE
popd
rm -rf libuv-v1.52.1
# libyaml.
tar -xf ../sources/yaml-0.2.5.tar.gz
pushd yaml-0.2.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libyaml -Dm644 License
popd
rm -rf yaml-0.2.5
# Make.
tar -xf ../sources/make-4.4.1.tar.gz
pushd make-4.4.1
./configure --prefix=/usr
make
make install
ln -sf make /usr/bin/gmake
ln -sf make.1 /usr/share/man/gmake.1
install -t /usr/share/licenses/make -Dm644 COPYING
popd
rm -rf make-4.4.1
# Ed.
tar -xf ../sources/ed-1.22.5.tar.lz
pushd ed-1.22.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/ed -Dm644 COPYING
popd
rm -rf ed-1.22.5
# Patch.
tar -xf ../sources/patch-2.8.tar.xz
pushd patch-2.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/patch -Dm644 COPYING
popd
rm -rf patch-2.8
# tar.
tar -xf ../sources/tar-1.35.tar.xz
pushd tar-1.35
patch -Np1 -i ../../patches/tar-1.35-acl240.patch
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/tar -Dm644 COPYING
popd
rm -rf tar-1.35
# Nano.
tar -xf ../sources/nano-9.1.tar.xz
pushd nano-9.1
./configure --prefix=/usr --sysconfdir=/etc --enable-utf8
make
make install
cp doc/sample.nanorc /etc/nanorc
sed -i '0,/# include/{s/# include/include/}' /etc/nanorc
install -t /usr/share/licenses/nano -Dm644 COPYING
popd
rm -rf nano-9.1
# dos2unix.
tar -xf ../sources/dos2unix-7.5.5.tar.gz
pushd dos2unix-7.5.5
make
make install
install -t /usr/share/licenses/dos2unix -Dm644 COPYING.txt
popd
rm -rf dos2unix-7.5.5
# docutils.
tar -xf ../sources/docutils-0.23.tar.gz
pushd docutils-0.23
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/docutils -Dm644 COPYING.rst
popd
rm -rf docutils-0.23
# MarkupSafe.
tar -xf ../sources/markupsafe-3.0.3.tar.gz
pushd markupsafe-3.0.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/markupsafe -Dm644 LICENSE.txt
popd
rm -rf markupsafe-3.0.3
# Jinja2.
tar -xf ../sources/jinja2-3.1.6.tar.gz
pushd jinja2-3.1.6
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/jinja2 -Dm644 LICENSE.txt
popd
rm -rf jinja2-3.1.6
# Mako.
tar -xf ../sources/mako-1.3.12.tar.gz
pushd mako-rel_1_3_12
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/mako -Dm644 LICENSE
popd
rm -rf mako-rel_1_3_12
# pyxdg.
tar -xf ../sources/pyxdg-0.28.tar.gz
pushd pyxdg-0.28
patch -Np1 -i ../../patches/pyxdg-0.28-python314.patch
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyxdg -Dm644 COPYING
popd
rm -rf pyxdg-0.28
# pefile.
tar -xf ../sources/pefile-2024.8.26.tar.gz
pushd pefile-2024.8.26
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pefile -Dm644 LICENSE
popd
rm -rf pefile-2024.8.26
# pyelftools.
tar -xf ../sources/pyelftools-0.32.tar.gz
pushd pyelftools-0.32
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyelftools -Dm644 LICENSE
popd
rm -rf pyelftools-0.32
# Pygments.
tar -xf ../sources/pygments-2.20.0.tar.gz
pushd pygments-2.20.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pygments -Dm644 LICENSE
popd
rm -rf pygments-2.20.0
# toml.
tar -xf ../sources/toml-0.10.2.tar.gz
pushd toml-0.10.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/toml -Dm644 LICENSE
popd
rm -rf toml-0.10.2
# semantic-version.
tar -xf ../sources/semantic_version-2.10.0.tar.gz
pushd semantic_version-2.10.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/semantic-version -Dm644 LICENSE
popd
rm -rf semantic_version-2.10.0
# smartypants.
tar -xf ../sources/smartypants.py-2.0.2.tar.gz
pushd smartypants.py-2.0.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/smartypants -Dm644 COPYING
popd
rm -rf smartypants.py-2.0.2
# typogrify.
tar -xf ../sources/typogrify-2.1.0.tar.gz
pushd typogrify-2.1.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/typogrify -Dm644 LICENSE.txt
popd
rm -rf typogrify-2.1.0
# zipp.
tar -xf ../sources/zipp-3.21.0.tar.gz
pushd zipp-3.21.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/zipp -Dm644 LICENSE
popd
rm -rf zipp-3.21.0
# importlib-metadata
tar -xf ../sources/importlib_metadata-8.6.1.tar.gz
pushd importlib_metadata-8.6.1
rm -f exercises.py
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/importlib-metadata -Dm644 LICENSE
popd
rm -rf importlib_metadata-8.6.1
# lark.
tar -xf ../sources/lark-1.2.2.tar.gz
pushd lark-1.2.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/lark -Dm644 LICENSE
popd
rm -rf lark-1.2.2
# fastjsonschema.
tar -xf ../sources/fastjsonschema-2.21.1.tar.gz
pushd fastjsonschema-2.21.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/fastjsonschema -Dm644 LICENSE
popd
rm -rf fastjsonschema-2.21.1
# poetry-core.
tar -xf ../sources/poetry_core-2.1.2.tar.gz
pushd poetry_core-2.1.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/poetry-core -Dm644 LICENSE
popd
rm -rf poetry_core-2.1.2
# Markdown.
tar -xf ../sources/markdown-3.10.2.tar.gz
pushd markdown-3.10.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/markdown -Dm644 LICENSE.md
popd
rm -rf markdown-3.10.2
# python-distutils-extra.
tar -xf ../sources/python-distutils-extra-2.39.tar.gz
pushd python-distutils-extra-2.39
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/python-distutils-extra -Dm644 LICENSE
popd
rm -rf python-distutils-extra-2.39
# ptyprocess.
tar -xf ../sources/ptyprocess-0.7.0.tar.gz
pushd ptyprocess-0.7.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/ptyprocess -Dm644 LICENSE
popd
rm -rf ptyprocess-0.7.0
# pexpect.
tar -xf ../sources/pexpect-4.9.tar.gz
pushd pexpect-4.9
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pexpect -Dm644 LICENSE
popd
rm -rf pexpect-4.9
# ply.
tar -xf ../sources/ply-3.11.tar.gz
pushd ply-3.11
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
head -n32 README.md | tail -n28 | install -Dm644 /dev/stdin /usr/share/licenses/ply/LICENSE.txt
popd
rm -rf ply-3.11
# Cython.
tar -xf ../sources/cython-3.2.8.tar.gz
pushd cython-3.2.8
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/cython -Dm644 {COPYING,LICENSE}.txt
popd
rm -rf cython-3.2.8
# PyYAML.
tar -xf ../sources/pyyaml-6.0.3.tar.gz
pushd pyyaml-6.0.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyyaml -Dm644 LICENSE
popd
rm -rf pyyaml-6.0.3
# gi-docgen.
tar -xf ../sources/gi-docgen-2026.1.tar.gz
pushd gi-docgen-2026.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddevelopment_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gi-docgen -Dm644 LICENSES/{Apache-2.0.txt,GPL-3.0-or-later.txt}
popd
rm -rf gi-docgen-2026.1
# Locale-gettext.
tar -xf ../sources/Locale-gettext-1.07.tar.gz
pushd Locale-gettext-1.07
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -dm755 /usr/share/licenses/locale-gettext
head -n16 README | tail -n6 > /usr/share/licenses/locale-gettext/COPYING
popd
rm -rf Locale-gettext-1.07
# help2man.
tar -xf ../sources/help2man-1.49.3.tar.xz
pushd help2man-1.49.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/help2man -Dm644 COPYING
popd
rm -rf help2man-1.49.3
# dialog.
tar -xf ../sources/dialog-1.3-20250116.tgz
pushd dialog-1.3-20250116
./configure --prefix=/usr --enable-nls --with-libtool --with-ncursesw
make
make install
rm -f /usr/lib/libdialog.a
chmod 755 /usr/lib/libdialog.so.15.0.0
install -t /usr/share/licenses/dialog -Dm644 COPYING
popd
rm -rf dialog-1.3-20250116
# acpi.
tar -xf ../sources/acpi-1.7.tar.gz
pushd acpi-1.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/acpi -Dm644 COPYING
popd
rm -rf acpi-1.7
# rpcsvc-proto.
tar -xf ../sources/rpcsvc-proto-1.4.4.tar.xz
pushd rpcsvc-proto-1.4.4
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/rpcsvc-proto -Dm644 COPYING
popd
rm -rf rpcsvc-proto-1.4.4
# Which.
tar -xf ../sources/which-2.25.tar.gz
pushd which-2.25
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/which -Dm644 COPYING
popd
rm -rf which-2.25
# tree.
tar -xf ../sources/unix-tree-2.3.2.tar.bz2
pushd unix-tree-2.3.2
make CFLAGS="$CFLAGS"
make PREFIX=/usr MANDIR=/usr/share/man install
chmod 644 /usr/share/man/man1/tree.1
install -t /usr/share/licenses/tree -Dm644 LICENSE
popd
rm -rf unix-tree-2.3.2
# GPM.
tar -xf ../sources/gpm-1.20.7-38-ge82d1a6.tar.gz
pushd gpm-e82d1a653ca94aa4ed12441424da6ce780b1e530
patch -Np1 -i ../../patches/gpm-1.20.7-gcc15.patch
patch -Np1 -i ../../patches/gpm-1.20.7-pregenerated-docs.patch
./autogen.sh
./configure PACKAGE_VERSION="1.20.7-38-ge82d1a6" --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin
make
make install
ln -sf libgpm.so.2.1.0 /usr/lib/libgpm.so
rm -f /usr/lib/libgpm.a
install -t /etc -m644 conf/gpm-root.conf
install -t /usr/share/info -vDm644 doc/gpm.info
install -t /usr/share/man/man1 -vDm644 doc/{gpm-root,mev,mouse-test}.1
install -t /usr/share/man/man7 -vDm644 doc/gpm-types.7
install -t /usr/share/man/man8 -vDm644 doc/gpm.8
install-info --dir-file=/usr/share/info/dir /usr/share/info/gpm.info
install -t /usr/share/licenses/gpm -Dm644 COPYING
popd
rm -rf gpm-e82d1a653ca94aa4ed12441424da6ce780b1e530
# pv.
tar -xf ../sources/pv-1.9.31.tar.gz
pushd pv-1.9.31
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/pv -Dm644 docs/COPYING
popd
rm -rf pv-1.9.31
# liburing.
tar -xf ../sources/liburing-2.9.tar.gz
pushd liburing-liburing-2.9
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
rm -f /usr/lib/liburing{,-ffi}.a
popd
rm -rf liburing-liburing-2.9
# duktape.
tar -xf ../sources/duktape-2.7.0.tar.xz
pushd duktape-2.7.0
CFLAGS="$CFLAGS -DDUK_USE_FASTINT" LDFLAGS="$LDFLAGS -lm" make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr
make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr install
install -t /usr/share/licenses/duktape -Dm644 LICENSE.txt
popd
rm -rf duktape-2.7.0
# oniguruma.
tar -xf ../sources/onig-6.9.10.tar.gz
pushd onig-6.9.10
./configure --prefix=/usr --disable-static --enable-posix-api
make
make install
install -t /usr/share/licenses/oniguruma -Dm644 COPYING
popd
rm -rf onig-6.9.10
# jq.
tar -xf ../sources/jq-1.8.0.tar.gz
pushd jq-1.8.0
./configure --prefix=/usr --disable-docs --disable-static
make
make install
install -t /usr/share/licenses/jq -Dm644 COPYING
popd
rm -rf jq-1.8.0
# ICU.
tar -xf ../sources/icu4c-78.3-sources.tgz
pushd icu/source
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/icu -Dm644 ../LICENSE
popd
rm -rf icu
# Boost.
tar -xf ../sources/boost-1.91.0-1-b2-nodocs.tar.xz
pushd boost-1.91.0-1
./bootstrap.sh --prefix=/usr --with-icu
./b2 stage -j$(nproc) threading=multi link=shared
./b2 install threading=multi link=shared
install -t /usr/share/licenses/boost -Dm644 LICENSE_1_0.txt
popd
rm -rf boost-1.91.0-1
# libgpg-error.
tar -xf ../sources/libgpg-error-1.61.tar.bz2
pushd libgpg-error-1.61
./configure --prefix=/usr --enable-install-gpg-error-config
make
make install
install -t /usr/share/licenses/libgpg-error -Dm644 COPYING COPYING.LIB
popd
rm -rf libgpg-error-1.61
# libgcrypt.
tar -xf ../sources/libgcrypt-1.12.2.tar.bz2
pushd libgcrypt-1.12.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libgcrypt -Dm644 COPYING COPYING.LIB
popd
rm -rf libgcrypt-1.12.2
# Unzip.
tar -xf ../sources/unzip60.tar.gz
pushd unzip60
patch -Np1 -i ../../patches/unzip-6.0-manyfixes.patch
make -f unix/Makefile generic CC="gcc -std=gnu17"
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
install -t /usr/share/licenses/unzip -Dm644 LICENSE
popd
rm -rf unzip60
# Zip.
tar -xf ../sources/zip30.tar.gz
pushd zip30
make -f unix/Makefile generic CC="gcc -std=gnu89"
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
install -t /usr/share/licenses/zip -Dm644 LICENSE
popd
rm -rf zip30
# minizip.
tar -xf ../sources/zlib-1.3.2.tar.xz
pushd zlib-1.3.2/contrib/minizip
autoreconf -fi
./configure --prefix=/usr --enable-static=no
make
make install
install -t /usr/share/licenses/minizip -Dm644 /usr/share/licenses/zlib/LICENSE
popd
rm -rf zlib-1.3.2
# libmicrodns.
tar -xf ../sources/microdns-0.2.0.tar.xz
pushd microdns-0.2.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=disabled -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libmicrodns -Dm644 COPYING
popd
rm -rf microdns-0.2.0
# libsodium.
tar -xf ../sources/libsodium-1.0.20.tar.gz
pushd libsodium-1.0.20
./configure --prefix=/usr --disable-static ax_cv_check_cCATCHABLE_ABRT=no
make
make install
install -t /usr/share/licenses/libsodium -Dm644 LICENSE
popd
rm -rf libsodium-1.0.20
# sgml-common.
tar -xf ../sources/sgml-common-0.6.3.tgz
pushd sgml-common-0.6.3
patch -Np1 -i ../../patches/sgml-common-0.6.3-manpage-1.patch
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc
make
make docdir=/usr/share/doc install
install-catalog --add /etc/sgml/sgml-ent.cat /usr/share/sgml/sgml-iso-entities-8879.1986/catalog
install-catalog --add /etc/sgml/sgml-docbook.cat /etc/sgml/sgml-ent.cat
popd
rm -rf sgml-common-0.6.3
# Docbook 3.1 DTD.
mkdir docbk31
pushd docbk31
unzip -q ../../sources/docbk31.zip
sed -i -e '/ISO 8879/d' -e 's|DTDDECL "-//OASIS//DTD DocBook V3.1//EN"|SGMLDECL|g' docbook.cat
install -dm755 /usr/share/sgml/docbook/sgml-dtd-3.1
chown -R root:root .
install docbook.cat /usr/share/sgml/docbook/sgml-dtd-3.1/catalog
cp -af -- *.dtd *.mod *.dcl /usr/share/sgml/docbook/sgml-dtd-3.1
install-catalog --add /etc/sgml/sgml-docbook-dtd-3.1.cat /usr/share/sgml/docbook/sgml-dtd-3.1/catalog
install-catalog --add /etc/sgml/sgml-docbook-dtd-3.1.cat /etc/sgml/sgml-docbook.cat
cat >> /usr/share/sgml/docbook/sgml-dtd-3.1/catalog << "END"
  -- Begin Single Major Version catalog changes --

PUBLIC "-//Davenport//DTD DocBook V3.0//EN" "docbook.dtd"

  -- End Single Major Version catalog changes --
END
popd
rm -rf docbk31
# Docbook 4.5 DTD.
mkdir docbook-4.5
pushd docbook-4.5
unzip -q ../../sources/docbook-4.5.zip
sed -i -e '/ISO 8879/d' -e '/gml/d' docbook.cat
install -d /usr/share/sgml/docbook/sgml-dtd-4.5
chown -R root:root .
install docbook.cat /usr/share/sgml/docbook/sgml-dtd-4.5/catalog
cp -af -- *.dtd *.mod *.dcl /usr/share/sgml/docbook/sgml-dtd-4.5
install-catalog --add /etc/sgml/sgml-docbook-dtd-4.5.cat /usr/share/sgml/docbook/sgml-dtd-4.5/catalog
install-catalog --add /etc/sgml/sgml-docbook-dtd-4.5.cat /etc/sgml/sgml-docbook.cat
cat >> /usr/share/sgml/docbook/sgml-dtd-4.5/catalog << "END"
  -- Begin Single Major Version catalog changes --

PUBLIC "-//OASIS//DTD DocBook V4.4//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.3//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.2//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.1//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.0//EN" "docbook.dtd"

  -- End Single Major Version catalog changes --
END
popd
rm -rf docbook-4.5
# libxml2.
tar -xf ../sources/libxml2-2.15.3.tar.gz
pushd libxml2-2.15.3
./autogen.sh --prefix=/usr --sysconfdir=/etc --disable-static --with-history --with-icu --with-threads
make
make install
sed -i '/libs=/s/xml2.*/xml2"/' /usr/bin/xml2-config
install -t /usr/share/licenses/libxml2 -Dm644 Copyright
popd
rm -rf libxml2-2.15.3
# libarchive.
tar -xf ../sources/libarchive-3.8.8.tar.xz
pushd libarchive-3.8.8
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libarchive -Dm644 COPYING
popd
rm -rf libarchive-3.8.8
# Docbook XML 4.5.
mkdir docbook-xml-4.5
pushd docbook-xml-4.5
unzip -q ../../sources/docbook-xml-4.5.zip
install -dm755 /usr/share/xml/docbook/xml-dtd-4.5
install -dm755 /etc/xml
chown -R root:root .
cp -af -- docbook.cat *.dtd ent/ *.mod /usr/share/xml/docbook/xml-dtd-4.5
test -e /etc/xml/docbook || xmlcatalog --noout --create /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML CALS Table Model V4.5//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/calstblx.dtd" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//DTD XML Exchange Table Model 19990315//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/soextblx.dtd" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ELEMENTS DocBook XML Information Pool V4.5//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/dbpoolx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ELEMENTS DocBook XML Document Hierarchy V4.5//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/dbhierx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ELEMENTS DocBook XML HTML Tables V4.5//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/htmltblx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ENTITIES DocBook XML Notations V4.5//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/dbnotnx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ENTITIES DocBook XML Character Entities V4.5//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/dbcentx.mod" /etc/xml/docbook
xmlcatalog --noout --add "public" "-//OASIS//ENTITIES DocBook XML Additional General Entities V4.5//EN" "file:///usr/share/xml/docbook/xml-dtd-4.5/dbgenent.mod" /etc/xml/docbook
xmlcatalog --noout --add "rewriteSystem" "http://www.oasis-open.org/docbook/xml/4.5" "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
xmlcatalog --noout --add "rewriteURI" "http://www.oasis-open.org/docbook/xml/4.5" "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
test -e /etc/xml/catalog || xmlcatalog --noout --create /etc/xml/catalog
xmlcatalog --noout --add "delegatePublic" "-//OASIS//ENTITIES DocBook XML" "file:///etc/xml/docbook" /etc/xml/catalog
xmlcatalog --noout --add "delegatePublic" "-//OASIS//DTD DocBook XML" "file:///etc/xml/docbook" /etc/xml/catalog
xmlcatalog --noout --add "delegateSystem" "http://www.oasis-open.org/docbook/" "file:///etc/xml/docbook" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://www.oasis-open.org/docbook/" "file:///etc/xml/docbook" /etc/xml/catalog
for DTDVERSION in 4.1.2 4.2 4.3 4.4; do
  xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML V$DTDVERSION//EN" "http://www.oasis-open.org/docbook/xml/$DTDVERSION/docbookx.dtd" /etc/xml/docbook
  xmlcatalog --noout --add "rewriteSystem" "http://www.oasis-open.org/docbook/xml/$DTDVERSION" "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
  xmlcatalog --noout --add "rewriteURI" "http://www.oasis-open.org/docbook/xml/$DTDVERSION" "file:///usr/share/xml/docbook/xml-dtd-4.5" /etc/xml/docbook
  xmlcatalog --noout --add "delegateSystem" "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" "file:///etc/xml/docbook" /etc/xml/catalog
  xmlcatalog --noout --add "delegateURI" "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" "file:///etc/xml/docbook" /etc/xml/catalog
done
popd
rm -rf docbook-xml-4.5
# docbook-xsl-nons.
tar -xf ../sources/docbook-xsl-nons-1.79.2.tar.bz2
pushd docbook-xsl-nons-1.79.2
patch -Np1 -i ../../patches/docbook-xsl-nons-1.79.2-stack_fix-1.patch
install -dm755 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
cp -R VERSION assembly common eclipse epub epub3 extensions fo highlighting html htmlhelp images javahelp lib manpages params profiling roundtrip slides template tests tools webhelp website xhtml xhtml-1_1 xhtml5 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
ln -s VERSION /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl
if [ ! -d /etc/xml ]; then install -dm755 /etc/xml; fi
if [ ! -f /etc/xml/catalog ]; then
  xmlcatalog --noout --create /etc/xml/catalog
fi
xmlcatalog --noout --add "rewriteSystem" "https://cdn.docbook.org/release/xsl-nons/1.79.2" "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "https://cdn.docbook.org/release/xsl-nons/1.79.2" "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteSystem" "https://cdn.docbook.org/release/xsl-nons/current" "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "https://cdn.docbook.org/release/xsl-nons/current" "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteSystem" "http://docbook.sourceforge.net/release/xsl/current" "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
xmlcatalog --noout --add "rewriteURI" "http://docbook.sourceforge.net/release/xsl/current" "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" /etc/xml/catalog
install -t /usr/share/licenses/docbook-xsl -Dm644 COPYING
popd
rm -rf docbook-xsl-nons-1.79.2
# libxslt.
tar -xf ../sources/libxslt-1.1.45.tar.gz
pushd libxslt-1.1.45
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxslt -Dm644 Copyright
popd
rm -rf libxslt-1.1.45
# Lynx.
tar -xf ../sources/lynx2.9.3.tar.bz2
pushd lynx2.9.3
./configure --prefix=/usr --sysconfdir=/etc/lynx --datadir=/usr/share/doc/lynx --with-bzlib --with-screen=ncursesw --with-ssl --with-zlib --enable-gzip-help --enable-ipv6 --enable-locale-charset
make
make install-full
sed -i 's/#LOCALE_CHARSET:FALSE/LOCALE_CHARSET:TRUE/' /etc/lynx/lynx.cfg
sed -i 's/#DEFAULT_EDITOR:/DEFAULT_EDITOR:nano/' /etc/lynx/lynx.cfg
sed -i 's/#PERSISTENT_COOKIES:FALSE/PERSISTENT_COOKIES:TRUE/' /etc/lynx/lynx.cfg
install -t /usr/share/licenses/lynx -Dm644 COPYHEADER COPYING
popd
rm -rf lynx2.9.3
# xmlto.
tar -xf ../sources/xmlto-0.0.29.tar.bz2
pushd xmlto-0.0.29
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xmlto -Dm644 COPYING
popd
rm -rf xmlto-0.0.29
# OpenSP.
tar -xf ../sources/OpenSP-1.5.2.tar.gz
pushd OpenSP-1.5.2
patch -Np1 -i ../../patches/OpenSP-1.5.2-fixes.patch
./configure --prefix=/usr --mandir=/usr/share/man --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static --disable-doc-build --enable-default-catalog=/etc/sgml/catalog --enable-default-search-path=/usr/share/sgml --enable-http
make pkgdatadir=/usr/share/sgml/OpenSP
make pkgdatadir=/usr/share/sgml/OpenSP install
for p in {nsgmls,s{gmlnorm,p{am,cat,ent},x}}; do ln -sf o$p /usr/bin/$p; done
ln -sf osx /usr/bin/sgml2xml
ln -sf libosp.so /usr/lib/libsp.so
install -t /usr/share/licenses/opensp -Dm644 COPYING
popd
rm -rf OpenSP-1.5.2
# OpenJade.
tar -xf ../sources/openjade-1.3.2.tar.gz
pushd openjade-1.3.2
patch -Np1 -i ../../patches/openjade-1.3.2-fixes.patch
CXXFLAGS="$CXXFLAGS -fno-lifetime-dse" ./configure --prefix=/usr --mandir=/usr/share/man --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --enable-http --disable-static --enable-default-catalog=/etc/sgml/catalog --enable-default-search-path=/usr/share/sgml --datadir=/usr/share/sgml/openjade
make
make install install-man
ln -sf openjade /usr/bin/jade
ln -sf openjade.1 /usr/share/man/man1/jade.1
ln -sf libogrove.so /usr/lib/libgrove.so
ln -sf libospgrove.so /usr/lib/libspgrove.so
ln -sf libostyle.so /usr/lib/libstyle.so
install -t /usr/share/sgml/openjade -Dm644 dsssl/{catalog,*.{dtd,dsl,sgm}}
install-catalog --add /etc/sgml/openjade.cat /usr/share/sgml/openjade/catalog
install-catalog --add /etc/sgml/sgml-docbook.cat /etc/sgml/openjade.cat
echo "SYSTEM \"http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd\" \"/usr/share/xml/docbook/xml-dtd-4.5/docbookx.dtd\"" >> /usr/share/sgml/openjade/catalog
install -t /usr/share/licenses/openjade -Dm644 COPYING
popd
rm -rf openjade-1.3.2
# docbook-dsssl.
tar -xf ../sources/docbook-dsssl-1.79.tar.bz2
pushd docbook-dsssl-1.79
install -m755 bin/collateindex.pl /usr/bin
install -m644 bin/collateindex.pl.1 /usr/share/man/man1
install -dm755 /usr/share/sgml/docbook/dsssl-stylesheets-1.79
cp -r -- * /usr/share/sgml/docbook/dsssl-stylesheets-1.79
install-catalog --add /etc/sgml/dsssl-docbook-stylesheets.cat /usr/share/sgml/docbook/dsssl-stylesheets-1.79/catalog
install-catalog --add /etc/sgml/dsssl-docbook-stylesheets.cat /usr/share/sgml/docbook/dsssl-stylesheets-1.79/common/catalog
install-catalog --add /etc/sgml/sgml-docbook.cat /etc/sgml/dsssl-docbook-stylesheets.cat
popd
rm -rf docbook-dsssl-1.79
# docbook-utils.
tar -xf ../sources/docbook-utils-0.6.14.tar.gz
pushd docbook-utils-0.6.14
patch -Np1 -i ../../patches/docbook-utils-0.6.14-grep.patch
sed -i 's:/html::' doc/HTML/Makefile.in
./configure --prefix=/usr --mandir=/usr/share/man
make
make docdir=/usr/share/doc install
for dt in {dvi,html,man,p{df,s},rtf,t{ex{,i},xt}}; do ln -sf docbook2$dt /usr/bin/db2$dt; done
install -t /usr/share/licenses/docbook-utils -Dm644 COPYING
popd
rm -rf docbook-utils-0.6.14
# Docbook XML 5.0.
unzip -q ../sources/docbook-5.0.zip
pushd docbook-5.0
install -dm755 /usr/share/xml/docbook/schema/{dtd,rng,sch,xsd}/5.0
install -m644  dtd/* /usr/share/xml/docbook/schema/dtd/5.0
install -m644  rng/* /usr/share/xml/docbook/schema/rng/5.0
install -m644  sch/* /usr/share/xml/docbook/schema/sch/5.0
install -m644  xsd/* /usr/share/xml/docbook/schema/xsd/5.0
if [ ! -e /etc/xml/docbook-5.0 ]; then
  xmlcatalog --noout --create /etc/xml/docbook-5.0
fi
xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML 5.0//EN" "file:///usr/share/xml/docbook/schema/dtd/5.0/docbook.dtd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "system" "http://www.oasis-open.org/docbook/xml/5.0/dtd/docbook.dtd" "file:///usr/share/xml/docbook/schema/dtd/5.0/docbook.dtd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "system" "http://docbook.org/xml/5.0/dtd/docbook.dtd" "file:///usr/share/xml/docbook/schema/dtd/5.0/docbook.dtd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rng" "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rng" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbook.rng" "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rng" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rng/docbookxi.rng" "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rng" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbookxi.rng" "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rng" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rnc/docbook.rnc" "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rnc" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbook.rnc" "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rnc" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rnc/docbookxi.rnc" "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rnc" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbookxi.rnc" "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rnc" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbook.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/docbook.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/docbook.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/docbook.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbookxi.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/docbookxi.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/docbookxi.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/docbookxi.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/xi.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/xi.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/xi.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/xi.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/xlink.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/xlink.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/xlink.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/xlink.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/xml.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/xml.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/xml.xsd" "file:///usr/share/xml/docbook/schema/xsd/5.0/xml.xsd" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/sch/docbook.sch" "file:///usr/share/xml/docbook/schema/sch/5.0/docbook.sch" /etc/xml/docbook-5.0
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/sch/docbook.sch" "file:///usr/share/xml/docbook/schema/sch/5.0/docbook.sch" /etc/xml/docbook-5.0
xmlcatalog --noout --create /usr/share/xml/docbook/schema/dtd/5.0/catalog.xml
xmlcatalog --noout --add "public" "-//OASIS//DTD DocBook XML 5.0//EN" "docbook.dtd" /usr/share/xml/docbook/schema/dtd/5.0/catalog.xml
xmlcatalog --noout --add "system" "http://www.oasis-open.org/docbook/xml/5.0/dtd/docbook.dtd" "docbook.dtd" /usr/share/xml/docbook/schema/dtd/5.0/catalog.xml
xmlcatalog --noout --create /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbook.rng" "docbook.rng" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rng" "docbook.rng" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbookxi.rng" "docbookxi.rng" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rng/docbookxi.rng" "docbookxi.rng" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbook.rnc" "docbook.rnc" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rnc" "docbook.rnc" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/rng/docbookxi.rnc" "docbookxi.rnc" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/rng/docbookxi.rnc" "docbookxi.rnc" /usr/share/xml/docbook/schema/rng/5.0/catalog.xml
xmlcatalog --noout --create /usr/share/xml/docbook/schema/sch/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/sch/docbook.sch" "docbook.sch" /usr/share/xml/docbook/schema/sch/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/sch/docbook.sch" "docbook.sch" /usr/share/xml/docbook/schema/sch/5.0/catalog.xml
xmlcatalog --noout --create /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/docbook.xsd" "docbook.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbook.xsd" "docbook.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/docbookxi.xsd" "docbookxi.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbookxi.xsd" "docbookxi.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/xlink.xsd" "xlink.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/xlink.xsd" "xlink.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.0/xsd/xml.xsd" "xml.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.0/xsd/xml.xsd" "xml.xsd" /usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
xmlcatalog --noout --add "delegatePublic" "-//OASIS//DTD DocBook XML 5.0//EN" "file:///usr/share/xml/docbook/schema/dtd/5.0/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateSystem" "http://docbook.org/xml/5.0/dtd/" "file:///usr/share/xml/docbook/schema/dtd/5.0/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.0/dtd/" "file:///usr/share/xml/docbook/schema/dtd/5.0/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.0/rng/" "file:///usr/share/xml/docbook/schema/rng/5.0/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.0/sch/" "file:///usr/share/xml/docbook/schema/sch/5.0/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.0/xsd/" "file:///usr/share/xml/docbook/schema/xsd/5.0/catalog.xml" /etc/xml/catalog
popd
rm -rf docbook-5.0
# Docbook XML 5.1.
mkdir docbook-5.1
pushd docbook-5.1
unzip -q ../../sources/docbook-v5.1-os.zip
install -dm755 /usr/share/xml/docbook/schema/{rng,sch}/5.1
install -m644 schemas/rng/* /usr/share/xml/docbook/schema/rng/5.1
install -m644 schemas/sch/* /usr/share/xml/docbook/schema/sch/5.1
install -m755 tools/db4-entities.pl /usr/bin
install -dm755 /usr/share/xml/docbook/stylesheet/docbook5
install -m644 tools/db4-upgrade.xsl /usr/share/xml/docbook/stylesheet/docbook5
if [ ! -e /etc/xml/docbook-5.1 ]; then
  xmlcatalog --noout --create /etc/xml/docbook-5.1
fi
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/rng/docbook.rng" "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rng" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/rng/docbook.rng" "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rng" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/rng/docbookxi.rng" "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rng" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/rng/docbookxi.rng" "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rng" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/rnc/docbook.rnc" "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rnc" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/rng/docbook.rnc" "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rnc" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/rnc/docbookxi.rnc" "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rnc" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/rng/docbookxi.rnc" "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rnc" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/sch/docbook.sch" "file:///usr/share/xml/docbook/schema/sch/5.1/docbook.sch" /etc/xml/docbook-5.1
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/sch/docbook.sch" "file:///usr/share/xml/docbook/schema/sch/5.1/docbook.sch" /etc/xml/docbook-5.1
xmlcatalog --noout --create /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/schemas/rng/docbook.schemas/rng" "docbook.schemas/rng" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbook.schemas/rng" "docbook.schemas/rng" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/schemas/rng/docbookxi.schemas/rng" "docbookxi.schemas/rng" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbookxi.schemas/rng" "docbookxi.schemas/rng" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/schemas/rng/docbook.rnc" "docbook.rnc" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbook.rnc" "docbook.rnc" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/schemas/rng/docbookxi.rnc" "docbookxi.rnc" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbookxi.rnc" "docbookxi.rnc" /usr/share/xml/docbook/schema/rng/5.1/catalog.xml
xmlcatalog --noout --create /usr/share/xml/docbook/schema/sch/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://docbook.org/xml/5.1/schemas/sch/docbook.schemas/sch" "docbook.schemas/sch" /usr/share/xml/docbook/schema/sch/5.1/catalog.xml
xmlcatalog --noout --add "uri" "http://www.oasis-open.org/docbook/xml/5.1/schemas/sch/docbook.schemas/sch" "docbook.schemas/sch" /usr/share/xml/docbook/schema/sch/5.1/catalog.xml
xmlcatalog --noout --add "delegatePublic" "-//OASIS//DTD DocBook XML 5.1//EN" "file:///usr/share/xml/docbook/schema/dtd/5.1/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateSystem" "http://docbook.org/xml/5.1/dtd/" "file:///usr/share/xml/docbook/schema/dtd/5.1/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.1/dtd/" "file:///usr/share/xml/docbook/schema/dtd/5.1/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.1/rng/" "file:///usr/share/xml/docbook/schema/rng/5.1/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.1/sch/" "file:///usr/share/xml/docbook/schema/sch/5.1/catalog.xml" /etc/xml/catalog
xmlcatalog --noout --add "delegateURI" "http://docbook.org/xml/5.1/xsd/" "file:///usr/share/xml/docbook/schema/xsd/5.1/catalog.xml" /etc/xml/catalog
popd
rm -rf docbook-5.1
# lxml.
tar -xf ../sources/lxml-6.1.1.tar.gz
pushd lxml-6.1.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/lxml -Dm644 LICENSE.txt LICENSES.txt
popd
rm -rf lxml-6.1.1
# itstool.
tar -xf ../sources/itstool-2.0.7.tar.gz
pushd itstool-2.0.7
patch -Np1 -i ../../patches/itstool-2.0.7-upstreamfixes.patch
./autogen.sh --prefix=/usr
make
make install
install -t /usr/share/licenses/itstool -Dm644 COPYING COPYING.GPL3
popd
rm -rf itstool-2.0.7
# Asciidoc.
tar -xf ../sources/asciidoc-10.2.1.tar.gz
pushd asciidoc-10.2.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/asciidoc -Dm644 /usr/lib/$(readlink /usr/bin/python3)/site-packages/asciidoc-*.dist-info/licenses/LICENSE
popd
rm -rf asciidoc-10.2.1
# talloc.
tar -xf ../sources/talloc-2.4.4.tar.gz
pushd talloc-2.4.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-talloc-compat1 --bundled-libraries=NONE
make
make install
install -t /usr/share/licenses/talloc -Dm644 LICENSE
popd
rm -rf talloc-2.4.4
# tdb.
tar -xf ../sources/tdb-1.4.14.tar.gz
pushd tdb-1.4.14
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/tdb -Dm644 LICENSE
popd
rm -rf tdb-1.4.14
# tevent.
tar -xf ../sources/tevent-0.17.1.tar.gz
pushd tevent-0.17.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/tevent -Dm644 LICENSE
popd
rm -rf tevent-0.17.1
# proot.
tar -xf ../sources/proot-5.4.0.tar.gz
pushd proot-5.4.0
make -C src
rst2man doc/proot/manual.rst proot.1
install -t /usr/bin -Dm755 src/proot
install -t /usr/share/man/man1 -Dm644 proot.1
install -t /usr/share/licenses/proot -Dm644 COPYING
popd
rm -rf proot-5.4.0
# Moreutils.
tar -xf ../sources/moreutils_0.69.orig.tar.xz
pushd moreutils-0.69
sed -e 's/parallel //' -e 's/parallel.1 //' -i Makefile
make CFLAGS="$CFLAGS" DOCBOOKXSL=/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
make install
install -t /usr/share/licenses/moreutils -Dm644 COPYING
popd
rm -rf moreutils-0.69
# GNU-EFI.
tar -xf ../sources/gnu-efi-4.0.4.tar.gz
pushd gnu-efi-4.0.4
CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" make
CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" make PREFIX=/usr install
install -t /usr/share/licenses/gnu-efi -Dm644 LICENSE licenses/*
popd
rm -rf gnu-efi-4.0.4
# sbsigntools.
tar -xf ../sources/sbsigntools-0.9.5.tar.gz
pushd sbsigntools-0.9.5
tar -xf ../../sources/ccan-7340873.tar.gz -C lib/ccan.git --strip-components=1
tar -xf ../../sources/sbsigntool-0.9.1-ccan.tar.gz
patch -Np1 -i ../../patches/sbsigntools-0.9.5-kmodsign-v2.patch
patch -Np1 -i ../../patches/sbsigntools-0.9.5-openssl4.patch
touch AUTHORS ChangeLog
autoreconf -fi
CFLAGS="$CFLAGS -fshort-wchar -Wno-error=unused-but-set-variable" CPPFLAGS="$CPPFLAGS -I$PWD/lib/ccan.git" ./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin
make
make install
install -t /usr/share/licenses/sbsigntools -Dm644 COPYING LICENSE.GPLv3
popd
rm -rf sbsigntools-0.9.5
# efitools.
tar -xf ../sources/efitools-1.9.2.tar.gz
pushd efitools-1.9.2
patch -Np1 -i ../../patches/efitools-1.9.2-manyfixes.patch
sed -i '44,45d' Makefile
ARCH="$MBS_ARCH" CC="gcc -std=gnu17" make -j1
make -j1 install
cat > /usr/share/efitools/README-MassOS << "END"
The EFI applications are no longer supplied as part of the efitools package on
newer builds of MassOS. This is primarily because they are entirely broken when
built with modern compiler toolchains (such as the one used by MassOS). They
also cannot be signed for secure boot by the MassOS developers, because they
are considered insecure applications by modern standards.

If you still need to obtain the EFI applications for some reason, you can
download a prebuilt efitools package (which is built with an older toolchain
and thus includes working builds of the EFI applications) from one of the
following locations (depending on your CPU architecture):

- https://dmassey.net/files/misc/efitools-1.9.2-standalone-x86_64.tar.xz
- https://dmassey.net/files/misc/efitools-1.9.2-standalone-aarch64.tar.xz

After extracting the tarball, the EFI applications can be found under the
'efi/' subdirectory (NOT 'usr/share/efitools/efi/'). They aren't signed for
secure boot but you can sign them yourself using sbsign(1) if you wish.
END
install -t /usr/share/licenses/efitools -Dm644 COPYING
popd
rm -rf efitools-1.9.2
# hwdata.
tar -xf ../sources/hwdata-0.409.tar.gz
pushd hwdata-0.409
./configure --prefix=/usr --disable-blacklist
make
make install
install -t /usr/share/licenses/hwdata -Dm644 COPYING
popd
rm -rf hwdata-0.409
# systemd (initial build; will be rebuilt later to support more features).
tar -xf ../sources/systemd-261.2.tar.gz
pushd systemd-261.2
patch -Np1 -i ../../patches/systemd-261.2-hardcode-uids.patch
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --localstatedir=/var --buildtype=minsize -Dmode=release -Dversion-tag="$(cat meson.version)-massos" -Dshared-lib-tag="$(cat meson.version)-massos" -Dsbat-distro-version="$(cat meson.version)-massos" -Dsbat-distro-url=https://massos.org -Dbpf-framework=disabled -Ddefault-compression=zstd -Ddefault-dnssec=no -Ddev-kvm-mode=0660 -Ddns-over-tls=openssl -Dfallback-hostname=massos -Dfirstboot=false -Dhomed=disabled -Dinitrd=true -Dinstall-tests=false -Dkernel-install=false -Dman=enabled -Dpamconfdir=/etc/pam.d -Drpmmacrosdir=no -Dsysupdate=disabled -Dsysusers=true -Dtests=false -Dtpm=true -Dukify=disabled -Duserdb=false -Dvmlinux-h=disabled -Dadm-gid=999 -Dwheel-gid=998 -Dempower-gid=997 -Dutmp-gid=996 -Daudio-gid=995 -Dcdrom-gid=994 -Dclock-gid=993 -Ddialout-gid=992 -Ddisk-gid=991 -Dinput-gid=990 -Dkmem-gid=989 -Dkvm-gid=988 -Dlp-gid=987 -Drender-gid=986 -Dsgx-gid=985 -Dtape-gid=984 -Dvideo-gid=983 -Dusers-gid=982 -Dsystemd-journal-gid=981 -Dtty-gid=5 -Dsystemd-network-uid=979 -Dsystemd-resolve-uid=977 -Dsystemd-timesync-uid=976 -Dsystemd-imds-uid=969
ninja -C build
ninja -C build install
cat > /etc/pam.d/systemd-user << "END"
account  required pam_access.so
account  include  system-account
session  required pam_env.so
session  required pam_limits.so
session  required pam_unix.so
session  required pam_loginuid.so
session  optional pam_keyinit.so force revoke
session  optional pam_systemd.so
auth     required pam_deny.so
password required pam_deny.so
END
cat > /usr/lib/sysusers.d/massos.conf << "END"
# This file defines additional system users/groups which are required on a
# MassOS system, but systemd doesn't provide sysusers files for by default.

u bin 1 bin -
u sys 2 sys -

u daemon 6 "Daemon User" -
m daemon bin

g floppy 7 -
g mail 8 -
g lpadmin 9 -
g scanner 10 -
g netdev 11 -
g autologin 12 -
END
systemd-sysusers
chgrp utmp /var/log/lastlog
systemctl preset-all
systemctl disable systemd-networkd-wait-online
install -t /usr/lib/systemd/system -Dm644 ../../extras/systemd-units/*
systemctl enable gpm
install -t /usr/share/licenses/systemd -Dm644 LICENSE.{GPL2,LGPL2.1} LICENSES/*
popd
rm -rf systemd-261.2
# D-Bus (initial build; will be rebuilt later for more features).
tar -xf ../sources/dbus-1.16.2.tar.xz
pushd dbus-1.16.2
patch -Np1 -i ../../patches/dbus-1.16.2-hardcode-uid.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dapparmor=disabled -Dlibaudit=disabled -Dmodular_tests=disabled -Dselinux=disabled -Dx11_autolaunch=disabled
ninja -C build
ninja -C build install
systemd-sysusers
ln -sf /etc/machine-id /var/lib/dbus
install -t /usr/share/licenses/dbus -Dm644 COPYING
popd
rm -rf dbus-1.16.2
# Man-DB.
tar -xf ../sources/man-db-2.13.1.tar.xz
pushd man-db-2.13.1
./configure --prefix=/usr --sysconfdir=/etc --with-systemdsystemunitdir=/usr/lib/systemd/system --with-db=gdbm --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx
make
make install
install -t /usr/share/licenses/man-db -Dm644 COPYING
popd
rm -rf man-db-2.13.1
# Procps-NG.
tar -xf ../sources/procps-ng-4.0.6.tar.xz
pushd procps-ng-4.0.6
sed -i 's/ITEMS_COUNT);/16);/' src/pgrep.c
./configure --prefix=/usr --disable-static --disable-kill --enable-watch8bit --with-systemd
make
make install
install -t /usr/share/licenses/procps-ng -Dm644 COPYING COPYING.LIB
popd
rm -rf procps-ng-4.0.6
# util-linux.
tar -xf ../sources/util-linux-2.42.2.tar.xz
pushd util-linux-2.42.2
patch -Np1 -i ../../patches/util-linux-2.42.2-hardcode-uid.patch
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run --bindir=/usr/bin --libdir=/usr/lib --sbindir=/usr/bin --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-liblastlog2 --disable-static --without-python
make
make install
systemd-sysusers
systemctl enable uuidd.socket
install -t /usr/share/licenses/util-linux -Dm644 COPYING
popd
rm -rf util-linux-2.42.2
# FUSE2.
tar -xf ../sources/fuse-2.9.9.tar.gz
pushd fuse-2.9.9
patch -Np1 -i ../../patches/fuse-2.9.9-buildfixes.patch
cp /usr/share/gettext/m4/*.m4 m4
autoreconf -fi
UDEV_RULES_PATH=/usr/lib/udev/rules.d MOUNT_FUSE_PATH=/usr/bin ./configure --prefix=/usr --libdir=/usr/lib --sbindir=/usr/bin --enable-lib --enable-util --disable-example --disable-static
make
make install
rm -f /etc/init.d/fuse
chmod 4755 /usr/bin/fusermount
install -t /usr/share/licenses/fuse2 -Dm644 COPYING COPYING.LIB
popd
rm -rf fuse-2.9.9
# FUSE3.
tar -xf ../sources/fuse-3.18.2.tar.gz
pushd fuse-3.18.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dtests=false
ninja -C build
ninja -C build install
rm -f /etc/init.d/fuse3
chmod 4755 /usr/bin/fusermount3
cat > /etc/fuse.conf << "END"
# Set the maximum number of FUSE mounts for non-root users (default = 1000).
#mount_max = 1000

# Allow non-root users to mount with the 'allow_other' or 'allow_root' options.
#user_allow_other
END
install -t /usr/share/licenses/fuse3 -Dm644 LICENSE GPL2.txt LGPL2.txt
popd
rm -rf fuse-3.18.2
# e2fsprogs.
tar -xf ../sources/e2fsprogs-1.47.4.tar.xz
pushd e2fsprogs-1.47.4
mkdir -p build; pushd build
../configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-elf-shlibs --disable-fsck --disable-libblkid --disable-libuuid --disable-uuidd
make
make install
rm -f /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gzip -d /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
install -t /usr/share/licenses/e2fsprogs -Dm644 ../NOTICE
popd; popd
rm -rf e2fsprogs-1.47.4
# dosfstools.
tar -xf ../sources/dosfstools-4.2.tar.gz
pushd dosfstools-4.2
./configure --prefix=/usr --sbindir=/usr/bin --enable-compat-symlinks
make
make install
install -t /usr/share/licenses/dosfstools -Dm644 COPYING
popd
rm -rf dosfstools-4.2
# LZO.
tar -xf ../sources/lzo-2.10.tar.gz
pushd lzo-2.10
./configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/lzo -Dm644 COPYING
popd
rm -rf lzo-2.10
# lzop.
tar -xf ../sources/lzop-1.04.tar.gz
pushd lzop-1.04
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/lzop -Dm644 COPYING
popd
rm -rf lzop-1.04
# cpio.
tar -xf ../sources/cpio-2.15.tar.bz2
pushd cpio-2.15
CFLAGS="$CFLAGS -std=gnu17" ./configure --prefix=/usr --enable-mt --with-rmt=/usr/libexec/rmt
make
make install
install -t /usr/share/licenses/cpio -Dm644 COPYING
popd
rm -rf cpio-2.15
# squashfs-tools.
tar -xf ../sources/squashfs4.7.tar.gz
pushd squashfs-tools-4.7/squashfs-tools
make GZIP_SUPPORT=1 XZ_SUPPORT=1 LZO_SUPPORT=1 LZMA_XZ_SUPPORT=1 LZ4_SUPPORT=1 ZSTD_SUPPORT=1 XATTR_SUPPORT=1
make INSTALL_PREFIX=/usr INSTALL_MANPAGES_DIR=/usr/share/man/man1 install
install -t /usr/share/licenses/squashfs-tools -Dm644 ../COPYING
popd
rm -rf squashfs-tools-4.7
# squashfuse.
tar -xf ../sources/squashfuse-0.6.0.tar.gz
pushd squashfuse-0.6.0
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/squashfuse -Dm644 LICENSE
popd
rm -rf squashfuse-0.6.0
# acpid.
tar -xf ../sources/acpid-2.0.34.tar.xz
pushd acpid-2.0.34
./configure --prefix=/usr --sbindir=/usr/bin
make
make install
install -dm755 /etc/acpi/{actions,events}
systemctl enable acpid
install -t /usr/share/licenses/acpid -Dm644 COPYING
popd
rm -rf acpid-2.0.34
# libtasn1.
tar -xf ../sources/libtasn1-4.21.0.tar.gz
pushd libtasn1-4.21.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libtasn1 -Dm644 COPYING
popd
rm -rf libtasn1-4.21.0
# p11-kit.
tar -xf ../sources/p11-kit-0.26.2.tar.xz
pushd p11-kit-0.26.2
sed '20,$ d' -i trust/trust-extract-compat
cat >> trust/trust-extract-compat << "END"
/usr/libexec/make-ca/copy-trust-modifications
/usr/bin/make-ca -r
END
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtrust_paths=/etc/pki/anchors
ninja -C build
ninja -C build install
ln -sfr /usr/libexec/p11-kit/trust-extract-compat /usr/bin/update-ca-certificates
ln -sf ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
install -t /usr/share/licenses/p11-kit -Dm644 COPYING
popd
rm -rf p11-kit-0.26.2
# make-ca.
tar -xf ../sources/make-ca-1.16.1.tar.gz
pushd make-ca-1.16.1
make SBINDIR=/usr/bin install
mkdir -p /etc/ssl/local
tar -xf ../../sources/nss-3.125.tar.gz nss-3.125/nss/lib/ckfw/builtins/certdata.txt --strip-components=5
install -t /usr/share/massos/certs -Dm644 certdata.txt
make-ca -fC /usr/share/massos/certs/certdata.txt
systemctl enable update-pki.timer
install -t /usr/share/licenses/make-ca -Dm644 LICENSE{,.GPLv3,.MIT}
popd
rm -rf make-ca-1.16.1
# libaio.
tar -xf ../sources/libaio-libaio-0.3.113.tar.gz
pushd libaio-libaio-0.3.113
make
make install
rm -f /usr/lib/libaio.a
install -t /usr/share/licenses/libaio -Dm644 COPYING
popd
rm -rf libaio-libaio-0.3.113
# mdadm.
tar -xf ../sources/mdadm-4.6.tar.gz
pushd mdadm-4.6
make BINDIR=/usr/bin UDEVDIR=/usr/lib/udev SYSTEMD_DIR=/usr/lib/systemd/system
make BINDIR=/usr/bin UDEVDIR=/usr/lib/udev SYSTEMD_DIR=/usr/lib/systemd/system install install-systemd
install -t /usr/share/licenses/mdadm -Dm644 COPYING
popd
rm -rf mdadm-4.6
# LVM2.
tar -xf ../sources/LVM2.2.03.41.tgz
pushd LVM2.2.03.41
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --enable-cmdlib --enable-dmeventd --enable-lvmpolld --enable-pkgconfig --enable-readline --enable-udev_rules --enable-udev_sync --with-thin=internal
make
make install install_systemd_units
install -t /usr/share/licenses/lvm2 -Dm644 COPYING{,.BSD,.LIB}
popd
rm -rf LVM2.2.03.41
# dmraid.
tar -xf ../sources/dmraid-1.0.0.rc16-3.tar.bz2
pushd dmraid/1.0.0.rc16-3/dmraid
CC="gcc -std=gnu17" ./configure --prefix=/usr --sbindir=/usr/bin --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --enable-led --enable-intel_led --enable-shared_lib
make -j1
make -j1 install
rm -f /usr/lib/libdmraid.a
install -t /usr/share/licenses/dmraid -Dm644 LICENSE{,_GPL,_LGPL}
popd
rm -rf dmraid
# btrfs-progs.
tar -xf ../sources/btrfs-progs-v7.0.tar.xz
pushd btrfs-progs-v7.0
./configure --prefix=/usr --sbindir=/usr/bin --disable-static
make
make install
install -t /usr/share/licenses/btrfs-progs -Dm644 COPYING
popd
rm -rf btrfs-progs-v7.0
# inih.
tar -xf ../sources/inih-r62.tar.gz
pushd inih-r62
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/inih -Dm644 LICENSE.txt
popd
rm -rf inih-r62
# Userspace-RCU.
tar -xf ../sources/userspace-rcu-0.15.6.tar.bz2
pushd userspace-rcu-0.15.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/userspace-rcu -Dm644 LICENSE.md lgpl-relicensing.md LICENSES/*
popd
rm -rf userspace-rcu-0.15.6
# xfsprogs.
tar -xf ../sources/xfsprogs-7.0.1.tar.xz
pushd xfsprogs-7.0.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --with-systemd-unit-dir=/usr/lib/systemd/system --enable-editline
make
make -j1 PKG_USER=root PKG_GROUP=root install install-dev
rm -f /usr/lib/libhandle.{l,}a
install -t /usr/share/licenses/xfsprogs -Dm644 debian/copyright
popd
rm -rf xfsprogs-7.0.1
# f2fs-tools.
tar -xf ../sources/f2fs-tools-1.16.0.tar.gz
pushd f2fs-tools-1.16.0
patch -Np1 -i ../../patches/f2fs-tools-1.16.0-gcc15.patch
./autogen.sh
./configure --prefix=/usr --sbindir=/usr/bin --disable-static
make
make install
install -t /usr/share/licenses/f2fs-tools -Dm644 COPYING
popd
rm -rf f2fs-tools-1.16.0
# jfsutils.
tar -xf ../sources/jfsutils-1.1.15.tar.gz
pushd jfsutils-1.1.15
patch -Np1 -i ../../patches/jfsutils-1.1.15-fixes.patch
./configure --prefix=/usr --sbindir=/usr/bin
make
make install
install -t /usr/share/licenses/jfsutils -Dm644 COPYING
popd
rm -rf jfsutils-1.1.15
# reiserfsprogs.
tar -xf ../sources/reiserfsprogs-3.6.27.tar.xz
pushd reiserfsprogs-3.6.27
sed -i '24iAC_USE_SYSTEM_EXTENSIONS' configure.ac
autoreconf -fi
./configure --prefix=/usr --sbindir=/usr/bin --disable-static
make
make install
install -t /usr/share/licenses/reiserfsprogs -Dm644 COPYING
popd
rm -rf reiserfsprogs-3.6.27
# ntfs-3g.
tar -xf ../sources/ntfs-3g-2026.2.25.tar.gz
pushd ntfs-3g-2026.2.25
./autogen.sh
./configure --prefix=/usr --sbindir=/usr/bin --disable-static --with-fuse=external
make
make install
ln -sf ntfs-3g /usr/bin/mount.ntfs
ln -sf ntfs-3g.8 /usr/share/man/man8/mount.ntfs.8
install -t /usr/share/licenses/ntfs-3g -Dm644 COPYING COPYING.LIB
popd
rm -rf ntfs-3g-2026.2.25
# exfatprogs.
tar -xf ../sources/exfatprogs-1.2.8.tar.xz
pushd exfatprogs-1.2.8
./configure --prefix=/usr --sbindir=/usr/bin
make
make install
install -t /usr/share/licenses/exfatprogs -Dm644 COPYING
popd
rm -rf exfatprogs-1.2.8
# udftools.
tar -xf ../sources/udftools-2.3.tar.gz
pushd udftools-2.3
./configure --prefix=/usr --sbindir=/usr/bin
make
make install
install -t /usr/share/licenses/udftools -Dm644 COPYING
popd
rm -rf udftools-2.3
# apfsprogs.
tar -xf ../sources/apfsprogs-0.2.1.tar.gz
pushd apfsprogs-0.2.1
make -C apfsck GIT_COMMIT=0.2.1
make -C apfs-label GIT_COMMIT=0.2.1
make -C apfs-snap GIT_COMMIT=0.2.1
make -C mkapfs GIT_COMMIT=0.2.1
make -C apfsck DESTDIR=/ BINDIR=/usr/bin MANDIR=/usr/share/man/man8 install
make -C apfs-label DESTDIR=/ BINDIR=/usr/bin MANDIR=/usr/share/man/man8 install
make -C apfs-snap DESTDIR=/ BINDIR=/usr/bin MANDIR=/usr/share/man/man8 install
make -C mkapfs DESTDIR=/ BINDIR=/usr/bin MANDIR=/usr/share/man/man8 install
install -t /usr/share/licenses/apfsprogs -Dm644 LICENSE
popd
rm -rf apfsprogs-0.2.1
# Fakeroot.
tar -xf ../sources/fakeroot-upstream-1.38.1.tar.bz2
pushd fakeroot-upstream-1.38.1
./bootstrap
./configure --prefix=/usr --libdir=/usr/lib/libfakeroot --disable-static
make
sed -i 's/de es fr nl pt ro sv//' doc/Makefile
make install
install -dm755 /etc/ld.so.conf.d
echo "/usr/lib/libfakeroot" > /etc/ld.so.conf.d/fakeroot.conf
ldconfig
install -t /usr/share/licenses/fakeroot -Dm644 COPYING
popd
rm -rf fakeroot-upstream-1.38.1
# Parted.
tar -xf ../sources/parted-3.7.tar.xz
pushd parted-3.7
./configure --prefix=/usr --sbindir=/usr/bin --disable-static
make
make install
install -t /usr/share/licenses/parted -Dm644 COPYING
popd
rm -rf parted-3.7
# Popt.
tar -xf ../sources/popt-popt-1.19-release.tar.gz
pushd popt-popt-1.19-release
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/popt -Dm644 COPYING
popd
rm -rf popt-popt-1.19-release
# gptfdisk.
tar -xf ../sources/gptfdisk-1.0.10.tar.gz
pushd gptfdisk-1.0.10
sed -i 's|ncursesw/||' gptcurses.cc
make
install -t /usr/bin -Dm755 gdisk cgdisk sgdisk fixparts
install -t /usr/share/man/man8 -Dm644 gdisk.8 cgdisk.8 sgdisk.8 fixparts.8
install -t /usr/share/licenses/gptfdisk -Dm644 COPYING
popd
rm -rf gptfdisk-1.0.10
# run-parts (from debianutils).
tar -xf ../sources/debianutils-debian-5.23.1.tar.gz
pushd debianutils-debian-5.23.1
autoreconf -fi
./configure --prefix=/usr
make run-parts
install -t /usr/bin -Dm755 run-parts
install -t /usr/share/man/man8 -Dm644 run-parts.8
install -t /usr/share/licenses/run-parts -Dm644 /usr/share/licenses/gptfdisk/COPYING
popd
rm -rf debianutils-debian-5.23.1
# spice-protocol.
tar -xf ../sources/spice-protocol-v0.14.4.tar.bz2
pushd spice-protocol-v0.14.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/spice-protocol -Dm644 COPYING
popd
rm -rf spice-protocol-v0.14.4
# seatd.
tar -xf ../sources/seatd-0.9.1.tar.gz
pushd seatd-0.9.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dlibseat-logind=systemd -Dserver=enabled -Dexamples=disabled -Dman-pages=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/seatd -Dm644 LICENSE
popd
rm -rf seatd-0.9.1
# libdisplay-info.
tar -xf ../sources/libdisplay-info-0.3.0.tar.bz2
pushd libdisplay-info-0.3.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libdisplay-info -Dm644 LICENSE
popd
rm -rf libdisplay-info-0.3.0
# libpaper.
tar -xf ../sources/libpaper-2.2.8.tar.gz
pushd libpaper-2.2.8
./configure --prefix=/usr --sysconfdir=/etc --disable-static --enable-relocatable
make
make install
cat > /etc/papersize << "END"
# Specify the default paper size in this file.
# Run 'paper --all --no-size' for a list of supported paper sizes.
END
install -dm755 /etc/libpaper.d
install -t /usr/share/licenses/libpaper -Dm644 COPYING
popd
rm -rf libpaper-2.2.8
# xxhash.
tar -xf ../sources/xxHash-0.8.3.tar.gz
pushd xxHash-0.8.3
make PREFIX=/usr CFLAGS="$CFLAGS -fPIC"
make PREFIX=/usr install
rm -f /usr/lib/libxxhash.a
ln -sf xxhsum.1 /usr/share/man/man1/xxh32sum.1
ln -sf xxhsum.1 /usr/share/man/man1/xxh64sum.1
ln -sf xxhsum.1 /usr/share/man/man1/xxh128sum.1
install -t /usr/share/licenses/xxhash -Dm644 LICENSE
popd
rm -rf xxHash-0.8.3
# rsync.
tar -xf ../sources/rsync-3.4.4.tar.gz
pushd rsync-3.4.4
./configure --prefix=/usr --without-included-popt --without-included-zlib
make
make install
install -t /usr/share/licenses/rsync -Dm644 COPYING
popd
rm -rf rsync-3.4.4
# libnghttp2.
tar -xf ../sources/nghttp2-1.69.0.tar.xz
pushd nghttp2-1.69.0
./configure --prefix=/usr --disable-static --enable-lib-only
make
make install
install -t /usr/share/licenses/libnghttp2 -Dm644 COPYING
popd
rm -rf nghttp2-1.69.0
# libnghttp3.
tar -xf ../sources/nghttp3-1.15.0.tar.xz
pushd nghttp3-1.15.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libnghttp3 -Dm644 COPYING
popd
rm -rf nghttp3-1.15.0
# curl (initial build for circular deps - rebuilt later for far more features).
tar -xf ../sources/curl-8.21.0.tar.xz
pushd curl-8.21.0
./configure --prefix=/usr --disable-static --disable-threaded-resolver --without-libpsl --with-openssl --with-ca-path=/etc/ssl/certs
make
make install
install -t /usr/share/licenses/curl -Dm644 COPYING
popd
rm -rf curl-8.21.0
# jsoncpp.
tar -xf ../sources/jsoncpp-1.9.6.tar.gz
pushd jsoncpp-1.9.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/jsoncpp -Dm644 LICENSE
popd
rm -rf jsoncpp-1.9.6
# rhash.
tar -xf ../sources/RHash-1.4.5.tar.gz
pushd RHash-1.4.5
./configure --prefix=/usr --sysconfdir=/etc --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
make
make -j1 install
make -j1 -C librhash install-lib-headers install-lib-shared install-so-link
install -t /usr/share/licenses/rhash -Dm644 COPYING
popd
rm -rf RHash-1.4.5
# CMake.
tar -xf ../sources/cmake-4.4.2.tar.gz
pushd cmake-4.4.2
sed -i 's/"lib64"/"lib"/' Modules/GNUInstallDirs.cmake
./bootstrap --prefix=/usr --parallel=$(nproc) --generator=Ninja --docdir=/share/doc/cmake --mandir=/share/man --system-libs --no-system-cppdap --sphinx-man
ninja
ninja install
install -t /usr/share/licenses/cmake -Dm644 LICENSE.rst
popd
rm -rf cmake-4.4.2
# brotli.
tar -xf ../sources/brotli-1.2.0.tar.gz
pushd brotli-1.2.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBROTLI_DISABLE_TESTS=TRUE -Wno-dev -G Ninja -B build
ninja -C build
python -m build -nw -o dist
ninja -C build install
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/brotli -Dm644 LICENSE
popd
rm -rf brotli-1.2.0
# c-ares.
tar -xf ../sources/c-ares-1.34.7.tar.gz
pushd c-ares-1.34.7
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/c-ares -Dm644 LICENSE.md
popd
rm -rf c-ares-1.34.7
# utfcpp.
tar -xf ../sources/utfcpp-4.1.1.tar.gz
pushd utfcpp-4.1.1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/utfcpp -Dm644 LICENSE
popd
rm -rf utfcpp-4.1.1
# fast-float.
tar -xf ../sources/fast_float-8.2.9.tar.gz
pushd fast_float-8.2.9
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fast-float -Dm644 LICENSE-{APACHE,BOOST,MIT}
popd
rm -rf fast_float-8.2.9
# simdutf.
tar -xf ../sources/simdutf-9.0.0.tar.gz
pushd simdutf-9.0.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -DSIMDUTF_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/simdutf -Dm644 LICENSE-{APACHE,MIT}
popd
rm -rf simdutf-9.0.0
# yyjson.
tar -xf ../sources/yyjson-0.12.0.tar.gz
pushd yyjson-0.12.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -DYYJSON_BUILD_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/yyjson -Dm644 LICENSE
popd
rm -rf yyjson-0.12.0
# JSON-C.
tar -xf ../sources/json-c-0.19.tar.gz
pushd json-c-0.19
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/json-c -Dm644 COPYING
popd
rm -rf json-c-0.19
# nlohmann-json.
tar -xf ../sources/nlohmann-json-3.11.3.tar.gz
pushd json-3.11.3
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DJSON_BuildTests=OFF -DJSON_MultipleHeaders=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/nlohmann-json -Dm644 LICENSE.MIT LICENSES/*.txt
popd
rm -rf json-3.11.3
# cryptsetup.
tar -xf ../sources/cryptsetup-2.8.6.tar.xz
pushd cryptsetup-2.8.6
./configure --prefix=/usr --sbindir=/usr/bin --disable-asciidoc --disable-ssh-token
make
make install
install -t /usr/share/licenses/cryptsetup -Dm644 COPYING docs/licenses/*
popd
rm -rf cryptsetup-2.8.6
# multipath-tools.
tar -xf ../sources/multipath-tools-0.14.3.tar.gz
pushd multipath-tools-0.14.3
make prefix=/usr bindir=/usr/bin etc_prefix= configfile=/etc/multipath.conf statedir=/etc/multipath LIB=lib
make prefix=/usr bindir=/usr/bin etc_prefix= configfile=/etc/multipath.conf statedir=/etc/multipath LIB=lib install
install -t /usr/share/licenses/multipath-tools -Dm644 COPYING
popd
rm -rf multipath-tools-0.14.3
# libtpms.
tar -xf ../sources/libtpms-0.10.2.tar.gz
pushd libtpms-0.10.2
patch -Np1 -i ../../patches/libtpms-0.10.2-glibc243.patch
./autogen.sh --prefix=/usr --with-openssl --with-tpm2
make
make install
rm -f /usr/lib/libtpms.a
install -t /usr/share/licenses/libtpms -Dm644 LICENSE
popd
rm -rf libtpms-0.10.2
# tpm2-tss.
tar -xf ../sources/tpm2-tss-4.2.0.tar.gz
pushd tpm2-tss-4.2.0
patch -Np1 -i ../../patches/tpm2-tss-4.2.0-hardcode-uid.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-runstatedir=/run --with-sysusersdir=/usr/lib/sysusers.d --with-tmpfilesdir=/usr/lib/tmpfiles.d --with-udevrulesprefix="60-" --disable-static
make
make install
install -t /usr/share/licenses/tpm2-tss -Dm644 LICENSE
popd
rm -rf tpm2-tss-4.2.0
# tpm2-tools.
tar -xf ../sources/tpm2-tools-5.8.tar.gz
pushd tpm2-tools-5.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/tpm2-tools -Dm644 docs/LICENSE
popd
rm -rf tpm2-tools-5.8
# Tcl.
tar -xf ../sources/tcl8.6.18-src.tar.gz
pushd tcl8.6.18/unix
rm -rf ../pkgs/sqlite3.53.0
./configure --prefix=/usr --mandir=/usr/share/man --disable-rpath
make
sed -e "s|$PWD|/usr/lib|" -e "s|${PWD/\/unix}|/usr/include|" -i tclConfig.sh
sed -e "s|$PWD/pkgs/tdbc1.1.13|/usr/lib/tdbc1.1.13|" -e "s|${PWD/\/unix}/pkgs/tdbc1.1.13/generic|/usr/include|" -e "s|${PWD/\/unix}/pkgs/tdbc1.1.13/library|/usr/lib/tcl8.6|" -e "s|${PWD/\/unix}/pkgs/tdbc1.1.13|/usr/include|" -i pkgs/tdbc1.1.13/tdbcConfig.sh
sed -e "s|$PWD/pkgs/itcl4.3.7|/usr/lib/itcl4.3.7|" -e "s|${PWD/\/unix}/pkgs/itcl4.3.7/generic|/usr/include|" -e "s|${PWD/\/unix}/pkgs/itcl4.3.7|/usr/include|" -i pkgs/itcl4.3.7/itclConfig.sh
make install install-private-headers
chmod 755 /usr/lib/libtcl8.6.so
ln -sf tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{,Tcl_}Thread.3
install -t /usr/share/licenses/tcl -Dm644 ../license.terms
popd
rm -rf tcl8.6.18
# SQLite.
tar -xf ../sources/sqlite-autoconf-3530300.tar.gz
pushd sqlite-autoconf-3530300
CPPFLAGS="$CPPFLAGS -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 -DSQLITE_ENABLE_DBSTAT_VTAB=1 -DSQLITE_SECURE_DELETE=1 -DSQLITE_ENABLE_STMTVTAB=1 -DSQLITE_ENABLE_STAT4=1 -DSQLITE_ENABLE_MATH_FUNCTIONS=1" ./configure --prefix=/usr --disable-static --fts4 --fts5 --rtree --icu-collations --with-icu-ldflags="-licui18n -licuuc -licudata"
make
make install
pushd tea
./configure --prefix=/usr --with-system-sqlite --override-sqlite-version=3.53.3
popd
make -C tea
make -C tea install
install -dm755 /usr/share/licenses/sqlite
cat > /usr/share/licenses/sqlite/LICENSE << "END"
The code and documentation of SQLite is dedicated to the public domain.
See <https://www.sqlite.org/copyright.html> for more information.
END
popd
rm -rf sqlite-autoconf-3530300
# libusb.
tar -xf ../sources/libusb-1.0.30.tar.bz2
pushd libusb-1.0.30
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libusb -Dm644 COPYING
popd
rm -rf libusb-1.0.30
# libmtp.
tar -xf ../sources/libmtp-1.1.22.tar.gz
pushd libmtp-1.1.22
./configure --prefix=/usr --disable-rpath --disable-static --with-udev=/usr/lib/udev
make
make install
install -t /usr/share/licenses/libmtp -Dm644 COPYING
popd
rm -rf libmtp-1.1.22
# libieee1284.
tar -xf ../sources/libieee1284-0.2.11-15-g882a598.tar.gz
pushd libieee1284-882a59871bd4c4fca58d01ba9fe87f15738a0d15
sed -i 's/0.2.11/0.2.11-15-g882a598/' configure.in
./bootstrap
./configure --prefix=/usr --mandir=/usr/share/man --disable-static --with-python
make -j1
make -j1 install
install -t /usr/share/licenses/libieee1284 -Dm644 COPYING
popd
rm -rf libieee1284-882a59871bd4c4fca58d01ba9fe87f15738a0d15
# libunistring.
tar -xf ../sources/libunistring-1.4.2.tar.xz
pushd libunistring-1.4.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libunistring -Dm644 COPYING COPYING.LIB
popd
rm -rf libunistring-1.4.2
# libidn2.
tar -xf ../sources/libidn2-2.3.8.tar.gz
pushd libidn2-2.3.8
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libidn2 -Dm644 COPYING COPYINGv2 COPYING.LESSERv3 COPYING.unicode
popd
rm -rf libidn2-2.3.8
# whois.
tar -xf ../sources/whois-5.6.6.tar.gz
pushd whois-5.6.6
sed 's|md+whois@linux.it|https://github.com/MassOS-Linux/MassOS/issues|' -i whois.c -i mkpasswd.c
make
make prefix=/usr install-whois
make prefix=/usr install-mkpasswd
make prefix=/usr install-pos
install -t /usr/share/licenses/whois -Dm644 COPYING
popd
rm -rf whois-5.6.6
# libpsl.
tar -xf ../sources/libpsl-0.22.0.tar.gz
pushd libpsl-0.22.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpsl -Dm644 COPYING
popd
rm -rf libpsl-0.22.0
# usbutils.
tar -xf ../sources/usbutils-019.tar.xz
pushd usbutils-019
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/usbutils -Dm644 LICENSES/*
popd
rm -rf usbutils-019
# pciutils.
tar -xf ../sources/pciutils-3.15.0.tar.xz
pushd pciutils-3.15.0
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes install install-lib
chmod 755 /usr/lib/libpci.so
install -t /usr/share/licenses/pciutils -Dm644 COPYING
popd
rm -rf pciutils-3.15.0
# pkcs11-helper.
tar -xf ../sources/pkcs11-helper-1.31.0.tar.bz2
pushd pkcs11-helper-1.31.0
patch -Np1 -i ../../patches/pkcs11-helper-1.31.0-openssl4.patch
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/pkcs11-helper -Dm644 COPYING COPYING.BSD COPYING.GPL
popd
rm -rf pkcs11-helper-1.31.0
# python-certifi.
tar -xf ../sources/python-certifi-2026.06.17.tar.gz
pushd python-certifi-2026.06.17
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/python-certifi -Dm644 LICENSE
popd
rm -rf python-certifi-2026.06.17
# libssh2.
tar -xf ../sources/libssh2-1.11.1.tar.xz
pushd libssh2-1.11.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libssh2 -Dm644 COPYING
popd
rm -rf libssh2-1.11.1
# Jansson.
tar -xf ../sources/jansson-2.15.1.tar.bz2
pushd jansson-2.15.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/jansson -Dm644 LICENSE
popd
rm -rf jansson-2.15.1
# nftables (rebuild with Jansson for JSON support).
tar -xf ../sources/nftables-1.1.1.tar.xz
pushd nftables-1.1.1
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-debug --with-json
make
make install
popd
rm -rf nftables-1.1.1
# libassuan.
tar -xf ../sources/libassuan-3.0.2.tar.bz2
pushd libassuan-3.0.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libassuan -Dm644 COPYING COPYING.LIB
popd
rm -rf libassuan-3.0.2
# Nettle.
tar -xf ../sources/nettle-3.10.2.tar.gz
pushd nettle-3.10.2
./configure --prefix=/usr --disable-static
make
make install
chmod 755 /usr/lib/lib{hogweed,nettle}.so
install -t /usr/share/licenses/nettle -Dm644 COPYINGv2 COPYINGv3 COPYING.LESSERv3
popd
rm -rf nettle-3.10.2
# GNUTLS.
tar -xf ../sources/gnutls-3.8.13.tar.xz
pushd gnutls-3.8.13
./configure --prefix=/usr --disable-rpath --disable-static --with-default-trust-store-pkcs11="pkcs11:" --enable-openssl-compatibility --enable-ssl3-support
make
make install
install -t /usr/share/licenses/gnutls -Dm644 COPYING{,.LESSERv2}
popd
rm -rf gnutls-3.8.13
# libngtcp2.
tar -xf ../sources/ngtcp2-1.22.1.tar.xz
pushd ngtcp2-1.22.1
./configure --prefix=/usr --disable-static --enable-lib-only --with-gnutls --with-libbrotlidec --with-libbrotlienc
make
make install
install -t /usr/share/licenses/libngtcp2 -Dm644 COPYING
popd
rm -rf ngtcp2-1.22.1
# libevent.
tar -xf ../sources/libevent-2.1.13-stable.tar.gz
pushd libevent-2.1.13-stable
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DEVENT__LIBRARY_TYPE=SHARED -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libevent -Dm644 LICENSE
popd
rm -rf libevent-2.1.13-stable
# libldap.
tar -xf ../sources/openldap-2.6.13.tgz
pushd openldap-2.6.13
patch -Np1 -i ../../patches/openldap-2.6.13-openssl4.patch
sed -i 's/$(uname -n)/massos/' build/mkversion
autoconf
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-dynamic --enable-versioning --disable-debug --disable-slapd --disable-static
make depend
make
make install
chmod 755 /usr/lib/libl{ber,dap}.so.2.*
install -t /usr/share/licenses/libldap -Dm644 COPYRIGHT LICENSE
popd
rm -rf openldap-2.6.13
# npth.
tar -xf ../sources/npth-1.8.tar.bz2
pushd npth-1.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/npth -Dm644 COPYING.LIB
popd
rm -rf npth-1.8
# libksba.
tar -xf ../sources/libksba-1.8.0.tar.bz2
pushd libksba-1.8.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libksba -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv3
popd
rm -rf libksba-1.8.0
# GNUPG.
tar -xf ../sources/gnupg-2.5.21.tar.bz2
pushd gnupg-2.5.21
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-g13
make
make install
install -t /usr/share/licenses/gnupg -Dm644 COPYING{,.CC0,.GPL2,.LGPL21,.LGPL3,.other}
popd
rm -rf gnupg-2.5.21
# krb5.
tar -xf ../sources/krb5-krb5-1.22.2-final.tar.gz
pushd krb5-krb5-1.22.2-final
patch -Np1 -i ../../patches/krb5-1.22.2-glibc243.patch
patch -Np1 -i ../../patches/krb5-1.22.2-autoconf273.patch
patch -Np1 -i ../../patches/krb5-1.22.2-openssl4.patch
pushd src
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var/lib --runstatedir=/run --sbindir=/usr/bin --disable-rpath --enable-dns-for-realm --with-system-et --with-system-ss --without-system-verto
make
make install
install -t /usr/share/licenses/krb5 -Dm644 ../NOTICE
popd; popd
rm -rf krb5-krb5-1.22.2-final
# libnfs.
tar -xf ../sources/libnfs-6.0.2.tar.gz
pushd libnfs-libnfs-6.0.2
patch -Np1 -i ../../patches/libnfs-6.0.2-gnutls.patch
patch -Np1 -i ../../patches/libnfs-6.0.2-glibc243.patch
./bootstrap
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libnfs -Dm644 COPYING LICENCE-BSD.txt LICENCE-GPL-3.txt LICENCE-LGPL-2.1.txt
popd
rm -rf libnfs-libnfs-6.0.2
# rtmpdump.
tar -xf ../sources/rtmpdump-2.4-105-g6f6bb13.tar.gz
pushd rtmpdump-6f6bb1353fc84f4cc37138baa99f586750028a01
make prefix=/usr sbindir=/usr/bin mandir=/usr/share/man
make prefix=/usr sbindir=/usr/bin mandir=/usr/share/man install
rm -f /usr/lib/librtmp.a
install -t /usr/share/licenses/rtmpdump -Dm644 COPYING
popd
rm -rf rtmpdump-6f6bb1353fc84f4cc37138baa99f586750028a01
# curl (rebuild to support more features).
tar -xf ../sources/curl-8.21.0.tar.xz
pushd curl-8.21.0
./configure --prefix=/usr --disable-static --disable-threaded-resolver --enable-ares --enable-httpsrr --with-openssl --with-libssh2 --with-gssapi --with-nghttp3 --with-ngtcp2 --with-ca-path=/etc/ssl/certs
make
make install
popd
rm -rf curl-8.21.0
# libnl.
tar -xf ../sources/libnl-3.11.0.tar.gz
pushd libnl-3.11.0
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libnl -Dm644 COPYING
popd
rm -rf libnl-3.11.0
# SWIG.
tar -xf ../sources/swig-4.4.1.tar.gz
pushd swig-4.4.1
./autogen.sh
./configure --prefix=/usr --without-maximum-compile-warnings
make
make install
install -t /usr/share/licenses/swig -Dm644 COPYRIGHT LICENSE LICENSE-GPL LICENSE-UNIVERSITIES
popd
rm -rf swig-4.4.1
# keyutils.
tar -xf ../sources/keyutils-1.6.3.tar.gz
pushd keyutils-1.6.3
make
make BINDIR=/usr/bin LIBDIR=/usr/lib SBINDIR=/usr/bin NO_ARLIB=1 install
install -t /usr/share/licenses/keyutils -Dm644 LICENCE.{L,}GPL
popd
rm -rf keyutils-1.6.3
# libnvme.
tar -xf ../sources/libnvme-1.16.2.tar.gz
pushd libnvme-1.16.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dlibdbus=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnvme -Dm644 COPYING
popd
rm -rf libnvme-1.16.2
# nvme-cli.
tar -xf ../sources/nvme-cli-2.16.tar.gz
pushd nvme-cli-2.16
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --buildtype=minsize -Ddocs=man -Ddocs-build=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/nvme-cli -Dm644 LICENSE
popd
rm -rf nvme-cli-2.16
# libcap-ng.
tar -xf ../sources/libcap-ng-0.8.5.tar.gz
pushd libcap-ng-0.8.5
./autogen.sh
./configure --prefix=/usr --disable-static --without-python --with-python3
make
make install
install -t /usr/share/licenses/libcap-ng -Dm644 COPYING{,.LIB}
popd
rm -rf libcap-ng-0.8.5
# smartmontools.
tar -xf ../sources/smartmontools-7.5.tar.gz
pushd smartmontools-7.5
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin
make
make install
systemctl enable smartd
install -t /usr/share/licenses/smartmontools -Dm644 COPYING
popd
rm -rf smartmontools-7.5
# OpenVPN.
tar -xf ../sources/openvpn-2.7.4.tar.gz
pushd openvpn-2.7.4
echo 'u openvpn 972 "OpenVPN" -' > /usr/lib/sysusers.d/openvpn.conf
systemd-sysusers
sed -i '/^CONFIGURE_DEFINES=/ s/set/env/g' configure.ac
autoreconf -fi
./configure --prefix=/usr --sbindir=/usr/bin --enable-pkcs11 --enable-plugins --enable-systemd --enable-x509-alt-username
make
make install
find contrib -type f -exec install -t /usr/share/openvpn -Dm644 {} ';'
chmod 755 /usr/share/openvpn/*.{sh,down,up}
cp -r sample/sample-config-files /usr/share/openvpn/examples
install -t /usr/share/licenses/openvpn -Dm644 COPYING COPYRIGHT.GPL
popd
rm -rf openvpn-2.7.4
# GPGME.
tar -xf ../sources/gpgme-2.1.2.tar.bz2
pushd gpgme-2.1.2
./configure --prefix=/usr --disable-gpg-test --disable-gpgsm-test
make
make install
install -t /usr/share/licenses/gpgme -Dm644 COPYING{,.LESSER} LICENSES
popd
rm -rf gpgme-2.1.2
# gpgmepp.
tar -xf ../sources/gpgmepp-2.1.0.tar.xz
pushd gpgmepp-2.1.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gpgmepp -Dm644 COPYING{,.L{ESSER,IB}}
popd
rm -rf gpgmepp-2.1.0
# gpgmepy.
tar -xf ../sources/gpgmepy-2.0.0.tar.bz2
pushd gpgmepy-2.0.0
sed -i 's/, "swig"//' pyproject.toml
./configure --prefix=/usr
mv src gpg
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/gpgmepy -Dm644 COPYING
popd
rm -rf gpgmepy-2.0.0
# Cyrus-SASL (rebuild to support krb5 and OpenLDAP).
tar -xf ../sources/cyrus-sasl-2.1.28.tar.gz
pushd cyrus-sasl-2.1.28
patch -Np1 -i ../../patches/cyrus-sasl-2.1.28-gcc15.patch
sed -i '/saslint/a #include <time.h>' lib/saslutil.c
sed -i '/plugin_common/a #include <time.h>' plugins/cram.c
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-ldap --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
popd
rm -rf cyrus-sasl-2.1.28
# libftdi.
tar -xf ../sources/libftdi1-1.5.tar.bz2
pushd libftdi1-1.5
patch -Np1 -i ../../patches/libftdi-1.5-fixes.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DFTDIPP=ON -DPYTHON_BINDINGS=ON -DLINK_PYTHON_LIBRARY=ON -DEXAMPLES=OFF -DSTATICLIBS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
sed 's|MODE="0664", GROUP="plugdev"|TAG+="uaccess"|g' packages/99-libftdi.rules > /usr/lib/udev/rules.d/69-libftdi.rules
install -t /usr/share/licenses/libftdi -Dm644 COPYING{.{GPL,LIB},-CMAKE-SCRIPTS} LICENSE
popd
rm -rf libftdi1-1.5
# libtirpc.
tar -xf ../sources/libtirpc-1.3.7.tar.bz2
pushd libtirpc-1.3.7
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libtirpc -Dm644 COPYING
popd
rm -rf libtirpc-1.3.7
# libnsl.
tar -xf ../sources/libnsl-2.0.1.tar.xz
pushd libnsl-2.0.1
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libnsl -Dm644 COPYING
popd
rm -rf libnsl-2.0.1
# Wget.
tar -xf ../sources/wget-1.25.0.tar.gz
pushd wget-1.25.0
CFLAGS="$CFLAGS -Wno-error=incompatible-pointer-types" ./configure --prefix=/usr --sysconfdir=/etc --disable-rpath --with-cares --with-metalink
make
make install
install -t /usr/share/licenses/wget -Dm644 COPYING
popd
rm -rf wget-1.25.0
# aria2.
tar -xf ../sources/aria2-1.37.0-42-g9e727358.tar.xz
pushd aria2-1.37.0-42-g9e727358
./configure --prefix=/usr --with-bashcompletiondir=/usr/share/bash-completion/completions --with-ca-bundle=/etc/pki/tls/certs/ca-bundle.crt --enable-libaria2 --with-libuv
make
make install
install -t /usr/share/licenses/aria2 -Dm644 COPYING
popd
rm -rf aria2-1.37.0-42-g9e727358
# Ruby.
tar -xf ../sources/ruby-4.0.5.tar.xz
pushd ruby-4.0.5
patch -Np1 -i ../../patches/ruby-4.0.5-openssl4.patch
./configure --prefix=/usr --enable-shared --without-baseruby --without-valgrind ac_cv_func_qsort_r=no
make
make capi
make install
install -t /usr/share/licenses/ruby -Dm644 COPYING
popd
rm -rf ruby-4.0.5
# asciidoctor.
tar -xf ../sources/asciidoctor-2.0.26.tar.gz
pushd asciidoctor-2.0.26
gem build asciidoctor.gemspec
gem install asciidoctor-2.0.26.gem
install -t /usr/share/licenses/asciidoctor -Dm644 LICENSE
popd
rm -rf asciidoctor-2.0.26
# Audit.
tar -xf ../sources/audit-userspace-4.0.3.tar.gz
pushd audit-userspace-4.0.3
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --enable-gssapi-krb5 --enable-systemd --with-libcap-ng
make
make install
install -dm0700 /var/log/audit
install -dm0750 /etc/audit/rules.d
systemctl enable auditd
install -t /usr/share/licenses/audit -Dm644 COPYING COPYING.LIB
popd
rm -rf audit-userspace-4.0.3
# AppArmor.
tar -xf ../sources/apparmor-v4.1.2.tar.bz2
pushd apparmor-v4.1.2
pushd libraries/libapparmor
./autogen.sh
./configure --prefix=/usr --sbindir=/usr/bin --with-perl --with-python --with-ruby
popd
make -C libraries/libapparmor
make -C changehat/pam_apparmor
make -C binutils
make -C parser
make -C profiles
make -C utils
make -C utils/vim
make -C libraries/libapparmor install
make -C changehat/pam_apparmor install
make -C binutils install
make -C parser -j1 install install-systemd
make -C profiles install
make -C utils install
rm -f /usr/lib/libapparmor.a
chmod 755 /usr/lib/perl5/*/vendor_perl/auto/LibAppArmor/LibAppArmor.so
mv /usr/lib/ruby/{site,vendor}_ruby/4.0.0/"$MBS_ARCH"-linux/LibAppArmor.so
sed -i 's|ADDITIONAL_PROFILE_DIR=|ADDITIONAL_PROFILE_DIR=/var/lib/snapd/apparmor/profiles|' /usr/lib/apparmor/rc.apparmor.functions
systemctl enable apparmor
install -t /usr/share/licenses/apparmor -Dm644 LICENSE libraries/libapparmor/COPYING.LGPL changehat/pam_apparmor/COPYING
popd
rm -rf apparmor-v4.1.2
# Linux-PAM (rebuild with newer version, and to support Audit).
tar -xf ../sources/Linux-PAM-1.7.2.tar.xz
pushd Linux-PAM-1.7.2
sed -e "s/'elinks'/'lynx'/" -e "s/'-no-numbering', '-no-references'/'-force-html', '-nonumbers', '-stdin'/" -i meson.build
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/linux-pam -Dm644 COPYING Copyright
popd
rm -rf Linux-PAM-1.7.2
# Shadow (rebuild to support systemd and Audit).
tar -xf ../sources/shadow-4.19.4.tar.xz
pushd shadow-4.19.4
patch -Np1 -i ../../patches/shadow-4.19.4-MassOS.patch
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-static --with-audit --with-bcrypt --with-group-name-max-length=32 --with-libcrack --with-yescrypt --without-libbsd
make
make exec_prefix=/usr pamdir= install
make -C man install-man
install -t /etc/pam.d -Dm644 pam.d/*
rm -f /etc/{limits,login.access}
popd
rm -rf shadow-4.19.4
# Sudo.
tar -xf ../sources/sudo-1.9.17p2.tar.gz
pushd sudo-1.9.17p2
patch -Np1 -i ../../patches/sudo-1.9.17p2-openssl4.patch
./configure --prefix=/usr --sbindir=/usr/bin --libexecdir=/usr/lib --with-linux-audit --with-secure-path --with-insults --with-all-insults --with-passwd-tries=5 --with-env-editor --with-passprompt="[sudo] password for %p: "
make
make install
sed -e '/pam_rootok.so/d' -e '/pam_wheel.so/d' /etc/pam.d/su > /etc/pam.d/sudo
sed -e 's|# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' -e 's|# Defaults secure_path|Defaults secure_path|' -e 's|/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin|/usr/local/bin:/usr/bin:/var/lib/flatpak/exports/bin:/snap/bin|' -i /etc/sudoers
sed -i '53i## Show astericks while typing the password.' /etc/sudoers
sed -i '54iDefaults pwfeedback' /etc/sudoers
sed -i '55i##' /etc/sudoers
install -t /usr/share/licenses/sudo -Dm644 LICENSE.md
popd
rm -rf sudo-1.9.17p2
# dracut.
tar -xf ../sources/dracut-112.tar.gz
pushd dracut-112
patch -Np1 -i ../../patches/dracut-111-simpledrmfix.patch
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --sbindir=/usr/bin --systemdsystemunitdir=/usr/lib/systemd/system --bashcompletiondir=/usr/share/bash-completion/completions --enable-dracut-cpio
make
make install
cat > /etc/dracut.conf.d/massos.conf << "END"
# Default dracut configuration file for MassOS.

# Compression to use for the initramfs.
# Zstd is faster than XZ, and only increases the initramfs size by ~3MiB.
compress="zstd"

# Make the initramfs reproducible.
# Note that this is not supported if you use bsdcpio as your cpio program.
reproducible="yes"

# A hostonly initramfs will only include drivers for the system it was made on.
# This reduces the size of the initramfs, but also impacts portability.
# You may not be able to boot the OS if you move the drive to another system.
# The hostonly mode is also incompatible with the live CD modules added below.
hostonly="no"

# These modules are required to support live CD booting.
add_dracutmodules+=" dmsquash-live overlayfs "

# These modules are unneeded for booting MassOS and would bloat the initramfs.
# Some of them also have dependencies outside the scope of MassOS.
# Remove them from the exclude list only if you know what you are doing.
omit_dracutmodules+=" biosdevname cifs connman dash dbus-broker fcoe fcoe-uefi hwdb iscsi kernel-modules-extra kernel-network-modules lunmask memstrack mksh multipath nbd network network-legacy network-manager nfs nvdimm nvmf qemu qemu-net rngd usrmount virtiofs "
END
install -t /usr/share/licenses/dracut -Dm644 COPYING
popd
rm -rf dracut-112
# Fcron.
tar -xf ../sources/fcron-ver3_4_0.tar.gz
pushd fcron-ver3_4_0
echo 'u fcron 971 "Fcron User" -' > /usr/lib/sysusers.d/fcron.conf
systemd-sysusers
autoconf
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --without-sendmail --with-piddir=/run --with-boot-install=no --with-editor=/usr/bin/nano --with-dsssl-dir=/usr/share/sgml/docbook/dsssl-stylesheets-1.79
make
make install
chmod 755 /usr/bin/fcron
for i in cron{,dyn,sighup,tab}; do ln -sf f$i /usr/bin/$i; done
for i in cron{dyn,tab}.1; do ln -sf f$i /usr/share/man/man1/$i; ln -sf f$i /usr/share/man/fr/man1/$i; done
ln -sf fcrontab.5 /usr/share/man/man5/crontab.5
ln -sf fcrontab.5 /usr/share/man/fr/man5/crontab.5
ln -sf fcron.8 /usr/share/man/man8/cron.8
ln -sf fcron.8 /usr/share/man/fr/man8/cron.8
install -dm754 /etc/cron.{hourly,daily,weekly,monthly}
cat > /var/spool/fcron/systab.orig << "END"
&bootrun 01 * * * * root run-parts /etc/cron.hourly
&bootrun 02 4 * * * root run-parts /etc/cron.daily
&bootrun 22 4 * * 0 root run-parts /etc/cron.weekly
&bootrun 42 4 1 * * root run-parts /etc/cron.monthly
END
fcrontab -z -u systab
systemctl enable fcron
install -t /usr/share/licenses/fcron -Dm644 doc/en/txt/gpl.txt
popd
rm -rf fcron-ver3_4_0
# lsof.
tar -xf ../sources/lsof-4.99.7.tar.gz
pushd lsof-4.99.7
./Configure linux -n
sed -i "s/cc/cc $CFLAGS/" Makefile
make LSOF_HOST=massos LSOF_SYSINFO=none
install -m755 lsof /usr/bin/lsof
install -m644 Lsof.8 /usr/share/man/man8/lsof.8
install -t /usr/share/licenses/lsof -Dm644 COPYING
popd
rm -rf lsof-4.99.7
# NSPR.
tar -xf ../sources/nspr-4.39.tar.gz
pushd nspr-4.39/nspr
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit
make
make install
rm -f /usr/lib/lib{nspr,plc,plds}4.a
rm -f /usr/bin/{compile-et.pl,prerr.properties}
install -t /usr/share/licenses/nspr -Dm644 LICENSE
popd
rm -rf nspr-4.39
# NSS.
tar -xf ../sources/nss-3.125.tar.gz
pushd nss-3.125/nss
sed -i "s|'disable_werror%': 0|'disable_werror%': 1|" coreconf/config.gypi
./build.sh --enable-libpkix --disable-tests --opt --system-nspr --system-sqlite
install -t /usr/lib -Dm755 ../dist/Release/lib/*.so
install -t /usr/lib -Dm644 ../dist/Release/lib/*.chk
install -t /usr/bin -Dm755 ../dist/Release/bin/{*util,shlibsign,signtool,signver,ssltap}
install -t /usr/share/man/man1 -Dm644 doc/nroff/{*util,signtool,signver,ssltap}.1
install -dm755 /usr/include/nss
cp -r ../dist/{public,private}/nss/* /usr/include/nss
sed pkg/pkg-config/nss.pc.in -e 's|%prefix%|/usr|g' -e 's|%libdir%|${prefix}/lib|g' -e 's|%exec_prefix%|${prefix}|g' -e 's|%includedir%|${prefix}/include/nss|g' -e "s|%NSPR_VERSION%|$(pkg-config --modversion nspr)|g" -e "s|%NSS_VERSION%|3.125.0|g" > /usr/lib/pkgconfig/nss.pc
sed pkg/pkg-config/nss-config.in -e 's|@prefix@|/usr|g' -e "s|@MOD_MAJOR_VERSION@|$(pkg-config --modversion nss | cut -d. -f1)|g" -e "s|@MOD_MINOR_VERSION@|$(pkg-config --modversion nss | cut -d. -f2)|g" -e "s|@MOD_PATCH_VERSION@|$(pkg-config --modversion nss | cut -d. -f3)|g" > /usr/bin/nss-config
chmod 755 /usr/bin/nss-config
ln -sf ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
install -t /usr/share/licenses/nss -Dm644 COPYING
popd
rm -rf nss-3.125
# Git.
tar -xf ../sources/git-2.55.0.tar.xz
pushd git-2.55.0
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --with-libpcre2
make all man
make perllibdir=/usr/lib/perl5/5.42/vendor_perl install install-man
install -t /usr/share/licenses/git -Dm644 COPYING LGPL-2.1
popd
rm -rf git-2.55.0
# Botan.
tar -xf ../sources/Botan-3.9.0.tar.xz
pushd Botan-3.9.0
CFLAGS="" CPPFLAGS="" CXXFLAGS="" LDFLAGS="" ./configure.py --prefix=/usr --optimize-for-size --disable-static-library --build-tool=ninja --distribution-info=MassOS --with-boost --with-bzip --with-lzma --with-sqlite3 --with-tpm2 --with-zlib --without-pdf --without-sphinx --with-os-feature=getrandom
ninja
ninja install
install -t /usr/share/licenses/botan -Dm644 license.txt
popd
rm -rf Botan-3.9.0
# rnp.
tar -xf ../sources/rnp-v0.18.0.tar.gz
pushd rnp-v0.18.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DDOWNLOAD_GTEST=OFF -DENABLE_COVERAGE=OFF -DENABLE_FUZZERS=OFF -DENABLE_SANITIZERS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/rnp -Dm644 LICENSE.md
popd
rm -rf rnp-v0.18.0
# snowball.
tar -xf ../sources/snowball-2.2.0.tar.gz
pushd snowball-2.2.0
patch -Np1 -i ../../patches/snowball-2.2.0-sharedlibrary.patch
make
install -t /usr/bin -Dm755 snowball stemwords
install -m755 libstemmer.so.0 /usr/lib/libstemmer.so.0.0.0
ln -sf libstemmer.so.0.0.0 /usr/lib/libstemmer.so.0
ln -sf libstemmer.so.0 /usr/lib/libstemmer.so
install -m644 include/libstemmer.h /usr/include/libstemmer.h
ldconfig
install -t /usr/share/licenses/snowball -Dm644 COPYING
popd
rm -rf snowball-2.2.0
# Pahole.
tar -xf ../sources/pahole-1.29.tar.gz
pushd pahole-1.29
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -D__LIB=lib -DLIBBPF_EMBEDDED=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
mv /usr/share/dwarves/runtime/python/ostra.py /usr/lib/$(readlink /usr/bin/python3)/ostra.py
rm -rf /usr/share/dwarves/runtime/python
install -t /usr/share/licenses/pahole -Dm644 COPYING
popd
rm -rf pahole-1.29
# DKMS.
tar -xf ../sources/dkms-3.2.1.tar.gz
pushd dkms-3.2.1
make MODDIR=/usr/lib/modules SBIN=/usr/bin KCONF=/tmp/.mbs_trash LIBDIR=/tmp/.mbs_trash install
sed -e 's|^# sign_file="/path/to/sign-file"$|sign_file="/usr/lib/modules/$kernelver/build/scripts/sign-file"|' -e 's|^# mok_signing_key=/var/lib/dkms/mok.key$|mok_signing_key=/var/lib/shim-signed/mok/MOK.priv|' -e 's|^# mok_certificate=/var/lib/dkms/mok.pub$|mok_certificate=/var/lib/shim-signed/mok/MOK.der|' -i /etc/dkms/framework.conf
install -t /usr/share/licenses/dkms -Dm644 COPYING
popd
rm -rf dkms-3.2.1
# xmlsec.
tar -xf ../sources/xmlsec-1.3.11.tar.gz
pushd xmlsec-1.3.11
autoreconf -fi
./configure --prefix=/usr --disable-static --disable-pedantic --disable-docs --enable-openssl3-engines
make
make install
install -t /usr/share/licenses/xmlsec -Dm644 Copyright
popd
rm -rf xmlsec-1.3.11
# GLib (initial build for circular dependency).
tar -xf ../sources/glib-2.88.2.tar.gz
pushd glib-2.88.2
tar -xf ../../sources/gvdb-2b42fc7.tar.gz -C subprojects/gvdb --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dglib_debug=disabled -Dintrospection=disabled -Dman-pages=enabled -Dtests=false -Dsysprof=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glib -Dm644 COPYING
popd
rm -rf glib-2.88.2
# GTK-Doc.
tar -xf ../sources/gtk-doc-1.36.0.tar.gz
pushd gtk-doc-1.36.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk-doc -Dm644 COPYING COPYING-DOCS
popd
rm -rf gtk-doc-1.36.0
# gnome-common.
tar -xf ../sources/gnome-common-3.18.0.tar.xz
pushd gnome-common-3.18.0
./configure --prefix=/usr --with-autoconf-archive
make
make install
install -t /usr/share/licenses/gnome-common -Dm644 COPYING
popd
rm -rf gnome-common-3.18.0
# libsigc++.
tar -xf ../sources/libsigc++-2.12.1.tar.xz
pushd libsigc++-2.12.1
sed -i "s/'system',//" meson.build
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsigc++ -Dm644 COPYING
popd
rm -rf libsigc++-2.12.1
# mm-common.
tar -xf ../sources/mm-common-1.0.6.tar.gz
pushd mm-common-1.0.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Duse-network=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/mm-common -Dm644 COPYING
popd
rm -rf mm-common-1.0.6
# GLibmm.
tar -xf ../sources/glibmm-2.66.9.tar.gz
pushd glibmm-2.66.9
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-documentation=false -Dmaintainer-mode=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glibmm -Dm644 COPYING COPYING.tools
popd
rm -rf glibmm-2.66.9
# gobject-introspection.
tar -xf ../sources/gobject-introspection-1.86.0.tar.gz
pushd gobject-introspection-1.86.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gobject-introspection -Dm644 COPYING{,.{GPL,LGPL}}
popd
rm -rf gobject-introspection-1.86.0
# GLib (rebuild to support gobject-introspection).
tar -xf ../sources/glib-2.88.2.tar.gz
pushd glib-2.88.2
tar -xf ../../sources/gvdb-2b42fc7.tar.gz -C subprojects/gvdb --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dglib_debug=disabled -Dintrospection=enabled -Dman-pages=enabled -Dtests=false -Dsysprof=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glib -Dm644 COPYING
popd
rm -rf glib-2.88.2
# shared-mime-info.
tar -xf ../sources/shared-mime-info-2.5.1.tar.gz
pushd shared-mime-info-2.5.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dupdate-mimedb=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/shared-mime-info -Dm644 COPYING
popd
rm -rf shared-mime-info-2.5.1
# desktop-file-utils.
tar -xf ../sources/desktop-file-utils-0.28.tar.xz
pushd desktop-file-utils-0.28
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -dm755 /usr/share/applications
update-desktop-database /usr/share/applications
install -t /usr/share/licenses/desktop-file-utils -Dm644 COPYING
popd
rm -rf desktop-file-utils-0.28
# Graphene.
tar -xf ../sources/graphene-1.10.8.tar.gz
pushd graphene-1.10.8
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false -Dinstalled_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/graphene -Dm644 LICENSE.txt
popd
rm -rf graphene-1.10.8
# LLVM / Clang / LLD / libc++ / libc++abi / compiler-rt / OpenMP.
tar -xf ../sources/llvm-project-22.1.8.src.tar.xz
pushd llvm-project-22.1.8.src
sed -i 's/utility/tool/' llvm/utils/FileCheck/CMakeLists.txt
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_DOCDIR=share/doc -DCMAKE_SKIP_INSTALL_RPATH=ON -DPACKAGE_VENDOR="MassOS" -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;openmp" -DLLVM_TARGETS_TO_BUILD="AArch64;AMDGPU;ARM;BPF;NVPTX;WebAssembly;X86" -DLLVM_HOST_TRIPLE="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" -DLLVM_BINUTILS_INCDIR=/usr/include -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_FFI=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_ZLIB=ON -DLLVM_ENABLE_ZSTD=ON -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_TESTS=OFF -DLLVM_USE_PERF=ON -DCLANG_LINK_CLANG_DYLIB=ON -DENABLE_LINKER_BUILD_ID=ON -DCLANG_CONFIG_FILE_SYSTEM_DIR=/etc/clang -DCLANG_DEFAULT_PIE_ON_LINUX=ON -DLIBCXX_INSTALL_LIBRARY_DIR=/usr/lib -DLIBCXXABI_INSTALL_LIBRARY_DIR=/usr/lib -DLIBCXXABI_USE_LLVM_UNWINDER=OFF -DCOMPILER_RT_USE_LIBCXX=OFF -DOPENMP_INSTALL_LIBDIR=lib -DLIBOMP_INSTALL_ALIASES=OFF -DLLVM_BUILD_DOCS=ON -DLLVM_ENABLE_SPHINX=ON -DSPHINX_WARNINGS_AS_ERRORS=OFF -Wno-dev -G Ninja -B build -S llvm
ninja -C build
ninja -C build install
install -dm755 /etc/clang
echo "-fstack-protector-strong" > /etc/clang/clang.cfg
echo "-fstack-protector-strong" > /etc/clang/clang++.cfg
sed -i 's/^complete/test ! -z "$ZSH_VERSION" || complete/' /usr/share/clang/bash-autocomplete.sh
ln -srf /usr/share/clang/bash-autocomplete.sh /etc/profile.d/clang-autocomplete.sh
install -t /usr/share/licenses/llvm -Dm644 LICENSE.TXT
install -t /usr/share/licenses/clang -Dm644 LICENSE.TXT
install -t /usr/share/licenses/lld -Dm644 LICENSE.TXT
install -t /usr/share/licenses/libc++ -Dm644 LICENSE.TXT
install -t /usr/share/licenses/libc++abi -Dm644 LICENSE.TXT
install -t /usr/share/licenses/compiler-rt -Dm644 LICENSE.TXT
install -t /usr/share/licenses/openmp -Dm644 LICENSE.TXT
popd
rm -rf llvm-project-22.1.8.src
# bpftool.
tar -xf ../sources/bpftool-7.6.0.tar.gz
tar -xf ../sources/libbpf-1.6.2.tar.gz -C bpftool-7.6.0/libbpf --strip-components=1
pushd bpftool-7.6.0/src
make all doc
make install doc-install prefix=/usr mandir=/usr/share/man
install -t /usr/share/licenses/bpftool -Dm644 ../LICENSE{,.BSD-2-Clause,.GPL-2.0}
popd
rm -rf bpftool-7.6.0
# volume-key.
tar -xf ../sources/volume_key-0.3.12.tar.gz
pushd volume_key-volume_key-0.3.12
autoreconf -fi
./configure --prefix=/usr --without-python
make
make install
install -t /usr/share/licenses/volume-key -Dm644 COPYING
popd
rm -rf volume_key-volume_key-0.3.12
# JSON-GLib.
tar -xf ../sources/json-glib-1.10.8.tar.gz
pushd json-glib-1.10.8
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dconformance=false -Dinstalled_tests=false -Dman=true -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/json-glib -Dm644 COPYING LICENSES/*
popd
rm -rf json-glib-1.10.8
# mandoc.
tar -xf ../sources/mandoc-1.14.6.tar.gz
pushd mandoc-1.14.6
./configure --prefix=/usr
make mandoc
install -m755 mandoc /usr/bin/mandoc
install -m644 mandoc.1 /usr/share/man/man1/mandoc.1
install -t /usr/share/licenses/mandoc -Dm644 LICENSE
popd
rm -rf mandoc-1.14.6
# efivar.
tar -xf ../sources/efivar-39.tar.gz
pushd efivar-39
make CFLAGS="$CFLAGS"
make LIBDIR=/usr/lib install
install -t /usr/share/licenses/efivar -Dm644 COPYING
popd
rm -rf efivar-39
# efibootmgr.
tar -xf ../sources/efibootmgr-18.tar.bz2
pushd efibootmgr-18
make libdir=/usr/lib sbindir=/usr/bin EFIDIR=massos EFI_LOADER="grub$MBS_ARCH_EFI.efi"
make libdir=/usr/lib sbindir=/usr/bin EFIDIR=massos EFI_LOADER="grub$MBS_ARCH_EFI.efi" install
install -t /usr/share/licenses/efibootmgr -Dm644 COPYING
popd
rm -rf efibootmgr-18
# libpng.
tar -xf ../sources/libpng-1.6.58.tar.xz
pushd libpng-1.6.58
patch -Np1 -i ../../patches/libpng-1.6.58-apng.patch
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpng -Dm644 LICENSE
popd
rm -rf libpng-1.6.58
# FreeType (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf ../sources/freetype-2.14.3.tar.xz
pushd freetype-2.14.3
patch -Np1 -i ../../patches/freetype-2.14.0-features.patch
./configure --prefix=/usr --enable-freetype-config --disable-static --without-harfbuzz
make
make install
install -t /usr/share/licenses/freetype -Dm644 LICENSE.TXT docs/GPLv2.TXT
popd
rm -rf freetype-2.14.3
# Graphite2 (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf ../sources/graphite2-1.3.14-121-g142e1bda.tar.gz
pushd graphite-142e1bda3439d2bd376bcac9c2b247c9532bacde
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/graphite2 -Dm644 COPYING LICENSE
popd
rm -rf graphite-142e1bda3439d2bd376bcac9c2b247c9532bacde
# HarfBuzz.
tar -xf ../sources/harfbuzz-14.2.1.tar.xz
pushd harfbuzz-14.2.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/harfbuzz -Dm644 COPYING
popd
rm -rf harfbuzz-14.2.1
# FreeType (rebuild to support HarfBuzz).
tar -xf ../sources/freetype-2.14.3.tar.xz
pushd freetype-2.14.3
patch -Np1 -i ../../patches/freetype-2.14.0-features.patch
./configure --prefix=/usr --enable-freetype-config --disable-static --with-harfbuzz
make
make install
popd
rm -rf freetype-2.14.3
# Graphite2 (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf ../sources/graphite2-1.3.14-121-g142e1bda.tar.gz
pushd graphite-142e1bda3439d2bd376bcac9c2b247c9532bacde
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
popd
rm -rf graphite-142e1bda3439d2bd376bcac9c2b247c9532bacde
# Woff2.
tar -xf ../sources/woff2-1.0.2.tar.gz
pushd woff2-1.0.2
patch -Np1 -i ../../patches/woff2-1.0.2-gcc15.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/woff2 -Dm644 LICENSE
popd
rm -rf woff2-1.0.2
# shim (Microsoft-signed version from another distro).
tar -xf ../sources/shim-signed-16.1-fedora-f45-7.tar.xz
pushd shim-signed-16.1-fedora-f45-7
install -t /usr/lib/shim -Dm644 fb"$MBS_ARCH_EFI".efi mm"$MBS_ARCH_EFI".efi shim"$MBS_ARCH_EFI".efi.signed
echo "shim$MBS_ARCH_EFI.efi,massos,,This is the boot entry for massos" | iconv -t UCS-2LE > /usr/lib/shim/BOOT"$MBS_ARCH_EFI_UPPER".CSV
install -dm755 /var/lib/shim-signed/mok
install -t /usr/share/licenses/shim -Dm644 COPYRIGHT
popd
rm -rf shim-signed-16.1-fedora-f45-7
# mokutil.
tar -xf ../sources/mokutil-0.7.2.tar.gz
pushd mokutil-0.7.2
./autogen.sh --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin
make
make install
install -t /usr/share/licenses/mokutil -Dm644 COPYING
popd
rm -rf mokutil-0.7.2
# Unifont.
tar -xf ../sources/unifont-17.0.03.tar.gz
install -dm755 /usr/share/fonts/unifont
gzip -cd unifont-17.0.03/font/precompiled/unifont-17.0.03.pcf.gz > /usr/share/fonts/unifont/unifont.pcf
install -t /usr/share/licenses/unifont -Dm644 unifont-17.0.03/COPYING
rm -rf unifont-17.0.03
# GRUB.
tar -xf ../sources/grub-2.14.tar.xz
pushd grub-2.14
patch -Np1 -i ../../patches/grub-2.14-reverts.patch
patch -Np1 -i ../../patches/grub-2.14-grubcfgfixes.patch
patch -Np1 -i ../../patches/grub-2.14-shim161fix.patch
patch -Np1 -i ../../patches/grub-2.14-installsignedimages.patch
autoreconf -fi
## Note that the Legacy BIOS target is only supported and thus built on x86_64.
mkdir -p build-pc; pushd build-pc
[ "$MBS_ARCH" != "x86_64" ] || CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" ../configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --with-platform=pc --target=i386 --enable-cache-stats --enable-device-mapper --enable-grub-mkfont --enable-grub-mount --disable-efiemu --disable-werror
popd
mkdir -p build-efi; pushd build-efi
CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" ../configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --with-platform=efi --enable-cache-stats --enable-device-mapper --enable-grub-mkfont --enable-grub-mount --disable-efiemu --disable-werror
popd
[ "$MBS_ARCH" != "x86_64" ] || make -C build-pc
make -C build-efi
make -C build-efi bashcompletiondir="/usr/share/bash-completion/completions" install
[ "$MBS_ARCH" != "x86_64" ] || make -C build-pc bashcompletiondir="/usr/share/bash-completion/completions" install
sed -i 's|${GRUB_DISTRIBUTOR} GNU/Linux|${GRUB_DISTRIBUTOR}|' /etc/grub.d/10_linux
sed -i "s|'uefi-firmware' {|'uefi-firmware' --class efi {|" /etc/grub.d/30_uefi-firmware
cat > /usr/share/grub/sbat.csv << "END"
sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md
grub,5,Free Software Foundation,grub,2.14,https://gnu.org/software/grub/
grub.massos,1,MassOS,grub,2.14,https://massos.org
END
## Generate GRUB EFI images that can be signed for UEFI secure boot.
## Please see 'keys/README.md' in the MassOS repo for detailed info about this.
cat > grub.cfg << "END"
insmod linux
insmod chain
insmod bli
insmod font
insmod gzio
insmod efi_gop
if [ "$grub_cpu" = "i386" -o "$grub_cpu" = "x86_64" ]; then
  insmod efi_uga
  insmod usbms
  insmod usb_keyboard
fi
set gfxpayload=keep
if loadfont (memdisk)/boot/grub/fonts/unicode.pf2; then
  insmod gfxterm
  set gfxmode=auto
  terminal_input console
  terminal_output gfxterm
fi
if [ "$grub_cpu" = "i386" ]; then
  set efi_suffix="ia32"
elif [ "$grub_cpu" = "x86_64" ]; then
  set efi_suffix="x64"
elif [ "$grub_cpu" = "arm64" ]; then
  set efi_suffix="aa64"
else
  set efi_suffix="$grub_cpu"
fi
END
cat > grub-normal.cfg << "END"
if [ -f "$cmdpath/mass$efi_suffix.cfg" ]; then
  configfile "$cmdpath/mass$efi_suffix.cfg"
else
  search --file --no-floppy --set=root "/EFI/massos/mass$efi_suffix.cfg"
  configfile "/EFI/massos/mass$efi_suffix.cfg"
fi
END
cat > grub-removable.cfg << "END"
if [ -f "$cmdpath/mass$efi_suffix.cfg" ]; then
  configfile "$cmdpath/mass$efi_suffix.cfg"
else
  search --file --no-floppy --set=root "/EFI/BOOT/mass$efi_suffix.cfg"
  configfile "/EFI/BOOT/mass$efi_suffix.cfg"
fi
END
cat > grub-livecd.cfg << "END"
search --file --no-floppy --set=root /THIS_IS_THE_MASSOS_LIVECD
configfile /grub.cfg
END
mkdir -p /boot/grub
install -dm755 /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed
cat grub{,-normal}.cfg > /boot/grub/grub.cfg
grub-mkstandalone -O "$MBS_ARCH_GRUB"-efi -d /usr/lib/grub/"$MBS_ARCH_GRUB"-efi -o /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed/grub"$MBS_ARCH_EFI".efi --modules="part_msdos part_gpt iso9660 ext2 btrfs fat ntfs exfat luks luks2" --sbat=/usr/share/grub/sbat.csv --compress=lzo /boot/grub/grub.cfg
cat grub{,-removable}.cfg > /boot/grub/grub.cfg
grub-mkstandalone -O "$MBS_ARCH_GRUB"-efi -d /usr/lib/grub/"$MBS_ARCH_GRUB"-efi -o /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed/gcd"$MBS_ARCH_EFI".efi --modules="part_msdos part_gpt iso9660 ext2 btrfs fat ntfs exfat luks luks2" --sbat=/usr/share/grub/sbat.csv --compress=lzo /boot/grub/grub.cfg
cat grub{,-livecd}.cfg > /boot/grub/grub.cfg
grub-mkstandalone -O "$MBS_ARCH_GRUB"-efi -d /usr/lib/grub/"$MBS_ARCH_GRUB"-efi -o /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed/glcd"$MBS_ARCH_EFI".efi --modules="part_msdos part_gpt iso9660 ext2 btrfs fat ntfs exfat luks luks2" --sbat=/usr/share/grub/sbat.csv --compress=lzo /boot/grub/grub.cfg
rm -f /boot/grub/grub.cfg
sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed/grub"$MBS_ARCH_EFI".efi
sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed/gcd"$MBS_ARCH_EFI".efi
sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed/glcd"$MBS_ARCH_EFI".efi
rm -f /usr/lib/grub/"$MBS_ARCH_GRUB"-efi-signed/g{rub,{,l}cd}"$MBS_ARCH_EFI".efi
rmdir /boot/grub 2>/dev/null || true
install -t /usr/share/licenses/grub -Dm644 COPYING
popd
rm -rf grub-2.14
# grub-theme-distro-massos.
install -dm755 /usr/share/grub/themes/distro-massos
tar -xf ../sources/grub-theme-distro-massos-002.tar.gz -C /usr/share/grub/themes/distro-massos --strip-components=1
install -t /usr/share/licenses/grub-theme-distro-massos -Dm644 /usr/share/grub/themes/distro-massos/LICENSE
# os-prober.
tar -xf ../sources/os-prober_1.84.tar.xz
pushd os-prober-1.84
patch -Np1 -i ../../patches/os-prober-1.84-massos-fallback.patch
gcc $CFLAGS newns.c -o newns $LDFLAGS
install -t /usr/bin -Dm755 os-prober linux-boot-prober
install -t /usr/lib/os-prober -Dm755 newns
install -t /usr/share/os-prober -Dm755 common.sh
for dir in os-probes{,/{mounted,init}} linux-boot-probes{,/mounted}; do install -t /usr/lib/$dir -Dm755 $dir/common/*; test ! -d $dir/x86 || cp -r $dir/x86/* /usr/lib/$dir; done
install -t /usr/lib/os-probes/mounted -Dm755 os-probes/mounted/powerpc/20macosx
install -dm755 /var/lib/os-prober
install -t /usr/share/licenses/os-prober -Dm644 debian/copyright
install -t /usr/share/licenses/os-prober /usr/share/licenses/systemd/LICENSE.GPL2
popd
rm -rf os-prober-1.84
# libatasmart.
tar -xf ../sources/libatasmart_0.19.orig.tar.xz
pushd libatasmart-0.19
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static
make
make install
install -t /usr/share/licenses/libatasmart -Dm644 LGPL
popd
rm -rf libatasmart-0.19
# libbytesize.
tar -xf ../sources/libbytesize-2.12.tar.gz
pushd libbytesize-2.12
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libbytesize -Dm644 LICENSE
popd
rm -rf libbytesize-2.12
# libblockdev.
tar -xf ../sources/libblockdev-3.5.0.tar.gz
pushd libblockdev-3.5.0
./configure --prefix=/usr --sysconfdir=/etc --with-python3 --without-nvdimm
make
make install
install -t /usr/share/licenses/libblockdev -Dm644 LICENSE
popd
rm -rf libblockdev-3.5.0
# libdaemon.
tar -xf ../sources/libdaemon_0.14.orig.tar.gz
pushd libdaemon-0.14
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static
make
make install
install -t /usr/share/licenses/libdaemon -Dm644 LICENSE
popd
rm -rf libdaemon-0.14
# libgudev.
tar -xf ../sources/libgudev-238.tar.gz
pushd libgudev-238
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libgudev -Dm644 COPYING
popd
rm -rf libgudev-238
# libmbim.
tar -xf ../sources/libmbim-1.34.0.tar.gz
pushd libmbim-1.34.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libmbim -Dm644 LICENSES/*
popd
rm -rf libmbim-1.34.0
# libqrtr-glib.
tar -xf ../sources/libqrtr-glib-1.2.2.tar.gz
pushd libqrtr-glib-1.2.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libqrtr-glib -Dm644 LICENSES/*
popd
rm -rf libqrtr-glib-1.2.2
# libqmi.
tar -xf ../sources/libqmi-1.38.0.tar.gz
pushd libqmi-1.38.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libqmi -Dm644 COPYING COPYING.LIB
popd
rm -rf libqmi-1.38.0
# libevdev.
tar -xf ../sources/libevdev-1.13.6.tar.xz
pushd libevdev-1.13.6
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --localstatedir=/var -Ddocumentation=disabled -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libevdev -Dm644 COPYING
popd
rm -rf libevdev-1.13.6
# evtest.
tar -xf ../sources/evtest-evtest-1.35.tar.gz
pushd evtest-evtest-1.35
./autogen.sh
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/evtest -Dm644 COPYING
popd
rm -rf evtest-evtest-1.35
# libwacom.
tar -xf ../sources/libwacom-2.19.0.tar.xz
pushd libwacom-2.19.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libwacom -Dm644 COPYING
popd
rm -rf libwacom-2.19.0
# mtdev.
tar -xf ../sources/mtdev-1.1.7.tar.bz2
pushd mtdev-1.1.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/mtdev -Dm644 COPYING
popd
rm -rf mtdev-1.1.7
# Wayland.
tar -xf ../sources/wayland-1.25.0.tar.xz
pushd wayland-1.25.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddocumentation=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/wayland -Dm644 COPYING
popd
rm -rf wayland-1.25.0
# wayland-protocols.
tar -xf ../sources/wayland-protocols-1.49.tar.xz
pushd wayland-protocols-1.49
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/wayland-protocols -Dm644 COPYING
popd
rm -rf wayland-protocols-1.49
# wlr-protocols.
tar -xf ../sources/wlr-protocols-107.tar.gz
pushd wlr-protocols-ffb89ac-ffb89ac790096f6e6272822c8d5df7d0cc6fcdfa
make install
install -dm755 /usr/share/licenses/wlr-protocols
cat > /usr/share/licenses/wlr-protocols/LICENSE << "END"
The license for each component in this package can be found in the component's
XML file in the directory '/usr/share/wlr-protocols/unstable/'.
END
popd
rm -rf wlr-protocols-ffb89ac-ffb89ac790096f6e6272822c8d5df7d0cc6fcdfa
# aspell.
tar -xf ../sources/aspell-0.60.8.2.tar.gz
pushd aspell-0.60.8.2
./configure --prefix=/usr
make
make install
ln -sfn aspell-0.60 /usr/lib/aspell
install -m755 scripts/ispell /usr/bin/
install -m755 scripts/spell /usr/bin/
install -t /usr/share/licenses/aspell -Dm644 COPYING
popd
rm -rf aspell-0.60.8.2
# aspell-en.
tar -xf ../sources/aspell6-en-2020.12.07-0.tar.bz2
pushd aspell6-en-2020.12.07-0
./configure
make
make install
popd
rm -rf aspell6-en-2020.12.07-0
# hunspell / hunspell-en.
tar -xf ../sources/hunspell-1.7.2.tar.gz
pushd hunspell-1.7.2
for f in AU CA GB US; do unzip -q ../../sources/hunspell-en_$f-large-2020.12.07.zip; mv en_$f{-large,}.aff; mv en_$f{-large,}.dic; sed -i 's/SET UTF8/SET UTF-8/g' en_$f.aff; done
./configure --prefix=/usr --disable-static --with-readline --with-ui
make
make install
install -t /usr/share/hunspell -Dm644 en_{AU,CA,GB,US}.{aff,dic}
for l in AG BS BW BZ DK GH HK IE IN JM NA NG NZ SG TT ZA ZW; do ln -sf en_GB.aff /usr/share/hunspell/en_$l.aff; ln -sf en_GB.dic /usr/share/hunspell/en_$l.dic; done
install -t /usr/share/licenses/hunspell -Dm644 COPYING{,.LESSER,.MPL}
install -t /usr/share/licenses/hunspell-en -Dm644 COPYING{,.LESSER,.MPL}
popd
rm -rf hunspell-1.7.2
# Enchant.
tar -xf ../sources/enchant-2.8.19.tar.gz
pushd enchant-2.8.19
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/enchant -Dm644 COPYING.LIB
popd
rm -rf enchant-2.8.19
# Fontconfig.
tar -xf ../sources/fontconfig-2.18.2.tar.bz2
pushd fontconfig-2.18.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddoc-pdf=disabled -Diconv=enabled -Dtests=disabled
ninja -C build
ninja -C build install
rm -f /usr/lib/libfontconfig.a
install -t /usr/share/licenses/fontconfig -Dm644 COPYING
popd
rm -rf fontconfig-2.18.2
# Fribidi.
tar -xf ../sources/fribidi-1.0.16.tar.xz
pushd fribidi-1.0.16
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fribidi -Dm644 COPYING
popd
rm -rf fribidi-1.0.16
# giflib.
tar -xf ../sources/giflib-6.1.3.tar.gz
pushd giflib-6.1.3
make
make PREFIX=/usr install
rm -f /usr/lib/libgif.a
install -t /usr/share/licenses/giflib -Dm644 COPYING
popd
rm -rf giflib-6.1.3
# libexif.
tar -xf ../sources/libexif-0.6.26.tar.bz2
pushd libexif-0.6.26
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libexif -Dm644 COPYING
popd
rm -rf libexif-0.6.26
# lolcat.
tar -xf ../sources/lolcat-1.5.tar.gz
pushd lolcat-1.5
make CFLAGS="$CFLAGS"
install -t /usr/bin -Dm755 censor lolcat
install -t /usr/share/licenses/lolcat -Dm644 LICENSE
popd
rm -rf lolcat-1.5
# NASM.
tar -xf ../sources/nasm-3.02.tar.xz
pushd nasm-3.02
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/nasm -Dm644 LICENSE
popd
rm -rf nasm-3.02
# libjpeg-turbo.
tar -xf ../sources/libjpeg-turbo-3.2.0.tar.gz
pushd libjpeg-turbo-3.2.0
patch -Np1 -i ../../patches/libjpeg-turbo-3.2.0-upstreamfix.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib -DCMAKE_SKIP_INSTALL_RPATH=TRUE -DENABLE_STATIC=FALSE -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libjpeg-turbo -Dm644 LICENSE.md README.ijg
popd
rm -rf libjpeg-turbo-3.2.0
# libgphoto2
tar -xf ../sources/libgphoto2-2.5.31.tar.xz
pushd libgphoto2-2.5.31
./configure --prefix=/usr --disable-rpath
make
make install
install -t /usr/share/licenses/libgphoto2 -Dm644 COPYING
popd
rm -rf libgphoto2-2.5.31
# Pixman.
tar -xf ../sources/pixman-pixman-0.46.4.tar.bz2
pushd pixman-pixman-0.46.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pixman -Dm644 COPYING
popd
rm -rf pixman-pixman-0.46.4
# Qpdf.
tar -xf ../sources/qpdf-12.3.2.tar.gz
pushd qpdf-12.3.2
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -DINSTALL_EXAMPLES=OFF -DREQUIRE_CRYPTO_GNUTLS=OFF -DREQUIRE_CRYPTO_OPENSSL=ON -DUSE_IMPLICIT_CRYPTO=OFF -DDEFAULT_CRYPTO=openssl -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/bash-completion/completions -Dm644 completions/bash/qpdf
install -t /usr/share/zsh/site-functions -Dm644 completions/zsh/_qpdf
install -t /usr/share/licenses/qpdf -Dm644 Artistic-2.0 LICENSE.txt NOTICE.md
popd
rm -rf qpdf-12.3.2
# qrencode.
tar -xf ../sources/qrencode-4.1.1.tar.gz
pushd libqrencode-4.1.1
./autogen.sh
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/qrencode -Dm644 COPYING
popd
rm -rf libqrencode-4.1.1
# libsass.
tar -xf ../sources/libsass-3.6.6.tar.gz
pushd libsass-3.6.6
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libsass -Dm644 COPYING LICENSE
popd
rm -rf libsass-3.6.6
# sassc.
tar -xf ../sources/sassc-3.6.2.tar.gz
pushd sassc-3.6.2
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sassc -Dm644 LICENSE
popd
rm -rf sassc-3.6.2
# ISO-Codes.
tar -xf ../sources/iso-codes-v4.20.1.tar.bz2
pushd iso-codes-v4.20.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/iso-codes -Dm644 LICENSES/*
popd
rm -rf iso-codes-v4.20.1
# xdg-user-dirs.
tar -xf ../sources/xdg-user-dirs-0.20.tar.xz
pushd xdg-user-dirs-0.20
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xdg-user-dirs -Dm644 COPYING
popd
rm -rf xdg-user-dirs-0.20
# LSB-Tools.
tar -xf ../sources/LSB-Tools-0.12.tar.gz
pushd LSB-Tools-0.12
make
make install
rm -f /usr/bin/{lsbinstall,install_initd,remove_initd}
install -t /usr/share/licenses/lsb-tools -Dm644 LICENSE
popd
rm -rf LSB-Tools-0.12
# 7zip (now provides p7zip).
tar -xf ../sources/7zip-26.01.tar.gz
pushd 7zip-26.01
sed -i 's/-Werror//' CPP/7zip/7zip_gcc.mak
make -C CPP/7zip/Bundles/Alone -f ../../cmpl_gcc.mak
make -C CPP/7zip/Bundles/Alone7z -f ../../cmpl_gcc.mak
make -C CPP/7zip/Bundles/Format7zF -f ../../cmpl_gcc.mak
make -C CPP/7zip/Bundles/SFXCon -f ../../cmpl_gcc.mak
make -C CPP/7zip/UI/Console -f ../../cmpl_gcc.mak
install -t /usr/lib/7zip -Dm755 CPP/7zip/Bundles/Alone/b/g/7za
install -t /usr/lib/7zip -Dm755 CPP/7zip/Bundles/Alone7z/b/g/7zr
install -t /usr/lib/7zip -Dm755 CPP/7zip/Bundles/Format7zF/b/g/7z.so
install -t /usr/lib/7zip -Dm755 CPP/7zip/UI/Console/b/g/7z
for e in 7z{,a,r}; do cat > /usr/bin/$e << END
#!/bin/sh
exec /usr/lib/7zip/$e "\$@"
END
chmod 755 /usr/bin/$e; done
install -t /usr/share/licenses/7zip -Dm644 DOC/License.txt
ln -sf 7zip /usr/share/licenses/p7zip
popd
rm -rf 7zip-26.01
# slang.
tar -xf ../sources/slang-2.3.3.tar.bz2
pushd slang-2.3.3
./configure --prefix=/usr --sysconfdir=/etc --with-readline=gnu
make -j1
make -j1 install_doc_dir=/usr/share/doc/slang SLSH_DOC_DIR=/usr/share/doc/slang/slsh install-all
chmod 755 /usr/lib/libslang.so.2.3.3 /usr/lib/slang/v2/modules/*.so
rm -f /usr/lib/libslang.a
install -t /usr/share/licenses/slang -Dm644 COPYING
popd
rm -rf slang-2.3.3
# BIND Utils.
tar -xf ../sources/bind-9.20.23.tar.xz
pushd bind-9.20.23
./configure --prefix=/usr --with-json-c --with-libidn2 --with-libxml2 --with-lmdb --with-openssl
make -C lib/isc
make -C lib/dns
make -C lib/ns
make -C lib/isccfg
make -C lib/isccc
make -C bin/dig
make -C bin/nsupdate
make -C bin/rndc
make -C doc
make -C lib/isc install
make -C lib/dns install
make -C lib/ns install
make -C lib/isccfg install
make -C lib/isccc install
make -C bin/dig install
make -C bin/nsupdate install
make -C bin/rndc install
install -t /usr/share/man/man1 -Dm644 doc/man/{dig,host,nslookup,nsupdate}.1
install -t /usr/share/licenses/bind-utils -Dm644 COPYRIGHT LICENSE
popd
rm -rf bind-9.20.23
# dhcpcd.
tar -xf ../sources/dhcpcd-10.2.3.tar.xz
pushd dhcpcd-10.2.3
echo 'u dhcpcd 970 "dhcpcd PrivSep" /var/lib/dhcpcd' > /usr/lib/sysusers.d/dhcpcd.conf
systemd-sysusers
install -o dhcpcd -g dhcpcd -dm700 /var/lib/dhcpcd
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --libexecdir=/usr/lib/dhcpcd --runstatedir=/run --dbdir=/var/lib/dhcpcd --privsepuser=dhcpcd
make
make install
rm -f /usr/lib/dhcpcd/dhcpcd-hooks/30-hostname
install -t /usr/share/licenses/dhcpcd -Dm644 LICENSE
popd
rm -rf dhcpcd-10.2.3
# xdg-utils.
tar -xf ../sources/xdg-utils-1.1.3.tar.gz
pushd xdg-utils-1.1.3
sed -i 's/egrep/grep -E/' scripts/xdg-open.in
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/xdg-utils -Dm644 LICENSE
popd
rm -rf xdg-utils-1.1.3
# iw.
tar -xf ../sources/iw-6.17.tar.gz
pushd iw-6.17
make
make SBINDIR=/usr/bin install
install -t /usr/share/licenses/iw -Dm644 COPYING
popd
rm -rf iw-6.17
# wpa_supplicant.
tar -xf ../sources/wpa_supplicant-2.11.tar.gz
pushd wpa_supplicant-2.11
patch -Np1 -i ../../patches/wpa_supplicant-2.11-miscfixes.patch
patch -Np1 -i ../../patches/wpa_supplicant-2.11-openssl4.patch
pushd wpa_supplicant
cp ../../../extras/build-configs/wpa-supplicant-config .config
make BINDIR=/usr/bin LIBDIR=/usr/lib
install -t /usr/bin -Dm755 wpa_{cli,passphrase,supplicant}
install -t /usr/share/man/man5 -Dm644 doc/docbook/wpa_supplicant.conf.5
install -t /usr/share/man/man8 -Dm644 doc/docbook/wpa_{cli,passphrase,supplicant}.8
install -t /usr/lib/systemd/system -Dm644 systemd/wpa_supplicant{,@,-nl80211@,-wired@}.service
install -t /usr/share/dbus-1/system-services -Dm644 dbus/fi.w1.wpa_supplicant1.service
install -Dm644 dbus/dbus-wpa_supplicant.conf /etc/dbus-1/system.d/wpa_supplicant.conf
install -t /usr/share/licenses/wpa-supplicant -Dm644 ../COPYING ../README
popd; popd
rm -rf wpa_supplicant-2.11
# wireless-tools.
tar -xf ../sources/wireless_tools.30.pre9.tar.gz
pushd wireless_tools.30
sed -i '/BUILD_STATIC =/d' Makefile
make CFLAGS="$CFLAGS -I."
make INSTALL_DIR=/usr/bin INSTALL_LIB=/usr/lib INSTALL_INC=/usr/include INSTALL_MAN=/usr/share/man install
install -t /usr/share/licenses/wireless-tools -Dm644 COPYING
popd
rm -rf wireless_tools.30
# fmt.
tar -xf ../sources/fmt-12.2.0.tar.gz
pushd fmt-12.2.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DFMT_TEST=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fmt -Dm644 LICENSE
popd
rm -rf fmt-12.2.0
# libzip.
tar -xf ../sources/libzip-1.11.4.tar.xz
pushd libzip-1.11.4
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_REGRESS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libzip -Dm644 LICENSE
popd
rm -rf libzip-1.11.4
# dmg2img.
tar -xf ../sources/dmg2img_1.6.7.orig.tar.gz
pushd dmg2img-1.6.7
patch -Np1 -i ../../patches/dmg2img-1.6.7-openssl.patch
make PREFIX=/usr CFLAGS="$CFLAGS"
install -t /usr/bin -Dm755 dmg2img vfdecrypt
install -t /usr/share/licenses/dmg2img -Dm644 COPYING
popd
rm -rf dmg2img-1.6.7
# libcbor.
tar -xf ../sources/libcbor-0.12.0.tar.gz
pushd libcbor-0.12.0
patch -Np1 -i ../../patches/libcbor-0.12.0-cmake400.patch
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DWITH_EXAMPLES=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libcbor -Dm644 LICENSE.md
popd
rm -rf libcbor-0.12.0
# libfido2.
tar -xf ../sources/libfido2-1.17.0.tar.gz
pushd libfido2-1.17.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_EXAMPLES=OFF -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libfido2 -Dm644 LICENSE
popd
rm -rf libfido2-1.17.0
# libsysprof-capture.
tar -xf ../sources/sysprof-50.0.tar.gz
pushd sysprof-50.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dgtk=false -Dhelp=false -Dlibsysprof=false -Dsysprofd=none -Dtests=false -Dtools=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsysprof-capture -Dm644 COPYING{,.gpl-2}
popd
rm -rf sysprof-50.0
# util-macros.
tar -xf ../sources/util-macros-1.20.2.tar.xz
pushd util-macros-1.20.2
./configure --prefix=/usr
make install
install -t /usr/share/licenses/util-macros -Dm644 COPYING
popd
rm -rf util-macros-1.20.2
# xorgproto.
tar -xf ../sources/xorgproto-2025.1.tar.xz
pushd xorgproto-2025.1
meson setup build --prefix=/usr -Dlegacy=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xorgproto -Dm644 COPYING*
popd
rm -rf xorgproto-2025.1
# libXau.
tar -xf ../sources/libXau-1.0.12.tar.xz
pushd libXau-1.0.12
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxau -Dm644 COPYING
popd
rm -rf libXau-1.0.12
# libXdmcp.
tar -xf ../sources/libXdmcp-1.1.5.tar.xz
pushd libXdmcp-1.1.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxdmcp -Dm644 COPYING
popd
rm -rf libXdmcp-1.1.5
# xcb-proto.
tar -xf ../sources/xcb-proto-1.17.0.tar.xz
pushd xcb-proto-1.17.0
./configure --prefix=/usr
make install
install -t /usr/share/licenses/xcb-proto -Dm644 COPYING
popd
rm -rf xcb-proto-1.17.0
# libxcb.
tar -xf ../sources/libxcb-1.17.0.tar.xz
pushd libxcb-1.17.0
./configure --prefix=/usr --disable-static --without-doxygen
make
make install
install -t /usr/share/licenses/libxcb -Dm644 COPYING
popd
rm -rf libxcb-1.17.0
# xtrans.
tar -xf ../sources/xtrans-1.6.0.tar.xz
pushd xtrans-1.6.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xtrans -Dm644 COPYING
popd
rm -rf xtrans-1.6.0
# font-util.
tar -xf ../sources/font-util-1.4.2.tar.xz
pushd font-util-1.4.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/font-util -Dm644 COPYING
popd
rm -rf font-util-1.4.2
# libX11.
tar -xf ../sources/libX11-1.8.13.tar.xz
pushd libX11-1.8.13
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libx11 -Dm644 COPYING
popd
rm -rf libX11-1.8.13
# libXext.
tar -xf ../sources/libXext-1.3.7.tar.xz
pushd libXext-1.3.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxext -Dm644 COPYING
popd
rm -rf libXext-1.3.7
# libFS.
tar -xf ../sources/libFS-1.0.10.tar.xz
pushd libFS-1.0.10
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libfs -Dm644 COPYING
popd
rm -rf libFS-1.0.10
# libICE.
tar -xf ../sources/libICE-1.1.2.tar.xz
pushd libICE-1.1.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libice -Dm644 COPYING
popd
rm -rf libICE-1.1.2
# libSM.
tar -xf ../sources/libSM-1.2.6.tar.xz
pushd libSM-1.2.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libsm -Dm644 COPYING
popd
rm -rf libSM-1.2.6
# libXScrnSaver.
tar -xf ../sources/libXScrnSaver-1.2.5.tar.xz
pushd libXScrnSaver-1.2.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxscrnsaver -Dm644 COPYING
popd
rm -rf libXScrnSaver-1.2.5
# libXt.
tar -xf ../sources/libXt-1.3.1.tar.xz
pushd libXt-1.3.1
./configure --prefix=/usr --sysconfdir=/etc --disable-static --with-appdefaultdir=/etc/X11/app-defaults
make
make install
install -t /usr/share/licenses/libxt -Dm644 COPYING
popd
rm -rf libXt-1.3.1
# libXmu.
tar -xf ../sources/libXmu-1.3.1.tar.xz
pushd libXmu-1.3.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxmu -Dm644 COPYING
popd
rm -rf libXmu-1.3.1
# libXpm.
tar -xf ../sources/libXpm-3.5.19.tar.xz
pushd libXpm-3.5.19
./configure --prefix=/usr --sysconfdir=/etc --disable-static --disable-open-zfile
make
make install
install -t /usr/share/licenses/libxpm -Dm644 COPYING
popd
rm -rf libXpm-3.5.19
# libXaw.
tar -xf ../sources/libXaw-1.0.16.tar.xz
pushd libXaw-1.0.16
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxaw -Dm644 COPYING
popd
rm -rf libXaw-1.0.16
# libXfixes.
tar -xf ../sources/libXfixes-6.0.2.tar.xz
pushd libXfixes-6.0.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxfixes -Dm644 COPYING
popd
rm -rf libXfixes-6.0.2
# libXcomposite.
tar -xf ../sources/libXcomposite-0.4.7.tar.xz
pushd libXcomposite-0.4.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxcomposite -Dm644 COPYING
popd
rm -rf libXcomposite-0.4.7
# libXrender.
tar -xf ../sources/libXrender-0.9.12.tar.xz
pushd libXrender-0.9.12
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxrender -Dm644 COPYING
popd
rm -rf libXrender-0.9.12
# libXcursor.
tar -xf ../sources/libXcursor-1.2.3.tar.xz
pushd libXcursor-1.2.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxcursor -Dm644 COPYING
popd
rm -rf libXcursor-1.2.3
# libXdamage.
tar -xf ../sources/libXdamage-1.1.7.tar.xz
pushd libXdamage-1.1.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxdamage -Dm644 COPYING
popd
rm -rf libXdamage-1.1.7
# libXi.
tar -xf ../sources/libXi-1.8.3.tar.xz
pushd libXi-1.8.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxi -Dm644 COPYING
popd
rm -rf libXi-1.8.3
# libXinerama.
tar -xf ../sources/libXinerama-1.1.6.tar.xz
pushd libXinerama-1.1.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxinerama -Dm644 COPYING
popd
rm -rf libXinerama-1.1.6
# libXrandr.
tar -xf ../sources/libXrandr-1.5.5.tar.xz
pushd libXrandr-1.5.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxrandr -Dm644 COPYING
popd
rm -rf libXrandr-1.5.5
# libXpresent.
tar -xf ../sources/libXpresent-1.0.2.tar.xz
pushd libXpresent-1.0.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxpresent -Dm644 COPYING
popd
rm -rf libXpresent-1.0.2
# libXres.
tar -xf ../sources/libXres-1.2.3.tar.xz
pushd libXres-1.2.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxres -Dm644 COPYING
popd
rm -rf libXres-1.2.3
# libXtst.
tar -xf ../sources/libXtst-1.2.5.tar.xz
pushd libXtst-1.2.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxtst -Dm644 COPYING
popd
rm -rf libXtst-1.2.5
# libXv.
tar -xf ../sources/libXv-1.0.13.tar.xz
pushd libXv-1.0.13
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxv -Dm644 COPYING
popd
rm -rf libXv-1.0.13
# libXvMC.
tar -xf ../sources/libXvMC-1.0.15.tar.xz
pushd libXvMC-1.0.15
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxvmc -Dm644 COPYING
popd
rm -rf libXvMC-1.0.15
# libXxf86dga.
tar -xf ../sources/libXxf86dga-1.1.7.tar.xz
pushd libXxf86dga-1.1.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxxf86dga -Dm644 COPYING
popd
rm -rf libXxf86dga-1.1.7
# libXxf86vm.
tar -xf ../sources/libXxf86vm-1.1.7.tar.xz
pushd libXxf86vm-1.1.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxxf86vm -Dm644 COPYING
popd
rm -rf libXxf86vm-1.1.7
# libxkbfile.
tar -xf ../sources/libxkbfile-1.2.0.tar.xz
pushd libxkbfile-1.2.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libxkbfile -Dm644 COPYING
popd
rm -rf libxkbfile-1.2.0
# libxshmfence.
tar -xf ../sources/libxshmfence-1.3.3.tar.xz
pushd libxshmfence-1.3.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxshmfence -Dm644 COPYING
popd
rm -rf libxshmfence-1.3.3
# libfontenc.
tar -xf ../sources/libfontenc-1.1.9.tar.xz
pushd libfontenc-1.1.9
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libfontenc -Dm644 COPYING
popd
rm -rf libfontenc-1.1.9
# libXfont2.
tar -xf ../sources/libXfont2-2.0.8.tar.xz
pushd libXfont2-2.0.8
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxfont2 -Dm644 COPYING
popd
rm -rf libXfont2-2.0.8
# libXft.
tar -xf ../sources/libXft-2.3.9.tar.xz
pushd libXft-2.3.9
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxft -Dm644 COPYING
popd
rm -rf libXft-2.3.9
# libdmx.
tar -xf ../sources/libdmx-1.1.5.tar.xz
pushd libdmx-1.1.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdmx -Dm644 COPYING
popd
rm -rf libdmx-1.1.5
# libpciaccess.
tar -xf ../sources/libpciaccess-0.19.tar.xz
pushd libpciaccess-0.19
meson setup build --prefix=/usr --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libpciaccess -Dm644 COPYING
popd
rm -rf libpciaccess-0.19
# xcb-util.
tar -xf ../sources/xcb-util-0.4.1.tar.xz
pushd xcb-util-0.4.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util -Dm644 COPYING
popd
rm -rf xcb-util-0.4.1
# xcb-util-image.
tar -xf ../sources/xcb-util-image-0.4.1.tar.xz
pushd xcb-util-image-0.4.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-image -Dm644 COPYING
popd
rm -rf xcb-util-image-0.4.1
# xcb-util-keysyms.
tar -xf ../sources/xcb-util-keysyms-0.4.1.tar.xz
pushd xcb-util-keysyms-0.4.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-keysyms -Dm644 COPYING
popd
rm -rf xcb-util-keysyms-0.4.1
# xcb-util-renderutil.
tar -xf ../sources/xcb-util-renderutil-0.3.10.tar.xz
pushd xcb-util-renderutil-0.3.10
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-renderutil -Dm644 COPYING
popd
rm -rf xcb-util-renderutil-0.3.10
# xcb-util-wm.
tar -xf ../sources/xcb-util-wm-0.4.2.tar.xz
pushd xcb-util-wm-0.4.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-wm -Dm644 COPYING
popd
rm -rf xcb-util-wm-0.4.2
# xcb-util-cursor.
tar -xf ../sources/xcb-util-cursor-0.1.5.tar.xz
pushd xcb-util-cursor-0.1.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-cursor -Dm644 COPYING
popd
rm -rf xcb-util-cursor-0.1.5
# xcb-util-xrm.
tar -xf ../sources/xcb-util-xrm-1.3.tar.bz2
pushd xcb-util-xrm-1.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-xrm -Dm644 COPYING
popd
rm -rf xcb-util-xrm-1.3
# xcb-util-errors.
tar -xf ../sources/xcb-util-errors-1.0.1.tar.xz
pushd xcb-util-errors-1.0.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-errors -Dm644 COPYING
popd
rm -rf xcb-util-errors-1.0.1
# libdrm.
tar -xf ../sources/libdrm-2.4.134.tar.xz
pushd libdrm-2.4.134
patch -Np1 -i ../../patches/libdrm-2.4.118-license.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false -Dudev=true -Dcairo-tests=disabled -Dvalgrind=disabled $(uname -m | grep -q '^aarch64$' && echo -Domap=enabled -Dtegra=enabled)
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libdrm -Dm644 LICENSE
popd
rm -rf libdrm-2.4.134
# DirectX-Headers.
tar -xf ../sources/DirectX-Headers-1.619.5.tar.gz
pushd DirectX-Headers-1.619.5
meson setup build --prefix=/usr --buildtype=minsize -Dbuild-test=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/directx-headers -Dm644 LICENSE
popd
rm -rf DirectX-Headers-1.619.5
# SPIRV-Headers.
tar -xf ../sources/SPIRV-Headers-vulkan-sdk-1.4.350.1.tar.gz
pushd SPIRV-Headers-vulkan-sdk-1.4.350.1
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/spirv-headers -Dm644 LICENSE
popd
rm -rf SPIRV-Headers-vulkan-sdk-1.4.350.1
# SPIRV-Tools.
tar -xf ../sources/SPIRV-Tools-vulkan-sdk-1.4.350.1.tar.gz
pushd SPIRV-Tools-vulkan-sdk-1.4.350.1
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DSPIRV_TOOLS_BUILD_STATIC=OFF -DSPIRV_WERROR=OFF -DSPIRV-Headers_SOURCE_DIR=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/spirv-tools -Dm644 LICENSE
popd
rm -rf SPIRV-Tools-vulkan-sdk-1.4.350.1
# SPIRV-LLVM-Translator.
tar -xf ../sources/SPIRV-LLVM-Translator-22.1.2.tar.gz
pushd SPIRV-LLVM-Translator-22.1.2
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=ON -DBUILD_SHARED_LIBS=ON -DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/spirv-llvm-translator -Dm644 LICENSE.TXT
popd
rm -rf SPIRV-LLVM-Translator-22.1.2
# libclc.
tar -xf ../sources/llvm-project-22.1.8.src.tar.xz
pushd llvm-project-22.1.8.src/libclc
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libclc -Dm644 LICENSE.TXT
popd
rm -rf llvm-project-22.1.8.src
# glslang.
tar -xf ../sources/glslang-16.3.0.tar.gz
pushd glslang-16.3.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DALLOW_EXTERNAL_SPIRV_TOOLS=ON -DGLSLANG_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glslang -Dm644 LICENSE.txt
popd
rm -rf glslang-16.3.0
# shaderc.
tar -xf ../sources/shaderc-2026.2.tar.gz
pushd shaderc-2026.2
sed -i '/third_party/d' CMakeLists.txt
sed -i '/build-version/d' glslc/CMakeLists.txt
sed -i 's|SPIRV|glslang/&|' libshaderc_util/src/compiler.cc
echo '"2026.2"' > glslc/src/build-version.inc
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSHADERC_SKIP_TESTS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/shaderc -Dm644 LICENSE
popd
rm -rf shaderc-2026.2
# Vulkan-Headers.
tar -xf ../sources/Vulkan-Headers-vulkan-sdk-1.4.350.1.tar.gz
pushd Vulkan-Headers-vulkan-sdk-1.4.350.1
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/vulkan-headers -Dm644 LICENSE.md
popd
rm -rf Vulkan-Headers-vulkan-sdk-1.4.350.1
# Vulkan-Loader.
tar -xf ../sources/Vulkan-Loader-vulkan-sdk-1.4.350.1.tar.gz
pushd Vulkan-Loader-vulkan-sdk-1.4.350.1
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DVULKAN_HEADERS_INSTALL_DIR=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_INSTALL_DATADIR=/share -DCMAKE_SKIP_RPATH=TRUE -DBUILD_TESTS=OFF -DBUILD_WSI_XCB_SUPPORT=ON -DBUILD_WSI_XLIB_SUPPORT=ON -DBUILD_WSI_WAYLAND_SUPPORT=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/vulkan-loader -Dm644 LICENSE.txt
popd
rm -rf Vulkan-Loader-vulkan-sdk-1.4.350.1
# ORC.
tar -xf ../sources/orc-0.4.41.tar.bz2
pushd orc-0.4.41
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
rm -f /usr/lib/liborc-test-0.4.a
install -t /usr/share/licenses/orc -Dm644 COPYING
popd
rm -rf orc-0.4.41
# Vulkan-Tools.
tar -xf ../sources/Vulkan-Tools-vulkan-sdk-1.4.350.1.tar.gz
pushd Vulkan-Tools-vulkan-sdk-1.4.350.1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_CUBE=ON -DBUILD_ICD=OFF -DBUILD_VULKANINFO=ON -DBUILD_WSI_XCB_SUPPORT=ON -DBUILD_WSI_XLIB_SUPPORT=ON -DBUILD_WSI_WAYLAND_SUPPORT=ON -Wno-dev -G Ninja -B build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_CUBE=ON -DBUILD_ICD=OFF -DBUILD_VULKANINFO=OFF -DBUILD_WSI_XCB_SUPPORT=OFF -DBUILD_WSI_XLIB_SUPPORT=OFF -DBUILD_WSI_WAYLAND_SUPPORT=ON -Wno-dev -G Ninja -B build-wayland
ninja -C build
ninja -C build-wayland
ninja -C build install
install -Dm755 build-wayland/cube/vkcube /usr/bin/vkcube-wayland
install -t /usr/share/licenses/vulkan-tools -Dm644 LICENSE.txt
popd
rm -rf Vulkan-Tools-vulkan-sdk-1.4.350.1
# libva (circular dependency; will be rebuilt later to support Mesa).
tar -xf ../sources/libva-2.24.1.tar.bz2
pushd libva-2.24.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libva -Dm644 COPYING
popd
rm -rf libva-2.24.1
# libvdpau.
tar -xf ../sources/libvdpau-1.5.tar.bz2
pushd libvdpau-1.5
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libvdpau -Dm644 COPYING
popd
rm -rf libvdpau-1.5
# libglvnd.
tar -xf ../sources/libglvnd-v1.7.0.tar.bz2
pushd libglvnd-v1.7.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
tail -n211 README.md | head -n22 | sed 's/    //g' > COPYING
install -t /usr/share/licenses/libglvnd -Dm644 COPYING
popd
rm -rf libglvnd-v1.7.0
# Mesa.
tar -xf ../sources/mesa-mesa-26.1.6.tar.bz2
pushd mesa-mesa-26.1.6
## TODO: Remove this patch once xf86-video-vmware is no longer needed.
patch -Np1 -i ../../patches/mesa-26.0.1-restore-gallium-xa.patch
## Try to only build drivers which are applicable to the target architecture.
[ "$MBS_ARCH" != "x86_64" ] || echo "-Dgallium-drivers=crocus,d3d12,i915,iris,llvmpipe,nouveau,r300,r600,radeonsi,softpipe,svga,virgl,zink -Dvulkan-drivers=amd,gfxstream,intel,intel_hasvk,microsoft-experimental,nouveau,swrast,virtio -Dgallium-rusticl-enable-drivers=radeonsi -Dintel-rt=enabled" > extraconf
[ "$MBS_ARCH" != "aarch64" ] || echo "-Dgallium-drivers=asahi,d3d12,ethosu,etnaviv,freedreno,lima,llvmpipe,nouveau,panfrost,r300,r600,radeonsi,rocket,softpipe,svga,tegra,v3d,vc4,virgl,zink -Dvulkan-drivers=amd,asahi,broadcom,freedreno,gfxstream,imagination,microsoft-experimental,nouveau,panfrost,swrast,virtio -Dgallium-rusticl-enable-drivers=asahi,freedreno,radeonsi -Dfreedreno-kmds=msm,virtio" > extraconf
CFLAGS="" CPPFLAGS="" CXXFLAGS="" LDFLAGS="$LDFLAGS" meson setup build --prefix=/usr --sbindir=bin --buildtype=release -Ddebug=false -Dplatforms=wayland,x11 -Dvulkan-layers=anti-lag,device-select,intel-nullhw,overlay,screenshot,vram-report-limit -Dgallium-rusticl=true -Damdgpu-virtio=true -Dgallium-xa=enabled -Dglx=dri -Dglvnd=enabled -Dsysprof=true -Dvideo-codecs=all -Dvalgrind=disabled $(cat extraconf)
ninja -C build
ninja -C build install
install -t /usr/share/licenses/mesa -Dm644 docs/license.rst licenses/{Apache-2.0,BSL-1.0,exceptions/Linux-Syscall-Note,GPL-1.0-or-later,GPL-2.0-only,MIT,SGI-B-2.0}
popd
rm -rf mesa-mesa-26.1.6
# libva (rebuild to support Mesa).
tar -xf ../sources/libva-2.24.1.tar.bz2
pushd libva-2.24.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libva -Dm644 COPYING
popd
rm -rf libva-2.24.1
# xbitmaps.
tar -xf ../sources/xbitmaps-1.1.4.tar.xz
pushd xbitmaps-1.1.4
./configure --prefix=/usr
make install
install -t /usr/share/licenses/xbitmaps -Dm644 COPYING
popd
rm -rf xbitmaps-1.1.4
# iceauth.
tar -xf ../sources/iceauth-1.0.11.tar.xz
pushd iceauth-1.0.11
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/iceauth -Dm644 COPYING
popd
rm -rf iceauth-1.0.11
# luit.
tar -xf ../sources/luit-1.1.1.tar.bz2
pushd luit-1.1.1
sed -i -e "/D_XOPEN/s/5/6/" configure
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu"
make
make install
install -t /usr/share/licenses/luit -Dm644 COPYING
popd
rm -rf luit-1.1.1
# mkfontscale.
tar -xf ../sources/mkfontscale-1.2.4.tar.xz
pushd mkfontscale-1.2.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/mkfontscale -Dm644 COPYING
popd
rm -rf mkfontscale-1.2.4
# sessreg.
tar -xf ../sources/sessreg-1.1.4.tar.xz
pushd sessreg-1.1.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sessreg -Dm644 COPYING
popd
rm -rf sessreg-1.1.4
# setxkbmap.
tar -xf ../sources/setxkbmap-1.3.4.tar.xz
pushd setxkbmap-1.3.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/setxkbmap -Dm644 COPYING
popd
rm -rf setxkbmap-1.3.4
# smproxy.
tar -xf ../sources/smproxy-1.0.8.tar.xz
pushd smproxy-1.0.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/smproxy -Dm644 COPYING
popd
rm -rf smproxy-1.0.8
# x11perf.
tar -xf ../sources/x11perf-1.7.0.tar.xz
pushd x11perf-1.7.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/x11perf -Dm644 COPYING
popd
rm -rf x11perf-1.7.0
# xauth.
tar -xf ../sources/xauth-1.1.5.tar.xz
pushd xauth-1.1.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xauth -Dm644 COPYING
popd
rm -rf xauth-1.1.5
# xbacklight.
tar -xf ../sources/xbacklight-1.2.4.tar.xz
pushd xbacklight-1.2.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xbacklight -Dm644 COPYING
popd
rm -rf xbacklight-1.2.4
# xcmsdb.
tar -xf ../sources/xcmsdb-1.0.7.tar.xz
pushd xcmsdb-1.0.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xcmsdb -Dm644 COPYING
popd
rm -rf xcmsdb-1.0.7
# xcursorgen.
tar -xf ../sources/xcursorgen-1.0.9.tar.xz
pushd xcursorgen-1.0.9
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xcursorgen -Dm644 COPYING
popd
rm -rf xcursorgen-1.0.9
# xdpyinfo.
tar -xf ../sources/xdpyinfo-1.4.0.tar.xz
pushd xdpyinfo-1.4.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xdpyinfo -Dm644 COPYING
popd
rm -rf xdpyinfo-1.4.0
# xdriinfo.
tar -xf ../sources/xdriinfo-1.0.8.tar.xz
pushd xdriinfo-1.0.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xdriinfo -Dm644 COPYING
popd
rm -rf xdriinfo-1.0.8
# xev.
tar -xf ../sources/xev-1.2.7.tar.xz
pushd xev-1.2.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xev -Dm644 COPYING
popd
rm -rf xev-1.2.7
# xgamma.
tar -xf ../sources/xgamma-1.0.7.tar.xz
pushd xgamma-1.0.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xgamma -Dm644 COPYING
popd
rm -rf xgamma-1.0.7
# xhost.
tar -xf ../sources/xhost-1.0.10.tar.xz
pushd xhost-1.0.10
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xhost -Dm644 COPYING
popd
rm -rf xhost-1.0.10
# xinput.
tar -xf ../sources/xinput-1.6.4.tar.xz
pushd xinput-1.6.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xinput -Dm644 COPYING
popd
rm -rf xinput-1.6.4
# xkbcomp.
tar -xf ../sources/xkbcomp-1.5.0.tar.xz
pushd xkbcomp-1.5.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xkbcomp -Dm644 COPYING
popd
rm -rf xkbcomp-1.5.0
# xkbevd.
tar -xf ../sources/xkbevd-1.1.6.tar.xz
pushd xkbevd-1.1.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xkbevd -Dm644 COPYING
popd
rm -rf xkbevd-1.1.6
# xkbutils.
tar -xf ../sources/xkbutils-1.0.7.tar.xz
pushd xkbutils-1.0.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xkbutils -Dm644 COPYING
popd
rm -rf xkbutils-1.0.7
# xkill.
tar -xf ../sources/xkill-1.0.7.tar.xz
pushd xkill-1.0.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xkill -Dm644 COPYING
popd
rm -rf xkill-1.0.7
# xlsatoms.
tar -xf ../sources/xlsatoms-1.1.5.tar.xz
pushd xlsatoms-1.1.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xlsatoms -Dm644 COPYING
popd
rm -rf xlsatoms-1.1.5
# xlsclients.
tar -xf ../sources/xlsclients-1.1.6.tar.xz
pushd xlsclients-1.1.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xlsclients -Dm644 COPYING
popd
rm -rf xlsclients-1.1.6
# xmessage.
tar -xf ../sources/xmessage-1.0.7.tar.xz
pushd xmessage-1.0.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xmessage -Dm644 COPYING
popd
rm -rf xmessage-1.0.7
# xmodmap.
tar -xf ../sources/xmodmap-1.0.11.tar.xz
pushd xmodmap-1.0.11
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xmodmap -Dm644 COPYING
popd
rm -rf xmodmap-1.0.11
# xpr.
tar -xf ../sources/xpr-1.2.0.tar.xz
pushd xpr-1.2.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xpr -Dm644 COPYING
popd
rm -rf xpr-1.2.0
# xprop.
tar -xf ../sources/xprop-1.2.8.tar.xz
pushd xprop-1.2.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xprop -Dm644 COPYING
popd
rm -rf xprop-1.2.8
# xrandr.
tar -xf ../sources/xrandr-1.5.4.tar.xz
pushd xrandr-1.5.4
./configure --prefix=/usr
make
make install
rm -f /usr/bin/xkeystone
install -t /usr/share/licenses/xrandr -Dm644 COPYING
popd
rm -rf xrandr-1.5.4
# xrdb.
tar -xf ../sources/xrdb-1.2.3.tar.xz
pushd xrdb-1.2.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xrdb -Dm644 COPYING
popd
rm -rf xrdb-1.2.3
# xrefresh.
tar -xf ../sources/xrefresh-1.1.1.tar.xz
pushd xrefresh-1.1.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xrefresh -Dm644 COPYING
popd
rm -rf xrefresh-1.1.1
# xset.
tar -xf ../sources/xset-1.2.6.tar.xz
pushd xset-1.2.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xset -Dm644 COPYING
popd
rm -rf xset-1.2.6
# xsetroot.
tar -xf ../sources/xsetroot-1.1.3.tar.xz
pushd xsetroot-1.1.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xsetroot -Dm644 COPYING
popd
rm -rf xsetroot-1.1.3
# xvinfo.
tar -xf ../sources/xvinfo-1.1.5.tar.xz
pushd xvinfo-1.1.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xvinfo -Dm644 COPYING
popd
rm -rf xvinfo-1.1.5
# xwd.
tar -xf ../sources/xwd-1.0.9.tar.xz
pushd xwd-1.0.9
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xwd -Dm644 COPYING
popd
rm -rf xwd-1.0.9
# xwininfo.
tar -xf ../sources/xwininfo-1.1.6.tar.xz
pushd xwininfo-1.1.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xwininfo -Dm644 COPYING
popd
rm -rf xwininfo-1.1.6
# xwud.
tar -xf ../sources/xwud-1.0.7.tar.xz
pushd xwud-1.0.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xwud -Dm644 COPYING
popd
rm -rf xwud-1.0.7
# noto-fonts / noto-fonts-cjk / noto-fonts-emoji.
tar --no-same-owner --same-permissions -xf ../sources/noto-fonts-2026.07.01.tar.xz -C / --strip-components=1
tar --no-same-owner --same-permissions -xf ../sources/noto-fonts-cjk-20240730.tar.xz -C / --strip-components=1
tar --no-same-owner --same-permissions -xf ../sources/noto-fonts-emoji-2.051.tar.xz -C / --strip-components=1
sed -i 's|<string>sans-serif</string>|<string>Noto Sans</string>|' /etc/fonts/fonts.conf
sed -i 's|<string>monospace</string>|<string>Noto Sans Mono</string>|' /etc/fonts/fonts.conf
fc-cache
# xkeyboard-config.
tar -xf ../sources/xkeyboard-config-2.48.tar.xz
pushd xkeyboard-config-2.48
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xkeyboard-config -Dm644 COPYING
popd
rm -rf xkeyboard-config-2.48
# libxklavier.
tar -xf ../sources/libxklavier-5.4.tar.bz2
pushd libxklavier-5.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxklavier -Dm644 COPYING.LIB
popd
rm -rf libxklavier-5.4
# libxkbcommon.
tar -xf ../sources/libxkbcommon-xkbcommon-1.13.2.tar.gz
pushd libxkbcommon-xkbcommon-1.13.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Denable-docs=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libxkbcommon -Dm644 LICENSE
popd
rm -rf libxkbcommon-xkbcommon-1.13.2
# eglexternalplatform.
tar -xf ../sources/eglexternalplatform-1.2.1.tar.gz
pushd eglexternalplatform-1.2.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize --includedir=/usr/include/EGL
ninja -C build
ninja -C build install
install -t /usr/share/licenses/eglexternalplatform -Dm644 COPYING
popd
rm -rf eglexternalplatform-1.2.1
# egl-wayland.
tar -xf ../sources/egl-wayland-1.1.18.tar.gz
pushd egl-wayland-1.1.18
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -dm755 /usr/share/egl/egl_external_platform.d
cat > /usr/share/egl/egl_external_platform.d/10_nvidia_wayland.json << "END"
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "libnvidia-egl-wayland.so.1"
    }
}

END
install -t /usr/share/licenses/egl-wayland -Dm644 COPYING
popd
rm -rf egl-wayland-1.1.18
# systemd (rebuild to support more features).
tar -xf ../sources/systemd-261.2.tar.gz
pushd systemd-261.2
patch -Np1 -i ../../patches/systemd-261.2-hardcode-uids.patch
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --localstatedir=/var --buildtype=minsize -Dmode=release -Dversion-tag="$(cat meson.version)-massos" -Dshared-lib-tag="$(cat meson.version)-massos" -Dsbat-distro-version="$(cat meson.version)-massos" -Dsbat-distro-url=https://massos.org -Dbpf-framework=enabled -Ddefault-compression=zstd -Ddefault-dnssec=no -Ddev-kvm-mode=0660 -Ddns-over-tls=openssl -Dfallback-hostname=massos -Dfirstboot=false -Dhomed=disabled -Dinitrd=true -Dinstall-tests=false -Dkernel-install=false -Dman=enabled -Dpamconfdir=/etc/pam.d -Drpmmacrosdir=no -Dsysupdate=disabled -Dsysusers=true -Dtests=false -Dtpm=true -Dukify=disabled -Duserdb=true -Dvmlinux-h=disabled -Dadm-gid=999 -Dwheel-gid=998 -Dempower-gid=997 -Dutmp-gid=996 -Daudio-gid=995 -Dcdrom-gid=994 -Dclock-gid=993 -Ddialout-gid=992 -Ddisk-gid=991 -Dinput-gid=990 -Dkmem-gid=989 -Dkvm-gid=988 -Dlp-gid=987 -Drender-gid=986 -Dsgx-gid=985 -Dtape-gid=984 -Dvideo-gid=983 -Dusers-gid=982 -Dsystemd-journal-gid=981 -Dtty-gid=5 -Dsystemd-network-uid=979 -Dsystemd-resolve-uid=977 -Dsystemd-timesync-uid=976 -Dsystemd-imds-uid=969
ninja -C build
ninja -C build install
sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt /usr/lib/systemd/boot/efi/systemd-boot"$MBS_ARCH_EFI".efi
cat > /etc/pam.d/systemd-user << "END"
account  required pam_access.so
account  include  system-account
session  required pam_env.so
session  required pam_limits.so
session  required pam_unix.so
session  required pam_loginuid.so
session  optional pam_keyinit.so force revoke
session  optional pam_systemd.so
auth     required pam_deny.so
password required pam_deny.so
END
popd
rm -rf systemd-261.2
# D-Bus (rebuild for X and libaudit support).
tar -xf ../sources/dbus-1.16.2.tar.xz
pushd dbus-1.16.2
patch -Np1 -i ../../patches/dbus-1.16.2-hardcode-uid.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dapparmor=enabled -Dlibaudit=enabled -Dmodular_tests=disabled -Dselinux=disabled -Dx11_autolaunch=enabled
ninja -C build
ninja -C build install
systemd-sysusers
popd
rm -rf dbus-1.16.2
# D-Bus GLib.
tar -xf ../sources/dbus-glib-0.114.tar.gz
pushd dbus-glib-0.114
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/dbus-glib -Dm644 COPYING
popd
rm -rf dbus-glib-0.114
# alsa-lib.
tar -xf ../sources/alsa-lib-1.2.16.tar.bz2
pushd alsa-lib-1.2.16
./configure --prefix=/usr --without-debug
make
make install
install -t /usr/share/licenses/alsa-lib -Dm644 COPYING
popd
rm -rf alsa-lib-1.2.16
# alsa-ucm-conf.
tar -xf ../sources/alsa-ucm-conf-1.2.16.tar.bz2
pushd alsa-ucm-conf-1.2.16
cp -r ucm{,2} /usr/share/alsa
install -t /usr/share/licenses/alsa-ucm-conf -Dm644 LICENSE
popd
rm -rf alsa-ucm-conf-1.2.16
# alsa-oss.
tar -xf ../sources/alsa-oss-1.1.8.tar.bz2
pushd alsa-oss-1.1.8
./configure --prefix=/usr --disable-static
make
make install
install -dm755 /usr/lib/modules-load.d
cat > /usr/lib/modules-load.d/alsa-oss.conf << "END"
snd_pcm_oss
snd_mixer_oss
snd_seq_oss
END
install -t /usr/share/licenses/alsa-oss -Dm644 COPYING
popd
rm -rf alsa-oss-1.1.8
# sndio.
tar -xf ../sources/sndio-1.10.0.tar.gz
pushd sndio-1.10.0
./configure --prefix=/usr --with-libbsd
make
make install
install -t /usr/share/licenses/sndio -Dm644 LICENSE
popd
rm -rf sndio-1.10.0
# libepoxy.
tar -xf ../sources/libepoxy-1.5.10.tar.gz
pushd libepoxy-1.5.10
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libepoxy -Dm644 COPYING
popd
rm -rf libepoxy-1.5.10
# virglrenderer.
tar -xf ../sources/virglrenderer-1.2.0.tar.bz2
pushd virglrenderer-1.2.0
patch -Np1 -i ../../patches/virglrenderer-1.2.0-glibc243.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dvenus=true -Dvideo=true -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/virglrenderer -Dm644 COPYING
popd
rm -rf virglrenderer-1.2.0
# libxcvt.
tar -xf ../sources/libxcvt-0.1.3.tar.xz
pushd libxcvt-0.1.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libxcvt -Dm644 COPYING
popd
rm -rf libxcvt-0.1.3
# Xorg-Server.
tar -xf ../sources/xorg-server-21.1.24.tar.xz
pushd xorg-server-21.1.24
patch -Np1 -i ../../patches/xorg-server-21.1.2-addxvfbrun.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dglamor=true -Dlibunwind=true -Dsuid_wrapper=true -Dxephyr=true -Dxvfb=true -Dxkb_output_dir=/var/lib/xkb
ninja -C build
ninja -C build install
install -t /usr/bin -Dm755 xvfb-run
install -t /usr/share/man/man1 xvfb-run.1
install -dm755 /etc/X11/xorg.conf.d
install -t /usr/share/licenses/xorg-server -Dm644 COPYING
popd
rm -rf xorg-server-21.1.24
# Xwayland.
tar -xf ../sources/xwayland-24.1.13.tar.xz
pushd xwayland-24.1.13
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dxvfb=false -Dxkb_output_dir=/var/lib/xkb
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xwayland -Dm644 COPYING
popd
rm -rf xwayland-24.1.13
# libinput.
tar -xf ../sources/libinput-1.31.3.tar.bz2
pushd libinput-1.31.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddebug-gui=false -Ddocumentation=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libinput -Dm644 COPYING
popd
rm -rf libinput-1.31.3
# xf86-input-libinput.
tar -xf ../sources/xf86-input-libinput-1.5.0.tar.xz
pushd xf86-input-libinput-1.5.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-libinput -Dm644 COPYING
popd
rm -rf xf86-input-libinput-1.5.0
# xf86-video-qxl.
tar -xf ../sources/xf86-video-qxl-0.1.6.tar.xz
pushd xf86-video-qxl-0.1.6
./configure --prefix=/usr --disable-xspice
make
make install
install -t /usr/share/licenses/xf86-video-qxl -Dm644 COPYING
popd
rm -rf xf86-video-qxl-0.1.6
# xf86-video-vmware.
tar -xf ../sources/xf86-video-vmware-13.4.0.tar.xz
pushd xf86-video-vmware-13.4.0
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" ./configure --prefix=/usr --enable-vmwarectrl-client
make
make install
install -t /usr/share/licenses/xf86-video-vmware -Dm644 COPYING
popd
rm -rf xf86-video-vmware-13.4.0
# xf86-video-fbdev.
tar -xf ../sources/xf86-video-fbdev-0.5.1.tar.xz
pushd xf86-video-fbdev-0.5.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xf86-video-fbdev -Dm644 COPYING
popd
rm -rf xf86-video-fbdev-0.5.1
# xf86-video-vesa.
tar -xf ../sources/xf86-video-vesa-2.6.0.tar.xz
pushd xf86-video-vesa-2.6.0
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" ./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xf86-video-vesa -Dm644 COPYING
popd
rm -rf xf86-video-vesa-2.6.0
# intel-gmmlib (x86_64 only).
tar -xf ../sources/intel-gmmlib-22.10.0.tar.gz
pushd gmmlib-intel-gmmlib-22.10.0
[ "$MBS_ARCH" != "x86_64" ] || CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DRUN_TEST_SUITE=OFF -Wno-dev -G Ninja -B build
[ "$MBS_ARCH" != "x86_64" ] || ninja -C build
[ "$MBS_ARCH" != "x86_64" ] || ninja -C build install
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/share/licenses/intel-gmmlib -Dm644 LICENSE.md
[ "$MBS_ARCH" = "x86_64" ] || sed -i '/^intel-gmmlib$/d' /usr/share/massos/builtins
popd
rm -rf gmmlib-intel-gmmlib-22.10.0
# intel-vaapi-driver (x86_64 only).
tar -xf ../sources/intel-vaapi-driver-2.4.1.tar.bz2
pushd intel-vaapi-driver-2.4.1
[ "$MBS_ARCH" != "x86_64" ] || meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
[ "$MBS_ARCH" != "x86_64" ] || ninja -C build
[ "$MBS_ARCH" != "x86_64" ] || ninja -C build install
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/share/licenses/intel-vaapi-driver -Dm644 COPYING
[ "$MBS_ARCH" = "x86_64" ] || sed -i '/^intel-vaapi-driver$/d' /usr/share/massos/builtins
popd
rm -rf intel-vaapi-driver-2.4.1
# intel-media-driver (x86_64 only).
tar -xf ../sources/intel-media-26.1.5.tar.gz
pushd media-driver-intel-media-26.1.5
patch -Np1 -i ../../patches/intel-media-driver-25.2.0-cmake400.patch
[ "$MBS_ARCH" != "x86_64" ] || CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DINSTALL_DRIVER_SYSCONF=OFF -DMEDIA_BUILD_FATAL_WARNINGS=OFF -Wno-dev -G Ninja -B build
[ "$MBS_ARCH" != "x86_64" ] || ninja -C build
[ "$MBS_ARCH" != "x86_64" ] || ninja -C build install
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/share/licenses/intel-media-driver -Dm644 LICENSE.md
[ "$MBS_ARCH" = "x86_64" ] || sed -i '/^intel-media-driver$/d' /usr/share/massos/builtins
popd
rm -rf media-driver-intel-media-26.1.5
# xinit.
tar -xf ../sources/xinit-1.4.4.tar.xz
pushd xinit-1.4.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-xinitdir=/etc/X11/app-defaults
make
make install
ldconfig
install -t /usr/share/licenses/xinit -Dm644 COPYING
popd
rm -rf xinit-1.4.4
# libburn.
tar -xf ../sources/libburn-1.5.8.tar.gz
pushd libburn-1.5.8
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libburn -Dm644 COPYING COPYRIGHT
popd
rm -rf libburn-1.5.8
# libisofs.
tar -xf ../sources/libisofs-1.5.8.pl02.tar.gz
pushd libisofs-1.5.8
./configure --prefix=/usr --disable-static --enable-libacl --enable-xattr
make
make install
install -t /usr/share/licenses/libisofs -Dm644 COPYING COPYRIGHT
popd
rm -rf libisofs-1.5.8
# libisoburn.
tar -xf ../sources/libisoburn-1.5.8.pl02.tar.gz
pushd libisoburn-1.5.8
./configure --prefix=/usr --disable-static --disable-debug
make
make install
install -t /usr/share/licenses/libisoburn -Dm644 COPYING COPYRIGHT
popd
rm -rf libisoburn-1.5.8
# zsh.
tar -xf ../sources/zsh-5.9.tar.xz
pushd zsh-5.9
patch -Np1 -i ../../patches/zsh-5.9-fixes.patch
./configure --prefix=/usr --enable-etcdir=/etc/zsh --enable-fndir=/usr/share/zsh/functions --enable-scriptdir=/usr/share/zsh/scripts --enable-zshenv=/etc/zsh/zshenv --enable-zlogin=/etc/zsh/zlogin --enable-zlogout=/etc/zsh/zlogout --enable-zprofile=/etc/zsh/zprofile --enable-zshrc=/etc/zsh/zshrc --enable-cap --enable-function-subdirs --enable-gdbm --enable-maildir-support --enable-multibyte --enable-pcre --enable-zsh-secure-free --with-tcsetpgrp --with-term-lib=ncursesw
make
make install
echo "emulate sh -c 'source /etc/profile'" | install -Dm644 /dev/stdin /etc/zsh/zprofile
cp /etc/zsh/z{profile,shrc}
install -t /usr/share/licenses/zsh -Dm644 LICENCE
popd
rm -rf zsh-5.9
# fish (no longer builds with MinSizeRel as of 4.x, see upstream issue #11376).
tar -xf ../sources/fish-4.0.2.tar.xz
pushd fish-4.0.2
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_BUILD_TYPE=Release -DBUILD_DOCS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
rm -f /usr/share/applications/fish.desktop
install -t /usr/share/licenses/fish -Dm644 COPYING doc_src/license.rst
popd
rm -rf fish-4.0.2
# yq.
tar -xf ../sources/yq-4.53.3.tar.gz
pushd yq-4.53.3
go build -trimpath -buildmode=pie -ldflags="-linkmode=external"
install -t /usr/bin -Dm755 yq
install -dm755 /usr/share/bash-completion/completions
install -dm755 /usr/share/zsh/site-functions
install -dm755 /usr/share/fish/vendor_completions.d
yq completion bash > /usr/share/bash-completion/completions/yq
yq completion zsh > /usr/share/zsh/site-functions/_yq
yq completion fish > /usr/share/fish/vendor_completions.d/yq.fish
install -t /usr/share/licenses/yq -Dm644 LICENSE
popd
rm -rf yq-4.53.3
# parallel.
tar -xf ../sources/parallel-20250322.tar.bz2
pushd parallel-20250322
patch -Np1 -i ../../patches/parallel-20250322-removecitation.patch
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/parallel -Dm644 LICENSES/*
popd
rm -rf parallel-20250322
# rdfind.
tar -xf ../sources/rdfind-releases-1.7.0.tar.gz
pushd rdfind-releases-1.7.0
./bootstrap.sh
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/rdfind -Dm644 COPYING
popd
rm -rf rdfind-releases-1.7.0
# ripgrep.
tar -xf ../sources/ripgrep-15.1.0.tar.gz
pushd ripgrep-15.1.0
cargo build --release --features=pcre2
install -t /usr/bin -Dm755 target/release/rg
rg --generate complete-bash > /usr/share/bash-completion/completions/rg
rg --generate complete-fish > /usr/share/fish/vendor_completions.d/rg.fish
rg --generate complete-zsh > /usr/share/zsh/site-functions/_rg
install -t /usr/share/licenses/ripgrep -Dm644 COPYING LICENSE-MIT UNLICENSE
popd
rm -rf ripgrep-15.1.0
# tldr (we use the Rust version called 'tealdeer' for faster runtime).
tar -xf ../sources/tealdeer-1.8.1.tar.gz
pushd tealdeer-1.8.1
cargo build --release
install -Dm755 target/release/tldr /usr/bin/tldr
install -Dm644 completion/bash_tealdeer /usr/share/bash-completion/completions/tldr
install -Dm644 completion/fish_tealdeer /usr/share/fish/vendor_completions.d/tldr.fish
install -Dm644 completion/zsh_tealdeer /usr/share/zsh/site-functions/_tldr
install -t /usr/share/licenses/tldr -Dm644 LICENSE-APACHE LICENSE-MIT
popd
rm -rf tealdeer-1.8.1
# hyfetch (provides neofetch).
tar -xf ../sources/hyfetch-2.1.0-rc1.tar.gz
pushd hyfetch-2.1.0-rc1
cargo build --release
install -t /usr/bin -Dm755 target/release/hyfetch
install -Dm755 neofetch /usr/bin/neowofetch
ln -sf neowofetch /usr/bin/neofetch
install -t /usr/share/licenses/hyfetch -Dm644 LICENSE.md
ln -sf hyfetch /usr/share/licenses/neofetch
popd
rm -rf hyfetch-2.1.0-rc1
# fastfetch.
tar -xf ../sources/fastfetch-2.66.0.tar.gz
pushd fastfetch-2.66.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_SYSTEM_YYJSON=ON -DINSTALL_LICENSE=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fastfetch -Dm644 LICENSE
popd
rm -rf fastfetch-2.66.0
# htop.
tar -xf ../sources/htop-3.4.1.tar.xz
pushd htop-3.4.1
./configure --prefix=/usr --sysconfdir=/etc --enable-delayacct --enable-openvz --enable-unicode --enable-vserver
make
make install
rm -f /usr/share/applications/htop.desktop
install -t /usr/share/licenses/htop -Dm644 COPYING
popd
rm -rf htop-3.4.1
# brightnessctl.
tar -xf ../sources/brightnessctl-0.5.1.tar.gz
pushd brightnessctl-0.5.1
make ENABLE_SYSTEMD=1
make ENABLE_SYSTEMD=1 install
install -t /usr/share/licenses/brightnessctl -Dm644 LICENSE
popd
rm -rf brightnessctl-0.5.1
# zram-generator.
tar -xf ../sources/zram-generator-1.2.1.tar.gz
pushd zram-generator-1.2.1
patch -Np1 -i ../../patches/zram-generator-1.2.1-pregenerated-manual-pages.patch
make
make install
cat > /etc/systemd/zram-generator.conf << "END"
# This is the default (example) ZRAM configuration file for MassOS.
# Everything is commented out (and thus disabled) by default.
# Uncomment to use these defaults, and/or customize to your own needs.

# Main ZRAM device.
#[zram0]

# Default is half of the total system RAM, or 4GB, whichever is LOWER.
# Alternatively you can replace min() with a hardcoded megabyte value.
#zram-size = min(ram / 2, 4096)

# 'zstd' compresses very efficiently, but uses a lot of CPU resources.
# For a less effective, but more lightweight alternative, try 'lz4'.
#compression-algorithm = zstd

# Format the ZRAM area as swap space. This is the recommended default.
#fs-type = swap

# Ensure ZRAM is given a higher priority than physical swap space.
#swap-priority = 100
END
install -t /usr/share/licenses/zram-generator -Dm644 LICENSE
popd
rm -rf zram-generator-1.2.1
# bsd-games.
tar -xf ../sources/bsd-games-3.3.tar.gz
pushd bsd-games-3.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/bsd-games -Dm644 LICENSE
popd
rm -rf bsd-games-3.3
# sl.
tar -xf ../sources/sl-5.05.tar.gz
pushd sl-5.05
gcc $CFLAGS sl.c -o sl -lncursesw $LDFLAGS
install -t /usr/bin -Dm755 sl
install -t /usr/share/man/man1 -Dm644 sl.1
install -t /usr/share/licenses/sl -Dm644 LICENSE
popd
rm -rf sl-5.05
# cowsay.
tar -xf ../sources/cowsay-3.8.4.tar.gz
pushd cowsay-3.8.4
make prefix=/usr sysconfdir=/etc install
install -t /usr/share/licenses/cowsay -Dm644 LICENSE.txt
popd
rm -rf cowsay-3.8.4
# figlet.
tar -xf ../sources/figlet_2.2.5.orig.tar.gz
pushd figlet-2.2.5
make BINDIR=/usr/bin MANDIR=/usr/share/man DEFAULTFONTDIR=/usr/share/figlet/fonts all
make BINDIR=/usr/bin MANDIR=/usr/share/man DEFAULTFONTDIR=/usr/share/figlet/fonts install
install -t /usr/share/licenses/figlet -Dm644 LICENSE
popd
rm -rf figlet-2.2.5
# CMatrix.
tar -xf ../sources/cmatrix-v2.0-Butterscotch.tar
pushd cmatrix
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/fonts/misc -Dm644 mtx.pcf
install -t /usr/share/consolefonts -Dm644 matrix.fnt
install -t /usr/share/consolefonts -Dm644 matrix.psf.gz
install -t /usr/share/man/man1 -Dm644 cmatrix.1
install -t /usr/share/licenses/cmatrix -Dm644 COPYING
popd
rm -rf cmatrix
# vitetris.
tar -xf ../sources/vitetris-0.59.1.tar.gz
pushd vitetris-0.59.1
sed -i 's|#define CONFIG_FILENAME ".vitetris"|#define CONFIG_FILENAME ".config/vitetris"|' src/config2.h
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration -Wno-error=implicit-int" ./configure --prefix=/usr --with-ncurses --without-x
make
make gameserver
make install
mv /usr/bin/{,vi}tetris
ln -sf vitetris /usr/bin/tetris
install -Dm755 gameserver /usr/bin/vitetris-gameserver
ln -sf vitetris-gameserver /usr/bin/tetris-gameserver
rm -f /usr/share/applications/vitetris.desktop
rm -f /usr/share/pixmaps/vitetris.xpm
install -t /usr/share/licenses/vitetris -Dm644 licence.txt
popd
rm -rf vitetris-0.59.1
# fuseiso.
tar -xf ../sources/fuseiso-20070708.tar.bz2
pushd fuseiso-20070708
patch -Np1 -i ../../patches/fuseiso-20070708-fixes.patch
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu"
make
make install
install -t /usr/share/licenses/fuseiso -Dm644 COPYING
popd
rm -rf fuseiso-20070708
# mtools.
tar -xf ../sources/mtools-4.0.49.tar.bz2
pushd mtools-4.0.49
sed -i '/^SAMPLE FILE$/s:^:# :' mtools.conf
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -t /etc -Dm644 mtools.conf
install -t /usr/share/licenses/mtools -Dm644 COPYING
popd
rm -rf mtools-4.0.49
# bcachefs-tools.
tar -xf ../sources/bcachefs-tools-1.38.5.tar.gz
pushd bcachefs-tools-1.38.5
## Initramfs scripts are inappropriate for dracut - throw them away.
## bcachefs will be built as an external module later.
make PREFIX=/usr ROOT_SBINDIR=/usr/bin INITRAMFS_DIR=/tmp/.mbs_trash DKMSDIR=/tmp/.mbs_trash
make PREFIX=/usr ROOT_SBINDIR=/usr/bin INITRAMFS_DIR=/tmp/.mbs_trash DKMSDIR=/tmp/.mbs_trash install
bcachefs completions bash > /usr/share/bash-completion/completions/bcachefs
bcachefs completions zsh > /usr/share/zsh/site-functions/_bcachefs
bcachefs completions fish > /usr/share/fish/vendor_completions.d/bcachefs.fish
install -t /usr/share/licenses/bcachefs-tools -Dm644 COPYING
popd
rm -rf bcachefs-tools-1.38.5
# Polkit.
tar -xf ../sources/polkit-127.tar.gz
pushd polkit-127
patch -Np1 -i ../../patches/polkit-127-pamconfig.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dman=true -Dpam_prefix=/etc/pam.d -Dpolkitd_uid=968 -Dsession_tracking=logind -Dtests=false
ninja -C build
ninja -C build install
systemd-sysusers
systemctl enable polkit-agent-helper.socket
install -t /usr/share/licenses/polkit -Dm644 COPYING
popd
rm -rf polkit-127
# OpenSSH.
tar -xf ../sources/openssh-10.4p1.tar.gz
pushd openssh-10.4p1
install -o root -g sys -dm700 /var/lib/sshd
echo 'u sshd 967 "sshd PrivSep" /var/lib/sshd' > /usr/lib/sysusers.d/sshd.conf
systemd-sysusers
./configure --prefix=/usr --sysconfdir=/etc/ssh --sbindir=/usr/bin --with-default-path="/usr/local/bin:/usr/bin" --with-kerberos5=/usr --with-libedit --with-pam --with-pid-dir=/run --with-privsep-path=/var/lib/sshd --with-privsep-user=sshd --with-xauth=/usr/bin/xauth
make
make install
install -t /usr/bin -Dm755 contrib/ssh-copy-id
install -t /usr/share/man/man1 -Dm644 contrib/ssh-copy-id.1
cp /etc/pam.d/{login,sshd}
sed -i 's/#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
rm -f /etc/ssh/ssh_host_*_key{,.pub}
install -t /usr/share/licenses/openssh -Dm644 LICENCE
popd
rm -rf openssh-10.4p1
# sshfs.
tar -xf ../sources/sshfs-3.7.6.tar.xz
pushd sshfs-3.7.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/sshfs -Dm644 COPYING
popd
rm -rf sshfs-3.7.6
# GLU.
tar -xf ../sources/glu-9.0.3.tar.xz
pushd glu-9.0.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgl_provider=gl
ninja -C build
ninja -C build install
rm -f /usr/lib/libGLU.a
popd
rm -rf glu-9.0.3
# FreeGLUT.
tar -xf ../sources/freeglut-3.8.0.tar.gz
pushd freeglut-3.8.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DFREEGLUT_BUILD_DEMOS=OFF -DFREEGLUT_BUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/freeglut -Dm644 COPYING
popd
rm -rf freeglut-3.8.0
# GLEW.
tar -xf ../sources/glew-2.3.1.tgz
pushd glew-2.3.1
sed -i 's|lib64|lib|g' config/Makefile.linux
make GLEW_PREFIX=/usr GLEW_DEST=/usr
make GLEW_PREFIX=/usr GLEW_DEST=/usr install.all
chmod 755 /usr/lib/libGLEW.so.2.3.1
rm -f /usr/lib/libGLEW.a
install -t /usr/share/licenses/glew -Dm644 LICENSE.txt
popd
rm -rf glew-2.3.1
# libtiff.
tar -xf ../sources/libtiff-v4.7.2.tar.bz2
pushd libtiff-v4.7.2
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libtiff -Dm644 LICENSE.md
popd
rm -rf libtiff-v4.7.2
# lcms2.
tar -xf ../sources/lcms2-2.19.1.tar.gz
pushd lcms2-2.19.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/lcms2 -Dm644 LICENSE
popd
rm -rf lcms2-2.19.1
# JasPer.
tar -xf ../sources/jasper-4.2.9.tar.gz
pushd jasper-4.2.9
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=YES -DALLOW_IN_SOURCE_BUILD=YES -DJAS_ENABLE_DOC=NO -DJAS_ENABLE_LIBJPEG=ON -DJAS_ENABLE_OPENGL=ON -Wno-dev -G Ninja -B build1
ninja -C build1
ninja -C build1 install
install -t /usr/share/licenses/jasper -Dm644 LICENSE.txt
popd
rm -rf jasper-4.2.9
# libliftoff.
tar -xf ../sources/libliftoff-v0.5.0.tar.bz2
pushd libliftoff-v0.5.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libliftoff -Dm644 LICENSE
popd
rm -rf libliftoff-v0.5.0
# wlroots.
tar -xf ../sources/wlroots-0.20.1.tar.bz2
pushd wlroots-0.20.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/wlroots -Dm644 LICENSE
popd
rm -rf wlroots-0.20.1
# at-spi2-core (now provides ATK and at-spi2-atk).
tar -xf ../sources/at-spi2-core-2.60.5.tar.gz
pushd at-spi2-core-2.60.5
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/at-spi2-core -Dm644 COPYING
ln -sf at-spi2-core /usr/share/licenses/at-spi2-atk
ln -sf at-spi2-core /usr/share/licenses/atk
popd
rm -rf at-spi2-core-2.60.5
# Atkmm.
tar -xf ../sources/atkmm-2.28.5.tar.gz
pushd atkmm-2.28.5
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-documentation=false -Dmaintainer-mode=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/atkmm -Dm644 COPYING{,.tools}
popd
rm -rf atkmm-2.28.5
# GDK-Pixbuf (initial build - will be rebuilt later with glycin for loaders).
tar -xf ../sources/gdk-pixbuf-2.44.7.tar.gz
pushd gdk-pixbuf-2.44.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgif=disabled -Dglycin=disabled -Djpeg=disabled -Dothers=disabled -Dpng=disabled -Dthumbnailer=disabled -Dtiff=disabled -Dinstalled_tests=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gdk-pixbuf -Dm644 COPYING
popd
rm -rf gdk-pixbuf-2.44.7
# Cairo.
tar -xf ../sources/cairo-1.18.4.tar.bz2
pushd cairo-1.18.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtee=enabled -Dtests=disabled -Dxlib-xcb=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/cairo -Dm644 COPYING{,-LGPL-2.1}
popd
rm -rf cairo-1.18.4
# Cairomm.
tar -xf ../sources/cairomm-1.14.6.tar.bz2
pushd cairomm-1.14.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-examples=false -Dbuild-tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/cairomm -Dm644 COPYING
popd
rm -rf cairomm-1.14.6
# HarfBuzz (rebuild to support Cairo).
tar -xf ../sources/harfbuzz-14.2.1.tar.xz
pushd harfbuzz-14.2.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled
ninja -C build
ninja -C build install
popd
rm -rf harfbuzz-14.2.1
# Pango.
tar -xf ../sources/pango-1.58.0.tar.gz
pushd pango-1.58.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dintrospection=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pango -Dm644 COPYING
popd
rm -rf pango-1.58.0
# Pangomm.
tar -xf ../sources/pangomm-2.46.4.tar.gz
pushd pangomm-2.46.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-documentation=false -Dmaintainer-mode=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pangomm -Dm644 COPYING{,.tools}
popd
rm -rf pangomm-2.46.4
# hicolor-icon-theme.
tar -xf ../sources/hicolor-icon-theme-0.18.tar.xz
pushd hicolor-icon-theme-0.18
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/hicolor-icon-theme -Dm644 COPYING
popd
rm -rf hicolor-icon-theme-0.18
# sound-theme-freedesktop.
tar -xf ../sources/sound-theme-freedesktop-0.8.tar.bz2
pushd sound-theme-freedesktop-0.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sound-theme-freedesktop -Dm644 CREDITS
popd
rm -rf sound-theme-freedesktop-0.8
# libwebp.
tar -xf ../sources/libwebp-1.6.0.tar.gz
pushd libwebp-1.6.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=ON -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libwebp -Dm644 COPYING
popd
rm -rf libwebp-1.6.0
# jp2a.
tar -xf ../sources/jp2a-1.3.2.tar.bz2
pushd jp2a-1.3.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/jp2a -Dm644 COPYING LICENSES
popd
rm -rf jp2a-1.3.2
# Graphviz.
tar -xf ../sources/graphviz-15.1.0.tar.bz2
pushd graphviz-15.1.0
sed -i '/LIBPOSTFIX="64"/s/64//' configure.ac
./autogen.sh
./configure --prefix=/usr --disable-php --enable-lefty --with-webp
sed -i "s|0|compiled on $(date +%Y-%m-%d) at $(date +%H:%M:%S)|" builddate.h
make
make -j1 install
install -t /usr/share/licenses/graphviz -Dm644 COPYING
popd
rm -rf graphviz-15.1.0
# Vala.
tar -xf ../sources/vala-0.56.19.tar.xz
pushd vala-0.56.19
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/vala -Dm644 COPYING
popd
rm -rf vala-0.56.19
# dconf.
tar -xf ../sources/dconf-0.40.0.tar.gz
pushd dconf-0.40.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -dm755 /etc/dconf/db
install -t /usr/share/licenses/dconf -Dm644 COPYING
popd
rm -rf dconf-0.40.0
# libcloudproviders.
tar -xf ../sources/libcloudproviders-0.3.6.tar.gz
pushd libcloudproviders-0.3.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libcloudproviders -Dm644 LICENSE
popd
rm -rf libcloudproviders-0.3.6
# libgusb.
tar -xf ../sources/libgusb-0.4.9.tar.xz
pushd libgusb-0.4.9
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddocs=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libgusb -Dm644 COPYING
popd
rm -rf libgusb-0.4.9
# hidapi.
tar -xf ../sources/hidapi-0.14.0.tar.gz
pushd hidapi-hidapi-0.14.0
patch -Np1 -i ../../patches/hidapi-0.14.0-cmake400.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/hidapi -Dm644 LICENSE{,-{bsd,gpl3,orig}}.txt
popd
rm -rf hidapi-hidapi-0.14.0
# libmanette.
tar -xf ../sources/libmanette-0.2.11.tar.gz
pushd libmanette-0.2.11
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgudev=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libmanette -Dm644 COPYING
popd
rm -rf libmanette-0.2.11
# librsvg.
tar -xf ../sources/librsvg-2.62.3.tar.gz
pushd librsvg-2.62.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=release
ninja -C build
ninja -C build install
install -t /usr/share/licenses/librsvg -Dm644 COPYING.LIB
popd
rm -rf librsvg-2.62.3
# Colord.
tar -xf ../sources/colord-1.4.8.tar.xz
pushd colord-1.4.8
patch -Np1 -i ../../patches/colord-1.4.8-allowfixeduid.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddaemon_user=colord -Ddaemon_uid=966 -Dvapi=true -Dsystemd=true -Dlibcolordcompat=true -Dargyllcms_sensor=false -Dman=false -Dtests=false
ninja -C build
ninja -C build install
systemd-sysusers
install -t /usr/share/licenses/colord -Dm644 COPYING
popd
rm -rf colord-1.4.8
# CUPS.
tar -xf ../sources/cups-2.4.19-source.tar.gz
pushd cups-2.4.19
cat > /usr/lib/sysusers.d/cups.conf << "END"
u cups 420 "CUPS Service User" /var/spool/cups
m cups lp
END
systemd-sysusers
patch -Np1 -i ../../patches/cups-2.4.11-pamconfig.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --sbindir=/usr/bin --with-docdir=/usr/share/cups/doc --with-rundir=/run/cups --with-cups-group=420 --with-cups-user=420 --with-system-groups="root wheel lpadmin" --enable-libpaper
make
make install
echo "ServerName /run/cups/cups.sock" > /etc/cups/client.conf
sed -e "s|#User 420|User 420|" -e "s|#Group 420|Group 420|" -i /etc/cups/cups-files.conf{,.default}
systemctl enable cups
install -t /usr/share/licenses/cups -Dm644 LICENSE NOTICE
popd
rm -rf cups-2.4.19
# cups-pk-helper.
tar -xf ../sources/cups-pk-helper-0.2.7.tar.xz
pushd cups-pk-helper-0.2.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/cups-pk-helper -Dm644 COPYING
popd
rm -rf cups-pk-helper-0.2.7
# GTK3.
tar -xf ../sources/gtk-3.24.52.tar.gz
pushd gtk-3.24.52
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbroadway_backend=true -Dcloudproviders=true -Dcolord=yes -Ddemos=false -Dexamples=false -Dman=true -Dprint_backends=cups,file,lpr -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk3 -Dm644 COPYING
popd
rm -rf gtk-3.24.52
# Gtkmm3.
tar -xf ../sources/gtkmm-3.24.11.tar.gz
pushd gtkmm-3.24.11
sed -i 420,421d meson.build
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-demos=false -Dbuild-documentation=false -Dbuild-tests=false -Dmaintainer-mode=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtkmm3 -Dm644 COPYING{,.tools}
popd
rm -rf gtkmm-3.24.11
# libhandy.
tar -xf ../sources/libhandy-1.8.3.tar.gz
pushd libhandy-1.8.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libhandy -Dm644 COPYING
popd
rm -rf libhandy-1.8.3
# GTK4 (initial build - rebuilt later for GStreamer and tinysparql support).
tar -xf ../sources/gtk-4.22.4.tar.gz
pushd gtk-4.22.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbroadway-backend=true -Dbuild-demos=false -Dbuild-examples=false -Dbuild-tests=false -Dbuild-testsuite=false -Dcloudproviders=enabled -Dcolord=enabled -Dintrospection=enabled -Dman-pages=true -Dmedia-gstreamer=disabled -Dsysprof=enabled -Dtracker=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk4 -Dm644 COPYING
popd
rm -rf gtk-4.22.4
# dconf-editor.
tar -xf ../sources/dconf-editor-45.0.1.tar.gz
cd dconf-editor-45.0.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/dconf-editor -Dm644 COPYING
cd ..
rm -rf dconf-editor-45.0.1
# libdecor.
tar -xf ../sources/libdecor-0.2.2.tar.gz
pushd libdecor-0.2.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddemo=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libdecor -Dm644 LICENSE
popd
rm -rf libdecor-0.2.2
# libindicator.
tar -xf ../sources/libindicator-12.10.1.tar.gz
pushd libindicator-12.10.1
patch -Np1 -i ../../patches/libindicator-12.10.1-buildfixes.patch
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-gtk=3 --disable-static --disable-tests
make
make -j1 install
install -t /usr/share/licenses/libindicator -Dm644 COPYING
popd
rm -rf libindicator-12.10.1
# libdbusmenu.
tar -xf ../sources/libdbusmenu_18.10.20180917~bzr492+repack1.orig.tar.xz
pushd libdbusmenu-18.10.20180917~bzr492
HAVE_VALGRIND_FALSE="" HAVE_VALGRIND_TRUE="#" ./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-gtk=3 --disable-dumper --disable-gtk-doc-html --disable-static --disable-tests
make
make -j1 install
install -t /usr/share/licenses/libdbusmenu -Dm644 COPYING
popd
rm -rf libdbusmenu-18.10.20180917~bzr492
# libappindicator.
tar --one-top-level -xf ../sources/libappindicator_12.10.1+20.10.20200706.1.orig.tar.gz
pushd libappindicator_12.10.1+20.10.20200706.1.orig
patch -Np1 -i ../../patches/libappindicator-12.10.1-runtimefix.patch
./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-gtk=3 --disable-static --disable-tests
make
make -j1 install
install -t /usr/share/licenses/libappindicator -Dm644 COPYING{,.LGPL.2.1}
popd
rm -rf libappindicator_12.10.1+20.10.20200706.1.orig
# mesa-utils.
tar -xf ../sources/mesa-demos-9.0.0.tar.xz
pushd mesa-demos-9.0.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
install -t /usr/bin -Dm755 build/src/{egl/opengl/eglinfo,xdemos/glx{info,gears}}
install -t /usr/share/licenses/mesa-utils -Dm644 /usr/share/licenses/mesa/license.rst
popd
rm -rf mesa-demos-9.0.0
# adwaita-icon-theme.
tar -xf ../sources/adwaita-icon-theme-50.0.tar.gz
pushd adwaita-icon-theme-50.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/adwaita-icon-theme -Dm644 COPYING{,_CCBYSA3,_LGPL}
popd
rm -rf adwaita-icon-theme-50.0
# gnome-themes-extra (for accessibility - provides high contrast theme).
tar -xf ../sources/gnome-themes-extra-3.28.tar.xz
pushd gnome-themes-extra-3.28
./configure --prefix=/usr --disable-gtk2-engine
make
make install
install -t /usr/share/licenses/gnome-themes-extra -Dm644 LICENSE
popd
rm -rf gnome-themes-extra-3.28
# gtk-layer-shell.
tar -xf ../sources/gtk-layer-shell-0.9.1.tar.gz
pushd gtk-layer-shell-0.9.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk-layer-shell -Dm644 LICENSE_{GPL,LGPL,MIT}.txt
popd
rm -rf gtk-layer-shell-0.9.1
# gcab.
tar -xf ../sources/gcab-1.6.tar.gz
pushd gcab-1.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gcab -Dm644 COPYING
popd
rm -rf gcab-1.6
# keybinder.
tar -xf ../sources/keybinder-3.0-0.3.2.tar.gz
pushd keybinder-3.0-0.3.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/keybinder -Dm644 COPYING
popd
rm -rf keybinder-3.0-0.3.2
# libgee.
tar -xf ../sources/libgee-0.20.8.tar.gz
pushd libgee-0.20.8
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libgee -Dm644 COPYING
popd
rm -rf libgee-0.20.8
# exiv2.
tar -xf ../sources/exiv2-0.28.8.tar.gz
pushd exiv2-0.28.8
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DEXIV2_ENABLE_CURL=YES -DEXIV2_ENABLE_NLS=YES -DEXIV2_ENABLE_VIDEO=YES -DEXIV2_ENABLE_WEBREADY=YES -DEXIV2_BUILD_SAMPLES=NO -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/exiv2 -Dm644 COPYING
popd
rm -rf exiv2-0.28.8
# meson-python.
tar -xf ../sources/meson_python-0.20.0.tar.gz
pushd meson_python-0.20.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/meson-python -Dm644 LICENSE LICENSES/MIT.txt
popd
rm -rf meson_python-0.20.0
# PyCairo.
tar -xf ../sources/pycairo-1.29.0.tar.gz
pushd pycairo-1.29.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pycairo -Dm644 COPYING{,-LGPL-2.1,-MPL-1.1}
popd
rm -rf pycairo-1.29.0
# PyGObject.
tar -xf ../sources/pygobject-3.56.3.tar.gz
pushd pygobject-3.56.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pygobject -Dm644 COPYING
popd
rm -rf pygobject-3.56.3
# dbus-python.
tar -xf ../sources/dbus-python-1.4.0.tar.xz
pushd dbus-python-1.4.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
tools/generate-pkginfo.py 1.4.0 PKG-INFO
ninja -C build install
install -t "/usr/lib/$(readlink /usr/bin/python3)/site-packages/dbus_python-1.4.0-py$(readlink /usr/bin/python3 | sed -e 's/python//').egg-info" -Dm644 PKG-INFO
install -t /usr/share/licenses/dbus-python -Dm644 COPYING
popd
rm -rf dbus-python-1.4.0
# python-dbusmock.
tar -xf ../sources/python_dbusmock-0.38.1.tar.gz
pushd python_dbusmock-0.38.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/python-dbusmock -Dm644 COPYING
popd
rm -rf python_dbusmock-0.38.1
# pycups.
tar -xf ../sources/pycups-2.0.4.tar.gz
pushd pycups-2.0.4
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pycups -Dm644 COPYING
popd
rm -rf pycups-2.0.4
# firewalld.
tar -xf ../sources/firewalld-2.3.0.tar.bz2
pushd firewalld-2.3.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin
make
make install
rm -f /etc/xdg/autostart/firewall-applet.desktop
install -t /usr/share/licenses/firewalld -Dm644 COPYING
popd
rm -rf firewalld-2.3.0
# blueprint-compiler.
tar -xf ../sources/blueprint-compiler-0.20.4.tar.gz
pushd blueprint-compiler-0.20.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/blueprint-compiler -Dm644 COPYING
popd
rm -rf blueprint-compiler-0.20.4
# gexiv2.
tar -xf ../sources/gexiv2-0.14.6.tar.gz
pushd gexiv2-gexiv2-0.14.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gexiv2 -Dm644 COPYING
popd
rm -rf gexiv2-gexiv2-0.14.6
# libpeas.
tar -xf ../sources/libpeas-1.36.0.tar.gz
pushd libpeas-libpeas-1.36.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddemos=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libpeas -Dm644 COPYING
popd
rm -rf libpeas-libpeas-1.36.0
# libjcat.
tar -xf ../sources/libjcat-0.2.3.tar.xz
pushd libjcat-0.2.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libjcat -Dm644 LICENSE
popd
rm -rf libjcat-0.2.3
# libgxps.
tar -xf ../sources/libgxps-0.3.2.tar.gz
pushd libgxps-0.3.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libgxps -Dm644 COPYING
popd
rm -rf libgxps-0.3.2
# djvulibre.
tar -xf ../sources/djvulibre-3.5.28.tar.gz
pushd djvulibre-3.5.28
./configure --prefix=/usr --disable-desktopfiles
make
make install
for i in 22 32 48 64; do install -m644 desktopfiles/prebuilt-hi${i}-djvu.png /usr/share/icons/hicolor/${i}x${i}/mimetypes/image-vnd.djvu.mime.png; done
install -t /usr/share/licenses/djvulibre -Dm644 COPYING COPYRIGHT
popd
rm -rf djvulibre-3.5.28
# libraw.
tar -xf ../sources/LibRaw-0.22.1.tar.gz
pushd LibRaw-0.22.1
autoreconf -fi
./configure --prefix=/usr --enable-jasper --enable-jpeg --enable-lcms --disable-static
make
make install
install -t /usr/share/licenses/libraw -Dm644 COPYRIGHT LICENSE.LGPL
popd
rm -rf LibRaw-0.22.1
# libogg.
tar -xf ../sources/libogg-1.3.6.tar.xz
pushd libogg-1.3.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libogg -Dm644 COPYING
popd
rm -rf libogg-1.3.6
# libvorbis.
tar -xf ../sources/libvorbis-1.3.7.tar.xz
pushd libvorbis-1.3.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libvorbis -Dm644 COPYING
popd
rm -rf libvorbis-1.3.7
# libtheora.
tar -xf ../sources/libtheora-1.2.0.tar.xz
pushd libtheora-1.2.0
./configure --prefix=/usr --disable-examples --disable-static
make
make install
install -t /usr/share/licenses/libtheora -Dm644 COPYING LICENSE
popd
rm -rf libtheora-1.2.0
# Speex.
tar -xf ../sources/speex-1.2.1.tar.gz
pushd speex-1.2.1
./configure --prefix=/usr --disable-static --enable-binaries
make
make install
install -t /usr/share/licenses/speex -Dm644 COPYING
popd
rm -rf speex-1.2.1
# SpeexDSP.
tar -xf ../sources/speexdsp-1.2.1.tar.gz
pushd speexdsp-1.2.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/speexdsp -Dm644 COPYING
popd
rm -rf speexdsp-1.2.1
# Opus.
tar -xf ../sources/opus-1.6.1.tar.gz
pushd opus-1.6.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/opus -Dm644 COPYING
popd
rm -rf opus-1.6.1
# FLAC.
tar -xf ../sources/flac-1.5.0.tar.xz
pushd flac-1.5.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/flac -Dm644 COPYING.{FDL,GPL,LGPL,Xiph}
popd
rm -rf flac-1.5.0
# libsndfile (will be rebuilt later with LAME/mpg123 for MPEG support).
tar -xf ../sources/libsndfile-1.2.2.tar.xz
pushd libsndfile-1.2.2
patch -Np1 -i ../../patches/libsndfile-1.2.2-gcc15.patch
./configure --prefix=/usr --disable-static --disable-mpeg
make
make install
install -t /usr/share/licenses/libsndfile -Dm644 COPYING
popd
rm -rf libsndfile-1.2.2
# libsamplerate.
tar -xf ../sources/libsamplerate-0.2.2.tar.xz
pushd libsamplerate-0.2.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libsamplerate -Dm644 COPYING
popd
rm -rf libsamplerate-0.2.2
# alsa-utils.
tar -xf ../sources/alsa-utils-1.2.16.tar.bz2
pushd alsa-utils-1.2.16
./configure --prefix=/usr --sbindir=/usr/bin --disable-alsaconf --with-systemdsystemunitdir=/usr/lib/systemd/system --with-udev-rules-dir=/usr/lib/udev/rules.d
make
make install
install -t /usr/share/licenses/alsa-utils -Dm644 COPYING
popd
rm -rf alsa-utils-1.2.16
# JACK2.
tar -xf ../sources/jack2-1.9.22.tar.gz
pushd jack2-1.9.22
patch -Np1 -i ../../patches/jack2-1.9.22-updatewaf.patch
./waf configure --prefix=/usr --htmldir=/usr/share/doc/jack2 --autostart=none --classic --dbus --systemd-unit
./waf build -j$(nproc)
./waf install
install -t /usr/share/licenses/jack2 -Dm644 COPYING
popd
rm -rf jack2-1.9.22
# SBC.
tar -xf ../sources/sbc-2.2.tar.xz
pushd sbc-2.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/sbc -Dm644 COPYING COPYING.LIB
popd
rm -rf sbc-2.2
# ldac.
tar -xf ../sources/ldacBT-2.0.2.3.tar.gz
pushd ldacBT
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/ldac -Dm644 LICENSE
popd
rm -rf ldacBT
# libfreeaptx.
tar -xf ../sources/libfreeaptx-0.2.2.tar.gz
pushd libfreeaptx-0.2.2
make PREFIX=/usr CC=gcc CFLAGS="$CFLAGS"
make PREFIX=/usr install
install -t /usr/share/licenses/libfreeaptx -Dm644 COPYING
popd
rm -rf libfreeaptx-0.2.2
# liblc3.
tar -xf ../sources/liblc3-1.1.3.tar.gz
pushd liblc3-1.1.3
sed -i "s|install_rpath: join_paths(get_option('prefix'), get_option('libdir'))||" tools/meson.build
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dpython=true -Dtools=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/liblc3 -Dm644 LICENSE
popd
rm -rf liblc3-1.1.3
# libical.
tar -xf ../sources/libical-4.0.2.tar.gz
pushd libical-4.0.2
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DLIBICAL_BUILD_DOCS=OFF -DLIBICAL_BUILD_TESTING=OFF -DLIBICAL_GLIB_VAPI=ON -DLIBICAL_GOBJECT_INTROSPECTION=ON -DLIBICAL_JAVA_BINDINGS=OFF -Wno-dev -G Ninja -B build
ninja -C build -j1
ninja -C build install
install -t /usr/share/licenses/libical -Dm644 COPYING.LESSER.txt LICENSE.txt LICENSES/*
popd
rm -rf libical-4.0.2
# BlueZ.
tar -xf ../sources/bluez-5.87.tar.xz
pushd bluez-5.87
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --enable-library
make
make install
ln -sf ../libexec/bluetooth/bluetoothd /usr/bin
install -dm755 /etc/bluetooth
install -m644 src/main.conf /etc/bluetooth/main.conf
systemctl enable bluetooth
systemctl enable --global obex
install -t /usr/share/licenses/bluez -Dm644 COPYING COPYING.LIB
popd
rm -rf bluez-5.87
# Avahi.
tar -xf ../sources/avahi-0.8.tar.gz
pushd avahi-0.8
echo 'u avahi 965 "Avahi Daemon Owner" /var/run/avahi-daemon' > /usr/lib/sysusers.d/avahi.conf
systemd-sysusers
patch -Np1 -i ../../patches/avahi-0.8-unifiedfixes.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-mono --disable-monodoc --disable-python --disable-qt3 --disable-qt4 --disable-qt5 --disable-rpath --disable-static --enable-compat-libdns_sd --with-distro=none
make
make install
systemctl enable avahi-daemon
install -t /usr/share/licenses/avahi -Dm644 LICENSE
popd
rm -rf avahi-0.8
# nss-mdns.
tar -xf ../sources/nss-mdns-0.15.1.tar.gz
pushd nss-mdns-0.15.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/nss-mdns -Dm644 LICENSE
popd
rm -rf nss-mdns-0.15.1
# ipp-usb.
tar -xf ../sources/ipp-usb-0.9.30.tar.gz
pushd ipp-usb-0.9.30
sed -i 's|ExecStart=/sbin|ExecStart=/usr/bin|' systemd-udev/ipp-usb.service
cat >> systemd-udev/ipp-usb.service << "END"

[Install]
WantedBy=multi-user.target
END
GOFLAGS="-trimpath -buildmode=pie -ldflags=-linkmode=external" make
install -t /usr/bin -Dm755 ipp-usb
install -t /usr/share/man/man8 -Dm644 ipp-usb.8
install -t /usr/share/ipp-usb/quirks -Dm644 ipp-usb-quirks/*
install -t /usr/lib/systemd/system -Dm644 systemd-udev/ipp-usb.service
install -t /usr/lib/udev/rules.d -Dm644 systemd-udev/71-ipp-usb.rules
systemctl enable ipp-usb
install -t /usr/share/licenses/ipp-usb -Dm644 LICENSE
popd
rm -rf ipp-usb-0.9.30
# PulseAudio.
tar -xf ../sources/pulseaudio-17.0.tar.xz
pushd pulseaudio-17.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddatabase=gdbm -Ddoxygen=false -Dtests=false
ninja -C build
ninja -C build install
rm -f /etc/dbus-1/system.d/pulseaudio-system.conf
install -t /usr/share/licenses/pulseaudio -Dm644 LICENSE GPL LGPL
popd
rm -rf pulseaudio-17.0
# libao.
tar -xf ../sources/libao-1.2.2.tar.bz2
pushd libao-1.2.2
autoreconf -fi
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" ./configure --prefix=/usr --disable-static --disable-esd --enable-alsa-mmap
make
make install
install -t /usr/share/licenses/libao -Dm644 COPYING
popd
rm -rf libao-1.2.2
# pcaudiolib.
tar -xf ../sources/pcaudiolib-1.3.tar.gz
pushd pcaudiolib-1.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/pcaudiolib -Dm644 COPYING
popd
rm -rf pcaudiolib-1.3
# espeak-ng.
tar -xf ../sources/espeak-ng-1.52.0.tar.gz
pushd espeak-ng-1.52.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_SKIP_INSTALL_RPATH=ON -DBUILD_SHARED_LIBS=ON -DESPEAK_COMPAT=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/espeak-ng -Dm644 COPYING{,.{APACHE,BSD2,UCD}}
popd
rm -rf espeak-ng-1.52.0
# speech-dispatcher.
tar -xf ../sources/speech-dispatcher-0.12.1.tar.gz
pushd speech-dispatcher-0.12.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --without-baratinoo --without-espeak --without-flite --without-ibmtts --without-kali --without-voxin
make
make install
rm -f /etc/speech-dispatcher/modules/{cicero,espeak,espeak-mbrola-generic,flite}.conf
rm -f /usr/libexec/speech-dispatcher-modules/sd_cicero
sed -i 's/#AddModule "espeak-ng"/AddModule "espeak-ng"/' /etc/speech-dispatcher/speechd.conf
systemctl enable speech-dispatcherd
install -t /usr/share/licenses/speech-dispatcher -Dm644 COPYING.{GPL-2,GPL-3,LGPL}
popd
rm -rf speech-dispatcher-0.12.1
# SDL3 (initial build - will be rebuilt later for PipeWire support).
tar -xf ../sources/SDL3-3.4.12.tar.gz
pushd SDL3-3.4.12
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSDL_STATIC=OFF -DSDL_RPATH=OFF -DSDL_PIPEWIRE=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/sdl3 -Dm644 LICENSE.txt
popd
rm -rf SDL3-3.4.12
# sdl2-compat (provides SDL2).
tar -xf ../sources/sdl2-compat-2.32.70.tar.gz
pushd sdl2-compat-2.32.70
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSDL2COMPAT_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
ln -sf sdl2-compat.pc /usr/lib/pkgconfig/sdl2.pc
install -t /usr/share/licenses/sdl2-compat -Dm644 LICENSE.txt
ln -sf sdl2-compat /usr/share/licenses/sdl2
popd
rm -rf sdl2-compat-2.32.70
# sdl12-compat (provides SDL).
tar -xf ../sources/sdl12-compat-release-1.2.76.tar.gz
pushd sdl12-compat-release-1.2.76
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSDL12TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/sdl12-compat -Dm644 LICENSE.txt
ln -sf sdl12-compat /usr/share/licenses/sdl
popd
rm -rf sdl12-compat-release-1.2.76
# dmidecode.
tar -xf ../sources/dmidecode-3.6.tar.xz
pushd dmidecode-3.6
make prefix=/usr CFLAGS="$CFLAGS"
make prefix=/usr install
install -t /usr/share/licenses/dmidecode -Dm644 LICENSE
popd
rm -rf dmidecode-3.6
# laptop-detect.
tar -xf ../sources/laptop-detect_0.16.tar.xz
pushd laptop-detect-0.16
sed -e "s/@VERSION@/0.16/g" < laptop-detect.in > laptop-detect
install -Dm755 laptop-detect /usr/bin/laptop-detect
install -Dm644 laptop-detect.1 /usr/share/man/man1/laptop-detect.1
install -t /usr/share/licenses/laptop-detect -Dm644 debian/copyright
popd
rm -rf laptop-detect-0.16
# flashrom.
tar -xf ../sources/flashrom-v1.7.0.tar.xz
pushd flashrom-v1.7.0
CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" meson setup build --prefix=/usr --sbindir=bin --buildtype=plain -Dprogrammer=all -Dtests=disabled
ninja -C build
ninja -C build install
rm -f /usr/lib/libflashrom.a
sed 's|GROUP="plugdev"|TAG+="uaccess"|g' util/flashrom_udev.rules > /usr/lib/udev/rules.d/70-flashrom.rules
install -t /usr/share/licenses/flashrom -Dm644 COPYING.rst
popd
rm -rf flashrom-v1.7.0
# rrdtool.
tar -xf ../sources/rrdtool-1.9.0.tar.gz
pushd rrdtool-1.9.0
sed -i 's|/ruby/extconf.rb|/ruby/extconf.rb --vendor|' bindings/Makefile.am
sed -i 's|LUA_INSTALL_CMOD="/usr/local/lib/lua/$lua_vdot"|LUA_INSTALL_CMOD="/usr/lib/lua/$lua_vdot"|' configure.ac
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-rpath --disable-static --enable-lua --enable-lua-site-install --enable-perl --enable-perl-site-install --with-perl-options="INSTALLDIRS=vendor" --enable-python --enable-ruby --enable-ruby-site-install --enable-tcl --enable-tcl-site
make
make install
install -t /usr/share/licenses/rrdtool -Dm644 COPYRIGHT LICENSE
popd
rm -rf rrdtool-1.9.0
# lm-sensors.
tar -xf ../sources/lm-sensors-3-6-0.tar.gz
pushd lm-sensors-3-6-0
sed -i 's/-Wl,-rpath,$(LIBDIR)//' Makefile
make PREFIX=/usr SBINDIR=/usr/bin MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord CFLAGS="$CFLAGS -Wno-error=incompatible-pointer-types"
make PREFIX=/usr SBINDIR=/usr/bin MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord install
install -t /usr/share/licenses/lm-sensors -Dm644 COPYING COPYING.LGPL
popd
rm -rf lm-sensors-3-6-0
# libpcap.
tar -xf ../sources/libpcap-1.10.6.tar.xz
pushd libpcap-1.10.6
autoreconf -fi
./configure --prefix=/usr --enable-ipv6 --enable-bluetooth --enable-usb --with-libnl
make
make install
rm -f /usr/lib/libpcap.a
install -t /usr/share/licenses/libpcap -Dm644 LICENSE
popd
rm -rf libpcap-1.10.6
# Net-SNMP.
tar -xf ../sources/net-snmp-5.9.4.tar.gz
pushd net-snmp-5.9.4
patch -Np1 -i ../../patches/net-snmp-5.9.4-upstreamfixes.patch
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --mandir=/usr/share/man --disable-static --enable-blumenthal-aes --enable-ipv6 --enable-ucd-snmp-compatibility --with-default-snmp-version=3 --with-logfile=/var/log/snmpd.log --with-mib-modules="host misc/ipfwacc ucd-snmp/diskio tunnel ucd-snmp/dlmod ucd-snmp/lmsensorsMib" --with-persistent-directory=/var/net-snmp --with-sys-contact=root@localhost --with-sys-location=Unknown --without-pcre --without-python-modules
make NETSNMP_DONT_CHECK_VERSION=1
make -j1 INSTALLDIRS=vendor install
python -m build -nw -o python/dist python
python -m installer --compile-bytecode 1 python/dist/*.whl
install -t /usr/share/licenses/net-snmp -Dm644 COPYING
popd
rm -rf net-snmp-5.9.4
# ppp.
tar -xf ../sources/ppp-2.5.2.tar.gz
pushd ppp-2.5.2
patch -Np1 -i ../../patches/ppp-2.4.9-extrafiles.patch
patch -Np1 -i ../../patches/ppp-2.5.2-gcc15.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run --sbindir=/usr/bin --enable-cbcp --enable-multilink --enable-systemd
make
make install
install -t /usr/bin -Dm755 scripts/p{on,off,log}
install -t /etc/ppp -Dm755 etc/{ip{,v6}-{down,up},options}
install -Dm600 etc.ppp/chap-secrets.example /etc/ppp/pap-secrets/chap-secrets
install -Dm600 etc.ppp/pap-secrets.example /etc/ppp/pap-secrets/pap-secrets
install -t /usr/share/man/man1 -Dm644 scripts/pon.1
ln -sf pon.1 /usr/share/man/man1/poff.1
ln -sf pon.1 /usr/share/man/man1/plog.1
install -dm755 /etc/ppp/peers
chmod 0755 /usr/lib/pppd/*/*.so
install -dm755 /usr/share/licenses/ppp
cat > /usr/share/licenses/ppp/LICENSE << "END"
All of the code can be freely used and redistributed.  The individual
source files each have their own copyright and permission notice.
Pppd, pppstats and pppdump are under BSD-style notices.  Some of the
pppd plugins are GPL'd.  Chat is public domain.
END
popd
rm -rf ppp-2.5.2
# Vim.
tar -xf ../sources/vim-9.2.0782.tar.gz
pushd vim-9.2.0782
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
echo '#define SYS_GVIMRC_FILE "/etc/gvimrc"' >> src/feature.h
./configure --prefix=/usr --with-features=huge --enable-gpm --enable-gui=gtk3 --with-tlib=ncursesw --enable-luainterp --enable-perlinterp --enable-python3interp=dynamic --enable-rubyinterp --enable-tclinterp --with-tclsh=tclsh --with-compiledby="MassOS"
make
make install
cat > /etc/vimrc << "END"
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif
END
ln -s vim /usr/bin/vi
for L in /usr/share/man/{,*/}man1/vim.1; do ln -s vim.1 $(dirname $L)/vi.1; done
rm -f /usr/share/applications/vim.desktop
rm -f /usr/share/applications/gvim.desktop
install -t /usr/share/licenses/vim -Dm644 LICENSE
popd
rm -rf vim-9.2.0782
# libwpe.
tar -xf ../sources/libwpe-1.16.2.tar.xz
pushd libwpe-1.16.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libwpe -Dm644 COPYING
popd
rm -rf libwpe-1.16.2
# OpenJPEG.
tar -xf ../sources/openjpeg-2.5.4.tar.gz
pushd openjpeg-2.5.4
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
cp -r doc/man /usr/share
install -t /usr/share/licenses/openjpeg -Dm644 LICENSE
popd
rm -rf openjpeg-2.5.4
# libsecret.
tar -xf ../sources/libsecret-0.21.7.tar.gz
pushd libsecret-0.21.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgtk_doc=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsecret -Dm644 COPYING{,.TESTS}
popd
rm -rf libsecret-0.21.7
# Gcr.
tar -xf ../sources/gcr-3.41.2.tar.gz
pushd gcr-3.41.2
sed -i 's|"/desktop|"/org|' schema/*.xml
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dssh_agent=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gcr -Dm644 COPYING
popd
rm -rf gcr-3.41.2
# Gcr4.
tar -xf ../sources/gcr-4.4.0.1.tar.gz
pushd gcr-4.4.0.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gcr4 -Dm644 COPYING
popd
rm -rf gcr-4.4.0.1
# pinentry.
tar -xf ../sources/pinentry-1.3.3.tar.bz2
pushd pinentry-1.3.3
./configure --prefix=/usr --enable-pinentry-tty
make
make install
install -t /usr/share/licenses/pinentry -Dm644 COPYING
popd
rm -rf pinentry-1.3.3
# AccountsService.
tar -xf ../sources/accountsservice-26.27.3.tar.bz2
pushd accountsservice-26.27.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dadmin_group=wheel -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/accountsservice -Dm644 COPYING
popd
rm -rf accountsservice-26.27.3
# polkit-gnome.
tar -xf ../sources/polkit-gnome-0.105.tar.xz
pushd polkit-gnome-0.105
patch -Np1 -i ../../patches/polkit-gnome-0.105-upstreamfixes.patch
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu"
make
make install
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop << "END"
[Desktop Entry]
Name=PolicyKit Authentication Agent
Comment=PolicyKit Authentication Agent
Exec=/usr/libexec/polkit-gnome-authentication-agent-1
Terminal=false
Type=Application
Categories=
NoDisplay=true
OnlyShowIn=GNOME;XFCE;Unity;
AutostartCondition=GNOME3 unless-session gnome
END
install -t /usr/share/licenses/polkit-gnome -Dm644 COPYING
popd
rm -rf polkit-gnome-0.105
# gnome-keyring.
tar -xf ../sources/gnome-keyring-48.0.tar.gz
pushd gnome-keyring-48.0
sed -i 's|"/desktop|"/org|' schema/*.xml
meson setup build1 --prefix=/usr --sbindir=bin --buildtype=minsize -Ddebug-mode=false -Dssh-agent=true
ninja -C build1
ninja -C build1 install
install -t /usr/share/licenses/gnome-keyring -Dm644 COPYING COPYING.LIB
popd
rm -rf gnome-keyring-48.0
# Poppler.
tar -xf ../sources/poppler-26.07.0.tar.xz
pushd poppler-26.07.0
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_CPP_TESTS=OFF -DBUILD_GTK_TESTS=OFF -DBUILD_MANUAL_TESTS=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF -DENABLE_UNSTABLE_API_ABI_HEADERS=ON -DENABLE_ZLIB_UNCOMPRESS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/poppler -Dm644 COPYING{,3}
popd
rm -rf poppler-26.07.0
# poppler-data.
tar -xf ../sources/poppler-data-0.4.12.tar.gz
pushd poppler-data-0.4.12
make prefix=/usr install
install -t /usr/share/licenses/poppler-data -Dm644 COPYING{,.adobe,.gpl2}
popd
rm -rf poppler-data-0.4.12
# GhostScript.
tar -xf ../sources/ghostscript-10.07.0.tar.xz
pushd ghostscript-10.07.0
rm -rf cups/libs freetype lcms2mt jpeg leptonica libpng openjpeg tesseract zlib
./configure --prefix=/usr --disable-compile-inits --disable-hidden-visibility --enable-dynamic --enable-fontconfig --enable-freetype --enable-openjpeg --with-drivers=ALL --with-system-libtiff --with-x
make so
make soinstall
install -t /usr/include/ghostscript -Dm644 base/*.h
ln -sf gsc /usr/bin/gs
ln -sfn ghostscript /usr/include/ps
install -t /usr/share/licenses/ghostscript -Dm644 LICENSE
popd
rm -rf ghostscript-10.07.0
# libcupsfilters.
tar -xf ../sources/libcupsfilters-2.1.1.tar.xz
pushd libcupsfilters-2.1.1
./configure --prefix=/usr --disable-static --disable-mutool
make
make install
install -t /usr/share/licenses/libcupsfilters -Dm644 LICENSE
popd
rm -rf libcupsfilters-2.1.1
# libppd.
tar -xf ../sources/libppd-2.1.1.tar.xz
pushd libppd-2.1.1
./configure --prefix=/usr --disable-static --disable-mutool --enable-ppdc-utils --with-cups-rundir=/run/cups
make
make install
install -t /usr/share/licenses/libppd -Dm644 LICENSE
popd
rm -rf libppd-2.1.1
# cups-browsed.
tar -xf ../sources/cups-browsed-2.1.1.tar.xz
pushd cups-browsed-2.1.1
./configure --prefix=/usr --sbindir=/usr/bin --with-cups-rundir=/run/cups --disable-static --without-rcdir
make
make install
install -t /usr/lib/systemd/system -Dm644 daemon/cups-browsed.service
systemctl enable cups-browsed
install -t /usr/share/licenses/cups-browsed -Dm644 COPYING LICENSE
popd
rm -rf cups-browsed-2.1.1
# cups-filters.
tar -xf ../sources/cups-filters-2.0.1.tar.xz
pushd cups-filters-2.0.1
patch -Np1 -i ../../patches/cups-filters-2.0.1-gcc15.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-mutool
make
make install
install -t /usr/share/licenses/cups-filters -Dm644 COPYING LICENSE
popd
rm -rf cups-filters-2.0.1
# cups-pdf.
tar -xf ../sources/cups-pdf_3.0.2.tar.gz
pushd cups-pdf-3.0.2/src
gcc $CFLAGS cups-pdf.c -o cups-pdf -lcups $LDFLAGS
install -t /usr/lib/cups/backend -Dm755 cups-pdf
install -t /usr/share/ppd/cups-pdf -Dm644 ../extra/CUPS-PDF_{,no}opt.ppd
install -t /etc/cups -Dm644 ../extra/cups-pdf.conf
install -t /usr/share/licenses/cups-pdf -Dm644 ../COPYING
popd
rm -rf cups-pdf-3.0.2
# Gutenprint.
tar -xf ../sources/gutenprint-5.3.5.tar.xz
pushd gutenprint-5.3.5
./configure --prefix=/usr --disable-static --disable-static-genppd --disable-test
make
make install
rm -f /usr/lib/gutenprint/5.3/config.summary
install -t /usr/share/licenses/gutenprint -Dm644 COPYING
popd
rm -rf gutenprint-5.3.5
# SANE.
tar -xf ../sources/sane-1.4.0.tar.gz
pushd backends-1.4.0-c7e4b5e35e3d614d2b1181d760a717bfc395a203
patch -Np1 -i ../../patches/sane-1.4.0-glibc243.patch
echo "1.4.0" > .tarball-version
echo "1.4.0" > .version
autoreconf -fi
mkdir -p build; pushd build
../configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-rpath --with-lockdir=/run/lock
make
make install
install -Dm644 tools/udev/libsane.rules /usr/lib/udev/rules.d/65-scanner.rules
install -t /usr/share/licenses/sane -Dm644 ../COPYING ../LICENSE ../README.djpeg
popd; popd
rm -rf backends-1.4.0-c7e4b5e35e3d614d2b1181d760a717bfc395a203
# sane-airscan.
tar -xf ../sources/sane-airscan-0.99.36.tar.gz
pushd sane-airscan-0.99.36
sed -i 's/-Werror //' Makefile
make
make install
ln -sf libsane-airscan.so.1 /usr/lib/sane/libsane-airscan.so
install -t /usr/share/licenses/sane-airscan -Dm644 COPYING LICENSE
popd
rm -rf sane-airscan-0.99.36
# HPLIP.
tar -xf ../sources/hplip-3.25.8.tar.gz
pushd hplip-3.25.8
patch -Np1 -i ../../patches/hplip-3.25.8-manyfixes.patch
AUTOMAKE="automake --foreign" autoreconf -fi
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=return-mismatch" ./configure --prefix=/usr --sbindir=/usr/bin --enable-cups-drv-install --enable-hpcups-install --disable-imageProcessor-build --enable-pp-build --disable-qt4 --disable-qt5
make
make -j1 rulesdir=/usr/lib/udev/rules.d install
rm -rf /usr/share/hal
rm -f /etc/xdg/autostart/hplip-systray.desktop
rm -f /usr/share/applications/hp{lip,-uiscan}.desktop
rm -f /usr/bin/hp-{uninstall,upgrade} /usr/share/hplip/{uninstall,upgrade}.py
install -t /usr/share/licenses/hplip -Dm644 COPYING
popd
rm -rf hplip-3.25.8
# system-config-printer.
tar -xf ../sources/system-config-printer-1.5.18.tar.xz
pushd system-config-printer-1.5.18
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-rpath --with-cups-serverbin-dir=/usr/lib/cups --with-systemdsystemunitdir=/usr/lib/systemd/system --with-udev-rules --with-udevdir=/usr/lib/udev
sed -e 's|$(PYTHON) setup.py build|$(PYTHON) -m build -nw -o dist|' -e 's|$(PYTHON) setup.py install --prefix=$(DESTDIR)$(prefix)|$(PYTHON) -m installer --compile-bytecode 1 dist/*.whl|' Makefile
make
make install
install -t /usr/share/licenses/system-config-printer -Dm644 COPYING
popd
rm -rf system-config-printer-1.5.18
# Tk.
tar -xf ../sources/tk8.6.18-src.tar.gz
pushd tk8.6.18/unix
./configure --prefix=/usr --mandir=/usr/share/man --enable-64bit
make
sed -e "s@^\(TK_SRC_DIR='\).*@\1/usr/include'@" -e "/TK_B/s@='\(-L\)\?.*unix@='\1/usr/lib@" -i tkConfig.sh
make install install-private-headers
ln -sf wish8.6 /usr/bin/wish
chmod 755 /usr/lib/libtk8.6.so
install -t /usr/share/licenses/tk -Dm644 license.terms
popd
rm -rf tk8.6.18
# Python (rebuild to support SQLite and Tk).
tar -xf ../sources/Python-3.14.6.tar.xz
pushd Python-3.14.6
patch -Np1 -i ../../patches/python-3.14.5-openssl4.patch
./configure --prefix=/usr --enable-shared --enable-optimizations --with-system-expat --with-system-libmpdec --without-ensurepip --without-static-libpython --disable-test-modules
make
make install
popd
rm -rf Python-3.14.6
# dnspython.
tar -xf ../sources/dnspython-2.7.0.tar.gz
pushd dnspython-2.7.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/dnspython -Dm644 LICENSE
popd
rm -rf dnspython-2.7.0
# chardet.
tar -xf ../sources/chardet-7.4.3.tar.gz
pushd chardet-7.4.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/chardet -Dm644 LICENSE
popd
rm -rf chardet-7.4.3
# charset-normalizer.
tar -xf ../sources/charset_normalizer-3.4.7.tar.gz
pushd charset_normalizer-3.4.7
python -m build -nw -o dist --skip-dependency-check
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/charset-normalizer -Dm644 LICENSE
popd
rm -rf charset_normalizer-3.4.7
# idna.
tar -xf ../sources/idna-3.18.tar.gz
pushd idna-3.18
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/idna -Dm644 LICENSE.md
popd
rm -rf idna-3.18
# cffi.
tar -xf ../sources/cffi-2.0.0.tar.gz
pushd cffi-2.0.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/cffi -Dm644 LICENSE
popd
rm -rf cffi-2.0.0
# glad.
tar -xf ../sources/glad-2.0.8.tar.gz
pushd glad-2.0.8
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/glad -Dm644 LICENSE
popd
rm -rf glad-2.0.8
# setuptools-rust.
tar -xf ../sources/setuptools-rust-1.12.1.tar.gz
pushd setuptools-rust-1.12.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/setuptools-rust -Dm644 LICENSE
popd
rm -rf setuptools-rust-1.12.1
# maturin.
tar -xf ../sources/maturin-1.14.1.tar.gz
pushd maturin-1.14.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/maturin -Dm644 license-{apache,mit}
popd
rm -rf maturin-1.14.1
# cryptography.
tar -xf ../sources/cryptography-48.0.0.tar.gz
pushd cryptography-48.0.0
CC=clang RUSTFLAGS="$RUSTFLAGS -Clinker-plugin-lto -Clinker=clang -Clink-arg=-fuse-ld=lld" python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/cryptography -Dm644 LICENSE{,.APACHE,.BSD}
popd
rm -rf cryptography-48.0.0
# pyopenssl.
tar -xf ../sources/pyopenssl-25.0.0.tar.gz
pushd pyopenssl-25.0.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyopenssl -Dm644 LICENSE
popd
rm -rf pyopenssl-25.0.0
# urllib3.
tar -xf ../sources/urllib3-2.7.0.tar.gz
pushd urllib3-2.7.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/urllib3 -Dm644 LICENSE.txt
popd
rm -rf urllib3-2.7.0
# requests.
tar -xf ../sources/requests-2.34.2.tar.gz
pushd requests-2.34.2
patch -Np1 -i ../../patches/requests-2.33.1-systemcertificates.patch
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/requests -Dm644 LICENSE
popd
rm -rf requests-2.34.2
# libplist.
tar -xf ../sources/libplist-2.7.0.tar.bz2
pushd libplist-2.7.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libplist -Dm644 COPYING COPYING.LESSER
popd
rm -rf libplist-2.7.0
# libimobiledevice-glue.
tar -xf ../sources/libimobiledevice-glue-1.3.2.tar.bz2
pushd libimobiledevice-glue-1.3.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libimobiledevice-glue -Dm644 COPYING
popd
rm -rf libimobiledevice-glue-1.3.2
# libusbmuxd.
tar -xf ../sources/libusbmuxd-2.1.0.tar.bz2
pushd libusbmuxd-2.1.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libusbmuxd -Dm644 COPYING
popd
rm -rf libusbmuxd-2.1.0
# libtatsu.
tar -xf ../sources/libtatsu-1.0.5.tar.bz2
pushd libtatsu-1.0.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libtatsu -Dm644 COPYING
popd
rm -rf libtatsu-1.0.5
# libimobiledevice.
tar -xf ../sources/libimobiledevice-1.4.0.tar.bz2
pushd libimobiledevice-1.4.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libimobiledevice -Dm644 COPYING COPYING.LESSER
popd
rm -rf libimobiledevice-1.4.0
# ytnef.
tar -xf ../sources/ytnef-2.1.2.tar.gz
pushd ytnef-2.1.2
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/ytnef -Dm644 COPYING
popd
rm -rf ytnef-2.1.2
# JSON (required by smblient 4.16+).
tar -xf ../sources/JSON-4.10.tar.gz
pushd JSON-4.10
perl Makefile.PL INSTALLDIRS=vendor
make
make install
tail -n9 lib/JSON.pm | head -n6 | install -Dm644 /dev/stdin /usr/share/licenses/json/COPYING
popd
rm -rf JSON-4.10
# Parse-Yapp.
tar -xf ../sources/Parse-Yapp-1.21.tar.gz
pushd Parse-Yapp-1.21
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -dm755 /usr/share/licenses/parse-yapp
tail -n14 lib/Parse/Yapp.pm | head -n12 > /usr/share/licenses/parse-yapp/COPYING
popd
rm -rf Parse-Yapp-1.21
# ldb / libwbclient / smbclient (client portions of Samba).
tar -xf ../sources/samba-4.23.3.tar.gz
pushd samba-4.23.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --libdir=/usr/lib --with-pammodulesdir=/usr/lib/security --with-piddir=/run/samba --systemd-install-services --enable-fhs --with-acl-support --with-ads --with-cluster-support --with-ldap --with-pam --with-profiling-data --with-systemd --with-winbind
make
make DESTDIR="$PWD"/staging install
## Remove samba server files, so we install only ldb/libwbclient/smbclient.
rm -rf staging/usr/{libexec,share/{ctdb,locale,samba}}
rm -rf staging/usr/include/samba-4.0/{core,gen_ndr,ndr,samba,util}
rm -rf staging/usr/lib/{$(readlink /usr/bin/python3)/site-packages/samba,security,systemd}
rm -rf staging/usr/lib/samba/{bind9,gensec,idmap,krb5,nss_info,process_model,service,vfs}
find staging/usr/{bin,include/samba-4.0,lib/pkgconfig,share/man} -type f,l ! -name ldbadd ! -name ldbdel ! -name ldbedit ! -name ldbmodify ! -name ldbrename ! -name ldbsearch ! -name net ! -name nmblookup ! -name rpcclient ! -name smbcacls ! -name smbclient ! -name smbcquotas ! -name smbget ! -name smbspool ! -name smbtar ! -name smbtree ! -name ldb.pc ! -name netapi.pc ! -name smbclient.pc ! -name wbclient.pc ! -name ldb.h ! -name ldb_errors.h ! -name ldb_handlers.h ! -name ldb_module.h ! -name ldb_version.h ! -name libsmbclient.h ! -name netapi.h ! -name wbclient.h ! -name ldbadd.1 ! -name ldbdel.1 ! -name ldbedit.1 ! -name ldbmodify.1 ! -name ldbrename.1 ! -name ldbsearch.1 ! -name nmblookup.1 ! -name rpcclient.1 ! -name smbcacls.1 ! -name smbclient.1 ! -name smbcquotas.1 ! -name smbget.1 ! -name smbtar.1 ! -name smbtree.1 ! -name ldb.3 ! -name libsmbclient.7 ! -name net.8 ! -name smbspool.8 -delete
cp -a staging/usr /
ln -sfr /usr/bin/smbspool /usr/lib/cups/backend/smb
ldconfig
install -t /usr/share/licenses/ldb -Dm644 COPYING VFS-License-clarification.txt
install -t /usr/share/licenses/libwbclient -Dm644 COPYING VFS-License-clarification.txt
install -t /usr/share/licenses/smbclient -Dm644 COPYING VFS-License-clarification.txt
popd
rm -rf samba-4.23.3
# mobile-broadband-provider-info.
tar -xf ../sources/mobile-broadband-provider-info-20240407.tar.gz
pushd mobile-broadband-provider-info-20240407
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/mobile-broadband-provider-info -Dm644 COPYING
popd
rm -rf mobile-broadband-provider-info-20240407
# ModemManager.
tar -xf ../sources/ModemManager-1.24.2.tar.gz
pushd ModemManager-1.24.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dpolkit=permissive -Dvapi=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/modemmanager -Dm644 COPYING COPYING.LIB
popd
rm -rf ModemManager-1.24.2
# libndp.
tar -xf ../sources/libndp-1.9.tar.gz
pushd libndp-1.9
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libndp -Dm644 COPYING
popd
rm -rf libndp-1.9
# newt.
tar -xf ../sources/newt-0.52.25.tar.gz
pushd newt-0.52.25
./configure --prefix=/usr --with-gpm-support --with-python=$(readlink /usr/bin/python3)
make
make install
rm -f /usr/lib/libnewt.a
install -t /usr/share/licenses/newt -Dm644 COPYING
popd
rm -rf newt-0.52.25
# UPower.
tar -xf ../sources/upower-v1.91.3.tar.bz2
pushd upower-v1.91.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dinstalled_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/upower -Dm644 COPYING
systemctl enable upower
popd
rm -rf upower-v1.91.3
# power-profiles-daemon.
tar -xf ../sources/power-profiles-daemon-0.30.tar.bz2
pushd power-profiles-daemon-0.30
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/power-profiles-daemon -Dm644 COPYING
systemctl enable power-profiles-daemon
popd
rm -rf power-profiles-daemon-0.30
# NetworkManager.
tar -xf ../sources/NetworkManager-1.58.0.tar.gz
pushd NetworkManager-1.58.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dnmtui=true -Dqt=false -Dselinux=false -Dsession_tracking=systemd -Dtests=no
ninja -C build
ninja -C build install
cat > /usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules << "END"
polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.NetworkManager.settings.modify.system" && (subject.isInGroup("wheel") || subject.isInGroup("netdev")) && subject.local) {
    return polkit.Result.YES;
  }
});
END
cat >> /etc/NetworkManager/NetworkManager.conf << "END"
# Put your custom configuration files in '/etc/NetworkManager/conf.d/'.
[main]
plugins=keyfile
END
install -t /usr/share/licenses/networkmanager -Dm644 COPYING{,.{GFD,LGP}L}
systemctl enable NetworkManager
popd
rm -rf NetworkManager-1.58.0
# libnma / libnma-gtk4
tar -xf ../sources/libnma-1.10.6.tar.gz
pushd libnma-1.10.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgcr=true -Dlibnma_gtk4=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnma -Dm644 COPYING{,.LGPL}
install -t /usr/share/licenses/libnma-gtk4 -Dm644 COPYING{,.LGPL}
popd
rm -rf libnma-1.10.6
# libnotify.
tar -xf ../sources/libnotify-0.8.8.tar.gz
pushd libnotify-0.8.8
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dman=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnotify -Dm644 COPYING
popd
rm -rf libnotify-0.8.8
# startup-notification.
tar -xf ../sources/startup-notification-0.12.tar.gz
pushd startup-notification-0.12
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static
make
make install
install -t /usr/share/licenses/startup-notification -Dm644 COPYING
popd
rm -rf startup-notification-0.12
# libwnck.
tar -xf ../sources/libwnck-43.3.tar.gz
pushd libwnck-43.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libwnck -Dm644 COPYING
popd
rm -rf libwnck-43.3
# network-manager-applet.
tar -xf ../sources/network-manager-applet-1.36.0.tar.bz2
pushd network-manager-applet-1.36.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dselinux=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/network-manager-applet -Dm644 COPYING
popd
rm -rf network-manager-applet-1.36.0
# NetworkManager-openvpn.
tar -xf ../sources/NetworkManager-openvpn-1.12.0.tar.bz2
pushd NetworkManager-openvpn-1.12.0
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
echo 'u nm-openvpn 964 "NetworkManager OpenVPN" -' > /usr/lib/sysusers.d/nm-openvpn.conf
systemd-sysusers
install -t /usr/share/licenses/networkmanager-openvpn -Dm644 COPYING
popd
rm -rf NetworkManager-openvpn-1.12.0
# UDisks.
tar -xf ../sources/udisks-2.11.0.tar.bz2
pushd udisks-2.11.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --enable-available-modules
make
make install
install -t /usr/share/licenses/udisks -Dm644 COPYING
popd
rm -rf udisks-2.11.0
# gsettings-desktop-schemas.
tar -xf ../sources/gsettings-desktop-schemas-50.1.tar.gz
pushd gsettings-desktop-schemas-50.1
sed -i -r 's|"(/system)|"/org/gnome\1|g' schemas/*.in
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gsettings-desktop-schemas -Dm644 COPYING
popd
rm -rf gsettings-desktop-schemas-50.1
# libproxy.
tar -xf ../sources/libproxy-0.5.12.tar.gz
pushd libproxy-0.5.12
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Drelease=true -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libproxy -Dm644 COPYING
popd
rm -rf libproxy-0.5.12
# glib-networking.
tar -xf ../sources/glib-networking-2.80.1.tar.gz
pushd glib-networking-2.80.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glib-networking -Dm644 COPYING
popd
rm -rf glib-networking-2.80.1
# libsoup.
tar -xf ../sources/libsoup-2.74.3.tar.gz
pushd libsoup-2.74.3
patch -Np1 -i ../../patches/libsoup-2.74.3-securityfixes.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false -Dvapi=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsoup -Dm644 COPYING
popd
rm -rf libsoup-2.74.3
# libsoup3.
tar -xf ../sources/libsoup-3.6.5.tar.gz
pushd libsoup-3.6.5
patch -Np1 -i ../../patches/libsoup-3.6.5-securityfixes.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dpkcs11_tests=disabled -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsoup3 -Dm644 COPYING
popd
rm -rf libsoup-3.6.5
# tinysparql.
tar -xf ../sources/tinysparql-3.9.2.tar.gz
pushd tinysparql-3.9.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/tinysparql -Dm644 COPYING{,.{,L}GPL}
ln -sf tinysparql /usr/share/licenses/tracker
popd
rm -rf tinysparql-3.9.2
# osm-gps-map.
tar -xf ../sources/osm-gps-map-1.2.0.tar.gz
pushd osm-gps-map-1.2.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/osm-gps-map -Dm644 COPYING
popd
rm -rf osm-gps-map-1.2.0
# ostree.
tar -xf ../sources/libostree-2026.1.tar.xz
pushd libostree-2026.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --enable-experimental-api --enable-gtk-doc --with-curl --with-dracut --with-ed25519-libsodium --with-modern-grub --with-grub2-mkconfig-path=/usr/bin/grub-mkconfig --with-openssl --without-soup
make
make install
rm -f /etc/dracut.conf.d/ostree.conf
install -t /usr/share/licenses/libostree -Dm644 COPYING
popd
rm -rf libostree-2026.1
# libfyaml.
tar -xf ../sources/libfyaml-0.9.6.tar.gz
pushd libfyaml-0.9.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libfyaml -Dm644 LICENSE
popd
rm -rf libfyaml-0.9.6
# libxmlb.
tar -xf ../sources/libxmlb-0.3.28.tar.xz
pushd libxmlb-0.3.28
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dstemmer=true -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libxmlb -Dm644 LICENSE
popd
rm -rf libxmlb-0.3.28
# AppStream.
tar -xf ../sources/AppStream-1.1.3.tar.xz
pushd AppStream-1.1.3
sed -i "/^subdir('tests\/')$/d" meson.build
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dapidocs=false -Dblake3-support=false -Dcompose=true -Dman=false -Dvapi=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/appstream -Dm644 COPYING
popd
rm -rf AppStream-1.1.3
# appstream-glib.
tar -xf ../sources/appstream_glib_0_8_3.tar.gz
pushd appstream-glib-appstream_glib_0_8_3
sed -e "/^subdir('installed-tests')$/d" -e "/^subdir('tests')$/d" -i data/meson.build
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Drpm=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/appstream-glib -Dm644 COPYING
popd
rm -rf appstream-glib-appstream_glib_0_8_3
# Bubblewrap.
tar -xf ../sources/bubblewrap-0.11.2.tar.xz
pushd bubblewrap-0.11.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/bubblewrap -Dm644 COPYING
popd
rm -rf bubblewrap-0.11.2
# xdg-dbus-proxy.
tar -xf ../sources/xdg-dbus-proxy-0.1.7.tar.xz
pushd xdg-dbus-proxy-0.1.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xdg-dbus-proxy -Dm644 COPYING
popd
rm -rf xdg-dbus-proxy-0.1.7
# Malcontent (initial build without malcontent-ui due to circular dependency).
tar -xf ../sources/malcontent-0.13.0.tar.bz2
pushd malcontent-0.13.0
mkdir -p subprojects/libglib-testing
tar -xf ../../sources/libglib-testing-0.1.1.tar.bz2 -C subprojects/libglib-testing --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dui=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/malcontent -Dm644 COPYING{,-DOCS}
popd
rm -rf malcontent-0.13.0
# Flatpak.
tar -xf ../sources/flatpak-1.18.0.tar.xz
pushd flatpak-1.18.0
patch -Np1 -i ../../patches/flatpak-1.18.0-hardcode-uid.patch
patch -Np1 -i ../../patches/flatpak-1.14.5-flathubrepo.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dsystem_bubblewrap=bwrap -Dsystem_dbus_proxy=xdg-dbus-proxy -Dtests=false
ninja -C build
ninja -C build install
cat >> /etc/profile.d/flatpak.sh << "END"
# Ensure PATH includes Flatpak directories.
if [ -n "$XDG_DATA_HOME" ] && [ -d "$XDG_DATA_HOME/flatpak/exports/bin" ]; then
  PATH="$PATH:$XDG_DATA_HOME/flatpak/exports/bin"
elif [ -n "$HOME" ] && [ -d "$HOME/.local/share/flatpak/exports/bin" ]; then
  PATH="$PATH:$HOME/.local/share/flatpak/exports/bin"
fi
if [ -d /var/lib/flatpak/exports/bin ]; then
  PATH="$PATH:/var/lib/flatpak/exports/bin"
fi
export PATH
END
systemd-sysusers
flatpak remote-add --if-not-exists flathub ./flathub.flatpakrepo
install -t /usr/share/licenses/flatpak -Dm644 COPYING
popd
rm -rf flatpak-1.18.0
# libportal / libportal-gtk3 / libportal-gtk4.
tar -xf ../sources/libportal-0.9.1.tar.xz
pushd libportal-0.9.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbackend-gtk3=enabled -Dbackend-gtk4=enabled -Dbackend-qt5=disabled -Dbackend-qt6=disabled -Ddocs=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libportal -Dm644 COPYING
install -t /usr/share/licenses/libportal-gtk3 -Dm644 COPYING
install -t /usr/share/licenses/libportal-gtk4 -Dm644 COPYING
popd
rm -rf libportal-0.9.1
# geocode-glib.
tar -xf ../sources/geocode-glib-3.26.4.tar.gz
pushd geocode-glib-3.26.4
meson setup build1 --prefix=/usr --buildtype=minsize -Denable-installed-tests=false
meson setup build2 --prefix=/usr --buildtype=minsize -Denable-installed-tests=false -Dsoup2=false
ninja -C build1
ninja -C build2
ninja -C build1 install
ninja -C build2 install
install -t /usr/share/licenses/geocode-glib -Dm644 COPYING.LIB
popd
rm -rf geocode-glib-3.26.4
# GeoClue.
tar -xf ../sources/geoclue-2.8.2.tar.bz2
pushd geoclue-2.8.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/geoclue -Dm644 COPYING{,.LIB}
popd
rm -rf geoclue-2.8.2
# passim.
tar -xf ../sources/passim-0.1.11.tar.xz
pushd passim-0.1.11
patch -Np1 -i ../../patches/passim-0.1.11-hardcode-uid.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
systemd-sysusers
install -t /usr/share/licenses/passim -Dm644 LICENSE
popd
rm -rf passim-0.1.11
# fwupd-efi.
tar -xf ../sources/fwupd-efi-1.8.tar.gz
pushd fwupd-efi-1.8
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Defi_sbat_distro_id=massos -Defi_sbat_distro_summary=MassOS -Defi_sbat_distro_pkgname=fwupd-efi -Defi_sbat_distro_version=1.8 -Defi_sbat_distro_url=https://massos.org
ninja -C build
ninja -C build install
sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt /usr/libexec/fwupd/efi/fwupd"$MBS_ARCH_EFI".efi
install -t /usr/share/licenses/fwupd-efi -Dm644 COPYING
popd
rm -rf fwupd-efi-1.8
# fwupd.
tar -xf ../sources/fwupd-2.1.2.tar.xz
pushd fwupd-2.1.2
patch -Np1 -i ../../patches/fwupd-2.1.2-hardcode-uid.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Defi_binary=false -Dsupported_build=enabled -Dsystemd_unit_user=fwupd -Dtests=false
ninja -C build
ninja -C build install
systemd-sysusers
install -t /usr/share/licenses/fwupd -Dm644 COPYING
popd
rm -rf fwupd-2.1.2
# libcdio.
tar -xf ../sources/libcdio-2.2.0.tar.bz2
pushd libcdio-2.2.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libcdio -Dm644 COPYING
popd
rm -rf libcdio-2.2.0
# libcdio-paranoia.
tar -xf ../sources/libcdio-paranoia-10.2+2.0.2.tar.gz
pushd libcdio-paranoia-10.2+2.0.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libcdio-paranoia -Dm644 COPYING
popd
rm -rf libcdio-paranoia-10.2+2.0.2
# rest (built twice for both ABIs: rest-0.7 and rest-1.0).
tar -xf ../sources/rest-0.8.1.tar.xz
pushd rest-0.8.1
./configure --prefix=/usr --with-ca-certificates=/etc/pki/tls/certs/ca-bundle.crt
make
make install
popd
rm -rf rest-0.8.1
tar -xf ../sources/rest-0.9.1.tar.xz
pushd rest-0.9.1
patch -Np1 -i ../../patches/rest-0.9.1-upstreamfix.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/rest -Dm644 COPYING
popd
rm -rf rest-0.9.1
# wpebackend-fdo.
tar -xf ../sources/wpebackend-fdo-1.16.0.tar.xz
pushd wpebackend-fdo-1.16.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/wpebackend-fdo -Dm644 COPYING
popd
rm -rf wpebackend-fdo-1.16.0
# libass.
tar -xf ../sources/libass-0.17.4.tar.xz
pushd libass-0.17.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libass -Dm644 COPYING
popd
rm -rf libass-0.17.4
# OpenH264.
tar -xf ../sources/openh264-2.6.0.tar.gz
pushd openh264-2.6.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/openh264 -Dm644 LICENSE
popd
rm -rf openh264-2.6.0
# libde265.
tar -xf ../sources/libde265-1.1.1.tar.gz
pushd libde265-1.1.1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libde265 -Dm644 COPYING
popd
rm -rf libde265-1.1.1
# cdparanoia.
tar -xf ../sources/cdparanoia-III-10.2.src.tgz
pushd cdparanoia-III-10.2
patch -Np1 -i ../../patches/cdparanoia-III-10.2-buildfix.patch
./configure --prefix=/usr --mandir=/usr/share/man --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu"
make -j1
make -j1 install
chmod 755 /usr/lib/libcdda_*.so.0.10.2
install -t /usr/share/licenses/cdparanoia -Dm644 COPYING-GPL COPYING-LGPL
popd
rm -rf cdparanoia-III-10.2
# mpg123.
tar -xf ../sources/mpg123-1.33.6.tar.bz2
pushd mpg123-1.33.6
./configure --prefix=/usr --enable-int-quality=yes --with-audio="pulse alsa oss sdl jack sndio"
make
make install
install -t /usr/share/licenses/mpg123 -Dm644 COPYING
popd
rm -rf mpg123-1.33.6
# libvpx.
tar -xf ../sources/libvpx-1.16.0.tar.gz
pushd libvpx-1.16.0
sed -i 's/cp -p/cp/' build/make/Makefile
./configure --prefix=/usr --enable-shared --disable-static --disable-examples --disable-unit-tests
make
make install
install -t /usr/share/licenses/libvpx -Dm644 LICENSE
popd
rm -rf libvpx-1.16.0
# LAME.
tar -xf ../sources/lame3_100.tar.gz
pushd LAME-lame3_100
./configure --prefix=/usr --enable-mp3rtp --enable-nasm --disable-static
make
make install
install -t /usr/share/licenses/lame -Dm644 COPYING LICENSE
popd
rm -rf LAME-lame3_100
# libsndfile (LAME/mpg123 rebuild).
tar -xf ../sources/libsndfile-1.2.2.tar.xz
pushd libsndfile-1.2.2
patch -Np1 -i ../../patches/libsndfile-1.2.2-gcc15.patch
./configure --prefix=/usr --disable-static
make
make install
popd
rm -rf libsndfile-1.2.2
# twolame.
tar -xf ../sources/twolame-0.4.0.tar.gz
pushd twolame-0.4.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/twolame -Dm644 COPYING
popd
rm -rf twolame-0.4.0
# Taglib.
tar -xf ../sources/taglib-2.3.tar.gz
pushd taglib-2.3
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/taglib -Dm644 COPYING.{LGPL,MPL}
popd
rm -rf taglib-2.3
# SoundTouch.
tar -xf ../sources/soundtouch-2.4.1.tar.gz
pushd soundtouch
./bootstrap
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/soundtouch -Dm644 COPYING.TXT
popd
rm -rf soundtouch
# libdv.
tar -xf ../sources/libdv-1.0.0.tar.gz
pushd libdv-1.0.0
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static
make
make install
install -t /usr/share/licenses/libdv -Dm644 COPYING COPYRIGHT
popd
rm -rf libdv-1.0.0
# libdvdread.
tar -xf ../sources/libdvdread-6.1.3.tar.bz2
pushd libdvdread-6.1.3
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdvdread -Dm644 COPYING
popd
rm -rf libdvdread-6.1.3
# libdvdnav.
tar -xf ../sources/libdvdnav-6.1.1.tar.bz2
pushd libdvdnav-6.1.1
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdvdnav -Dm644 COPYING
popd
rm -rf libdvdnav-6.1.1
# libcanberra.
tar -xf ../sources/libcanberra_0.30.orig.tar.xz
pushd libcanberra-0.30
patch -Np1 -i ../../patches/libcanberra-0.30-wayland.patch
./configure --prefix=/usr --disable-oss
make
make -j1 install
install -t /usr/share/licenses/libcanberra -Dm644 LGPL
cat > /etc/X11/xinit/xinitrc.d/40-libcanberra-gtk-module.sh << "END"
#!/bin/bash

# GNOME loads the libcanberra GTK module automatically, but others don't.
if [ "${DESKTOP_SESSION:0:5}" != "gnome" ] && [ -z "${GNOME_DESKTOP_SESSION_ID}" ]; then
  if [ -z "$GTK_MODULES" ]; then
    GTK_MODULES="canberra-gtk-module"
  else
    GTK_MODULES="$GTK_MODULES:canberra-gtk-module"
  fi
  export GTK_MODULES
fi
END
chmod 755 /etc/X11/xinit/xinitrc.d/40-libcanberra-gtk-module.sh
popd
rm -rf libcanberra-0.30
# x264.
tar -xf ../sources/x264-0.165.3223.tar.bz2
pushd x264-0480cb0-0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee
cat > version.sh << "END"
#!/usr/bin/env bash
# Hardcode the version because the git tarball lacks the required data.
cat > /dev/stdout << "EOS"
#define X264_REV 3223
#define X264_REV_DIFF 0
#define X264_VERSION " r3223 0480cb0"
#define X264_POINTVER "0.165.3223 0480cb0"
EOS
END
./configure --prefix=/usr --enable-shared --enable-strip --extra-cflags="-DX264_BIT_DEPTH=0 -DX264_CHROMA_FORMAT=0 -DX264_GPL=1 -DX264_INTERLACED=1"
make
make install
install -t /usr/share/licenses/x264 -Dm644 COPYING
popd
rm -rf x264-0480cb0-0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee
# x265.
tar -xf ../sources/x265_4.2.tar.gz
pushd x265_4.2
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DGIT_ARCHETYPE=1 -Wno-dev -G Ninja -B build -S source
ninja -C build
ninja -C build install
rm -f /usr/lib/libx265.a
install -t /usr/share/licenses/x265 -Dm644 COPYING
popd
rm -rf x265_4.2
# libraw1394.
tar -xf ../sources/libraw1394-2.1.2.tar.xz
pushd libraw1394-2.1.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libraw1394 -Dm644 COPYING.LIB
popd
rm -rf libraw1394-2.1.2
# libavc1394.
tar -xf ../sources/libavc1394-0.5.4.tar.gz
pushd libavc1394-0.5.4
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static
make
make install
install -t /usr/share/licenses/libavc1394 -Dm644 COPYING
popd
rm -rf libavc1394-0.5.4
# libiec61883.
tar -xf ../sources/libiec61883-1.2.0.tar.xz
pushd libiec61883-1.2.0
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static
make
make install
install -t /usr/share/licenses/libiec61883 -Dm644 COPYING
popd
rm -rf libiec61883-1.2.0
# libnice.
tar -xf ../sources/libnice-0.1.22.tar.gz
pushd libnice-0.1.22
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=disabled -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnice -Dm644 COPYING.LGPL
popd
rm -rf libnice-0.1.22
# libbs2b.
tar -xf ../sources/libbs2b-3.1.0.tar.bz2
pushd libbs2b-3.1.0
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --disable-static
make
make install
install -t /usr/share/licenses/libbs2b -Dm644 COPYING
popd
rm -rf libbs2b-3.1.0
# a52dec.
tar -xf ../sources/a52dec-0.8.0.tar.gz
pushd a52dec-0.8.0
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=/usr --mandir=/usr/share/man --enable-shared --disable-static
make
make install
install -t /usr/include/a52dec -Dm644 liba52/a52_internal.h
install -t /usr/share/licenses/a52dec -Dm644 COPYING
popd
rm -rf a52dec-0.8.0
# xvidcore.
tar -xf ../sources/xvidcore-1.3.7.tar.bz2
pushd xvidcore
patch -Np1 -i ../../patches/xvidcore-1.3.7-gcc15.patch
pushd build/generic
./configure --prefix=/usr
make
make install
chmod 755 /usr/lib/libxvidcore.so.4.3
rm -f /usr/lib/libxvidcore.a
install -t /usr/share/licenses/xvidcore -Dm644 ../../LICENSE
popd; popd
rm -rf xvidcore
# libaom.
tar -xf ../sources/libaom-3.14.1.tar.gz
pushd libaom-3.14.1
sed -i 's/aom aom_static/aom/' cmake/aom_install.cmake
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
rm -f /usr/lib/libaom.a
install -t /usr/share/licenses/libaom -Dm644 LICENSE PATENTS
popd
rm -rf libaom-3.14.1
# SVT-AV1.
tar -xf ../sources/SVT-AV1-v4.1.0.tar.bz2
pushd SVT-AV1-v4.1.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DNATIVE=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/svt-av1 -Dm644 {LICENSE{,-BSD2},PATENTS}.md
popd
rm -rf SVT-AV1-v4.1.0
# dav1d.
tar -xf ../sources/dav1d-1.5.3.tar.bz2
pushd dav1d-1.5.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Denable_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/dav1d -Dm644 COPYING
popd
rm -rf dav1d-1.5.3
# rav1e.
tar -xf ../sources/rav1e-0.8.1.tar.gz
pushd rav1e-0.8.1
sed -i "s/git_version(),/\"compiled on $(date +%Y-%m-%d) at $(date +%H:%M:%S)\"/" src/lib.rs
cargo build --release
cargo cbuild --release
sed -i 's|/usr/local|/usr|' target/"$MBS_ARCH"-unknown-linux-gnu/release/rav1e.pc
install -t /usr/bin -Dm755 target/release/rav1e
install -t /usr/include/rav1e -Dm644 target/"$MBS_ARCH"-unknown-linux-gnu/release/include/rav1e/rav1e.h
install -t /usr/lib/pkgconfig -Dm644 target/"$MBS_ARCH"-unknown-linux-gnu/release/rav1e.pc
install -Dm755 target/"$MBS_ARCH"-unknown-linux-gnu/release/librav1e.so /usr/lib/librav1e.so.0.8.1
ln -sf librav1e.so.0.8.1 /usr/lib/librav1e.so.0
ln -sf librav1e.so.0.8.1 /usr/lib/librav1e.so
ldconfig
install -t /usr/share/licenses/rav1e -Dm644 LICENSE PATENTS
popd
rm -rf rav1e-0.8.1
# libdovi / dovi-tool.
tar -xf ../sources/dovi_tool-2.3.1.tar.gz
pushd dovi_tool-2.3.1
cargo cbuild --release --prefix=/usr --manifest-path=dolby_vision/Cargo.toml
cargo build --release
cargo cinstall --release --prefix=/usr --manifest-path=dolby_vision/Cargo.toml
install -t /usr/bin -Dm755 target/release/dovi_tool
rm -f /usr/lib/libdovi.a
install -t /usr/share/licenses/libdovi -Dm644 dolby_vision/LICENSE
install -t /usr/share/licenses/dovi-tool -Dm644 LICENSE
popd
rm -rf dovi_tool-2.3.1
# libplacebo.
tar -xf ../sources/libplacebo-v7.360.1.tar.gz
pushd libplacebo-v7.360.1
meson setup build --prefix=/usr --buildtype=minsize --sbindir=bin -Dglslang=enabled -Ddemos=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libplacebo -Dm644 LICENSE
popd
rm -rf libplacebo-v7.360.1
# wavpack.
tar -xf ../sources/wavpack-5.8.1.tar.xz
pushd wavpack-5.8.1
./configure --prefix=/usr --disable-rpath --enable-legacy
make
make install
install -t /usr/share/licenses/wavpack -Dm644 COPYING
popd
rm -rf wavpack-5.8.1
# libudfread.
tar -xf ../sources/libudfread-1.1.2.tar.bz2
pushd libudfread-1.1.2
./bootstrap
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libudfread -Dm644 COPYING
popd
rm -rf libudfread-1.1.2
# libbluray.
tar -xf ../sources/libbluray-1.3.4.tar.bz2
pushd libbluray-1.3.4
./bootstrap
sed -i 's/with_external_libudfread=$withwal/with_external_libudfread=yes/' configure
./configure --prefix=/usr --disable-bdjava-jar --disable-examples --disable-static
make
make install
install -t /usr/share/licenses/libbluray -Dm644 COPYING
popd
rm -rf libbluray-1.3.4
# libmodplug.
tar -xf ../sources/libmodplug-0.8.9.0.tar.gz
pushd libmodplug-0.8.9.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libmodplug -Dm644 COPYING
popd
rm -rf libmodplug-0.8.9.0
# libmpeg2.
tar -xf ../sources/libmpeg2-upstream-0.5.1.tar.gz
pushd libmpeg2-upstream-0.5.1
sed -i 's/static const/static/' libmpeg2/idct_mmx.c
./configure --prefix=/usr --build="$MBS_ARCH-$MBS_ARCH_VENDOR-linux-gnu" --enable-shared --disable-static
find . -name Makefile -exec sed -i 's|-Wl,-rpath,/usr/lib||' {} ';'
make
make install
install -t /usr/share/licenses/libmpeg2 -Dm644 COPYING
popd
rm -rf libmpeg2-upstream-0.5.1
# libyuv.
tar -xf ../sources/libyuv-2880.tar.gz
pushd libyuv-1b1c058787474b1a54cd7c0d7cee38db9e0816c6
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
rm -f /usr/lib/libyuv.a
install -t /usr/share/licenses/libyuv -Dm644 LICENSE PATENTS
popd
rm -rf libyuv-1b1c058787474b1a54cd7c0d7cee38db9e0816c6
# libheif.
tar -xf ../sources/libheif-1.23.0.tar.gz
pushd libheif-1.23.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -DWITH_EXAMPLE_HEIF_THUMB=OFF -DWITH_GDK_PIXBUF=OFF -DWITH_AOM_DECODER=ON -DWITH_AOM_ENCODER=ON -DWITH_DAV1D=ON -DWITH_JPEG_DECODER=ON -DWITH_JPEG_ENCODER=ON -DWITH_LIBDE265=ON -DWITH_OpenJPEG_DECODER=ON -DWITH_OpenJPEG_ENCODER=ON -DWITH_RAV1E=ON -DWITH_SvtEnc=ON -DWITH_X265=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libheif -Dm644 COPYING
popd
rm -rf libheif-1.23.0
# libavif.
tar -xf ../sources/libavif-1.4.2.tar.gz
pushd libavif-1.4.2
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DAVIF_BUILD_APPS=ON -DAVIF_BUILD_GDK_PIXBUF=OFF -DAVIF_CODEC_AOM=SYSTEM -DAVIF_CODEC_SVT=SYSTEM -DAVIF_CODEC_DAV1D=SYSTEM -DAVIF_CODEC_RAV1E=SYSTEM -DAVIF_LIBYUV=SYSTEM -DAVIF_ENABLE_WERROR=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libavif -Dm644 LICENSE
popd
rm -rf libavif-1.4.2
# highway.
tar -xf ../sources/highway-1.4.0.tar.gz
pushd highway-1.4.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/highway -Dm644 LICENSE
popd
rm -rf highway-1.4.0
# libjxl.
tar -xf ../sources/libjxl-0.12.0.tar.gz
pushd libjxl-0.12.0
tar -xf ../../sources/sjpeg-46da5ae.tar.gz -C third_party/sjpeg --strip-components=1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_PLUGINS=OFF -DJPEGXL_ENABLE_SKCMS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
rm -f /usr/lib/libjxl_extras_codec.a
install -t /usr/share/licenses/libjxl -Dm644 LICENSE PATENTS
popd
rm -rf libjxl-0.12.0
# chafa.
tar -xf ../sources/chafa-1.14.5.tar.xz
pushd chafa-1.14.5
./configure --prefix=/usr --enable-gtk-doc --enable-man --disable-static
make
make install
install -t /usr/share/licenses/chafa -Dm644 COPYING{,.LESSER}
popd
rm -rf chafa-1.14.5
# HarfBuzz (rebuild again to support chafa).
tar -xf ../sources/harfbuzz-14.2.1.tar.xz
pushd harfbuzz-14.2.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled
ninja -C build
ninja -C build install
popd
rm -rf harfbuzz-14.2.1
# FAAC.
tar -xf ../sources/faac-1.50.tar.gz
pushd faac-faac-1.50
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
rm -f /usr/lib/libfaac.a
install -t /usr/share/licenses/faac -Dm644 COPYING README
popd
rm -rf faac-faac-1.50
# FAAD2.
tar -xf ../sources/faad2-2.11.2.tar.gz
pushd faad2-2.11.2
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/faad2 -Dm644 COPYING
popd
rm -rf faad2-2.11.2
# kvazaar.
tar -xf ../sources/kvazaar-2.3.1.tar.xz
pushd kvazaar-2.3.1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/kvazaar -Dm644 LICENSE
popd
rm -rf kvazaar-2.3.1
# AMF-Headers.
tar --no-same-owner -xf ../sources/AMF-headers-v1.5.2.tar.gz -C /usr/include --strip-components=1
head -n31 /usr/include/AMF/core/Platform.h | install -Dm644 /dev/stdin /usr/share/licenses/amf-headers/LICENSE.txt
# nv-codec-headers.
tar -xf ../sources/nv-codec-headers-13.0.19.0.tar.gz
pushd nv-codec-headers-13.0.19.0
make PREFIX=/usr
make PREFIX=/usr install
install -dm755 /usr/share/licenses/nv-codec-headers
for h in /usr/include/ffnvcodec/*.h; do head -n26 "$h" > /usr/share/licenses/nv-codec-headers/"$(basename "$h")".txt; done
popd
rm -rf nv-codec-headers-13.0.19.0
# OpenAL (initial build - circular dependency with FFmpeg).
tar -xf ../sources/openal-soft-1.24.3.tar.gz
pushd openal-soft-1.24.3
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/openal -Dm644 COPYING BSD-3Clause
popd
rm -rf openal-soft-1.24.3
# FFmpeg.
tar -xf ../sources/ffmpeg-9.0.tar.xz
pushd ffmpeg-9.0
patch -Np1 -i ../../patches/ffmpeg-7.1-chromium.patch
./configure --prefix=/usr --disable-debug --disable-htmlpages --disable-nonfree --disable-podpages --disable-rpath --disable-static --disable-txtpages --enable-alsa --enable-amf --enable-bzlib --enable-cuda-llvm --enable-cuvid --enable-ffnvcodec --enable-gmp --enable-gpl --enable-iconv --enable-libaom --enable-libass --enable-libbluray --enable-libbs2b --enable-libcdio --enable-libdav1d --enable-libdrm --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libiec61883 --enable-libjack --enable-libjxl --enable-libkvazaar --enable-liblc3 --enable-libmodplug --enable-libmp3lame --enable-libopenh264 --enable-libopenjpeg --enable-libopus --enable-libplacebo --enable-libpulse --enable-libqrencode --enable-librav1e --enable-librsvg --enable-librtmp --enable-libspeex --enable-libsvtav1 --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxcb --enable-libxcb-shape --enable-libxcb-shm --enable-libxcb-xfixes --enable-libxml2 --enable-libxvid --enable-manpages --enable-nvdec --enable-nvenc --enable-openal --enable-opengl --enable-openssl --enable-optimizations --enable-sdl2 --enable-shared --enable-small --enable-stripping --enable-vaapi --enable-vdpau --enable-version3 --enable-vulkan --enable-xlib --enable-zlib
make
gcc $CFLAGS tools/qt-faststart.c -o tools/qt-faststart $LDFLAGS
make install
install -t /usr/bin -Dm755 tools/qt-faststart
install -t /usr/share/licenses/ffmpeg -Dm644 COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md
popd
rm -rf ffmpeg-9.0
# OpenAL (rebuild - circular dependency with FFmpeg).
tar -xf ../sources/openal-soft-1.24.3.tar.gz
pushd openal-soft-1.24.3
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
popd
rm -rf openal-soft-1.24.3
# GStreamer / gst-plugins-{base,good,bad,ugly} / gst-libav / gstreamer-vaapi / gst-editing-services / gst-python
tar -xf ../sources/gstreamer-1.28.6.tar.bz2
pushd gstreamer-1.28.6
mkdir -p subprojects/gl-headers
tar -xf ../../sources/gl-headers-1d237e3.tar.bz2 -C subprojects/gl-headers --strip-components=1
CFLAGS="" CXXFLAGS="" CPPFLAGS="" LDFLAGS="" meson setup build --prefix=/usr --sbindir=bin --buildtype=release -Ddevtools=disabled -Dexamples=disabled -Dglib_assert=false -Dglib_checks=false -Dglib_debug=disabled -Dgpl=enabled -Dgst-examples=disabled -Dlibnice=disabled -Dorc-source=system -Dpackage-name="MassOS GStreamer 1.28.6" -Dpackage-origin="https://massos.org" -Drtsp_server=disabled -Dtests=disabled -Dgst-plugins-bad:aja=disabled -Dgst-plugins-bad:avtp=disabled -Dgst-plugins-bad:fdkaac=disabled -Dgst-plugins-bad:gpl=enabled -Dgst-plugins-bad:iqa=disabled -Dgst-plugins-bad:srtp=disabled -Dgst-plugins-bad:tinyalsa=disabled -Dgst-plugins-bad:vmaf=disabled -Dgst-plugins-bad:webrtcdsp=disabled -Dgst-plugins-ugly:gpl=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gstreamer -Dm644 LICENSE
install -t /usr/share/licenses/gst-plugins-base -Dm644 subprojects/gst-plugins-base/COPYING
install -t /usr/share/licenses/gst-plugins-good -Dm644 subprojects/gst-plugins-good/COPYING
install -t /usr/share/licenses/gst-plugins-bad -Dm644 subprojects/gst-plugins-bad/COPYING
install -t /usr/share/licenses/gst-plugins-ugly -Dm644 subprojects/gst-plugins-ugly/COPYING
install -t /usr/share/licenses/gst-libav -Dm644 subprojects/gst-libav/COPYING
install -t /usr/share/licenses/gst-editing-services -Dm644 subprojects/gst-editing-services/COPYING{,.LIB}
install -t /usr/share/licenses/gst-python -Dm644 subprojects/gst-python/COPYING
popd
rm -rf gstreamer-1.28.6
# nvidia-vaapi-driver.
tar -xf ../sources/nvidia-vaapi-driver-0.0.13.tar.gz
pushd nvidia-vaapi-driver-0.0.13
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/nvidia-vaapi-driver -Dm644 COPYING
popd
rm -rf nvidia-vaapi-driver-0.0.13
# PipeWire + WirePlumber.
tar -xf ../sources/pipewire-1.6.8.tar.bz2
pushd pipewire-1.6.8
mkdir -p subprojects/wireplumber
tar -xf ../../sources/wireplumber-0.5.15.tar.bz2 -C subprojects/wireplumber --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbluez5-backend-native-mm=enabled -Dexamples=disabled -Dffmpeg=enabled -Dpw-cat-ffmpeg=enabled -Dtests=disabled -Dvulkan=enabled -Dsession-managers=wireplumber -Dwireplumber:system-lua=true -Dwireplumber:tests=false
ninja -C build
ninja -C build install
install -dm755 /etc/alsa/conf.d
ln -sfr /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/50-pipewire.conf
ln -sfr /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/99-pipewire-default.conf
systemctl --global enable pipewire.socket pipewire-pulse.socket
systemctl --global enable wireplumber
echo "autospawn = no" >> /etc/pulse/client.conf
install -t /usr/share/licenses/pipewire -Dm644 COPYING
install -t /usr/share/licenses/wireplumber -Dm644 subprojects/wireplumber/LICENSE
popd
rm -rf pipewire-1.6.8
# SDL3 (rebuild for PipeWire support).
tar -xf ../sources/SDL3-3.4.12.tar.gz
pushd SDL3-3.4.12
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSDL_STATIC=OFF -DSDL_RPATH=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/sdl3 -Dm644 LICENSE.txt
popd
rm -rf SDL3-3.4.12
# GTK4 (rebuild to support GStreamer and tinysparql).
tar -xf ../sources/gtk-4.22.4.tar.gz
pushd gtk-4.22.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbroadway-backend=true -Dbuild-demos=false -Dbuild-examples=false -Dbuild-tests=false -Dbuild-testsuite=false -Dcloudproviders=enabled -Dcolord=enabled -Dintrospection=enabled -Dman-pages=true -Dmedia-gstreamer=enabled -Dsysprof=enabled -Dtracker=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk4 -Dm644 COPYING
popd
rm -rf gtk-4.22.4
# glycin.
tar -xf ../sources/glycin-2.1.5.tar.gz
pushd glycin-2.1.5
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dloaders=glycin-heif,glycin-image-rs,glycin-jxl,glycin-raw,glycin-svg -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glycin -Dm644 LICENSE{,-LGPL-2.1,-MPL-2.0}
popd
rm -rf glycin-2.1.5
# GDK-Pixbuf (rebuild - glycin now provides most loaders and the thumbnailer).
tar -xf ../sources/gdk-pixbuf-2.44.7.tar.gz
pushd gdk-pixbuf-2.44.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgif=disabled -Dglycin=enabled -Djpeg=disabled -Dothers=enabled -Dpng=disabled -Dthumbnailer=disabled -Dtiff=disabled -Dinstalled_tests=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gdk-pixbuf -Dm644 COPYING
popd
rm -rf gdk-pixbuf-2.44.7
# libadwaita.
tar -xf ../sources/libadwaita-1.9.2.tar.gz
pushd libadwaita-1.9.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libadwaita -Dm644 COPYING
popd
rm -rf libadwaita-1.9.2
# gst-plugin-gtk4 / gst-plugin-dav1d / gst-plugin-rav1e (from gst-plugins-rs).
tar -xf ../sources/gst-plugins-rs-0.15.3.tar.bz2
pushd gst-plugins-rs-0.15.3
pushd video/gtk4
cargo build --release
popd
pushd video/dav1d
cargo build --release
popd
pushd video/rav1e
cargo build --release
popd
install -t /usr/lib/gstreamer-1.0 -Dm755 target/release/libgst{gtk4,dav1d,rav1e}.so
install -t /usr/share/licenses/gst-plugin-gtk4 -Dm644 video/gtk4/LICENSE-MPL-2.0
install -t /usr/share/licenses/gst-plugin-dav1d -Dm644 video/dav1d/LICENSE-{APACHE,MIT}
install -t /usr/share/licenses/gst-plugin-rav1e -Dm644 video/rav1e/LICENSE-{APACHE,MIT}
popd
rm -rf gst-plugins-rs-0.15.3
# colord-gtk.
tar -xf ../sources/colord-gtk-0.3.1.tar.gz
pushd colord-gtk-0.3.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddocs=false -Dgtk3=true -Dgtk4=true -Dintrospection=true -Dman=false -Dtests=false -Dvapi=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/colord-gtk -Dm644 COPYING
popd
rm -rf colord-gtk-0.3.1
# xdg-desktop-portal.
tar -xf ../sources/xdg-desktop-portal-1.22.1.tar.xz
pushd xdg-desktop-portal-1.22.1
patch -Np1 -i ../../patches/xdg-desktop-portal-1.22.0-upstreamfix.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xdg-desktop-portal -Dm644 COPYING
popd
rm -rf xdg-desktop-portal-1.22.1
# xdg-desktop-portal-gtk.
tar -xf ../sources/xdg-desktop-portal-gtk-1.15.3.tar.xz
pushd xdg-desktop-portal-gtk-1.15.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dappchooser=enabled -Dlockdown=enabled -Dsettings=enabled -Dwallpaper=disabled
ninja -C build
ninja -C build install
cat > /etc/xdg/autostart/xdg-desktop-portal-gtk.desktop << "END"
[Desktop Entry]
Type=Application
Name=Portal service (GTK/GNOME implementation)
Exec=/usr/bin/bash -c "dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY; systemctl start --user xdg-desktop-portal-gtk.service"
END
install -t /usr/share/licenses/xdg-desktop-portal-gtk -Dm644 COPYING
popd
rm -rf xdg-desktop-portal-gtk-1.15.3
# xdg-desktop-portal-wlr.
tar -xf ../sources/xdg-desktop-portal-wlr-0.8.3.tar.gz
pushd xdg-desktop-portal-wlr-0.8.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
cat > /usr/share/xdg-desktop-portal/wlr-portals.conf << "END"
[preferred]
default=wlr
END
install -t /usr/share/licenses/xdg-desktop-portal-wlr -Dm644 LICENSE
popd
rm -rf xdg-desktop-portal-wlr-0.8.3
# WebKitGTK.
tar -xf ../sources/webkitgtk-2.52.4.tar.xz
pushd webkitgtk-2.52.4
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_RPATH=ON -DPORT=GTK -DLIB_INSTALL_DIR=/usr/lib -DENABLE_BUBBLEWRAP_SANDBOX=ON -DENABLE_GAMEPAD=ON -DENABLE_MINIBROWSER=ON -DENABLE_SPEECH_SYNTHESIS=OFF -DUSE_AVIF=ON -DUSE_GTK4=OFF -DUSE_LIBBACKTRACE=OFF -DUSE_LIBHYPHEN=OFF -DUSE_WOFF2=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -dm755 /usr/share/licenses/webkitgtk
while IFS= read -r file; do echo "### $file ###"; cat "$file"; done <<< "$(find Source -name 'COPYING*' -o -name 'LICENSE*')" > /usr/share/licenses/webkitgtk/LICENSE
popd
rm -rf webkitgtk-2.52.4
# Cogl.
tar -xf ../sources/cogl-1.22.8.tar.xz
pushd cogl-1.22.8
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types" ./configure --prefix=/usr --enable-gles1 --enable-gles2 --enable-kms-egl-platform --enable-wayland-egl-platform --enable-xlib-egl-platform --enable-wayland-egl-server --enable-cogl-gst
make -j1
make -j1 install
install -t /usr/share/licenses/cogl -Dm644 COPYING
popd
rm -rf cogl-1.22.8
# Clutter.
tar -xf ../sources/clutter-1.26.4.tar.xz
pushd clutter-1.26.4
./configure --prefix=/usr --sysconfdir=/etc --enable-egl-backend --enable-evdev-input --enable-wayland-backend --enable-wayland-compositor
make
make install
install -t /usr/share/licenses/clutter -Dm644 COPYING
popd
rm -rf clutter-1.26.4
# Clutter-GTK.
tar -xf ../sources/clutter-gtk-1.8.4.tar.xz
pushd clutter-gtk-1.8.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/clutter-gtk -Dm644 COPYING
popd
rm -rf clutter-gtk-1.8.4
# Clutter-GST.
tar -xf ../sources/clutter-gst-3.0.27.tar.xz
pushd clutter-gst-3.0.27
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration -Wno-error=int-conversion" ./configure --prefix=/usr --sysconfdir=/etc --disable-debug
make
make install
install -t /usr/share/licenses/clutter-gst -Dm644 COPYING
popd
rm -rf clutter-gst-3.0.27
# libchamplain.
tar -xf ../sources/libchamplain-0.12.21.tar.gz
pushd libchamplain-0.12.21
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libchamplain -Dm644 COPYING
popd
rm -rf libchamplain-0.12.21
# gspell.
tar -xf ../sources/gspell-1.14.3.tar.gz
pushd gspell-1.14.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dinstall_tests=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gspell -Dm644 LICENSES/LGPL-2.1-or-later.txt
popd
rm -rf gspell-1.14.3
# gnome-online-accounts.
tar -xf ../sources/gnome-online-accounts-3.56.4.tar.gz
pushd gnome-online-accounts-3.56.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dfedora=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gnome-online-accounts -Dm644 COPYING
popd
rm -rf gnome-online-accounts-3.56.4
# libgdata.
tar -xf ../sources/libgdata-0.18.1.tar.xz
pushd libgdata-0.18.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dalways_build_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libgdata -Dm644 COPYING
popd
rm -rf libgdata-0.18.1
# VTE / VTE4.
tar -xf ../sources/vte-0.82.3.tar.gz
pushd vte-0.82.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
rm -f /etc/profile.d/vte.*
rm -f /usr/share/applications/org.gnome.Vte.App.Gtk{3,4}.desktop
install -t /usr/share/licenses/vte -Dm644 COPYING.{CC-BY-4-0,GPL3,LGPL3,XTERM}
install -t /usr/share/licenses/vte4 -Dm644 COPYING.{CC-BY-4-0,GPL3,LGPL3,XTERM}
popd
rm -rf vte-0.82.3
# gtksourceview3.
tar -xf ../sources/gtksourceview-3.24.11-28-g73e57b5.tar.gz
pushd gtksourceview-73e57b5787ac60776c57032e05a4cc32207f9cf6
find . -type f -name Makefile.am -exec sed -i '/@CODE_COVERAGE_RULES@/d' {} ';'
CFLAGS="$CFLAGS -Wno-error=incompatible-pointer-types" ./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-glade-catalog
make
make install
install -t /usr/share/licenses/gtksourceview3 -Dm644 COPYING
popd
rm -rf gtksourceview-73e57b5787ac60776c57032e05a4cc32207f9cf6
# gtksourceview4.
tar -xf ../sources/gtksourceview-4.8.4.tar.gz
pushd gtksourceview-4.8.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtksourceview4 -Dm644 COPYING
popd
rm -rf gtksourceview-4.8.4
# gtksourceview5.
tar -xf ../sources/gtksourceview-5.20.0.tar.gz
pushd gtksourceview-5.20.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-testsuite=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtksourceview5 -Dm644 COPYING
popd
rm -rf gtksourceview-5.20.0
# Malcontent (rebuild with malcontent-ui due to circular dependency).
tar -xf ../sources/malcontent-0.13.0.tar.bz2
pushd malcontent-0.13.0
mkdir -p subprojects/libglib-testing
tar -xf ../../sources/libglib-testing-0.1.1.tar.bz2 -C subprojects/libglib-testing --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dui=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/malcontent -Dm644 COPYING{,-DOCS}
popd
rm -rf malcontent-0.13.0
# yad.
tar -xf ../sources/yad-14.1.tar.xz
pushd yad-14.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/yad -Dm644 COPYING
popd
rm -rf yad-14.1
# msgraph.
tar -xf ../sources/msgraph-0.3.3.tar.gz
pushd msgraph-0.3.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/msgraph -Dm644 COPYING
popd
rm -rf msgraph-0.3.3
# GVFS.
tar -xf ../sources/gvfs-1.58.2.tar.gz
pushd gvfs-1.58.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dburn=true -Dman=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gvfs -Dm644 COPYING
popd
rm -rf gvfs-1.58.2
# Plymouth.
tar -xf ../sources/plymouth-24.004.60-149-g4a3c171d.tar.bz2
pushd plymouth-4a3c171d-4a3c171df86de1e6d2586fd09382fe4f6b69d307
echo -e '#!/bin/sh\necho 24.004.60-149-g4a3c171d' > scripts/generate-version.sh
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dlogo=/usr/share/massos/massos-logo-sidetext.png -Drelease-file=/etc/os-release
ninja -C build
ninja -C build install
cp /usr/share/massos/massos-logo-sidetext.png /usr/share/plymouth/themes/spinner/watermark.png
sed -i 's/dracut -f/mkinitramfs/' /usr/libexec/plymouth/plymouth-update-initrd
sed -i 's/Theme=spinner/Theme=bgrt/' /usr/share/plymouth/plymouthd.defaults
echo "UseSimpledrm=1" >> /usr/share/plymouth/plymouthd.defaults
install -t /usr/share/licenses/plymouth -Dm644 COPYING
popd
rm -rf plymouth-4a3c171d-4a3c171df86de1e6d2586fd09382fe4f6b69d307
# Busybox.
tar -xf ../sources/busybox-1.38.0.tar.bz2
pushd busybox-1.38.0
patch -Np1 -i ../../patches/busybox-1.38.0-upstreamfix.patch
cp ../../extras/build-configs/busybox-config .config
make
install -t /usr/bin -Dm755 busybox
install -t /usr/share/licenses/busybox -Dm644 LICENSE
popd
rm -rf busybox-1.38.0
# memtest86+ (only supported on x86_64 systems).
tar -xf ../sources/memtest86plus-7.20.tar.gz
pushd memtest86plus-7.20
[ "$MBS_ARCH" != "x86_64" ] || make -C build64
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/lib/memtest86+ -Dm644 build64/memtest.{bin,efi}
[ "$MBS_ARCH" != "x86_64" ] || sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt /usr/lib/memtest86+/memtest.efi
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/share/licenses/memtest86+ -Dm644 LICENSE
[ "$MBS_ARCH" = "x86_64" ] || sed -i '/^memtest86+$/d' /usr/share/massos/builtins
popd
rm -rf memtest86plus-7.20
# iPXE.
tar -xf ../sources/ipxe-2.0.0.tar.gz
pushd ipxe-2.0.0
patch -Np1 -i ../../patches/ipxe-2.0.0-gcc16.patch
cp ../../extras/build-configs/ipxe-config src/config/general.h
cat > src/config/local/general.h << "END"
#undef IMAGE_EFI
END
[ "$MBS_ARCH" != "x86_64" ] || make -C src bin/ipxe.{lkrn,pxe} NO_WERROR=1
[ "$MBS_ARCH" != "x86_64" ] || cp src/bin/ipxe.{lkrn,pxe} .
make -C src veryclean
cat > src/config/local/general.h << "END"
#undef IMAGE_NBI
#undef IMAGE_ELF
#undef IMAGE_MULTIBOOT
#undef IMAGE_PXE
#undef IMAGE_COMBOOT
#undef IMAGE_SDI
#undef PXE_CMD
END
[ "$MBS_ARCH" = "x86_64" ] || echo "#undef IMAGE_UCODE" >> src/config/local/general.h
make -C src bin-"$MBS_ARCH_GRUB"-efi/ipxe.efi NO_WERROR=1
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/lib/ipxe -Dm644 ipxe.{lkrn,pxe}
install -t /usr/lib/ipxe -Dm644 src/bin-"$MBS_ARCH_GRUB"-efi/ipxe.efi
sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt /usr/lib/ipxe/ipxe.efi
install -t /usr/share/licenses/ipxe -Dm644 COPYING{,.GPLv2,.UBDL}
popd
rm -rf ipxe-2.0.0
# EDK2-Shell.
tar -xf ../sources/edk2-stable202605.tar.xz
pushd edk2-stable202605
cp BaseTools/Conf/tools_def.template Conf/tools_def.txt
cp BaseTools/Conf/build_rule.template Conf/build_rule.txt
cp BaseTools/Conf/build_rule.template build_rule.txt
make -C BaseTools
echo -e '#!/bin/sh\nif test "$(uname -m)" = x86_64; then echo X64; elif test "$(uname -m)" = aarch64; then echo AARCH64; else echo UNKNOWN; fi' | install -m755 /dev/stdin edk2arch
PATH="$PWD/BaseTools/BinWrappers/PosixLike:$PATH" WORKSPACE="$PWD" EDK_TOOLS_PATH="$PWD/BaseTools" build -p ShellPkg/ShellPkg.dsc -a "$(./edk2arch)" -b RELEASE -n "$(nproc)" -t GCC
install -Dm644 Build/Shell/RELEASE_GCC/"$(./edk2arch)"/ShellPkg/Application/Shell/EA4BB293-2D7F-4456-A681-1F22F42CD0BC/OUTPUT/Shell.efi /usr/lib/edk2-shell/shell"$MBS_ARCH_EFI".efi
## NOTE: The UEFI EDK2 Shell is intentionally not signed for secure boot by us.
## NOTE: This is because it is insecure by nature (it is a debugging tool).
install -t /usr/share/licenses/edk2-shell -Dm644 License.txt
popd
rm -rf edk2-stable202605
# virtiofsd.
tar -xf ../sources/virtiofsd-v1.13.1.tar.bz2
pushd virtiofsd-v1.13.1
cargo build --release
install -t /usr/libexec -Dm755 target/release/virtiofsd
install -t /usr/share/qemu/vhost-user -Dm644 50-virtiofsd.json
install -t /usr/share/licenses/virtiofsd -Dm644 LICENSE-{APACHE,BSD-3-Clause}
popd
rm -rf virtiofsd-v1.13.1
# qemu-guest-agent.
tar -xf ../sources/qemu-11.0.2.tar.xz
pushd qemu-11.0.2
sed -i 's/b6910bec11614980a21e46fbccc35934b671bd81/9a1c801a1a3c102bf95c5339c9e985b26b823a21/' subprojects/dtc.wrap
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-docs --target-list="$MBS_ARCH-linux-user,$MBS_ARCH-softmmu"
make
install -t /usr/bin -Dm755 build/qga/qemu-ga
install -t /etc/qemu -Dm755 scripts/qemu-guest-agent/fsfreeze-hook
cat > /etc/qemu/qemu-ga.conf << "END"
[general]
daemonize = 0
verbose = 0
method = virtio-serial
path = /dev/virtio-ports/org.qemu.guest_agent.0
pidfile = /run/qemu-ga.pid
statedir = /run
fsfreeze-hook = /etc/qemu/fsfreeze-hook
END
install -t /usr/lib/systemd/system -Dm644 contrib/systemd/qemu-guest-agent.service
echo 'SUBSYSTEM=="virtio-ports", ATTR{name}=="org.qemu.guest_agent.0", TAG+="systemd" ENV{SYSTEMD_WANTS}="qemu-guest-agent.service"' > /usr/lib/udev/rules.d/99-qemu-guest-agent.rules
install -t /usr/share/licenses/qemu-guest-agent -Dm644 COPYING{,.LIB} LICENSE
popd
rm -rf qemu-11.0.2
# spice-vdagent.
tar -xf ../sources/spice-vdagent-0.22.1.tar.bz2
pushd spice-vdagent-0.22.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --with-init-script=systemd --with-session-info=systemd
make
make install
install -t /usr/share/licenses/spice-vdagent -Dm644 COPYING
popd
rm -rf spice-vdagent-0.22.1
# open-vm-tools.
tar -xf ../sources/open-vm-tools-stable-13.0.10.tar.gz
pushd open-vm-tools-stable-13.0.10/open-vm-tools
patch -Np2 -i ../../../patches/open-vm-tools-13.0.10-glibc243.patch
autoreconf -fi
CFLAGS="$CFLAGS -Wno-error=discarded-qualifiers" ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --with-udev-rules-dir=/usr/lib/udev/rules.d --disable-docs --disable-tests --without-kernel-modules --disable-containerinfo
make
make install
chmod 7755 /usr/bin/vmware-user-suid-wrapper
install -t /usr/bin -Dm755 scripts/common/vmware-xdg-detect-de
cp /etc/pam.d/{polkit-1,vmtoolsd}
systemctl enable vmtoolsd
systemctl enable vmware-vmblock-fuse
install -t /usr/share/licenses/open-vm-tools -Dm644 COPYING LICENSE
popd
rm -rf open-vm-tools-stable-13.0.10
# Linux / Linux-Headers.
tar -xf ../sources/linux-7.1.6.tar.xz
pushd linux-7.1.6
patch -Np1 -i ../../patches/linux-6.17.5-uefisecureboot.patch
sed -i 's/$(ZSTD) --rm -f -q/$(ZSTD) --ultra -22 --rm -f -q/' scripts/Makefile.modinst
make mrproper
cat ../../extras/secureboot/db.{key,crt} > certs/massos_signing.pem
cat > sbat.csv << "END"
sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md
linux,1,The Linux Kernel Developers,linux,7.1.6,https://kernel.org
linux.massos,1,MassOS,linux,7.1.6,https://massos.org
END
cp ../../extras/build-configs/linux-config."$MBS_ARCH" .config
make olddefconfig
make KBUILD_BUILD_HOST=massos
[ "$MBS_ARCH" != "x86_64" ] || sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt arch/x86/boot/bzImage
[ "$MBS_ARCH" != "aarch64" ] || sbsign --key ../../extras/secureboot/db.key --cert ../../extras/secureboot/db.crt arch/arm64/boot/Image
make -s kernelrelease > version
make INSTALL_MOD_STRIP=1 modules_install
[ "$MBS_ARCH" != "aarch64" ] || make INSTALL_DTBS_PATH=/boot/dtbs-"$(cat version)" dtbs_install
install -Dm644 version /usr/share/massos/.krel
[ "$MBS_ARCH" != "x86_64" ] || cp arch/x86/boot/bzImage.signed /boot/vmlinuz-"$(cat version)"
[ "$MBS_ARCH" != "aarch64" ] || cp arch/arm64/boot/Image.signed /boot/vmlinuz-"$(cat version)"
cp /boot/vmlinuz-"$(cat version)" /usr/lib/modules/"$(cat version)"/vmlinuz
cp System.map /boot/System.map-"$(cat version)"
cp .config /boot/config-"$(cat version)"
rm -f /usr/lib/modules/"$(cat version)"/{build,source}
install -t /usr/lib/modules/"$(cat version)"/build -Dm644 .config Makefile Module.symvers System.map version vmlinux sbat.csv
install -t /usr/lib/modules/"$(cat version)"/build/kernel -Dm644 kernel/Makefile
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/lib/modules/"$(cat version)"/build/arch/x86 -Dm644 arch/x86/Makefile
[ "$MBS_ARCH" != "aarch64" ] || install -t /usr/lib/modules/"$(cat version)"/build/arch/arm64 -Dm644 arch/arm64/Makefile
cp -t /usr/lib/modules/"$(cat version)"/build -a scripts
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/lib/modules/"$(cat version)"/build/tools/objtool -Dm755 tools/objtool/objtool
mkdir -p /usr/lib/modules/"$(cat version)"/build/{fs/xfs,mm}
cp -t /usr/lib/modules/"$(cat version)"/build -a include
[ "$MBS_ARCH" != "x86_64" ] || cp -t /usr/lib/modules/"$(cat version)"/build/arch/x86 -a arch/x86/include
[ "$MBS_ARCH" != "aarch64" ] || cp -t /usr/lib/modules/"$(cat version)"/build/arch/arm64 -a arch/arm64/include
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/lib/modules/"$(cat version)"/build/arch/x86/kernel -Dm644 arch/x86/kernel/asm-offsets.s
[ "$MBS_ARCH" != "aarch64" ] || install -t /usr/lib/modules/"$(cat version)"/build/arch/arm64/kernel -Dm644 arch/arm64/kernel/asm-offsets.s
install -t /usr/lib/modules/"$(cat version)"/build/drivers/md -Dm644 drivers/md/*.h
install -t /usr/lib/modules/"$(cat version)"/build/net/mac80211 -Dm644 net/mac80211/*.h
install -t /usr/lib/modules/"$(cat version)"/build/drivers/media/i2c -Dm644 drivers/media/i2c/msp3400-driver.h
install -t /usr/lib/modules/"$(cat version)"/build/drivers/media/usb/dvb-usb -Dm644 drivers/media/usb/dvb-usb/*.h
install -t /usr/lib/modules/"$(cat version)"/build/drivers/media/dvb-frontends -Dm644 drivers/media/dvb-frontends/*.h
install -t /usr/lib/modules/"$(cat version)"/build/drivers/media/tuners -Dm644 drivers/media/tuners/*.h
install -t /usr/lib/modules/"$(cat version)"/build/drivers/iio/common/hid-sensors -Dm644 drivers/iio/common/hid-sensors/*.h
find . -name 'Kconfig*' -exec install -Dm644 {} /usr/lib/modules/"$(cat version)"/build/{} ';'
rm -rf /usr/lib/modules/"$(cat version)"/build/Documentation
find -L /usr/lib/modules/"$(cat version)"/build -type l -delete
find /usr/lib/modules/"$(cat version)"/build -type f -name '*.o' -delete
ln -sr /usr/lib/modules/"$(cat version)"/build /usr/src/linux
echo "options kvm enable_virt_at_load=0" > /usr/lib/modprobe.d/kvm.conf
cat > /etc/modprobe.d/blacklist-nouveau.conf << "END"
# Blacklist nouveau so it doesn't conflict with nvidia-modules-open.
# Comment out or remove the lines if you need nouveau for some reason.
# But don't delete this file, else MassOS upgrades may re-create it.
blacklist nouveau
options nouveau modeset=0
END
cat > /etc/modprobe.d/blacklist-novacore.conf << "END"
# nova_core is a new Rust-based Linux driver for NVIDIA GPUs.
# Unfortunately, similar to nouveau, it can conflict with nvidia-modules-open.
# At the time of writing, it is also yet to be fully stable or even functional.
# Comment out or remove these following lines if you want to try out nova_core.
# But don't delete this file, else MassOS upgrades may re-create it.
blacklist nova_core
blacklist nova_drm
END
install -t /usr/share/licenses/linux -Dm644 COPYING LICENSES/exceptions/* LICENSES/preferred/*
install -t /usr/share/licenses/linux-headers -Dm644 COPYING LICENSES/exceptions/* LICENSES/preferred/*
popd
rm -rf linux-7.1.6
# nvidia-modules-open (provides nvidia-modules).
tar -xf ../sources/open-gpu-kernel-modules-610.57.04.tar.gz
pushd open-gpu-kernel-modules-610.57.04
patch -Np1 -i ../../patches/nvidia-modules-open-595.44.03-hardening.patch
LDFLAGS="" make modules SYSSRC=/usr/src/linux
find kernel-open -name \*.ko -exec strip --strip-debug {} ';'
find kernel-open -name \*.ko -exec kmodsign sha512 ../../extras/secureboot/db.key ../../extras/secureboot/db.der {} ';'
find kernel-open -name \*.ko -exec zstd --ultra -22 -T0 -q {} ';'
install -t /usr/lib/modules/"$(cat /usr/share/massos/.krel)"/extramodules -Dm644 kernel-open/*.ko.zst
echo "options nvidia NVreg_OpenRmEnableUnsupportedGpus=1" > /usr/lib/modprobe.d/nvidia.conf
depmod "$(cat /usr/share/massos/.krel)"
install -t /usr/share/licenses/nvidia-modules-open -Dm644 COPYING
ln -sf nvidia-modules-open /usr/share/licenses/nvidia-modules
popd
rm -rf open-gpu-kernel-modules-610.57.04
# bcachefs-module.
tar -xf ../sources/bcachefs-tools-1.38.5.tar.gz
pushd bcachefs-tools-1.38.5
mv fs mod
mkdir -p fs
mv mod fs/bcachefs
make -C /usr/src/linux M="$PWD/fs/bcachefs" CONFIG_BCACHEFS_FS=m CONFIG_BCACHEFS_QUOTA=y CONFIG_BCACHEFS_POSIX_ACL=y CONFIG_BCACHEFS_LOCK_TIME_STATS=y CONFIG_BCACHEFS_SIX_OPTIMISTIC_SPIN=y modules
strip --strip-debug fs/bcachefs/bcachefs.ko
kmodsign sha512 ../../extras/secureboot/db.key ../../extras/secureboot/db.der fs/bcachefs/bcachefs.ko
zstd --ultra -22 -T0 -q fs/bcachefs/bcachefs.ko
install -t /usr/lib/modules/"$(cat /usr/share/massos/.krel)"/extramodules -Dm644 fs/bcachefs/bcachefs.ko.zst
depmod "$(cat /usr/share/massos/.krel)"
install -t /usr/share/licenses/bcachefs-module -Dm644 COPYING
popd
rm -rf bcachefs-tools-1.38.5
# apfs-rw-module.
tar -xf ../sources/linux-apfs-rw-0.3.20.tar.gz
pushd linux-apfs-rw-0.3.20
sed -i 's/?"$/"/' genver.sh
make KERNEL_DIR=/usr/src/linux
strip --strip-debug apfs.ko
kmodsign sha512 ../../extras/secureboot/db.key ../../extras/secureboot/db.der apfs.ko
zstd --ultra -22 -T0 -q apfs.ko
install -t /usr/lib/modules/"$(cat /usr/share/massos/.krel)"/extramodules -Dm644 apfs.ko.zst
depmod "$(cat /usr/share/massos/.krel)"
install -t /usr/share/licenses/apfs-rw-module -Dm644 LICENSE
popd
rm -rf linux-apfs-rw-0.3.20
# Linux-Firmware.
tar -xf ../sources/linux-firmware-20260622.tar.xz
pushd linux-firmware-20260622
sed -i 's/zstd --compress --quiet --stdout/zstd --ultra -22 --compress --quiet --stdout/' copy-firmware.sh
./copy-firmware.sh -v -j$(nproc) --zstd /usr/lib/firmware
./dedup-firmware.sh -v /usr/lib/firmware
## Only needed for high-end enterprise/data-center hardware. Wastes space.
rm -rf /usr/lib/firmware/{liquidio,mellanox,netronome,qed,qlogic,{c*fw-*,ql2*_fw}.bin.zst}
## Only needed on x86_64 host systems, similar to Intel Microcode.
[ "$MBS_ARCH" = "x86_64" ] || rm -rf /usr/lib/firmware/amd-ucode
## Only needed on aarch64 host systems. Wastes space otherwise.
[ "$MBS_ARCH" = "aarch64" ] || rm -rf /usr/lib/firmware/{mrvl/prestera/mvsw_prestera_fw_arm64-v4.1.img.zst,qcom}
install -t /usr/share/licenses/linux-firmware -Dm644 LICENSES/* WHENCE
popd
rm -rf linux-firmware-20260622
# Intel-Microcode (has no use on non-x86_64 architectures).
tar -xf ../sources/intel-microcode-20260227.tar.gz
pushd Intel-Linux-Processor-Microcode-Data-Files-microcode-20260227
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/lib/firmware/intel-ucode -Dm644 intel-ucode{,-with-caveats}/*
[ "$MBS_ARCH" != "x86_64" ] || install -t /usr/share/licenses/intel-microcode -Dm644 license
[ "$MBS_ARCH" = "x86_64" ] || sed -i '/^intel-microcode$/d' /usr/share/massos/builtins
popd
rm -rf Intel-Linux-Processor-Microcode-Data-Files-microcode-20260227
# SOF-Firmware.
tar -xf ../sources/sof-bin-2025.12.2.tar.gz
pushd sof-bin-2025.12.2
cp -at /usr/lib/firmware/intel sof*
install -t /usr/share/licenses/sof-firmware -Dm644 LICENCE.Intel LICENCE.NXP Notice.NXP
popd
rm -rf sof-bin-2025.12.2
# upgrade-massos.
tar -xf ../sources/upgrade-massos-0.2.1.tar.gz
pushd upgrade-massos-0.2.1
go build -trimpath ugm-install-helper.go
sed -i "s|massos-builds|builds/$(uname -m)|" upgrade-massos.conf
install -t /usr/bin -Dm755 upgrade-massos
install -t /usr/libexec/upgrade-massos -Dm755 ugm-install-helper
install -t /etc/upgrade-massos -Dm644 upgrade-massos.conf
install -t /etc/upgrade-massos/trusted-keys -Dm644 trusted-keys/{*.asc,README.md}
install -t /usr/share/licenses/upgrade-massos -Dm644 LICENSE
popd
rm -rf upgrade-massos-0.2.1
# MassOS release detection utility.
gcc $CFLAGS ../sources/massos-release.c -o massos-release
install -t /usr/bin -Dm755 massos-release
# Specify the Raspberry Pi firmware version to use for aarch64 raspi images.
echo "1.20260408" > /usr/share/massos/.rpifwver
echo "b26fd19facd534aab474cc64e25db4b120682c2c4c9a2a4bed97495ec578a645" > /usr/share/massos/.rpifwsum
# Specify the version of osinstallgui that should be used by the Live CD.
echo "0.14.2" > /usr/share/massos/.osinstallguiver
echo "cb623f0f3cc1213d9ba1422619e349530c88cbc5b898f688d630af7baa3adf05" > /usr/share/massos/.osinstallguisum
# Set up the osinstallgui configuration file.
cat > /usr/share/massos/.osinstallguicfg << "END"
OSINSTALLGUI_ROOTFS="/run/initramfs/squashed.img"
OSINSTALLGUI_ROOTFS_ALT="/run/initramfs/live/LiveOS/squashfs.img"
OSINSTALLGUI_CLEANUP_CMD="/tmp/livecd-cleanup.sh"
OSINSTALLGUI_INITRAMFS_CMD="/usr/bin/mkinitramfs"
OSINSTALLGUI_ALLOW_BTRFS=1
OSINSTALLGUI_ALLOW_LUKS=1
OSINSTALLGUI_LUKS_MAPPER_NAME="cryptroot"
OSINSTALLGUI_LUKS_ARGON2=1
OSINSTALLGUI_ALWAYS_OFFER_FULLPORT=0
OSINSTALLGUI_LOCALES_CMD="/usr/bin/mklocales"
OSINSTALLGUI_LOCALES_FILE="/etc/locales"
OSINSTALLGUI_KEYMAPS_SYSTEMD=1
OSINSTALLGUI_KEYMAPS_LOCATION="/usr/share/keymaps"
OSINSTALLGUI_ROOTPW=1
OSINSTALLGUI_ADMIN_GROUP="wheel"
OSINSTALLGUI_USER_SHELL="/usr/bin/bash"
OSINSTALLGUI_USER_PWSCORE=0
OSINSTALLGUI_GRUB_EXTRA_ARGS_LEGACY=""
OSINSTALLGUI_GRUB_EXTRA_ARGS_UEFIIN=""
OSINSTALLGUI_GRUB_EXTRA_ARGS_UEFIRM=""
END
# snapd version, for use with the snapd installation program (massos-snapd).
cat > /usr/share/massos/snapdversion << "END"
# DO NOT EDIT THIS FILE!

# This file defines the version of snapd corresponding to this MassOS build.
# snapd is not installed by default due to its controversy.
# But we still want to offer it, as it provides some packages not in Flatpak.

# Eventually, a utility called 'massos-snapd' will be created, to allow
# installing snapd and uninstalling it. It will need to reference to this file
# to know which version of snapd to install.

# The snapd version, see <https://github.com/canonical/snapd/releases>.
# SHA256 checksum is for the source file named 'snapd_<VERSION>.vendor.tar.xz'.
version: 2.76
checksum: 78ad358dc685ab5a40b9ca0b3fc283ae7c8fbbabb4612182d512bde7efeef605
END
# Number that defines this build's compatibility with create-livecd.sh.
# Increment if create-livecd.sh needs updates to accomodate build changes.
echo 7 > /usr/share/massos/.rootfs_compat
# Clean up the mbs directory and self-destruct.
# Keep /root/mbs/extras as it can be used by stage 3.
popd
find /root/mbs -mindepth 1 -maxdepth 1 ! -name "extras" -exec rm -rf {} ';'
# Flush disk write cache if needed (for redundancy).
sync
