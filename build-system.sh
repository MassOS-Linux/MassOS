#!/bin/bash
#
# Builds the core MassOS system (Stage 2) in a chroot environment.
# Copyright (C) 2021-2025 Daniel Massey / MassOS Developers.
#
# This script is part of the MassOS build system. It is licensed under GPLv3+.
# See the 'LICENSE' file for the full license text. On a MassOS system, this
# document can also be found at '/usr/share/massos/LICENSE'.
#
# === IF RESUMING A FAILED BUILD, DO NOT REMOVE ANY LINES BEFORE LINE 26 ===
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
tar -xf ../sources/rust-1.86.0-x86_64-unknown-linux-gnu.tar.gz
pushd rust-1.86.0-x86_64-unknown-linux-gnu
./install.sh --prefix=/root/mbs/extras/rust --without=rust-docs
tar -xf ../../sources/cargo-c-x86_64-unknown-linux-musl.tar.gz -C /root/mbs/extras/rust/bin
tar -xf ../../sources/bindgen-cli-x86_64-unknown-linux-gnu.tar.xz -C /root/mbs/extras/rust/bin --strip-components=1 bindgen-cli-x86_64-unknown-linux-gnu/bindgen
install -t /root/mbs/extras/rust/bin -Dm755 ../../sources/cbindgen
popd
rm -rf rust-1.86.0-x86_64-unknown-linux-gnu
tar -xf ../sources/go1.24.2.linux-amd64.tar.gz -C /root/mbs/extras
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
tar -xf ../sources/ncurses-6.5.tar.gz
pushd ncurses-6.5
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
rm -rf ncurses-6.5
# Perl (circular deps; rebuilt later).
tar -xf ../sources/perl-5.40.2.tar.xz
pushd perl-5.40.2
./Configure -des -Doptimize="$CFLAGS" -Dprefix=/usr -Dvendorprefix=/usr -Duseshrplib -Dprivlib=/usr/lib/perl5/5.40/core_perl -Darchlib=/usr/lib/perl5/5.40/core_perl -Dsitelib=/usr/lib/perl5/5.40/site_perl -Dsitearch=/usr/lib/perl5/5.40/site_perl -Dvendorlib=/usr/lib/perl5/5.40/vendor_perl -Dvendorarch=/usr/lib/perl5/5.40/vendor_perl
make
make install
popd
rm -rf perl-5.40.2
# Python (circular deps; rebuilt later).
tar -xf ../sources/Python-3.13.3.tar.xz
pushd Python-3.13.3
./configure --prefix=/usr --enable-shared --without-ensurepip --disable-test-modules
make
make install
popd
rm -rf Python-3.13.3
# Texinfo (circular deps; rebuilt later).
tar -xf ../sources/texinfo-7.2.tar.xz
pushd texinfo-7.2
./configure --prefix=/usr
make
make install
popd
rm -rf texinfo-7.2
# util-linux (circular deps; rebuilt later).
tar -xf ../sources/util-linux-2.41.tar.xz
pushd util-linux-2.41
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run --bindir=/usr/bin --libdir=/usr/lib --sbindir=/usr/bin --disable-static --disable-chfn-chsh --disable-liblastlog2 --disable-login --disable-nologin --disable-pylibmount --disable-runuser --disable-setpriv --disable-su --disable-use-tty-group --without-python
make
make install
popd
rm -rf util-linux-2.41
# man-pages.
tar -xf ../sources/man-pages-6.13.tar.xz
pushd man-pages-6.13
rm -f man3/crypt*
make -R prefix=/usr GIT=false install
install -t /usr/share/licenses/man-pages -Dm644 LICENSES/*
popd
rm -rf man-pages-6.13
# iana-etc.
tar -xf ../sources/iana-etc-20250403.tar.gz
install -t /etc -Dm644 iana-etc-20250403/{protocols,services}
install -dm755 /usr/share/licenses/iana-etc
cat > /usr/share/licenses/iana-etc/LICENSE << "END"
Copyright 2017 Jörg Thalheim

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
END
rm -rf iana-etc-20250403
# Glibc.
tar -xf ../sources/glibc-2.41.tar.xz
pushd glibc-2.41
patch -Np1 -i ../../patches/glibc-2.40-vardirectories.patch
mkdir -p build; pushd build
echo "rootsbindir=/usr/bin" > configparms
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --with-pkgversion="MassOS Glibc 2.41" --with-bugurl="https://github.com/MassOS-Linux/MassOS/issues" --enable-kernel=5.10 --enable-stack-protector=strong --disable-nscd --disable-werror libc_cv_slibdir=/usr/lib
make
sed -i '/test-installation/s@$(PERL)@echo not running@' ../Makefile
make install
sed -i '/RTLDLIST=/s@/usr@@g' /usr/bin/ldd
sed -e '/#/d' -e '/SUPPORTED-LOCALES/d' -e 's|\\||g' -e 's|/| |g' -e 's|^|#|g' -e 's|#en_US.UTF-8|en_US.UTF-8|' ../localedata/SUPPORTED >> /etc/locales
mklocales
install -t /usr/share/licenses/glibc -Dm644 ../COPYING ../COPYING.LIB ../LICENSES
popd; popd
rm -rf glibc-2.41
# tzdata.
mkdir -p tzdata; pushd tzdata
tar -xf ../../sources/tzdata2025b.tar.gz
mkdir -p /usr/share/zoneinfo/{posix,right}
for r in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do zic -L /dev/null -d /usr/share/zoneinfo $r; zic -L /dev/null -d /usr/share/zoneinfo/posix $r; zic -L leapseconds -d /usr/share/zoneinfo/right $r; done
install -t /usr/share/zoneinfo -Dm644 {iso3166,zone{,1970}}.tab
zic -d /usr/share/zoneinfo -p America/New_York
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
install -t /usr/share/licenses/tzdata -Dm644 LICENSE
popd
rm -rf tzdata
# zlib.
tar -xf ../sources/zlib-1.3.1.tar.xz
pushd zlib-1.3.1
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libz.a
head -n28 zlib.h | tail -n25 | install -Dm644 /dev/stdin /usr/share/licenses/zlib/LICENSE
popd
rm -rf zlib-1.3.1
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
ln -s libbz2.so.1.0.8 /usr/lib/libbz2.so
cp bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sf bzip2 $i
done
rm -f /usr/lib/libbz2.a
install -t /usr/share/licenses/bzip2 -Dm644 LICENSE
popd
rm -rf bzip2-1.0.8
# xz.
tar -xf ../sources/xz-5.8.1.tar.xz
pushd xz-5.8.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xz -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1
popd
rm -rf xz-5.8.1
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
cat README | tail -n18 > /usr/share/licenses/pigz/LICENSE
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
tar -xf ../sources/readline-8.2.13.tar.gz
pushd readline-8.2.13
./configure --prefix=/usr --disable-static --with-curses
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
install -t /usr/share/licenses/readline -Dm644 COPYING
popd
rm -rf readline-8.2.13
# m4.
tar -xf ../sources/m4-1.4.19.tar.xz
pushd m4-1.4.19
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/m4 -Dm644 COPYING
popd
rm -rf m4-1.4.19
# bc.
tar -xf ../sources/bc-7.0.3.tar.xz
pushd bc-7.0.3
CC=gcc ./configure.sh --prefix=/usr --disable-generated-tests --enable-readline
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
tar -xf ../sources/pkgconf-2.4.3.tar.xz
pushd pkgconf-2.4.3
./configure --prefix=/usr --disable-static
make
make install
ln -sf pkgconf /usr/bin/pkg-config
ln -sf pkgconf.1 /usr/share/man/man1/pkg-config.1
install -t /usr/share/licenses/pkgconf -Dm644 COPYING
ln -sf pkgconf /usr/share/licenses/pkg-config
popd
rm -rf pkgconf-2.4.3
# Binutils.
tar -xf ../sources/binutils-2.44.tar.xz
pushd binutils-2.44
mkdir -p build; pushd build
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --sysconfdir=/etc --with-pkgversion="MassOS Binutils 2.44" --with-bugurl="https://github.com/MassOS-Linux/MassOS/issues" --with-system-zlib --enable-default-hash-style=gnu --enable-gold --enable-install-libiberty --enable-ld=default --enable-new-dtags --enable-plugins --enable-relro --enable-shared --disable-werror
make tooldir=/usr
make -j1 tooldir=/usr install
rm -f /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
install -t /usr/share/licenses/binutils -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB
popd; popd
rm -rf binutils-2.44
# GMP.
tar -xf ../sources/gmp-6.3.0.tar.xz
pushd gmp-6.3.0
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
tar -xf ../sources/mpc-1.3.1.tar.gz
pushd mpc-1.3.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/mpc -Dm644 COPYING.LESSER
popd
rm -rf mpc-1.3.1
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
tar -xf ../sources/attr-2.5.2.tar.xz
pushd attr-2.5.2
./configure --prefix=/usr --disable-static --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/attr -Dm644 doc/COPYING doc/COPYING.LGPL
popd
rm -rf attr-2.5.2
# Acl.
tar -xf ../sources/acl-2.3.2.tar.xz
pushd acl-2.3.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/acl -Dm644 doc/COPYING doc/COPYING.LGPL
popd
rm -rf acl-2.3.2
# libxcrypt.
tar -xf ../sources/libxcrypt-4.4.38.tar.xz
pushd libxcrypt-4.4.38
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
rm -rf libxcrypt-4.4.38
# Libcap.
tar -xf ../sources/libcap-2.76.tar.xz
pushd libcap-2.76
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib CFLAGS="$CFLAGS -fPIC"
make prefix=/usr lib=lib install
chmod 755 /usr/lib/lib{cap,psx}.so.2.*
install -t /usr/share/licenses/libcap -Dm644 License
popd
rm -rf libcap-2.76
# CrackLib.
tar -xf ../sources/cracklib-2.10.3.tar.bz2
pushd cracklib-2.10.3
CPPFLAGS="-I/usr/include/$(readlink /usr/bin/python3)" ./configure --prefix=/usr --sbindir=/usr/bin --disable-static --with-python --with-default-dict=/usr/lib/cracklib/pw_dict
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
tar -xf ../sources/libcap-2.76.tar.xz
pushd libcap-2.76
make CFLAGS="$CFLAGS -fPIC" -C pam_cap
install -t /usr/lib/security -Dm755 pam_cap/pam_cap.so
install -t /etc/security -Dm644 pam_cap/capability.conf
popd
rm -rf libcap-2.76
# Shadow (initial build; will be rebuilt later to support AUDIT).
tar -xf ../sources/shadow-4.17.4.tar.xz
pushd shadow-4.17.4
patch -Np1 -i ../../patches/shadow-4.17.2-MassOS.patch
touch /usr/bin/passwd
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-static --with-bcrypt --with-group-name-max-length=32 --with-libcrack --with-yescrypt --without-libbsd
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
rm -rf shadow-4.17.4
# GCC.
tar -xf ../sources/gcc-14.2.0.tar.xz
pushd gcc-14.2.0
sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64
mkdir -p build; pushd build
CFLAGS="-O2" CXXFLAGS="-O2" ../configure LD=ld --prefix=/usr --with-pkgversion="MassOS GCC 14.2.0" --with-bugurl="https://github.com/MassOS-Linux/MassOS/issues" --with-system-zlib --enable-languages=c,c++ --enable-default-pie --enable-default-ssp --enable-host-pie --enable-linker-build-id --disable-fixincludes --disable-multilib
make
make install
ln -sfr /usr/bin/cpp /usr/lib
ln -sf ../../libexec/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion)/liblto_plugin.so /usr/lib/bfd-plugins/
ln -sf gcc.1 /usr/share/man/man1/cc.1
mkdir -p /usr/share/gdb/auto-load/usr/lib
mv /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
find /usr -depth -name x86_64-stage1-linux-gnu\* | xargs rm -rf
install -t /usr/share/licenses/gcc -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB ../COPYING.RUNTIME
popd; popd
rm -rf gcc-14.2.0
# unifdef.
tar -xf ../sources/unifdef-2.12.tar.gz
pushd unifdef-2.12
make
make prefix=/usr install
install -t /usr/share/licenses/unifdef -Dm644 COPYING
popd
rm -rf unifdef-2.12
# Ncurses.
tar -xf ../sources/ncurses-6.5.tar.gz
pushd ncurses-6.5
mkdir -p build; pushd build
../configure --prefix=/usr --mandir=/usr/share/man --enable-pc-files --with-shared --with-cxx-shared --without-debug --without-normal --with-pkg-config-libdir=/usr/lib/pkgconfig
make
make DESTDIR=$PWD/temp install
install -t /usr/lib -Dm755 temp/usr/lib/libncursesw.so.6.5
rm -f temp/usr/lib/libncursesw.so.6.5
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
rm -rf ncurses-6.5
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
tar -xf ../sources/libsigsegv-2.14.tar.gz
pushd libsigsegv-2.14
./configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/libsigsegv -Dm644 COPYING
popd
rm -rf libsigsegv-2.14
# Sed.
tar -xf ../sources/sed-4.9.tar.xz
pushd sed-4.9
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sed -Dm644 COPYING
popd
rm -rf sed-4.9
# Gettext.
tar -xf ../sources/gettext-0.24.tar.xz
pushd gettext-0.24
./configure --prefix=/usr --disable-static
make
make install
chmod 0755 /usr/lib/preloadable_libintl.so
install -t /usr/share/licenses/gettext -Dm644 COPYING
popd
rm -rf gettext-0.24
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
tar -xf ../sources/pcre2-10.45.tar.bz2
pushd pcre2-10.45
./configure --prefix=/usr --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline --disable-static
make
make install
install -t /usr/share/licenses/pcre2 -Dm644 LICENCE.md
popd
rm -rf pcre2-10.45
# Grep.
tar -xf ../sources/grep-3.12.tar.xz
pushd grep-3.12
./configure --prefix=/usr
make
make install
popd
rm -rf grep-3.12
# Bash.
tar -xf ../sources/bash-5.2.37.tar.gz
pushd bash-5.2.37
./configure --prefix=/usr --without-bash-malloc --with-installed-readline
make
make install
ln -sf bash.1 /usr/share/man/man1/sh.1
install -t /usr/share/licenses/bash -Dm644 COPYING
popd
rm -rf bash-5.2.37
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
tar -xf ../sources/gperf-3.2.1.tar.gz
pushd gperf-3.2.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gperf -Dm644 COPYING
popd
rm -rf gperf-3.2.1
# Expat.
tar -xf ../sources/expat-2.7.1.tar.xz
pushd expat-2.7.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/expat -Dm644 COPYING
popd
rm -rf expat-2.7.1
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
tar -xf ../sources/inetutils-2.6.tar.xz
pushd inetutils-2.6
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" ./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var --disable-ifconfig --disable-logger --disable-servers --disable-whois
make
make install
install -t /usr/share/licenses/inetutils -Dm644 COPYING
popd
rm -rf inetutils-2.6
# net-tools.
tar -xf ../sources/net-tools-2.10.tar.xz
pushd net-tools-2.10
sed -e 's/I18N n/I18N y/' -e 's/HAVE_HOSTNAME_TOOLS y/HAVE_HOSTNAME_TOOLS n/' -e 's/HAVE_HOSTNAME_SYMLINKS y/HAVE_HOSTNAME_SYMLINKS n/' -i config.in
yes "" | ./configure.sh config.in
make BINDIR=/usr/bin SBINDIR=/usr/bin
make BINDIR=/usr/bin SBINDIR=/usr/bin install
install -t /usr/share/licenses/net-tools -Dm644 COPYING
popd
rm -rf net-tools-2.10
# Netcat.
tar -xf ../sources/netcat-0.7.1.tar.bz2
pushd netcat-0.7.1
./configure --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -t /usr/share/licenses/netcat -Dm644 COPYING
popd
rm -rf netcat-0.7.1
# Less.
tar -xf ../sources/less-668.tar.gz
pushd less-668
./configure --prefix=/usr --sysconfdir=/etc --with-regex=pcre2
make
make install
install -t /usr/share/licenses/less -Dm644 COPYING LICENSE
popd
rm -rf less-668
# Lua.
tar -xf ../sources/lua-5.4.7.tar.gz
pushd lua-5.4.7
patch -Np1 -i ../../patches/lua-5.4.4-sharedlib+pkgconfig.patch
make MYCFLAGS="$CFLAGS -fPIC" linux-readline
make INSTALL_DATA="cp -d" INSTALL_TOP=/usr INSTALL_MAN=/usr/share/man/man1 TO_LIB="liblua.so liblua.so.5.4 liblua.so.5.4.7" install
install -t /usr/lib/pkgconfig -Dm644 lua.pc
cat src/lua.h | tail -n24 | head -n20 | sed -e 's/* //g' -e 's/*//g' > COPYING
install -t /usr/share/licenses/lua -Dm644 COPYING
popd
rm -rf lua-5.4.7
# Perl.
tar -xf ../sources/perl-5.40.2.tar.xz
pushd perl-5.40.2
BUILD_ZLIB=False BUILD_BZIP2=0 ./Configure -des -Doptimize="$CFLAGS" -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.40/core_perl -Darchlib=/usr/lib/perl5/5.40/core_perl -Dsitelib=/usr/lib/perl5/5.40/site_perl -Dsitearch=/usr/lib/perl5/5.40/site_perl -Dvendorlib=/usr/lib/perl5/5.40/vendor_perl -Dvendorarch=/usr/lib/perl5/5.40/vendor_perl -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 -Dpager="/usr/bin/less -isR" -Duseshrplib -Dusethreads
BUILD_ZLIB=False BUILD_BZIP2=0 make
BUILD_ZLIB=False BUILD_BZIP2=0 make install
install -t /usr/share/licenses/perl -Dm644 Copying
popd
rm -rf perl-5.40.2
# SGMLSpm
tar -xf ../sources/SGMLSpm-1.1.tar.gz
pushd SGMLSpm-1.1
chmod +w MYMETA.yml
perl Makefile.PL INSTALLDIRS=vendor
make
make install
rm -f /usr/lib/perl5/5.40/core_perl/perllocal.pod
ln -sf sgmlspl.pl /usr/bin/sgmlspl
install -t /usr/share/licenses/sgmlspm -Dm644 COPYING
popd
rm -rf SGMLSpm-1.1
# XML-Parser.
tar -xf ../sources/XML-Parser-2.47.tar.gz
pushd XML-Parser-2.47
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -t /usr/share/licenses/xml-parser -Dm644 LICENSE
popd
rm -rf XML-Parser-2.47
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
tar -xf ../sources/autoconf-2.72.tar.xz
pushd autoconf-2.72
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/autoconf -Dm644 COPYING COPYINGv3 COPYING.EXCEPTION
popd
rm -rf autoconf-2.72
# Autoconf (legacy version 2.13).
tar -xf ../sources/autoconf-2.13.tar.gz
pushd autoconf-2.13
patch -Np1 -i ../../patches/autoconf-2.13-consolidated_fixes-1.patch
mv autoconf.texi autoconf213.texi
rm autoconf.info
./configure --prefix=/usr --infodir=/usr/share/info --program-suffix=2.13
make
make install
install -m644 autoconf213.info /usr/share/info
install-info --info-dir=/usr/share/info autoconf213.info
install -t /usr/share/licenses/autoconf213 -Dm644 COPYING
popd
rm -rf autoconf-2.13
# Automake.
tar -xf ../sources/automake-1.17.tar.xz
pushd automake-1.17
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/automake -Dm644 COPYING
popd
rm -rf automake-1.17
# autoconf-archive.
tar -xf ../sources/autoconf-archive-2023.02.20.tar.xz
pushd autoconf-archive-2023.02.20
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/autoconf-archive -Dm644 COPYING{,.EXCEPTION}
popd
rm -rf autoconf-archive-2023.02.20
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
tar -xf ../sources/elfutils-0.192.tar.bz2
pushd elfutils-0.192
CFLAGS="-O2" CXXFLAGS="-O2" ./configure --prefix=/usr --sysconfdir=/etc --program-prefix="eu-" --disable-debuginfod --enable-libdebuginfod=dummy
make
make install
rm -f /usr/lib/lib{asm,dw,elf}.a
install -t /usr/share/licenses/elfutils -Dm644 COPYING COPYING-GPLV2 COPYING-LGPLV3
popd
rm -rf elfutils-0.192
# libbpf.
tar -xf ../sources/libbpf-1.5.0.tar.gz
pushd libbpf-1.5.0/src
make
make LIBSUBDIR=lib install
rm -f /usr/lib/libbpf.a
install -t /usr/share/licenses/libbpf -Dm644 ../LICENSE{,.BSD-2-Clause,.LGPL-2.1}
popd
rm -rf libbpf-1.5.0
# patchelf.
tar -xf ../sources/patchelf-0.18.0.tar.bz2
pushd patchelf-0.18.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/patchelf -Dm644 COPYING
popd
rm -rf patchelf-0.18.0
# strace.
tar -xf ../sources/strace-6.14.tar.xz
pushd strace-6.14
./configure --prefix=/usr --with-libdw
make
make install
install -t /usr/share/licenses/strace -Dm644 COPYING LGPL-2.1-or-later
popd
rm -rf strace-6.14
# memstrack.
tar -xf ../sources/memstrack-0.2.5.tar.gz
pushd memstrack-0.2.5
make
make install
install -t /usr/share/licenses/memstrack -Dm644 LICENSE
popd
rm -rf memstrack-0.2.5
# libffi.
tar -xf ../sources/libffi-3.4.7.tar.gz
pushd libffi-3.4.7
./configure --prefix=/usr --disable-static --disable-exec-static-tramp --disable-multi-os-directory --enable-pax_emutramp
make
make install
install -t /usr/share/licenses/libffi -Dm644 LICENSE
popd
rm -rf libffi-3.4.7
# OpenSSL.
tar -xf ../sources/openssl-3.5.0.tar.gz
pushd openssl-3.5.0
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
install -t /usr/share/licenses/openssl -Dm644 LICENSE.txt
popd
rm -rf openssl-3.5.0
# easy-rsa.
tar -xf ../sources/EasyRSA-3.2.2.tgz
pushd EasyRSA-3.2.2
install -Dm755 easyrsa /usr/bin/easyrsa
install -Dm644 openssl-easyrsa.cnf /etc/easy-rsa/openssl-easyrsa.cnf
install -Dm644 vars.example /etc/easy-rsa/vars
install -dm755 /etc/easy-rsa/x509-types/
install -m644 x509-types/* /etc/easy-rsa/x509-types/
install -t /usr/share/licenses/easy-rsa -Dm644 COPYING.md gpl-2.0.txt
popd
rm -rf EasyRSA-3.2.2
# mpdecimal.
tar -xf ../sources/mpdecimal-4.0.0.tar.gz
pushd mpdecimal-4.0.0
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libmpdec{,++}.a
install -t /usr/share/licenses/mpdecimal -Dm644 COPYRIGHT.txt
popd
rm -rf mpdecimal-4.0.0
# scdoc.
tar -xf ../sources/scdoc-1.11.0.tar.gz
pushd scdoc-1.11.0
sed -i 's/-Werror//g' Makefile
make PREFIX=/usr
make PREFIX=/usr install
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
tar -xf ../sources/Python-3.13.3.tar.xz
pushd Python-3.13.3
./configure --prefix=/usr --enable-shared --enable-optimizations --with-system-expat --with-system-libmpdec --with-ensurepip --disable-test-modules
make
make install
ln -sf python3 /usr/bin/python
ln -sf pydoc3 /usr/bin/pydoc
ln -sf idle3 /usr/bin/idle
ln -sf python3-config /usr/bin/python-config
ln -sf pip3 /usr/bin/pip
install -t /usr/share/licenses/python -Dm644 LICENSE
popd
rm -rf Python-3.13.3
# flit-core.
tar -xf ../sources/flit_core-3.12.0.tar.gz
pushd flit_core-3.12.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist flit_core
install -t /usr/share/licenses/flit-core -Dm644 LICENSE
popd
rm -rf flit_core-3.12.0
# packaging.
tar -xf ../sources/packaging-24.2.tar.gz
pushd packaging-24.2
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist packaging
install -t /usr/share/licenses/packaging -Dm644 LICENSE{,.APACHE,.BSD}
popd
rm -rf packaging-24.2
# wheel.
tar -xf ../sources/wheel-0.46.1.tar.gz
pushd wheel-0.46.1
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist wheel
install -t /usr/share/licenses/wheel -Dm644 LICENSE.txt
popd
rm -rf wheel-0.46.1
# setuptools.
tar -xf ../sources/setuptools-78.1.0.tar.gz
pushd setuptools-78.1.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist setuptools
install -t /usr/share/licenses/setuptools -Dm644 LICENSE
popd
rm -rf setuptools-78.1.0
# pip.
tar -xf ../sources/pip-25.0.1.tar.gz
pushd pip-25.0.1
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist pip --upgrade
install -t /usr/share/licenses/pip -Dm644 LICENSE.txt
popd
rm -rf pip-25.0.1
# pyproject-hooks.
tar -xf ../sources/pyproject_hooks-1.2.0.tar.gz
pushd pyproject_hooks-1.2.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist pyproject-hooks
install -t /usr/share/licenses/pyproject-hooks -Dm644 LICENSE
popd
rm -rf pyproject_hooks-1.2.0
# installer.
tar -xf ../sources/installer-0.7.0.tar.gz
pushd installer-0.7.0
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist installer
install -t /usr/share/licenses/installer -Dm644 LICENSE
popd
rm -rf installer-0.7.0
# build.
tar -xf ../sources/build-1.2.2.post1.tar.gz
pushd build-1.2.2.post1
pip --disable-pip-version-check wheel --no-build-isolation --no-cache-dir --no-deps -w dist .
pip --disable-pip-version-check install --root-user-action ignore --compile --no-cache-dir --no-index --no-user -f dist build
install -t /usr/share/licenses/build -Dm644 LICENSE
popd
rm -rf build-1.2.2.post1
# Sphinx (required to build man pages of some packages).
mkdir -p /root/mbs/extras/sphinx
tar --no-same-owner --same-permissions -xf ../sources/sphinx-20250119-x86_64-python3.13-venv.tar.xz -C /root/mbs/extras/sphinx --strip-components=1
# Ninja.
tar -xf ../sources/ninja-1.12.1.tar.gz
pushd ninja-1.12.1
python configure.py --bootstrap
install -t /usr/bin -Dm755 ninja
install -Dm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -Dm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja
install -t /usr/share/licenses/ninja -Dm644 COPYING
popd
rm -rf ninja-1.12.1
# Meson.
tar -xf ../sources/meson-1.7.2.tar.gz
pushd meson-1.7.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/bash-completion/completions -Dm644 data/shell-completions/bash/meson
install -t /usr/share/zsh/site-functions -Dm644 data/shell-completions/zsh/_meson
install -t /usr/share/licenses/meson -Dm644 COPYING
popd
rm -rf meson-1.7.2
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
tar -xf ../sources/pyparsing-3.2.3.tar.gz
pushd pyparsing-3.2.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyparsing -Dm644 LICENSE
popd
rm -rf pyparsing-3.2.3
# edittables.
tar -xf ../sources/editables-0.5.tar.gz
pushd editables-0.5
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/editables -Dm644 LICENSE.txt
popd
rm -rf editables-0.5
# pyproject-metadata.
tar -xf ../sources/pyproject_metadata-0.9.1.tar.gz
pushd pyproject_metadata-0.9.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyproject-metadata -Dm644 LICENSE
popd
rm -rf pyproject_metadata-0.9.1
# typing-extensions
tar -xf ../sources/typing_extensions-4.13.1.tar.gz
pushd typing_extensions-4.13.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/typing-extensions -Dm644 LICENSE
popd
rm -rf typing_extensions-4.13.1
# setuptools-scm.
tar -xf ../sources/setuptools-scm-8.2.0.tar.gz
pushd setuptools-scm-8.2.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/setuptools-scm -Dm644 LICENSE
popd
rm -rf setuptools-scm-8.2.0
# pytz.
tar -xf ../sources/pytz-2025.2.tar.gz
pushd pytz-2025.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pytz -Dm644 LICENSE.txt
popd
rm -rf pytz-2025.2
# pathspec.
tar -xf ../sources/pathspec-0.12.1.tar.gz
pushd pathspec-0.12.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pathspec -Dm644 LICENSE
popd
rm -rf pathspec-0.12.1
# pluggy.
tar -xf ../sources/pluggy-1.5.0.tar.gz
pushd pluggy-1.5.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pluggy -Dm644 LICENSE
popd
rm -rf pluggy-1.5.0
# trove-classifiers.
tar -xf ../sources/trove-classifiers-2025.3.19.19.tar.gz
pushd trove-classifiers-2025.3.19.19
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
popd
rm -rf trove-classifiers-2025.3.19.19
# hatchling.
tar -xf ../sources/hatchling-1.27.0.tar.gz
pushd hatchling-1.27.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/hatching -Dm644 LICENSE.txt
popd
rm -rf hatchling-1.27.0
# hatch-vcs.
tar -xf ../sources/hatch-vcs-0.4.0.tar.gz
pushd hatch-vcs-0.4.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/hatch-vcs -Dm644 LICENSE.txt
popd
rm -rf hatch-vcs-0.4.0
# legacy-cgi.
tar -xf ../sources/legacy-cgi-2.6.3.tar.gz
pushd legacy-cgi-2.6.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/legacy-cgi -Dm644 LICENSE
popd
rm -rf legacy-cgi-2.6.3
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
# libmspack.
tar -xf ../sources/libmspack-1.11.tar.gz
pushd libmspack-1.11/libmspack
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libmspack -Dm644 COPYING.LIB
popd
rm -rf libmspack-1.11
# libseccomp.
tar -xf ../sources/libseccomp-2.6.0.tar.gz
pushd libseccomp-2.6.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libseccomp -Dm644 LICENSE
popd
rm -rf libseccomp-2.6.0
# File.
tar -xf ../sources/file-5.46.tar.gz
pushd file-5.46
mkdir -p bootstrap; pushd bootstrap
../configure --prefix=/usr --enable-libseccomp
make
popd
./configure --prefix=/usr --enable-libseccomp
make FILE_COMPILE="$PWD"/bootstrap/src/file
make install
install -t /usr/share/licenses/file -Dm644 COPYING
popd
rm -rf file-5.46
# Coreutils.
tar -xf ../sources/coreutils-9.7.tar.xz
pushd coreutils-9.7
./configure --prefix=/usr --enable-no-install-program=hostname,kill,uptime --with-packager=MassOS
make
make install
mv /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
dircolors -p > /etc/dircolors
install -t /usr/share/licenses/coreutils -Dm644 COPYING
popd
rm -rf coreutils-9.7
# Diffutils.
tar -xf ../sources/diffutils-3.12.tar.xz
pushd diffutils-3.12
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/diffutils -Dm644 COPYING
popd
rm -rf diffutils-3.12
# Gawk.
tar -xf ../sources/gawk-5.3.2.tar.xz
pushd gawk-5.3.2
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/gawk -Dm644 COPYING
popd
rm -rf gawk-5.3.2
# Findutils.
tar -xf ../sources/findutils-4.10.0.tar.xz
pushd findutils-4.10.0
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make install
install -t /usr/share/licenses/findutils -Dm644 COPYING
popd
rm -rf findutils-4.10.0
# Groff.
tar -xf ../sources/groff-1.23.0.tar.gz
pushd groff-1.23.0
./configure --prefix=/usr
make -j1
make install
install -t /usr/share/licenses/groff -Dm644 COPYING LICENSES
popd
rm -rf groff-1.23.0
# Gzip.
tar -xf ../sources/gzip-1.14.tar.xz
pushd gzip-1.14
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gzip -Dm644 COPYING
popd
rm -rf gzip-1.14
# Texinfo.
tar -xf ../sources/texinfo-7.2.tar.xz
pushd texinfo-7.2
./configure --prefix=/usr
make
make install
make TEXMF=/usr/share/texmf install-tex
install -t /usr/share/licenses/texinfo -Dm644 COPYING
popd
rm -rf texinfo-7.2
# Sharutils.
tar -xf ../sources/sharutils-4.15.2.tar.xz
pushd sharutils-4.15.2
sed -i 's/BUFSIZ/rw_base_size/' src/unshar.c
sed -i '/program_name/s/^/extern /' src/*opts.h
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sharutils -Dm644 COPYING
popd
rm -rf sharutils-4.15.2
# LMDB.
tar -xf ../sources/LMDB_0.9.31.tar.gz
pushd lmdb-LMDB_0.9.31/libraries/liblmdb
make CFLAGS="$CFLAGS"
sed -i 's| liblmdb.a||' Makefile
make prefix=/usr install
install -t /usr/share/licenses/lmdb -Dm644 COPYRIGHT LICENSE
popd
rm -rf lmdb-LMDB_0.9.31
# Cyrus-SASL (will be rebuilt later to support krb5 and OpenLDAP).
tar -xf ../sources/cyrus-sasl-2.1.28.tar.gz
pushd cyrus-sasl-2.1.28
sed -i '/saslint/a #include <time.h>' lib/saslutil.c
sed -i '/plugin_common/a #include <time.h>' plugins/cram.c
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
tar -xf ../sources/iptables-1.8.11.tar.xz
pushd iptables-1.8.11
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-libipq --enable-nftables
make
make install
install -t /usr/share/licenses/iptables -Dm644 COPYING
popd
rm -rf iptables-1.8.11
# UFW.
tar -xf ../sources/ufw-0.36.2.tar.gz
pushd ufw-0.36.2
python setup.py install
install -t /usr/share/licenses/ufw -Dm644 COPYING
popd
rm -rf ufw-0.36.2
# IPRoute2.
tar -xf ../sources/iproute2-6.14.0.tar.xz
pushd iproute2-6.14.0
make
make SBINDIR=/usr/bin install
install -t /usr/share/licenses/iproute2 -Dm644 COPYING
popd
rm -rf iproute2-6.14.0
# Kbd.
tar -xf ../sources/kbd-2.7.1.tar.xz
pushd kbd-2.7.1
patch -Np1 -i ../../patches/kbd-2.4.0-backspace-1.patch
sed -i 's/RESIZECONS_PROGS=yes/RESIZECONS_PROGS=no/g' configure
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-tests
make
make install
rm -f /usr/share/man/man8/resizecons.8
install -t /usr/share/licenses/kbd -Dm644 COPYING
popd
rm -rf kbd-2.7.1
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
tar -xf ../sources/libunwind-1.8.1.tar.gz
pushd libunwind-1.8.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libunwind -Dm644 COPYING
popd
rm -rf libunwind-1.8.1
# libuv.
tar -xf ../sources/libuv-v1.50.0.tar.gz
pushd libuv-v1.50.0
./autogen.sh
./configure --prefix=/usr --disable-static
make
make -C docs man
make install
install -t /usr/share/man/man1 -Dm644 docs/build/man/libuv.1
install -t /usr/share/licenses/libuv -Dm644 LICENSE
popd
rm -rf libuv-v1.50.0
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
tar -xf ../sources/ed-1.21.1.tar.lz
pushd ed-1.21.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/ed -Dm644 COPYING
popd
rm -rf ed-1.21.1
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
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/tar -Dm644 COPYING
popd
rm -rf tar-1.35
# Nano.
tar -xf ../sources/nano-8.4.tar.xz
pushd nano-8.4
./configure --prefix=/usr --sysconfdir=/etc --enable-utf8
make
make install
cp doc/sample.nanorc /etc/nanorc
sed -i '0,/# include/{s/# include/include/}' /etc/nanorc
install -t /usr/share/licenses/nano -Dm644 COPYING
popd
rm -rf nano-8.4
# dos2unix.
tar -xf ../sources/dos2unix-7.5.2.tar.gz
pushd dos2unix-7.5.2
make
make install
install -t /usr/share/licenses/dos2unix -Dm644 COPYING.txt
popd
rm -rf dos2unix-7.5.2
# docutils.
tar -xf ../sources/docutils-0.21.2.tar.gz
pushd docutils-0.21.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/docutils -Dm644 COPYING.txt
popd
rm -rf docutils-0.21.2
# MarkupSafe.
tar -xf ../sources/markupsafe-3.0.2.tar.gz
pushd markupsafe-3.0.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/markupsafe -Dm644 LICENSE.txt
popd
rm -rf markupsafe-3.0.2
# Jinja2.
tar -xf ../sources/jinja2-3.1.6.tar.gz
pushd jinja2-3.1.6
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/jinja2 -Dm644 LICENSE.txt
popd
rm -rf jinja2-3.1.6
# Mako.
tar -xf ../sources/mako-1.3.10.tar.gz
pushd mako-rel_1_3_10
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/mako -Dm644 LICENSE
popd
rm -rf mako-rel_1_3_10
# pyxdg.
tar -xf ../sources/pyxdg-0.28.tar.gz
pushd pyxdg-0.28
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
tar -xf ../sources/pygments-2.19.1.tar.gz
pushd pygments-2.19.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pygments -Dm644 LICENSE
popd
rm -rf pygments-2.19.1
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
tar -xf ../sources/smartypants.py-2.0.1.tar.gz
pushd smartypants.py-2.0.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/smartypants -Dm644 COPYING
popd
rm -rf smartypants.py-2.0.1
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
tar -xf ../sources/markdown-3.7.tar.gz
pushd markdown-3.7
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/markdown -Dm644 LICENSE.md
popd
rm -rf markdown-3.7
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
tar -xf ../sources/cython-3.0.12.tar.gz
pushd cython-3.0.12
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/cython -Dm644 {COPYING,LICENSE}.txt
popd
rm -rf cython-3.0.12
# PyYAML.
tar -xf ../sources/pyyaml-6.0.2.tar.gz
pushd pyyaml-6.0.2
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyyaml -Dm644 LICENSE
popd
rm -rf pyyaml-6.0.2
# gi-docgen.
tar -xf ../sources/gi-docgen-2025.3.tar.gz
pushd gi-docgen-2025.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddevelopment_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gi-docgen -Dm644 LICENSES/{Apache-2.0.txt,GPL-3.0-or-later.txt}
popd
rm -rf gi-docgen-2025.3
# Locale-gettext.
tar -xf ../sources/Locale-gettext-1.07.tar.gz
pushd Locale-gettext-1.07
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -dm755 /usr/share/licenses/locale-gettext
cat README | head -n16 | tail -n6 > /usr/share/licenses/locale-gettext/COPYING
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
tar -xf ../sources/which-2.23.tar.gz
pushd which-2.23
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/which -Dm644 COPYING
popd
rm -rf which-2.23
# tree.
tar -xf ../sources/unix-tree-2.2.1.tar.bz2
pushd unix-tree-2.2.1
make CFLAGS="$CFLAGS"
make PREFIX=/usr MANDIR=/usr/share/man install
chmod 644 /usr/share/man/man1/tree.1
install -t /usr/share/licenses/tree -Dm644 LICENSE
popd
rm -rf unix-tree-2.2.1
# GPM.
tar -xf ../sources/gpm-1.20.7-38-ge82d1a6.tar.gz
pushd gpm-e82d1a653ca94aa4ed12441424da6ce780b1e530
patch -Np1 -i ../../patches/gpm-1.20.7-pregenerated-docs.patch
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin
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
tar -xf ../sources/jq-1.7.1.tar.gz
pushd jq-1.7.1
./configure --prefix=/usr --disable-docs --disable-static
make
make install
install -t /usr/share/licenses/jq -Dm644 COPYING
popd
rm -rf jq-1.7.1
# ICU.
tar -xf ../sources/icu4c-77_1-src.tgz
pushd icu/source
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/icu -Dm644 ../LICENSE
popd
rm -rf icu
# Boost.
tar -xf ../sources/boost-1.88.0-b2-nodocs.tar.xz
pushd boost-1.88.0
./bootstrap.sh --prefix=/usr --with-icu
./b2 stage -j$(nproc) threading=multi link=shared
./b2 install threading=multi link=shared
install -t /usr/share/licenses/boost -Dm644 LICENSE_1_0.txt
popd
rm -rf boost-1.88.0
# libgpg-error.
tar -xf ../sources/libgpg-error-1.55.tar.bz2
pushd libgpg-error-1.55
./configure --prefix=/usr --enable-install-gpg-error-config
make
make install
install -t /usr/share/licenses/libgpg-error -Dm644 COPYING COPYING.LIB
popd
rm -rf libgpg-error-1.55
# libgcrypt.
tar -xf ../sources/libgcrypt-1.11.0.tar.bz2
pushd libgcrypt-1.11.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libgcrypt -Dm644 COPYING COPYING.LIB
popd
rm -rf libgcrypt-1.11.0
# Unzip.
tar -xf ../sources/unzip60.tar.gz
pushd unzip60
patch -Np1 -i ../../patches/unzip-6.0-manyfixes.patch
make -f unix/Makefile generic
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
tar -xf ../sources/zlib-1.3.1.tar.xz
pushd zlib-1.3.1/contrib/minizip
autoreconf -fi
./configure --prefix=/usr --enable-static=no
make
make install
install -t /usr/share/licenses/minizip -Dm644 /usr/share/licenses/zlib/LICENSE
popd
rm -rf zlib-1.3.1
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
./configure --prefix=/usr --disable-static
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
cp -af *.dtd *.mod *.dcl /usr/share/sgml/docbook/sgml-dtd-3.1
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
cp -af *.dtd *.mod *.dcl /usr/share/sgml/docbook/sgml-dtd-4.5
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
tar -xf ../sources/libxml2-2.14.2.tar.gz
pushd libxml2-2.14.2
./autogen.sh --prefix=/usr --sysconfdir=/etc --disable-static --with-history --with-icu --with-threads
make
make install
sed -i '/libs=/s/xml2.*/xml2"/' /usr/bin/xml2-config
install -t /usr/share/licenses/libxml2 -Dm644 Copyright
popd
rm -rf libxml2-2.14.2
# libarchive.
tar -xf ../sources/libarchive-3.7.9.tar.xz
pushd libarchive-3.7.9
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libarchive -Dm644 COPYING
popd
rm -rf libarchive-3.7.9
# Docbook XML 4.5.
mkdir docbook-xml-4.5
pushd docbook-xml-4.5
unzip -q ../../sources/docbook-xml-4.5.zip
install -dm755 /usr/share/xml/docbook/xml-dtd-4.5
install -dm755 /etc/xml
chown -R root:root .
cp -af docbook.cat *.dtd ent/ *.mod /usr/share/xml/docbook/xml-dtd-4.5
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
tar -xf ../sources/libxslt-1.1.43.tar.gz
pushd libxslt-1.1.43
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxslt -Dm644 Copyright
popd
rm -rf libxslt-1.1.43
# Lynx.
tar -xf ../sources/lynx2.9.2.tar.bz2
pushd lynx2.9.2
./configure --prefix=/usr --sysconfdir=/etc/lynx --datadir=/usr/share/doc/lynx --with-bzlib --with-screen=ncursesw --with-ssl --with-zlib --enable-gzip-help --enable-ipv6 --enable-locale-charset
make
make install-full
sed -i 's/#LOCALE_CHARSET:FALSE/LOCALE_CHARSET:TRUE/' /etc/lynx/lynx.cfg
sed -i 's/#DEFAULT_EDITOR:/DEFAULT_EDITOR:nano/' /etc/lynx/lynx.cfg
sed -i 's/#PERSISTENT_COOKIES:FALSE/PERSISTENT_COOKIES:TRUE/' /etc/lynx/lynx.cfg
install -t /usr/share/licenses/lynx -Dm644 COPYHEADER COPYING
popd
rm -rf lynx2.9.2
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
./configure --prefix=/usr --mandir=/usr/share/man --disable-static --enable-default-catalog=/etc/sgml/catalog --enable-default-search-path=/usr/share/sgml --enable-http
make pkgdatadir=/usr/share/sgml/OpenSP
make pkgdatadir=/usr/share/sgml/OpenSP install
for prog in {nsgmls,s{gmlnorm,p{am,cat,ent},x}}; do ln -sf o$prog /usr/bin/$prog; ln -sf o$prog.1 /usr/share/man/man1/$prog.1; done
ln -sf osx /usr/bin/sgml2xml
ln -sf libosp.so /usr/lib/libsp.so
install -t /usr/share/licenses/opensp -Dm644 COPYING
popd
rm -rf OpenSP-1.5.2
# OpenJade.
tar -xf ../sources/openjade-1.3.2.tar.gz
pushd openjade-1.3.2
patch -Np1 -i ../../patches/openjade-1.3.2-fixes.patch
CXXFLAGS="$CXXFLAGS -fno-lifetime-dse" ./configure --prefix=/usr --mandir=/usr/share/man --enable-http --disable-static --enable-default-catalog=/etc/sgml/catalog --enable-default-search-path=/usr/share/sgml --datadir=/usr/share/sgml/openjade
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
cp -R * /usr/share/sgml/docbook/dsssl-stylesheets-1.79
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
tar -xf ../sources/lxml-5.4.0.tar.gz
pushd lxml-5.4.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/lxml -Dm644 LICENSE.txt LICENSES.txt
popd
rm -rf lxml-5.4.0
# itstool.
tar -xf ../sources/itstool-2.0.7.tar.bz2
pushd itstool-2.0.7
PYTHON=/usr/bin/python3 ./configure --prefix=/usr
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
tar -xf ../sources/talloc-2.4.3.tar.gz
pushd talloc-2.4.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-talloc-compat1 --bundled-libraries=NONE
make
make install
install -t /usr/share/licenses/talloc -Dm644 LICENSE
popd
rm -rf talloc-2.4.3
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
tar -xf ../sources/gnu-efi-3.0.18.tar.bz2
pushd gnu-efi-3.0.18
CFLAGS="-O2" make
CFLAGS="-O2" make PREFIX=/usr install
install -t /usr/share/licenses/gnu-efi -Dm644 README.efilib
popd
rm -rf gnu-efi-3.0.18
# hwdata.
tar -xf ../sources/hwdata-0.394.tar.gz
pushd hwdata-0.394
./configure --prefix=/usr --disable-blacklist
make
make install
install -t /usr/share/licenses/hwdata -Dm644 COPYING
popd
rm -rf hwdata-0.394
# systemd (initial build; will be rebuilt later to support more features).
tar -xf ../sources/systemd-257.5.tar.gz
pushd systemd-257.5
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --localstatedir=/var --buildtype=minsize -Dmode=release -Dversion-tag=257.5-massos -Dshared-lib-tag=257.5-massos -Dbpf-framework=disabled -Dcryptolib=openssl -Ddefault-compression=xz -Ddefault-dnssec=no -Ddev-kvm-mode=0660 -Ddns-over-tls=openssl -Dfallback-hostname=massos -Dhomed=disabled -Dinitrd=true -Dinstall-tests=false -Dman=enabled -Dpamconfdir=/etc/pam.d -Drpmmacrosdir=no -Dsysupdate=disabled -Dsysusers=true -Dtests=false -Dtpm=true -Dukify=disabled -Duserdb=false
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
systemd-machine-id-setup
cat > /usr/lib/sysusers.d/massos.conf << "END"
# This file defines additional system users/groups which are required on a
# MassOS system, but systemd doesn't provide sysusers files for by default.

u bin 1 bin -
u sys 2 sys -

u daemon 6 "Daemon User" -
m daemon bin

g floppy 7 -
g lpadmin 19 -
g mail 34 -
g scanner 70 -
END
systemd-sysusers
chgrp utmp /var/log/lastlog
systemctl preset-all
systemctl disable systemd-time-wait-sync
install -t /usr/lib/systemd/system -Dm644 ../../extras/systemd-units/*
systemctl enable gpm
install -t /usr/share/licenses/systemd -Dm644 LICENSE.{GPL2,LGPL2.1} LICENSES/*
popd
rm -rf systemd-257.5
# D-Bus (initial build; will be rebuilt later for more features).
tar -xf ../sources/dbus-1.16.2.tar.xz
pushd dbus-1.16.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dapparmor=disabled -Dlibaudit=disabled -Dmodular_tests=disabled -Dselinux=disabled -Dx11_autolaunch=disabled
ninja -C build
ninja -C build install
systemd-sysusers
ln -sf /etc/machine-id /var/lib/dbus
install -t /usr/share/licenses/dbus -Dm644 COPYING
popd
rm -rf dbus-1.16.2
# Man-DB.
tar -xf ../sources/man-db-2.13.0.tar.xz
pushd man-db-2.13.0
./configure --prefix=/usr --sysconfdir=/etc --with-systemdsystemunitdir=/usr/lib/systemd/system --with-db=gdbm --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx
make
make install
install -t /usr/share/licenses/man-db -Dm644 COPYING
popd
rm -rf man-db-2.13.0
# Procps-NG.
tar -xf ../sources/procps-ng-4.0.5.tar.xz
pushd procps-ng-4.0.5
sed -i 's/ITEMS_COUNT);/16);/' src/pgrep.c
./configure --prefix=/usr --disable-static --disable-kill --with-systemd
make
make install
install -t /usr/share/licenses/procps-ng -Dm644 COPYING COPYING.LIB
popd
rm -rf procps-ng-4.0.5
# util-linux.
tar -xf ../sources/util-linux-2.41.tar.xz
pushd util-linux-2.41
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run --bindir=/usr/bin --libdir=/usr/lib --sbindir=/usr/bin --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-liblastlog2 --disable-static --without-python
make
make install
systemd-sysusers
systemctl enable uuidd.socket
install -t /usr/share/licenses/util-linux -Dm644 COPYING
popd
rm -rf util-linux-2.41
# FUSE2.
tar -xf ../sources/fuse-2.9.9.tar.gz
pushd fuse-2.9.9
patch -Np1 -i ../../patches/fuse-2.9.9-glibc234.patch
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
tar -xf ../sources/fuse-3.17.2.tar.gz
pushd fuse-3.17.2
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
rm -rf fuse-3.17.2
# e2fsprogs.
tar -xf ../sources/e2fsprogs-1.47.2.tar.xz
pushd e2fsprogs-1.47.2
mkdir -p build; pushd build
../configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-elf-shlibs --disable-fsck --disable-libblkid --disable-libuuid --disable-uuidd
make
make install
rm -f /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gzip -d /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
install -t /usr/share/licenses/e2fsprogs -Dm644 ../NOTICE
popd; popd
rm -rf e2fsprogs-1.47.2
# dosfstools.
tar -xf ../sources/dosfstools-4.2.tar.gz
pushd dosfstools-4.2
./configure --prefix=/usr --sbindir=/usr/bin --enable-compat-symlinks
make
make install
install -t /usr/share/licenses/dosfstools -Dm644 COPYING
popd
rm -rf dosfstools-4.2
# dracut.
tar -xf ../sources/dracut-ng-106.tar.gz
pushd dracut-ng-106
patch -Np1 -i ../../patches/dracut-106-upstreamfix.patch
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --sbindir=/usr/bin --systemdsystemunitdir=/usr/lib/systemd/system --bashcompletiondir=/usr/share/bash-completion/completions
make
make install
cat > /etc/dracut.conf.d/massos.conf << "END"
# Default dracut configuration file for MassOS.

# Compression to use for the initramfs.
compress="xz"

# Make the initramfs reproducible.
reproducible="yes"

# These modules are required to support live CD booting; do not remove them.
add_dracutmodules+=" dmsquash-live overlayfs "

# These modules are unneeded for booting MassOS and would bloat the initramfs.
# Some of them also have dependencies outside the scope of MassOS.
# Remove them from the exclude list only if you know what you are doing.
omit_dracutmodules+=" biosdevname cifs connman dash dbus-broker fcoe fcoe-uefi hwdb iscsi kernel-modules-extra kernel-network-modules lunmask memstrack mksh multipath nbd network network-legacy network-manager nfs nvdimm nvmf qemu qemu-net rngd usrmount virtiofs "
END
install -t /usr/share/licenses/dracut -Dm644 COPYING
popd
rm -rf dracut-ng-106
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
./configure --prefix=/usr --enable-mt --with-rmt=/usr/libexec/rmt
make
make install
install -t /usr/share/licenses/cpio -Dm644 COPYING
popd
rm -rf cpio-2.15
# squashfs-tools.
tar -xf ../sources/squashfs-tools-4.6.1.tar.gz
pushd squashfs-tools-4.6.1/squashfs-tools
make GZIP_SUPPORT=1 XZ_SUPPORT=1 LZO_SUPPORT=1 LZMA_XZ_SUPPORT=1 LZ4_SUPPORT=1 ZSTD_SUPPORT=1 XATTR_SUPPORT=1
make INSTALL_PREFIX=/usr INSTALL_MANPAGES_DIR=/usr/share/man/man1 install
install -t /usr/share/licenses/squashfs-tools -Dm644 ../COPYING
popd
rm -rf squashfs-tools-4.6.1
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
# libtasn1.
tar -xf ../sources/libtasn1-4.20.0.tar.gz
pushd libtasn1-4.20.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libtasn1 -Dm644 COPYING
popd
rm -rf libtasn1-4.20.0
# p11-kit.
tar -xf ../sources/p11-kit-0.25.5.tar.xz
pushd p11-kit-0.25.5
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
rm -rf p11-kit-0.25.5
# make-ca.
tar -xf ../sources/make-ca-1.16.tar.gz
pushd make-ca-1.16
make SBINDIR=/usr/bin install
mkdir -p /etc/ssl/local
make-ca -g
systemctl enable update-pki.timer
install -t /usr/share/licenses/make-ca -Dm644 LICENSE{,.GPLv3,.MIT}
popd
rm -rf make-ca-1.16
# libaio.
tar -xf ../sources/libaio-libaio-0.3.113.tar.gz
pushd libaio-libaio-0.3.113
sed -i '/install.*libaio.a/s/^/#/' src/Makefile
make
make install
install -t /usr/share/licenses/libaio -Dm644 COPYING
popd
rm -rf libaio-libaio-0.3.113
# mdadm.
tar -xf ../sources/mdadm-4.4.tar.gz
pushd mdadm-4.4
make BINDIR=/usr/bin UDEVDIR=/usr/lib/udev SYSTEMD_DIR=/usr/lib/systemd/system
make BINDIR=/usr/bin UDEVDIR=/usr/lib/udev SYSTEMD_DIR=/usr/lib/systemd/system install install-systemd
install -t /usr/share/licenses/mdadm -Dm644 COPYING
popd
rm -rf mdadm-4.4
# LVM2.
tar -xf ../sources/LVM2.2.03.31.tgz
pushd LVM2.2.03.31
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --enable-cmdlib --enable-dmeventd --enable-lvmpolld --enable-pkgconfig --enable-readline --enable-udev_rules --enable-udev_sync --with-thin=internal
make
make install install_systemd_units
install -t /usr/share/licenses/lvm2 -Dm644 COPYING{,.BSD,.LIB}
popd
rm -rf LVM2.2.03.31
# dmraid.
tar -xf ../sources/dmraid-1.0.0.rc16-3.tar.bz2
pushd dmraid/1.0.0.rc16-3/dmraid
./configure --prefix=/usr --sbindir=/usr/bin --enable-led --enable-intel_led --enable-shared_lib
make -j1
make -j1 install
rm -f /usr/lib/libdmraid.a
install -t /usr/share/licenses/dmraid -Dm644 LICENSE{,_GPL,_LGPL}
popd
rm -rf dmraid
# btrfs-progs.
tar -xf ../sources/btrfs-progs-v6.14.tar.xz
pushd btrfs-progs-v6.14
./configure --prefix=/usr --sbindir=/usr/bin --disable-static
make
make install
install -t /usr/share/licenses/btrfs-progs -Dm644 COPYING
popd
rm -rf btrfs-progs-v6.14
# inih.
tar -xf ../sources/inih-r60.tar.gz
pushd inih-r60
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/inih -Dm644 LICENSE.txt
popd
rm -rf inih-r60
# Userspace-RCU.
tar -xf ../sources/userspace-rcu-0.15.2.tar.bz2
pushd userspace-rcu-0.15.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/userspace-rcu -Dm644 LICENSE.md lgpl-relicensing.md LICENSES/*
popd
rm -rf userspace-rcu-0.15.2
# xfsprogs.
tar -xf ../sources/xfsprogs-6.14.0.tar.xz
pushd xfsprogs-6.14.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --with-systemd-unit-dir=/usr/lib/systemd/system --enable-editline
make
make PKG_USER=root PKG_GROUP=root install install-dev
rm -f /usr/lib/libhandle.{l,}a
install -t /usr/share/licenses/xfsprogs -Dm644 debian/copyright
popd
rm -rf xfsprogs-6.14.0
# f2fs-tools.
tar -xf ../sources/f2fs-tools-1.16.0.tar.gz
pushd f2fs-tools-1.16.0
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
tar -xf ../sources/ntfs-3g-2022.10.3.tar.gz
pushd ntfs-3g-2022.10.3
./autogen.sh
./configure --prefix=/usr --sbindir=/usr/bin --disable-static --with-fuse=external
make
make install
ln -sf ntfs-3g /usr/bin/mount.ntfs
ln -sf ntfs-3g.8 /usr/share/man/man8/mount.ntfs.8
install -t /usr/share/licenses/ntfs-3g -Dm644 COPYING COPYING.LIB
popd
rm -rf ntfs-3g-2022.10.3
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
# Fakeroot.
tar -xf ../sources/fakeroot-upstream-1.37.1.1.tar.bz2
pushd fakeroot-upstream-1.37.1.1
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
rm -rf fakeroot-upstream-1.37.1.1
# Parted.
tar -xf ../sources/parted-3.6.tar.xz
pushd parted-3.6
./configure --prefix=/usr --sbindir=/usr/bin --disable-static
make
make install
install -t /usr/share/licenses/parted -Dm644 COPYING
popd
rm -rf parted-3.6
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
tar -xf ../sources/debianutils-5.5.tar.gz
pushd debianutils-5.5
./configure --prefix=/usr
make run-parts
install -t /usr/bin -Dm755 run-parts
install -t /usr/share/man/man8 -Dm644 run-parts.8
install -t /usr/share/licenses/run-parts -Dm644 /usr/share/licenses/gptfdisk/COPYING
popd
rm -rf debianutils-5.5
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
tar -xf ../sources/libdisplay-info-0.2.0.tar.bz2
pushd libdisplay-info-0.2.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libdisplay-info -Dm644 LICENSE
popd
rm -rf libdisplay-info-0.2.0
# libpaper.
tar -xf ../sources/libpaper-2.2.6.tar.gz
pushd libpaper-2.2.6
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
rm -rf libpaper-2.2.6
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
tar -xf ../sources/rsync-3.4.1.tar.gz
pushd rsync-3.4.1
./configure --prefix=/usr --without-included-popt --without-included-zlib
make
make install
install -t /usr/share/licenses/rsync -Dm644 COPYING
popd
rm -rf rsync-3.4.1
# libnghttp2.
tar -xf ../sources/nghttp2-1.65.0.tar.xz
pushd nghttp2-1.65.0
./configure --prefix=/usr --disable-static --enable-lib-only
make
make install
install -t /usr/share/licenses/libnghttp2 -Dm644 COPYING
popd
rm -rf nghttp2-1.65.0
# libnghttp3.
tar -xf ../sources/nghttp3-1.8.0.tar.xz
pushd nghttp3-1.8.0
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libnghttp3.a
install -t /usr/share/licenses/libnghttp3 -Dm644 COPYING
popd
rm -rf nghttp3-1.8.0
# curl (INITIAL LIMITED BUILD; will be rebuilt later to support more features).
tar -xf ../sources/curl-8.13.0.tar.xz
pushd curl-8.13.0
./configure --prefix=/usr --disable-static --without-libpsl --with-openssl --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
install -t /usr/share/licenses/curl -Dm644 COPYING
popd
rm -rf curl-8.13.0
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
tar -xf ../sources/cmake-4.0.1.tar.gz
pushd cmake-4.0.1
sed -i 's/"lib64"/"lib"/' Modules/GNUInstallDirs.cmake
./bootstrap --prefix=/usr --parallel=$(nproc) --generator=Ninja --docdir=/share/doc/cmake --mandir=/share/man --system-libs --no-system-cppdap --sphinx-man
ninja
ninja install
install -t /usr/share/licenses/cmake -Dm644 LICENSE.rst
popd
rm -rf cmake-4.0.1
# brotli.
tar -xf ../sources/brotli-1.1.0.tar.gz
pushd brotli-1.1.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBROTLI_DISABLE_TESTS=TRUE -Wno-dev -G Ninja -B build
ninja -C build
python -m build -nw -o dist
ninja -C build install
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/brotli -Dm644 LICENSE
popd
rm -rf brotli-1.1.0
# c-ares.
tar -xf ../sources/c-ares-1.34.5.tar.gz
pushd c-ares-1.34.5
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/c-ares -Dm644 LICENSE.md
popd
rm -rf c-ares-1.34.5
# utfcpp.
tar -xf ../sources/utfcpp-4.0.6.tar.gz
pushd utfcpp-4.0.6
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/license/utfcpp -Dm644 LICENSE
popd
rm -rf utfcpp-4.0.6
# yyjson.
tar -xf ../sources/yyjson-0.10.0.tar.gz
pushd yyjson-0.10.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -DYYJSON_BUILD_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/yyjson -Dm644 LICENSE
popd
rm -rf yyjson-0.10.0
# JSON-C.
tar -xf ../sources/json-c-0.18.tar.gz
pushd json-c-0.18
patch -Np1 -i ../../patches/json-c-0.18-cmake400.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/json-c -Dm644 COPYING
popd
rm -rf json-c-0.18
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
tar -xf ../sources/cryptsetup-2.7.5.tar.xz
pushd cryptsetup-2.7.5
./configure --prefix=/usr --sbindir=/usr/bin --disable-asciidoc --disable-ssh-token
make
make install
install -t /usr/share/licenses/cryptsetup -Dm644 COPYING.LGPL
popd
rm -rf cryptsetup-2.7.5
# multipath-tools.
tar -xf ../sources/multipath-tools-0.11.1.tar.gz
pushd multipath-tools-0.11.1
make prefix=/usr bindir=/usr/bin etc_prefix= configfile=/etc/multipath.conf statedir=/etc/multipath LIB=lib
make prefix=/usr bindir=/usr/bin etc_prefix= configfile=/etc/multipath.conf statedir=/etc/multipath LIB=lib install
install -t /usr/share/licenses/multipath-tools -Dm644 COPYING
popd
rm -rf multipath-tools-0.11.1
# libtpms.
tar -xf ../sources/libtpms-0.10.0.tar.gz
pushd libtpms-0.10.0
./autogen.sh --prefix=/usr --with-openssl --with-tpm2
make
make install
rm -f /usr/lib/libtpms.a
install -t /usr/share/licenses/libtpms -Dm644 LICENSE
popd
rm -rf libtpms-0.10.0
# tpm2-tss.
tar -xf ../sources/tpm2-tss-4.1.3.tar.gz
pushd tpm2-tss-4.1.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-runstatedir=/run --with-sysusersdir=/usr/lib/sysusers.d --with-tmpfilesdir=/usr/lib/tmpfiles.d --with-udevrulesprefix="60-" --disable-static
make
make install
install -t /usr/share/licenses/tpm2-tss -Dm644 LICENSE
popd
rm -rf tpm2-tss-4.1.3
# tpm2-tools.
tar -xf ../sources/tpm2-tools-5.7.tar.gz
pushd tpm2-tools-5.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/tpm2-tools -Dm644 docs/LICENSE
popd
rm -rf tpm2-tools-5.7
# Tcl.
tar -xf ../sources/tcl8.6.16-src.tar.gz
pushd tcl8.6.16/unix
rm -rf ../pkgs/sqlite3.47.2
./configure --prefix=/usr --mandir=/usr/share/man --disable-rpath
make
sed -e "s|$PWD|/usr/lib|" -e "s|${PWD/\/unix}|/usr/include|" -i tclConfig.sh
sed -e "s|$PWD/pkgs/tdbc1.1.10|/usr/lib/tdbc1.1.10|" -e "s|${PWD/\/unix}/pkgs/tdbc1.1.10/generic|/usr/include|" -e "s|${PWD/\/unix}/pkgs/tdbc1.1.10/library|/usr/lib/tcl8.6|" -e "s|${PWD/\/unix}/pkgs/tdbc1.1.10|/usr/include|" -i pkgs/tdbc1.1.10/tdbcConfig.sh
sed -e "s|$PWD/pkgs/itcl4.3.2|/usr/lib/itcl4.3.2|" -e "s|${PWD/\/unix}/pkgs/itcl4.3.2/generic|/usr/include|" -e "s|${PWD/\/unix}/pkgs/itcl4.3.2|/usr/include|" -i pkgs/itcl4.3.2/itclConfig.sh
make install install-private-headers
chmod 755 /usr/lib/libtcl8.6.so
ln -sf tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{,Tcl_}Thread.3
install -t /usr/share/licenses/tcl -Dm644 ../license.terms
popd
rm -rf tcl8.6.16
# SQLite.
tar -xf ../sources/sqlite-autoconf-3490100.tar.gz
pushd sqlite-autoconf-3490100
CPPFLAGS="$CPPFLAGS -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 -DSQLITE_ENABLE_DBSTAT_VTAB=1 -DSQLITE_SECURE_DELETE=1" ./configure --prefix=/usr --disable-static --enable-fts4 --enable-fts5
make
make install
install -dm755 /usr/share/licenses/sqlite
cat > /usr/share/licenses/sqlite/LICENSE << "END"
The code and documentation of SQLite is dedicated to the public domain.
See <https://www.sqlite.org/copyright.html> for more information.
END
popd
rm -rf sqlite-autoconf-3490100
# libusb.
tar -xf ../sources/libusb-1.0.28.tar.bz2
pushd libusb-1.0.28
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libusb -Dm644 COPYING
popd
rm -rf libusb-1.0.28
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
tar -xf ../sources/libieee1284-0.2.11-12-g0663326.tar.gz
pushd libieee1284-0663326cbcfdf2a59f9492ddaff72ec5d1b248eb
patch -Np1 -i ../../patches/libieee1284-0.2.11-python3.patch
./bootstrap
./configure --prefix=/usr --mandir=/usr/share/man --disable-static --with-python
make -j1
make -j1 install
install -t /usr/share/licenses/libieee1284 -Dm644 COPYING
popd
rm -rf libieee1284-0663326cbcfdf2a59f9492ddaff72ec5d1b248eb
# libunistring.
tar -xf ../sources/libunistring-1.3.tar.xz
pushd libunistring-1.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libunistring -Dm644 COPYING COPYING.LIB
popd
rm -rf libunistring-1.3
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
tar -xf ../sources/whois-5.5.23.tar.gz
pushd whois-5.5.23
make
make prefix=/usr install-whois
make prefix=/usr install-mkpasswd
make prefix=/usr install-pos
install -t /usr/share/licenses/whois -Dm644 COPYING
popd
rm -rf whois-5.5.23
# libpsl.
tar -xf ../sources/libpsl-0.21.5.tar.gz
pushd libpsl-0.21.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpsl -Dm644 COPYING
popd
rm -rf libpsl-0.21.5
# usbutils.
tar -xf ../sources/usbutils-018.tar.xz
pushd usbutils-018
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/usbutils -Dm644 LICENSES/*
popd
rm -rf usbutils-018
# pciutils.
tar -xf ../sources/pciutils-3.13.0.tar.xz
pushd pciutils-3.13.0
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes install install-lib
chmod 755 /usr/lib/libpci.so
install -t /usr/share/licenses/pciutils -Dm644 COPYING
popd
rm -rf pciutils-3.13.0
# pkcs11-helper.
tar -xf ../sources/pkcs11-helper-1.30.0.tar.bz2
pushd pkcs11-helper-1.30.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/pkcs11-helper -Dm644 COPYING COPYING.BSD COPYING.GPL
popd
rm -rf pkcs11-helper-1.30.0
# python-certifi.
tar -xf ../sources/python-certifi-2025.01.31.tar.gz
pushd python-certifi-2025.01.31
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/python-certifi -Dm644 LICENSE
popd
rm -rf python-certifi-2025.01.31
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
tar -xf ../sources/jansson-2.14.1.tar.bz2
pushd jansson-2.14.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/jansson -Dm644 LICENSE
popd
rm -rf jansson-2.14.1
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
tar -xf ../sources/nettle-3.10.1.tar.gz
pushd nettle-3.10.1
./configure --prefix=/usr --disable-static
make
make install
chmod 755 /usr/lib/lib{hogweed,nettle}.so
install -t /usr/share/licenses/nettle -Dm644 COPYINGv2 COPYINGv3 COPYING.LESSERv3
popd
rm -rf nettle-3.10.1
# GNUTLS.
tar -xf ../sources/gnutls-3.8.9.tar.xz
pushd gnutls-3.8.9
./configure --prefix=/usr --disable-rpath --disable-static --with-default-trust-store-pkcs11="pkcs11:" --enable-openssl-compatibility --enable-ssl3-support
make
make install
install -t /usr/share/licenses/gnutls -Dm644 COPYING{,.LESSERv2}
popd
rm -rf gnutls-3.8.9
# libevent.
tar -xf ../sources/libevent-2.1.12-stable.tar.gz
pushd libevent-2.1.12-stable
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DEVENT__LIBRARY_TYPE=SHARED -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libevent -Dm644 LICENSE
popd
rm -rf libevent-2.1.12-stable
# libldap.
tar -xf ../sources/openldap-2.6.9.tgz
pushd openldap-2.6.9
autoconf
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-dynamic --enable-versioning --disable-debug --disable-slapd --disable-static
make depend
make
make install
chmod 755 /usr/lib/libl{ber,dap}.so.2.*
install -t /usr/share/licenses/libldap -Dm644 COPYRIGHT LICENSE
popd
rm -rf openldap-2.6.9
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
tar -xf ../sources/libksba-1.6.7.tar.bz2
pushd libksba-1.6.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libksba -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv3
popd
rm -rf libksba-1.6.7
# GNUPG.
tar -xf ../sources/gnupg-2.5.4.tar.bz2
pushd gnupg-2.5.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-g13
make
make install
install -t /usr/share/licenses/gnupg -Dm644 COPYING{,.CC0,.GPL2,.LGPL21,.LGPL3,.other}
popd
rm -rf gnupg-2.5.4
# krb5.
tar -xf ../sources/krb5-1.21.3.tar.gz
pushd krb5-1.21.3/src
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var/lib --runstatedir=/run --sbindir=/usr/bin --disable-rpath --enable-dns-for-realm --with-system-et --with-system-ss --without-system-verto
make
make install
install -t /usr/share/licenses/krb5 -Dm644 ../NOTICE
popd
rm -rf krb5-1.21.3
# libnfs.
tar -xf ../sources/libnfs-6.0.2.tar.gz
pushd libnfs-libnfs-6.0.2
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
tar -xf ../sources/curl-8.13.0.tar.xz
pushd curl-8.13.0
./configure --prefix=/usr --disable-static --with-openssl --with-libssh2 --with-gssapi --with-nghttp3 --with-openssl-quic --enable-ares --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
popd
rm -rf curl-8.13.0
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
tar -xf ../sources/swig-4.3.1.tar.gz
pushd swig-4.3.1
./autogen.sh
./configure --prefix=/usr --without-maximum-compile-warnings
make
make install
install -t /usr/share/licenses/swig -Dm644 COPYRIGHT LICENSE LICENSE-GPL LICENSE-UNIVERSITIES
popd
rm -rf swig-4.3.1
# keyutils.
tar -xf ../sources/keyutils-1.6.3.tar.gz
pushd keyutils-1.6.3
make
make BINDIR=/usr/bin LIBDIR=/usr/lib SBINDIR=/usr/bin NO_ARLIB=1 install
install -t /usr/share/licenses/keyutils -Dm644 LICENCE.{L,}GPL
popd
rm -rf keyutils-1.6.3
# libnvme.
tar -xf ../sources/libnvme-1.13.tar.gz
pushd libnvme-1.13
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dlibdbus=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnvme -Dm644 COPYING
popd
rm -rf libnvme-1.13
# nvme-cli.
tar -xf ../sources/nvme-cli-2.13.tar.gz
pushd nvme-cli-2.13
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --buildtype=minsize -Ddocs=man -Ddocs-build=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/nvme-cli -Dm644 LICENSE
popd
rm -rf nvme-cli-2.13
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
tar -xf ../sources/smartmontools-7.4.tar.gz
pushd smartmontools-7.4
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin
make
make install
systemctl enable smartd
install -t /usr/share/licenses/smartmontools -Dm644 COPYING
popd
rm -rf smartmontools-7.4
# OpenVPN.
tar -xf ../sources/openvpn-2.6.14.tar.gz
pushd openvpn-2.6.14
echo 'u openvpn - "OpenVPN" -' > /usr/lib/sysusers.d/openvpn.conf
systemd-sysusers
sed -i '/^CONFIGURE_DEFINES=/s/set/env/g' configure.ac
autoreconf -fi
./configure --prefix=/usr --sbindir=/usr/bin --enable-pkcs11 --enable-plugins --enable-systemd --enable-x509-alt-username
make
make install
while read -r line; do
  case "$(file -bS --mime-type "$line")" in
    "text/x-shellscript") install -t /usr/share/openvpn -Dm755 "$line" ;;
    *) install -t /usr/share/openvpn -Dm644 "$line" ;;
  esac
done <<< $(find contrib -type f)
cp -r sample/sample-config-files /usr/share/openvpn/examples
install -t /usr/share/licenses/openvpn -Dm644 COPYING COPYRIGHT.GPL
popd
rm -rf openvpn-2.6.14
# GPGME.
tar -xf ../sources/gpgme-1.24.2.tar.bz2
pushd gpgme-1.24.2
./configure --prefix=/usr --disable-gpg-test --disable-gpgsm-test --enable-languages=cl,cpp,python
make PYTHONS=
top_builddir="$PWD" srcdir="$PWD/lang/python" python -m build -nw -o dist "$PWD/lang/python"
make PYTHONS= install
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/gpgme -Dm644 COPYING{,.LESSER} LICENSES
popd
rm -rf gpgme-1.24.2
# Cyrus-SASL (rebuild to support krb5 and OpenLDAP).
tar -xf ../sources/cyrus-sasl-2.1.28.tar.gz
pushd cyrus-sasl-2.1.28
sed -i '/saslint/a #include <time.h>' lib/saslutil.c
sed -i '/plugin_common/a #include <time.h>' plugins/cram.c
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-ldap --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
popd
rm -rf cyrus-sasl-2.1.28
# libtirpc.
tar -xf ../sources/libtirpc-1.3.6.tar.bz2
pushd libtirpc-1.3.6
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libtirpc -Dm644 COPYING
popd
rm -rf libtirpc-1.3.6
# libnsl.
tar -xf ../sources/libnsl-2.0.1.tar.xz
pushd libnsl-2.0.1
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libnsl -Dm644 COPYING
popd
rm -rf libnsl-2.0.1
# libetpan.
tar -xf ../sources/libetpan-1.9.4.tar.gz
pushd libetpan-1.9.4
patch -Np1 -i ../../patches/libetpan-1.9.4-securityfix.patch
./autogen.sh --prefix=/usr --disable-debug --disable-static --with-gnutls --without-openssl
make
make install
install -t /usr/share/licenses/libetpan -Dm644 COPYRIGHT
popd
rm -rf libetpan-1.9.4
# Wget.
tar -xf ../sources/wget-1.25.0.tar.gz
pushd wget-1.25.0
./configure --prefix=/usr --sysconfdir=/etc --disable-rpath --with-cares --with-metalink
make
make install
install -t /usr/share/licenses/wget -Dm644 COPYING
popd
rm -rf wget-1.25.0
# aria2.
tar -xf ../sources/aria2-1.37.0.tar.xz
pushd aria2-1.37.0
./configure --prefix=/usr --with-bashcompletiondir=/usr/share/bash-completion/completions --with-ca-bundle=/etc/pki/tls/certs/ca-bundle.crt --enable-libaria2 --with-libuv
make
make install
install -t /usr/share/licenses/aria2 -Dm644 COPYING
popd
rm -rf aria2-1.37.0
# Ruby.
tar -xf ../sources/ruby-3.4.3.tar.xz
pushd ruby-3.4.3
./configure --prefix=/usr --enable-shared --without-baseruby --without-valgrind ac_cv_func_qsort_r=no
make
make capi
make install
install -t /usr/share/licenses/ruby -Dm644 COPYING
popd
rm -rf ruby-3.4.3
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
tar -xf ../sources/apparmor-4.1.0.tar.gz
pushd apparmor-4.1.0
pushd libraries/libapparmor
./configure --prefix=/usr --sbindir=/usr/bin --with-perl --with-python --with-ruby
make
popd
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
mv /usr/lib/ruby/{site,vendor}_ruby/3.4.0/x86_64-linux/LibAppArmor.so
sed -i 's|ADDITIONAL_PROFILE_DIR=|ADDITIONAL_PROFILE_DIR=/var/lib/snapd/apparmor/profiles|' /usr/lib/apparmor/rc.apparmor.functions
systemctl enable apparmor
install -t /usr/share/licenses/apparmor -Dm644 LICENSE libraries/libapparmor/COPYING.LGPL changehat/pam_apparmor/COPYING
popd
rm -rf apparmor-4.0.3
# Linux-PAM (rebuild with newer version, and to support Audit).
tar -xf ../sources/Linux-PAM-1.7.0.tar.xz
pushd Linux-PAM-1.7.0
sed -e "s/'elinks'/'lynx'/" -e "s/'-no-numbering', '-no-references'/'-force-html', '-nonumbers', '-stdin'/" -i meson.build
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/linux-pam -Dm644 COPYING Copyright
popd
rm -rf Linux-PAM-1.7.0
# Shadow (rebuild to support Audit).
tar -xf ../sources/shadow-4.17.4.tar.xz
pushd shadow-4.17.4
patch -Np1 -i ../../patches/shadow-4.17.2-MassOS.patch
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-static --with-audit --with-bcrypt --with-group-name-max-length=32 --with-libcrack --with-yescrypt --without-libbsd
make
make exec_prefix=/usr pamdir= install
make -C man install-man
install -t /etc/pam.d -Dm644 pam.d/*
rm -f /etc/{limits,login.access}
popd
rm -rf shadow-4.17.4
# Sudo.
tar -xf ../sources/sudo-1.9.16p2.tar.gz
pushd sudo-1.9.16p2
./configure --prefix=/usr --sbindir=/usr/bin --libexecdir=/usr/lib --with-linux-audit --with-secure-path --with-insults --with-all-insults --with-passwd-tries=5 --with-env-editor --with-passprompt="[sudo] password for %p: "
make
make install
sed -e '/pam_rootok.so/d' -e '/pam_wheel.so/d' /etc/pam.d/su > /etc/pam.d/sudo
sed -e 's|# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' -e 's|# Defaults secure_path|Defaults secure_path|' -e 's|/sbin:/bin|/var/lib/flatpak/exports/bin:/snap/bin|' -i /etc/sudoers
sed -i '53i## Show astericks while typing the password.' /etc/sudoers
sed -i '54iDefaults pwfeedback' /etc/sudoers
sed -i '55i##' /etc/sudoers
install -t /usr/share/licenses/sudo -Dm644 LICENSE.md
popd
rm -rf sudo-1.9.16p2
# Fcron.
tar -xf ../sources/fcron-ver3_3_1.tar.gz
pushd fcron-ver3_3_1
echo 'u fcron - "Fcron User" -' > /usr/lib/sysusers.d/fcron.conf
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
&bootrun 01 * * * *  /usr/bin/run-parts /etc/cron.hourly
&bootrun 02 00 * * * /usr/bin/run-parts /etc/cron.daily
&bootrun 22 00 * * 0 /usr/bin/run-parts /etc/cron.weekly
&bootrun 42 00 1 * * /usr/bin/run-parts /etc/cron.monthly
END
fcrontab -z -u systab
systemctl enable fcron
install -t /usr/share/licenses/fcron -Dm644 doc/en/txt/gpl.txt
popd
rm -rf fcron-ver3_3_1
# lsof.
tar -xf ../sources/lsof-4.99.4.tar.gz
pushd lsof-4.99.4
./Configure linux -n
sed -i "s/cc/cc $CFLAGS/" Makefile
make
install -m755 lsof /usr/bin/lsof
install -m644 Lsof.8 /usr/share/man/man8/lsof.8
install -t /usr/share/licenses/lsof -Dm644 COPYING
popd
rm -rf lsof-4.99.4
# NSPR.
tar -xf ../sources/nspr-4.36.tar.gz
pushd nspr-4.36/nspr
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit
make
make install
rm -f /usr/lib/lib{nspr,plc,plds}4.a
rm -f /usr/bin/{compile-et.pl,prerr.properties}
install -t /usr/share/licenses/nspr -Dm644 LICENSE
popd
rm -rf nspr-4.36
# NSS.
tar -xf ../sources/nss-3.110.tar.gz
pushd nss-3.110/nss
sed -i "s|'disable_werror%': 0|'disable_werror%': 1|" coreconf/config.gypi
./build.sh --target=x64 --enable-libpkix --disable-tests --opt --system-nspr --system-sqlite
install -t /usr/lib -Dm755 ../dist/Release/lib/*.so
install -t /usr/lib -Dm644 ../dist/Release/lib/*.chk
install -t /usr/bin -Dm755 ../dist/Release/bin/{*util,shlibsign,signtool,signver,ssltap}
install -t /usr/share/man/man1 -Dm644 doc/nroff/{*util,signtool,signver,ssltap}.1
install -dm755 /usr/include/nss
cp -r ../dist/{public,private}/nss/* /usr/include/nss
sed pkg/pkg-config/nss.pc.in -e 's|%prefix%|/usr|g' -e 's|%libdir%|${prefix}/lib|g' -e 's|%exec_prefix%|${prefix}|g' -e 's|%includedir%|${prefix}/include/nss|g' -e "s|%NSPR_VERSION%|$(pkg-config --modversion nspr)|g" -e "s|%NSS_VERSION%|3.110.0|g" > /usr/lib/pkgconfig/nss.pc
sed pkg/pkg-config/nss-config.in -e 's|@prefix@|/usr|g' -e "s|@MOD_MAJOR_VERSION@|$(pkg-config --modversion nss | cut -d. -f1)|g" -e "s|@MOD_MINOR_VERSION@|$(pkg-config --modversion nss | cut -d. -f2)|g" -e "s|@MOD_PATCH_VERSION@|$(pkg-config --modversion nss | cut -d. -f3)|g" > /usr/bin/nss-config
chmod 755 /usr/bin/nss-config
ln -sf ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
install -t /usr/share/licenses/nss -Dm644 COPYING
popd
rm -rf nss-3.110
# Git.
tar -xf ../sources/git-2.49.0.tar.xz
pushd git-2.49.0
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --with-libpcre2
make all man
make perllibdir=/usr/lib/perl5/5.40/vendor_perl install install-man
install -t /usr/share/licenses/git -Dm644 COPYING LGPL-2.1
popd
rm -rf git-2.49.0
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
# libsmbios.
tar -xf ../sources/libsmbios-2.4.3.tar.gz
pushd libsmbios-2.4.3
./autogen.sh --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-rpath --disable-static
make
make install
cp -r out/public-include/* /usr/include
install -t /usr/share/licenses/libsmbios -Dm644 COPYING COPYING-GPL
popd
rm -rf libsmbios-2.4.3
# DKMS.
tar -xf ../sources/dkms-3.1.7.tar.gz
pushd dkms-3.1.7
make MODDIR=/usr/lib/modules SBIN=/usr/bin install
install -t /usr/share/licenses/dkms -Dm644 COPYING
popd
rm -rf dkms-3.1.7
# xmlsec.
tar -xf ../sources/xmlsec-1.3.7.tar.gz
pushd xmlsec-1.3.7
autoreconf -fi
./configure --prefix=/usr --disable-static --disable-docs --enable-openssl3-engines
make
make install
install -t /usr/share/licenses/xmlsec -Dm644 Copyright
popd
rm -rf xmlsec-1.3.7
# GLib (initial build for circular dependency).
tar -xf ../sources/glib-2.84.1.tar.gz
pushd glib-2.84.1
tar -xf ../../sources/gvdb-2b42fc7.tar.gz -C subprojects/gvdb --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dglib_debug=disabled -Dintrospection=disabled -Dman-pages=enabled -Dtests=false -Dsysprof=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glib -Dm644 COPYING
popd
rm -rf glib-2.84.1
# GTK-Doc.
tar -xf ../sources/gtk-doc-1.34.0.tar.gz
pushd gtk-doc-1.34.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk-doc -Dm644 COPYING COPYING-DOCS
popd
rm -rf gtk-doc-1.34.0
# libsigc++.
tar -xf ../sources/libsigc++-2.12.1.tar.xz
pushd libsigc++-2.12.1
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
tar -xf ../sources/glibmm-2.66.8.tar.gz
pushd glibmm-2.66.8
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-documentation=false -Dmaintainer-mode=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glibmm -Dm644 COPYING COPYING.tools
popd
rm -rf glibmm-2.66.8
# gobject-introspection.
tar -xf ../sources/gobject-introspection-1.84.0.tar.gz
pushd gobject-introspection-1.84.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gobject-introspection -Dm644 COPYING{,.{GPL,LGPL}}
popd
rm -rf gobject-introspection-1.84.0
# GLib (rebuild to support gobject-introspection).
tar -xf ../sources/glib-2.84.1.tar.gz
pushd glib-2.84.1
tar -xf ../../sources/gvdb-2b42fc7.tar.gz -C subprojects/gvdb --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dglib_debug=disabled -Dintrospection=enabled -Dman-pages=enabled -Dtests=false -Dsysprof=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glib -Dm644 COPYING
popd
rm -rf glib-2.84.1
# shared-mime-info.
tar -xf ../sources/shared-mime-info-2.4.tar.gz
pushd shared-mime-info-2.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dupdate-mimedb=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/shared-mime-info -Dm644 COPYING
popd
rm -rf shared-mime-info-2.4
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
# LLVM / Clang / LLD / libc++ / libc++abi / compiler-rt.
tar -xf ../sources/llvm-project-20.1.3.src.tar.xz
pushd llvm-project-20.1.3.src
sed -i 's/utility/tool/' llvm/utils/FileCheck/CMakeLists.txt
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_DOCDIR=share/doc -DCMAKE_SKIP_INSTALL_RPATH=ON -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi" -DLLVM_TARGETS_TO_BUILD="AMDGPU;BPF;X86" -DLLVM_HOST_TRIPLE=x86_64-pc-linux-gnu -DLLVM_BINUTILS_INCDIR=/usr/include -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_FFI=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_ZLIB=ON -DLLVM_ENABLE_ZSTD=ON -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_TESTS=OFF -DLLVM_USE_PERF=ON -DENABLE_LINKER_BUILD_ID=ON -DCLANG_CONFIG_FILE_SYSTEM_DIR=/etc/clang -DCLANG_DEFAULT_PIE_ON_LINUX=ON -DLIBCXX_INSTALL_LIBRARY_DIR=/usr/lib -DLIBCXXABI_INSTALL_LIBRARY_DIR=/usr/lib -DLIBCXXABI_USE_LLVM_UNWINDER=OFF -DCOMPILER_RT_USE_LIBCXX=OFF -DLLVM_BUILD_DOCS=ON -DLLVM_ENABLE_SPHINX=ON -DSPHINX_WARNINGS_AS_ERRORS=OFF -Wno-dev -G Ninja -B build -S llvm
ninja -C build
ninja -C build install
install -dm755 /etc/clang
echo "-fstack-protector-strong" > /etc/clang/clang.cfg
echo "-fstack-protector-strong" > /etc/clang/clang++.cfg
install -t /usr/share/licenses/llvm -Dm644 LICENSE.TXT
install -t /usr/share/licenses/clang -Dm644 LICENSE.TXT
install -t /usr/share/licenses/lld -Dm644 LICENSE.TXT
install -t /usr/share/licenses/libc++ -Dm644 LICENSE.TXT
install -t /usr/share/licenses/libc++abi -Dm644 LICENSE.TXT
install -t /usr/share/licenses/compiler-rt -Dm644 LICENSE.TXT
popd
rm -rf llvm-project-20.1.3.src
# bpftool.
tar -xf ../sources/bpftool-7.5.0.tar.gz
tar -xf ../sources/libbpf-1.5.0.tar.gz -C bpftool-7.5.0/libbpf --strip-components=1
pushd bpftool-7.5.0/src
make all doc
make install doc-install prefix=/usr mandir=/usr/share/man
install -t /usr/share/licenses/bpftool -Dm644 ../LICENSE{,.BSD-2-Clause,.GPL-2.0}
popd
rm -rf bpftool-7.5.0
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
tar -xf ../sources/json-glib-1.10.6.tar.gz
pushd json-glib-1.10.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dconformance=false -Dinstalled_tests=false -Dman=true -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/json-glib -Dm644 COPYING LICENSES/*
popd
rm -rf json-glib-1.10.6
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
make libdir=/usr/lib sbindir=/usr/bin EFIDIR=massos EFI_LOADER=grubx64.efi
make libdir=/usr/lib sbindir=/usr/bin EFIDIR=massos EFI_LOADER=grubx64.efi install
install -t /usr/share/licenses/efibootmgr -Dm644 COPYING
popd
rm -rf efibootmgr-18
# libpng.
tar -xf ../sources/libpng-1.6.47.tar.xz
pushd libpng-1.6.47
patch -Np1 -i ../../patches/libpng-1.6.47-apng.patch
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpng -Dm644 LICENSE
popd
rm -rf libpng-1.6.47
# FreeType (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf ../sources/freetype-2.13.3.tar.xz
pushd freetype-2.13.3
sed -ri "s|.*(AUX_MODULES.*valid)|\1|" modules.cfg
sed -r "s|.*(#.*SUBPIXEL_RENDERING) .*|\1|" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static --without-harfbuzz
make
make install
install -t /usr/share/licenses/freetype -Dm644 LICENSE.TXT docs/GPLv2.TXT
popd
rm -rf freetype-2.13.3
# Graphite2 (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf ../sources/graphite2-1.3.14-99-g6938f052.tar.gz
pushd graphite-6938f05260a63a070304d0fccf6fbc9d0e52758c
patch -Np1 -i ../../patches/graphite2-1.3.14-99-g6938f052-cmake400.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/graphite2 -Dm644 COPYING LICENSE
popd
rm -rf graphite-6938f05260a63a070304d0fccf6fbc9d0e52758c
# HarfBuzz.
tar -xf ../sources/harfbuzz-11.1.0.tar.xz
pushd harfbuzz-11.1.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/harfbuzz -Dm644 COPYING
popd
rm -rf harfbuzz-11.1.0
# FreeType (rebuild to support HarfBuzz).
tar -xf ../sources/freetype-2.13.3.tar.xz
pushd freetype-2.13.3
sed -ri "s|.*(AUX_MODULES.*valid)|\1|" modules.cfg
sed -r "s|.*(#.*SUBPIXEL_RENDERING) .*|\1|" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static --with-harfbuzz
make
make install
popd
rm -rf freetype-2.13.3
# Graphite2 (rebuild to support HarfBuzz).
tar -xf ../sources/graphite2-1.3.14-99-g6938f052.tar.gz
pushd graphite-6938f05260a63a070304d0fccf6fbc9d0e52758c
patch -Np1 -i ../../patches/graphite2-1.3.14-99-g6938f052-cmake400.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
popd
rm -rf graphite-6938f05260a63a070304d0fccf6fbc9d0e52758c
# Woff2.
tar -xf ../sources/woff2-1.0.2.tar.gz
pushd woff2-1.0.2
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/woff2 -Dm644 LICENSE
popd
rm -rf woff2-1.0.2
# Unifont.
tar -xf ../sources/unifont-16.0.02.tar.gz
install -dm755 /usr/share/fonts/unifont
gzip -cd unifont-16.0.02/font/precompiled/unifont-16.0.02.pcf.gz > /usr/share/fonts/unifont/unifont.pcf
install -t /usr/share/licenses/unifont -Dm644 unifont-16.0.02/COPYING
rm -rf unifont-16.0.02
# GRUB.
tar -xf ../sources/grub-2.12.tar.xz
pushd grub-2.12
echo "depends bli part_gpt" > grub-core/extra_deps.lst
mkdir -p build-pc; pushd build-pc
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-efiemu --enable-grub-mkfont --enable-grub-mount --with-platform=pc --disable-werror
popd
mkdir -p build-efi; pushd build-efi
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-efiemu --enable-grub-mkfont --enable-grub-mount --with-platform=efi --disable-werror
popd
make -C build-pc
make -C build-efi
make -C build-efi bashcompletiondir="/usr/share/bash-completion/completions" install
make -C build-pc bashcompletiondir="/usr/share/bash-completion/completions" install
sed -i 's|${GRUB_DISTRIBUTOR} GNU/Linux|${GRUB_DISTRIBUTOR}|' /etc/grub.d/10_linux
cat > /usr/share/grub/sbat.csv << "END"
sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md
grub,3,Free Software Foundation,grub,2.12,https://gnu.org/software/grub/
grub.massos,1,MassOS,grub,2.12,https://massos.org
END
install -t /usr/share/licenses/grub -Dm644 COPYING
popd
rm -rf grub-2.12
# grub-theme-distro-massos.
install -dm755 /usr/share/grub/themes/distro-massos
tar -xf ../sources/grub-theme-distro-massos-001.tar.gz -C /usr/share/grub/themes/distro-massos --strip-components=1
install -t /usr/share/licenses/grub-theme-distro-massos -Dm644 /usr/share/grub/themes/distro-massos/LICENSE
# os-prober.
tar -xf ../sources/os-prober_1.83.tar.xz
pushd work
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
rm -rf work
# libatasmart.
tar -xf ../sources/libatasmart_0.19.orig.tar.xz
pushd libatasmart-0.19
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libatasmart -Dm644 LGPL
popd
rm -rf libatasmart-0.19
# libbytesize.
tar -xf ../sources/libbytesize-2.11.tar.gz
pushd libbytesize-2.11
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libbytesize -Dm644 LICENSE
popd
rm -rf libbytesize-2.11
# libblockdev.
tar -xf ../sources/libblockdev-3.3.0.tar.gz
pushd libblockdev-3.3.0
./configure --prefix=/usr --sysconfdir=/etc --with-python3 --without-nvdimm
make
make install
install -t /usr/share/licenses/libblockdev -Dm644 LICENSE
popd
rm -rf libblockdev-3.3.0
# libdaemon.
tar -xf ../sources/libdaemon_0.14.orig.tar.gz
pushd libdaemon-0.14
./configure --prefix=/usr --disable-static
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
tar -xf ../sources/libmbim-1.32.0.tar.gz
pushd libmbim-1.32.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libmbim -Dm644 LICENSES/*
popd
rm -rf libmbim-1.32.0
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
tar -xf ../sources/libqmi-1.36.0.tar.gz
pushd libqmi-1.36.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libqmi -Dm644 COPYING COPYING.LIB
popd
rm -rf libqmi-1.36.0
# libevdev.
tar -xf ../sources/libevdev-1.13.4.tar.xz
pushd libevdev-1.13.4
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --localstatedir=/var -Ddocumentation=disabled -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libevdev -Dm644 COPYING
popd
rm -rf libevdev-1.13.4
# libwacom.
tar -xf ../sources/libwacom-2.15.0.tar.xz
pushd libwacom-2.15.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libwacom -Dm644 COPYING
popd
rm -rf libwacom-2.15.0
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
tar -xf ../sources/wayland-1.23.1.tar.xz
pushd wayland-1.23.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddocumentation=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/wayland -Dm644 COPYING
popd
rm -rf wayland-1.23.1
# wayland-protocols.
tar -xf ../sources/wayland-protocols-1.43.tar.xz
pushd wayland-protocols-1.43
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/wayland-protocols -Dm644 COPYING
popd
rm -rf wayland-protocols-1.43
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
tar -xf ../sources/aspell-0.60.8.1.tar.gz
pushd aspell-0.60.8.1
./configure --prefix=/usr
make
make install
ln -sfn aspell-0.60 /usr/lib/aspell
install -m755 scripts/ispell /usr/bin/
install -m755 scripts/spell /usr/bin/
install -t /usr/share/licenses/aspell -Dm644 COPYING
popd
rm -rf aspell-0.60.8.1
# aspell-en.
tar -xf ../sources/aspell6-en-2020.12.07-0.tar.bz2
pushd aspell6-en-2020.12.07-0
./configure
make
make install
popd
rm -rf aspell6-en-2020.12.07-0
# Enchant.
tar -xf ../sources/enchant-2.8.2.tar.gz
pushd enchant-2.8.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/enchant -Dm644 COPYING.LIB
popd
rm -rf enchant-2.8.2
# Fontconfig.
tar -xf ../sources/fontconfig-2.16.2.tar.bz2
pushd fontconfig-2.16.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddoc-pdf=disabled -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fontconfig -Dm644 COPYING
popd
rm -rf fontconfig-2.16.2
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
tar -xf ../sources/giflib-5.2.2.tar.gz
pushd giflib-5.2.2
patch -Np1 -i ../../patches/giflib-5.2.2-manpagedirectory.patch
cp pic/gifgrid.gif doc/giflib-logo.gif
make
make PREFIX=/usr install
rm -f /usr/lib/libgif.a
install -t /usr/share/licenses/giflib -Dm644 COPYING
popd
rm -rf giflib-5.2.2
# libexif.
tar -xf ../sources/libexif-0.6.25.tar.bz2
pushd libexif-0.6.25
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libexif -Dm644 COPYING
popd
rm -rf libexif-0.6.25
# lolcat.
tar -xf ../sources/lolcat-1.5.tar.gz
pushd lolcat-1.5
make CFLAGS="$CFLAGS"
install -t /usr/bin -Dm755 censor lolcat
install -t /usr/share/licenses/lolcat -Dm644 LICENSE
popd
rm -rf lolcat-1.5
# NASM.
tar -xf ../sources/nasm-2.16.03.tar.xz
pushd nasm-2.16.03
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/nasm -Dm644 LICENSE
popd
rm -rf nasm-2.16.03
# libjpeg-turbo.
tar -xf ../sources/libjpeg-turbo-3.1.0.tar.gz
pushd libjpeg-turbo-3.1.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib -DCMAKE_SKIP_INSTALL_RPATH=TRUE -DENABLE_STATIC=FALSE -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libjpeg-turbo -Dm644 LICENSE.md README.ijg
popd
rm -rf libjpeg-turbo-3.1.0
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
tar -xf ../sources/pixman-0.44.2.tar.xz
pushd pixman-0.44.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pixman -Dm644 COPYING
popd
rm -rf pixman-0.44.2
# Qpdf.
tar -xf ../sources/qpdf-12.1.0.tar.gz
pushd qpdf-12.1.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -DINSTALL_EXAMPLES=OFF -DREQUIRE_CRYPTO_GNUTLS=OFF -DREQUIRE_CRYPTO_OPENSSL=ON -DUSE_IMPLICIT_CRYPTO=OFF -DDEFAULT_CRYPTO=openssl -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/bash-completion/completions -Dm644 completions/bash/qpdf
install -t /usr/share/zsh/site-functions -Dm644 completions/zsh/_qpdf
install -t /usr/share/licenses/qpdf -Dm644 Artistic-2.0 LICENSE.txt NOTICE.md
popd
rm -rf qpdf-12.1.0
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
tar -xf ../sources/iso-codes-v4.18.0.tar.bz2
pushd iso-codes-v4.18.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/iso-codes -Dm644 COPYING
popd
rm -rf iso-codes-v4.18.0
# xdg-user-dirs.
tar -xf ../sources/xdg-user-dirs-0.18.tar.gz
pushd xdg-user-dirs-0.18
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xdg-user-dirs -Dm644 COPYING
popd
rm -rf xdg-user-dirs-0.18
# LSB-Tools.
tar -xf ../sources/LSB-Tools-0.12.tar.gz
pushd LSB-Tools-0.12
make
make install
rm -f /usr/bin/{lsbinstall,install_initd,remove_initd}
install -t /usr/share/licenses/lsb-tools -Dm644 LICENSE
popd
rm -rf LSB-Tools-0.12
# p7zip.
tar -xf ../sources/p7zip-17.06.tar.gz
pushd p7zip-17.06
make OPTFLAGS="$CFLAGS" all3
make DEST_HOME=/usr DEST_MAN=/usr/share/man DEST_SHARE_DOC=/usr/share/doc/p7zip install
install -t /usr/share/licenses/p7zip -Dm644 DOC/License.txt
popd
rm -rf p7zip-17.06
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
tar -xf ../sources/bind-9.20.7.tar.xz
pushd bind-9.20.7
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
rm -rf bind-9.20.7
# dhcpcd.
tar -xf ../sources/dhcpcd-10.2.2.tar.xz
pushd dhcpcd-10.2.2
echo 'u dhcpcd - "dhcpcd PrivSep" /var/lib/dhcpcd' > /usr/lib/sysusers.d/dhcpcd.conf
systemd-sysusers
install -o dhcpcd -g dhcpcd -dm700 /var/lib/dhcpcd
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --libexecdir=/usr/lib/dhcpcd --runstatedir=/run --dbdir=/var/lib/dhcpcd --privsepuser=dhcpcd
make
make install
rm -f /usr/lib/dhcpcd/dhcpcd-hooks/30-hostname
install -t /usr/share/licenses/dhcpcd -Dm644 LICENSE
popd
rm -rf dhcpcd-10.2.2
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
# wpa_supplicant.
tar -xf ../sources/wpa_supplicant-2.11.tar.gz
pushd wpa_supplicant-2.11/wpa_supplicant
cat > .config << "END"
CONFIG_BACKEND=file
CONFIG_CTRL_IFACE=y
CONFIG_CTRL_IFACE_DBUS=y
CONFIG_CTRL_IFACE_DBUS_NEW=y
CONFIG_CTRL_IFACE_DBUS_INTRO=y
CONFIG_DEBUG_FILE=y
CONFIG_DEBUG_SYSLOG=y
CONFIG_DEBUG_SYSLOG_FACILITY=LOG_DAEMON
CONFIG_DRIVER_NL80211=y
CONFIG_DRIVER_WEXT=y
CONFIG_DRIVER_WIRED=y
CONFIG_EAP_GTC=y
CONFIG_EAP_LEAP=y
CONFIG_EAP_MD5=y
CONFIG_EAP_MSCHAPV2=y
CONFIG_EAP_OTP=y
CONFIG_EAP_PEAP=y
CONFIG_EAP_TLS=y
CONFIG_EAP_TTLS=y
CONFIG_IEEE8021X_EAPOL=y
CONFIG_IPV6=y
CONFIG_LIBNL32=y
CONFIG_PEERKEY=y
CONFIG_PKCS12=y
CONFIG_READLINE=y
CONFIG_SMARTCARD=y
CONFIG_WPS=y
CFLAGS += -I/usr/include/libnl3
END
make BINDIR=/usr/bin LIBDIR=/usr/lib
install -m755 wpa_{cli,passphrase,supplicant} /usr/bin/
install -m644 doc/docbook/wpa_supplicant.conf.5 /usr/share/man/man5/
install -m644 doc/docbook/wpa_{cli,passphrase,supplicant}.8 /usr/share/man/man8/
install -m644 systemd/*.service /usr/lib/systemd/system/
install -m644 dbus/fi.w1.wpa_supplicant1.service /usr/share/dbus-1/system-services/
install -dm755 /etc/dbus-1/system.d
install -m644 dbus/dbus-wpa_supplicant.conf /etc/dbus-1/system.d/wpa_supplicant.conf
install -t /usr/share/licenses/wpa-supplicant -Dm644 ../COPYING ../README
popd
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
tar -xf ../sources/fmt-11.1.4.tar.gz
pushd fmt-11.1.4
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DFMT_TEST=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fmt -Dm644 LICENSE
popd
rm -rf fmt-11.1.4
# libzip.
tar -xf ../sources/libzip-1.11.3.tar.xz
pushd libzip-1.11.3
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_REGRESS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libzip -Dm644 LICENSE
popd
rm -rf libzip-1.11.3
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
tar -xf ../sources/libfido2-1.15.0.tar.gz
pushd libfido2-1.15.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_EXAMPLES=OFF -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libfido2 -Dm644 LICENSE
popd
rm -rf libfido2-1.15.0
# util-macros.
tar -xf ../sources/util-macros-1.20.2.tar.xz
pushd util-macros-1.20.2
./configure --prefix=/usr
make install
install -t /usr/share/licenses/util-macros -Dm644 COPYING
popd
rm -rf util-macros-1.20.2
# xorgproto.
tar -xf ../sources/xorgproto-2024.1.tar.xz
pushd xorgproto-2024.1
meson setup build --prefix=/usr -Dlegacy=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xorgproto -Dm644 COPYING*
popd
rm -rf xorgproto-2024.1
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
tar -xf ../sources/font-util-1.4.1.tar.bz2
pushd util-font-util-1.4.1-b5ca142f81a6f14eddb23be050291d1c25514777
./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/font-util -Dm644 COPYING
popd
rm -rf util-font-util-1.4.1-b5ca142f81a6f14eddb23be050291d1c25514777
# libX11.
tar -xf ../sources/libX11-1.8.12.tar.bz2
pushd libx11-libX11-1.8.12-59917d28a3c41ad22d6fc52e323cafe2cdd596d5
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libx11 -Dm644 COPYING
popd
rm -rf libx11-libX11-1.8.12-59917d28a3c41ad22d6fc52e323cafe2cdd596d5
# libXext.
tar -xf ../sources/libXext-1.3.6.tar.bz2
pushd libxext-libXext-1.3.6-3826a58d190c2d8093d3586cb33867668cbb4553
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxext -Dm644 COPYING
popd
rm -rf libxext-libXext-1.3.6-3826a58d190c2d8093d3586cb33867668cbb4553
# libFS.
tar -xf ../sources/libFS-1.0.10.tar.bz2
pushd libfs-libFS-1.0.10-a21531705199c69f25dd67234449c8c6404f9af6
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libfs -Dm644 COPYING
popd
rm -rf libfs-libFS-1.0.10-a21531705199c69f25dd67234449c8c6404f9af6
# Many needed libraries and dependencies from the Xorg project.
for i in libICE-1.1.2 libSM-1.2.6 libXScrnSaver-1.2.4 libXt-1.3.1 libXmu-1.2.1 libXpm-3.5.17 libXaw-1.0.16 libXfixes-6.0.1 libXcomposite-0.4.6 libXrender-0.9.12 libXcursor-1.2.3 libXdamage-1.1.6 libXi-1.8.2 libXinerama-1.1.5 libXrandr-1.5.4 libXres-1.2.2 libXtst-1.2.5 libXv-1.0.13 libXvMC-1.0.14 libXxf86dga-1.1.6 libXxf86vm-1.1.6 libxkbfile-1.1.3 libxshmfence-1.3.3; do
  tar -xf ../sources/$i.tar.*
  pushd $i
  case $i in
    libXt-*) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-appdefaultdir=/etc/X11/app-defaults ;;
    libXpm-*) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-open-zfile ;;
    *) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static ;;
  esac
  make
  make install
  install -t /usr/share/licenses/$(echo $i | cut -d- -f1 | tr '[:upper:]' '[:lower:]') -Dm644 COPYING
  popd
  rm -rf $i
  ldconfig
done
# libfontenc.
tar -xf ../sources/libfontenc-1.1.8.tar.bz2
pushd libfontenc-libfontenc-1.1.8-92a85fda2acb4e14ec0b2f6d8fe3eaf2b687218c
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libfontenc -Dm644 COPYING
popd
rm -rf libfontenc-libfontenc-1.1.8-92a85fda2acb4e14ec0b2f6d8fe3eaf2b687218c
# libXfont2.
tar -xf ../sources/libXfont2-2.0.7.tar.bz2
pushd libxfont-libXfont2-2.0.7-2c2e44c94ef17ecd5003a173237b57b315e28d93
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxfont2 -Dm644 COPYING
popd
rm -rf libxfont-libXfont2-2.0.7-2c2e44c94ef17ecd5003a173237b57b315e28d93
# libXft.
tar -xf ../sources/libXft-2.3.9.tar.bz2
pushd libxft-libXft-2.3.9-f4805c8645914cbdcfd42e71051ba3f8fc664ef5
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxft -Dm644 COPYING
popd
rm -rf libxft-libXft-2.3.9-f4805c8645914cbdcfd42e71051ba3f8fc664ef5
# libdmx.
tar -xf ../sources/libdmx-libdmx-1.1.5.tar.bz2
pushd libdmx-libdmx-1.1.5
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdmx -Dm644 COPYING
popd
rm -rf libdmx-libdmx-1.1.5
# libpciaccess.
tar -xf ../sources/libpciaccess-0.18.1.tar.xz
pushd libpciaccess-0.18.1
meson setup build --prefix=/usr --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libpciaccess -Dm644 COPYING
popd
rm -rf libpciaccess-0.18.1
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
tar -xf ../sources/libdrm-2.4.124.tar.xz
pushd libdrm-2.4.124
patch -Np1 -i ../../patches/libdrm-2.4.118-license.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false -Dudev=true -Dvalgrind=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libdrm -Dm644 LICENSE
popd
rm -rf libdrm-2.4.124
# DirectX-Headers.
tar -xf ../sources/DirectX-Headers-1.615.0.tar.gz
pushd DirectX-Headers-1.615.0
meson setup build --prefix=/usr --buildtype=minsize -Dbuild-test=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/directx-headers -Dm644 LICENSE
popd
rm -rf DirectX-Headers-1.615.0
# SPIRV-Headers.
tar -xf ../sources/SPIRV-Headers-vulkan-sdk-1.4.309.0.tar.gz
pushd SPIRV-Headers-vulkan-sdk-1.4.309.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/spirv-headers -Dm644 LICENSE
popd
rm -rf SPIRV-Headers-vulkan-sdk-1.4.309.0
# SPIRV-Tools.
tar -xf ../sources/SPIRV-Tools-vulkan-sdk-1.4.309.0.tar.gz
pushd SPIRV-Tools-vulkan-sdk-1.4.309.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DSPIRV_TOOLS_BUILD_STATIC=OFF -DSPIRV_WERROR=OFF -DSPIRV-Headers_SOURCE_DIR=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/spirv-tools -Dm644 LICENSE
popd
rm -rf SPIRV-Tools-vulkan-sdk-1.4.309.0
# SPIRV-LLVM-Translator.
tar -xf ../sources/SPIRV-LLVM-Translator-20.1.1.tar.gz
pushd SPIRV-LLVM-Translator-20.1.1
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=ON -DBUILD_SHARED_LIBS=ON -DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/spirv-llvm-translator -Dm644 LICENSE.TXT
popd
rm -rf SPIRV-LLVM-Translator-20.1.1
# libclc.
tar -xf ../sources/libclc-20.1.3.src.tar.xz
pushd libclc-20.1.3.src
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libclc -Dm644 LICENSE.TXT
popd
rm -rf libclc-20.1.3.src
# glslang.
tar -xf ../sources/glslang-15.2.0.tar.gz
pushd glslang-15.2.0
patch -Np1 -i ../../patches/glslang-15.2.0-upstreamfix.patch
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DALLOW_EXTERNAL_SPIRV_TOOLS=ON -DGLSLANG_TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/glslang -Dm644 LICENSE.txt
popd
rm -rf glslang-15.2.0
# shaderc.
tar -xf ../sources/shaderc-2025.1.tar.gz
pushd shaderc-2025.1
sed -i '/third_party/d' CMakeLists.txt
sed -i '/build-version/d' glslc/CMakeLists.txt
sed -i 's|SPIRV|glslang/&|' libshaderc_util/src/compiler.cc
echo '"2025.1"' > glslc/src/build-version.inc
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSHADERC_SKIP_TESTS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/shaderc -Dm644 LICENSE
popd
rm -rf shaderc-2025.1
# Vulkan-Headers.
tar -xf ../sources/Vulkan-Headers-vulkan-sdk-1.4.309.0.tar.gz
pushd Vulkan-Headers-vulkan-sdk-1.4.309.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/vulkan-headers -Dm644 LICENSE.md
popd
rm -rf Vulkan-Headers-vulkan-sdk-1.4.309.0
# Vulkan-Loader.
tar -xf ../sources/Vulkan-Loader-vulkan-sdk-1.4.309.0.tar.gz
pushd Vulkan-Loader-vulkan-sdk-1.4.309.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DVULKAN_HEADERS_INSTALL_DIR=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_INSTALL_DATADIR=/share -DCMAKE_SKIP_RPATH=TRUE -DBUILD_TESTS=OFF -DBUILD_WSI_XCB_SUPPORT=ON -DBUILD_WSI_XLIB_SUPPORT=ON -DBUILD_WSI_WAYLAND_SUPPORT=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/vulkan-loader -Dm644 LICENSE.txt
popd
rm -rf Vulkan-Loader-vulkan-sdk-1.4.309.0
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
tar -xf ../sources/Vulkan-Tools-vulkan-sdk-1.4.309.0.tar.gz
pushd Vulkan-Tools-vulkan-sdk-1.4.309.0
mkdir -p volk
tar -xf ../../sources/volk-1.4.304.tar.gz -C volk --strip-components=1
cmake -DCMAKE_INSTALL_PREFIX="$PWD/volk/install" -DCMAKE_BUILD_TYPE=MinSizeRel -DVOLK_INSTALL=ON -Wno-dev -G Ninja -B volk/build -S volk
ninja -C volk/build
ninja -C volk/build install
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_CUBE=ON -DBUILD_ICD=OFF -DBUILD_VULKANINFO=ON -DBUILD_WSI_XCB_SUPPORT=ON -DBUILD_WSI_XLIB_SUPPORT=ON -DBUILD_WSI_WAYLAND_SUPPORT=ON -DVOLK_INSTALL_DIR="$PWD/volk/install" -Wno-dev -G Ninja -B build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_CUBE=ON -DBUILD_ICD=OFF -DBUILD_VULKANINFO=OFF -DBUILD_WSI_XCB_SUPPORT=OFF -DBUILD_WSI_XLIB_SUPPORT=OFF -DBUILD_WSI_WAYLAND_SUPPORT=ON -DVOLK_INSTALL_DIR="$PWD/volk/install" -Wno-dev -G Ninja -B build-wayland
ninja -C build
ninja -C build-wayland
ninja -C build install
install -Dm755 build-wayland/cube/vkcube /usr/bin/vkcube-wayland
install -t /usr/share/licenses/vulkan-tools -Dm644 LICENSE.txt
popd
rm -rf Vulkan-Tools-vulkan-sdk-1.4.309.0
# libva (circular dependency; will be rebuilt later to support Mesa).
tar -xf ../sources/libva-2.22.0.tar.bz2
pushd libva-2.22.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libva -Dm644 COPYING
popd
rm -rf libva-2.22.0
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
cat README.md | tail -n211 | head -n22 | sed 's/    //g' > COPYING
install -t /usr/share/licenses/libglvnd -Dm644 COPYING
popd
rm -rf libglvnd-v1.7.0
# Mesa.
tar -xf ../sources/mesa-mesa-25.0.4.tar.bz2
pushd mesa-mesa-25.0.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dplatforms=wayland,x11 -Dgallium-drivers=auto -Dvulkan-drivers=auto -Dvulkan-layers=device-select,intel-nullhw,overlay,screenshot,vram-report-limit -Dgallium-nine=true -Dgallium-opencl=icd -Dgallium-rusticl=true -Dglx=dri -Dglvnd=enabled -Dintel-clc=enabled -Dintel-rt=enabled -Dosmesa=true -Dvideo-codecs=all -Dvalgrind=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/mesa -Dm644 docs/license.rst licenses/{Apache-2.0,BSL-1.0,exceptions/Linux-Syscall-Note,GPL-1.0-or-later,GPL-2.0-only,MIT,SGI-B-2.0}
popd
rm -rf mesa-mesa-25.0.4
# libva (rebuild to support Mesa).
tar -xf ../sources/libva-2.22.0.tar.bz2
pushd libva-2.22.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libva -Dm644 COPYING
popd
rm -rf libva-2.22.0
# xbitmaps.
tar -xf ../sources/xbitmaps-1.1.3.tar.xz
pushd xbitmaps-1.1.3
./configure --prefix=/usr
make install
install -t /usr/share/licenses/xbitmaps -Dm644 COPYING
popd
rm -rf xbitmaps-1.1.3
# iceauth.
tar -xf ../sources/iceauth-iceauth-1.0.10.tar.bz2
pushd iceauth-iceauth-1.0.10
./autogen.sh --prefix=/usr
make
make install
install -t /usr/share/licenses/iceauth -Dm644 COPYING
popd
rm -rf iceauth-iceauth-1.0.10
# luit.
tar -xf ../sources/luit-1.1.1.tar.bz2
pushd luit-1.1.1
sed -i -e "/D_XOPEN/s/5/6/" configure
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/luit -Dm644 COPYING
popd
rm -rf luit-1.1.1
# mkfontscale.
tar -xf ../sources/mkfontscale-1.2.3.tar.xz
pushd mkfontscale-1.2.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/mkfontscale -Dm644 COPYING
popd
rm -rf mkfontscale-1.2.3
# sessreg.
tar -xf ../sources/sessreg-1.1.3.tar.xz
pushd sessreg-1.1.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sessreg -Dm644 COPYING
popd
rm -rf sessreg-1.1.3
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
tar -xf ../sources/smproxy-1.0.7.tar.xz
pushd smproxy-1.0.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/smproxy -Dm644 COPYING
popd
rm -rf smproxy-1.0.7
# Many needed programs from the Xorg project.
for i in x11perf-1.7.0 xauth-1.1.4 xbacklight-1.2.4 xcmsdb-1.0.7 xcursorgen-1.0.8 xdpyinfo-1.3.4 xdriinfo-1.0.7 xev-1.2.6 xgamma-1.0.7 xhost-1.0.10 xinput-1.6.4 xkbcomp-1.4.7 xkbevd-1.1.6 xkbutils-1.0.6 xkill-1.0.6 xlsatoms-1.1.4 xlsclients-1.1.5 xmessage-1.0.7 xmodmap-1.0.11 xpr-1.2.0 xprop-1.2.8 xrandr-1.5.3 xrdb-1.2.2 xrefresh-1.1.0 xset-1.2.5 xsetroot-1.1.3 xvinfo-1.1.5 xwd-1.0.9 xwininfo-1.1.6 xwud-1.0.7; do
  tar -xf ../sources/$i.tar.*
  pushd $i
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  make
  make install
  install -t /usr/share/licenses/$(echo $i | cut -d- -f1) -Dm644 COPYING
  popd
  rm -rf $i
done
rm -f /usr/bin/xkeystone
# noto-fonts / noto-fonts-cjk / noto-fonts-emoji.
tar --no-same-owner --same-permissions -xf ../sources/noto-fonts-2025.04.01.tar.xz -C / --strip-components=1
tar --no-same-owner --same-permissions -xf ../sources/noto-fonts-cjk-20240730.tar.xz -C / --strip-components=1
tar --no-same-owner --same-permissions -xf ../sources/noto-fonts-emoji-2.047.tar.xz -C / --strip-components=1
sed -i 's|<string>sans-serif</string>|<string>Noto Sans</string>|' /etc/fonts/fonts.conf
sed -i 's|<string>monospace</string>|<string>Noto Sans Mono</string>|' /etc/fonts/fonts.conf
fc-cache
# xkeyboard-config.
tar -xf ../sources/xkeyboard-config-2.44.tar.xz
pushd xkeyboard-config-2.44
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xkeyboard-config -Dm644 COPYING
popd
rm -rf xkeyboard-config-2.44
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
tar -xf ../sources/libxkbcommon-xkbcommon-1.8.1.tar.gz
pushd libxkbcommon-xkbcommon-1.8.1
sed -i 's/sizeof(dtdstr)/ARRAY_SIZE(dtdstr) - 1/' src/registry.c
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Denable-docs=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libxkbcommon -Dm644 LICENSE
popd
rm -rf libxkbcommon-xkbcommon-1.8.1
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
tar -xf ../sources/systemd-257.5.tar.gz
pushd systemd-257.5
meson setup build --prefix=/usr --sbindir=bin --sysconfdir=/etc --localstatedir=/var --buildtype=minsize -Dmode=release -Dversion-tag=257.5-massos -Dshared-lib-tag=257.5-massos -Dbpf-framework=enabled -Dcryptolib=openssl -Ddefault-compression=xz -Ddefault-dnssec=no -Ddev-kvm-mode=0660 -Ddns-over-tls=openssl -Dfallback-hostname=massos -Dhomed=disabled -Dinitrd=true -Dinstall-tests=false -Dman=enabled -Dpamconfdir=/etc/pam.d -Drpmmacrosdir=no -Dsysupdate=disabled -Dsysusers=true -Dtests=false -Dtpm=true -Dukify=disabled -Duserdb=true
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
popd
rm -rf systemd-257.5
# D-Bus (rebuild for X and libaudit support).
tar -xf ../sources/dbus-1.16.2.tar.xz
pushd dbus-1.16.2
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
tar -xf ../sources/alsa-lib-1.2.14.tar.bz2
pushd alsa-lib-1.2.14
./configure --prefix=/usr --without-debug
make
make install
install -t /usr/share/licenses/alsa-lib -Dm644 COPYING
popd
rm -rf alsa-lib-1.2.14
# libepoxy.
tar -xf ../sources/libepoxy-1.5.10.tar.gz
pushd libepoxy-1.5.10
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libepoxy -Dm644 COPYING
popd
rm -rf libepoxy-1.5.10
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
tar -xf ../sources/xorg-server-21.1.16.tar.bz2
pushd xserver-xorg-server-21.1.16-b7f84e6d509c004a7abb514af75b94cb907d451b
patch -Np1 -i ../../patches/xorg-server-21.1.2-addxvfbrun.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dglamor=true -Dlibunwind=true -Dsuid_wrapper=true -Dxephyr=true -Dxvfb=true -Dxkb_output_dir=/var/lib/xkb
ninja -C build
ninja -C build install
install -t /usr/bin -Dm755 xvfb-run
install -t /usr/share/man/man1 xvfb-run.1
install -dm755 /etc/X11/xorg.conf.d
install -t /usr/share/licenses/xorg-server -Dm644 COPYING
popd
rm -rf xserver-xorg-server-21.1.16-b7f84e6d509c004a7abb514af75b94cb907d451b
# Xwayland.
tar -xf ../sources/xwayland-24.1.6.tar.bz2
pushd xserver-xwayland-24.1.6-5b1d9da00f217d3b52bfd3cc862dff79a9433e63
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dxvfb=false -Dxkb_output_dir=/var/lib/xkb
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xwayland -Dm644 COPYING
popd
rm -rf xserver-xwayland-24.1.6-5b1d9da00f217d3b52bfd3cc862dff79a9433e63
# libinput.
tar -xf ../sources/libinput-1.28.1.tar.bz2
pushd libinput-1.28.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddebug-gui=false -Ddocumentation=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libinput -Dm644 COPYING
popd
rm -rf libinput-1.28.1
# xf86-input-libinput.
tar -xf ../sources/xf86-input-libinput-1.5.0.tar.xz
pushd xf86-input-libinput-1.5.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-libinput -Dm644 COPYING
popd
rm -rf xf86-input-libinput-1.5.0
# xf86-input-vmmouse.
tar -xf ../sources/xf86-input-vmmouse-13.2.0.tar.xz
pushd xf86-input-vmmouse-13.2.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xf86-input-vmmouse -Dm644 COPYING
popd
rm -rf xf86-input-vmmouse-13.2.0
# xf86-video-vmware.
tar -xf ../sources/xf86-video-vmware-13.4.0.tar.bz2
pushd xf86-video-vmware-xf86-video-vmware-13.4.0-f82ce27f17e1c706f34a0fdc5cceaf6e42db1476
autoreconf -fi
./configure --prefix=/usr --enable-vmwarectrl-client
make
make install
install -t /usr/share/licenses/xf86-video-vmware -Dm644 COPYING
popd
rm -rf xf86-video-vmware-xf86-video-vmware-13.4.0-f82ce27f17e1c706f34a0fdc5cceaf6e42db1476
# intel-gmmlib.
tar -xf ../sources/intel-gmmlib-22.7.1.tar.gz
pushd gmmlib-intel-gmmlib-22.7.1
patch -Np1 -i ../../patches/intel-gmmlib-22.7.1-cmake400.patch
CFLAGS="" CXXFLAGS="" LDFLAGS="" cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DRUN_TEST_SUITE=OFF -Wno-dev -G Ninja -B build
CFLAGS="" CXXFLAGS="" LDFLAGS="" ninja -C build
CFLAGS="" CXXFLAGS="" LDFLAGS="" ninja -C build install
install -t /usr/share/licenses/intel-gmmlib -Dm644 LICENSE.md
popd
rm -rf gmmlib-intel-gmmlib-22.7.1
# intel-vaapi-driver.
tar -xf ../sources/intel-vaapi-driver-2.4.1.tar.bz2
pushd intel-vaapi-driver-2.4.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/intel-vaapi-driver -Dm644 COPYING
popd
rm -rf intel-vaapi-driver-2.4.1
# intel-media-driver.
tar -xf ../sources/intel-media-25.2.1.tar.gz
pushd media-driver-intel-media-25.2.1
patch -Np1 -i ../../patches/intel-media-driver-25.2.0-cmake400.patch
CFLAGS="" CXXFLAGS="" LDFLAGS="" cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DINSTALL_DRIVER_SYSCONF=OFF -DMEDIA_BUILD_FATAL_WARNINGS=OFF -Wno-dev -G Ninja -B build
CFLAGS="" CXXFLAGS="" LDFLAGS="" ninja -C build
CFLAGS="" CXXFLAGS="" LDFLAGS="" ninja -C build install
install -t /usr/share/licenses/intel-media-driver -Dm644 LICENSE.md
popd
rm -rf media-driver-intel-media-25.2.1
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
# cdrkit.
tar -xf ../sources/cdrkit_1.1.11.orig.tar.gz
pushd cdrkit-1.1.11
patch -Np1 -i ../../patches/cdrkit-1.1.11-buildfixes.patch
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/cdrkit -Dm644 COPYING
popd
rm -rf cdrkit-1.1.11
# dvd+rw-tools.
tar -xf ../sources/dvd+rw-tools-7.1.tar.gz
pushd pkg-dvd-rw-tools-upstream-7.1
patch -Np1 -i ../../patches/dvd+rw-tools-7.1-genericfixes.patch
make CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
install -t /usr/bin -m755 growisofs dvd+rw-booktype dvd+rw-format dvd+rw-mediainfo dvd-ram-control
install -t /usr/share/man/man1 -m644 growisofs.1
install -t /usr/share/licenses/dvd+rw-tools -Dm644 LICENSE
popd
rm -rf pkg-dvd-rw-tools-upstream-7.1
# libburn.
tar -xf ../sources/libburn-1.5.6.tar.gz
pushd libburn-1.5.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libburn -Dm644 COPYING COPYRIGHT
popd
rm -rf libburn-1.5.6
# libisofs.
tar -xf ../sources/libisofs-1.5.6.tar.gz
pushd libisofs-1.5.6
./configure --prefix=/usr --disable-static --enable-libacl --enable-xattr
make
make install
install -t /usr/share/licenses/libisofs -Dm644 COPYING COPYRIGHT
popd
rm -rf libisofs-1.5.6
# libisoburn.
tar -xf ../sources/libisoburn-1.5.6.tar.gz
pushd libisoburn-1.5.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libisoburn -Dm644 COPYING COPYRIGHT
popd
rm -rf libisoburn-1.5.6
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
tar -xf ../sources/fish-4.0.1.tar.xz
pushd fish-4.0.1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_BUILD_TYPE=Release -DBUILD_DOCS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
rm -f /usr/share/applications/fish.desktop
install -t /usr/share/licenses/fish -Dm644 COPYING doc_src/license.rst
popd
rm -rf fish-4.0.1
# yq.
tar -xf ../sources/yq-4.45.1.tar.gz
pushd yq-4.45.1
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
rm -rf yq-4.45.1
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
# tldr (we use the Rust version called 'tealdeer' for faster runtime).
tar -xf ../sources/tealdeer-1.7.2.tar.gz
pushd tealdeer-1.7.2
cargo build --release
install -Dm755 target/release/tldr /usr/bin/tldr
install -Dm644 completion/bash_tealdeer /usr/share/bash-completion/completions/tldr
install -Dm644 completion/fish_tealdeer /usr/share/fish/vendor_completions.d/tldr.fish
install -Dm644 completion/zsh_tealdeer /usr/share/zsh/site-functions/_tldr
install -t /usr/share/licenses/tldr -Dm644 LICENSE-APACHE LICENSE-MIT
popd
rm -rf tealdeer-1.7.2
# hyfetch (provides neofetch).
tar -xf ../sources/hyfetch-1.99.0.tar.gz
pushd hyfetch-1.99.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
ln -sf neowofetch /usr/bin/neofetch
install -t /usr/share/licenses/hyfetch -Dm644 LICENSE.md
popd
rm -rf hyfetch-1.99.0
# fastfetch.
tar -xf ../sources/fastfetch-2.41.0.tar.gz
pushd fastfetch-2.41.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_SYSTEM_YYJSON=ON -DINSTALL_LICENSE=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fastfetch -Dm644 LICENSE
popd
rm -rf fastfetch-2.41.0
# htop.
tar -xf ../sources/htop-3.4.0.tar.xz
pushd htop-3.4.0
./configure --prefix=/usr --sysconfdir=/etc --enable-delayacct --enable-openvz --enable-unicode --enable-vserver
make
make install
rm -f /usr/share/applications/htop.desktop
install -t /usr/share/licenses/htop -Dm644 COPYING
popd
rm -rf htop-3.4.0
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
gcc $CFLAGS sl.c -o sl -lncursesw
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
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/fuseiso -Dm644 COPYING
popd
rm -rf fuseiso-20070708
# mtools.
tar -xf ../sources/mtools-4.0.48.tar.bz2
pushd mtools-4.0.48
sed -e '/^SAMPLE FILE$/s:^:# :' -i mtools.conf
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -t /etc -Dm644 mtools.conf
install -t /usr/share/licenses/mtools -Dm644 COPYING
popd
rm -rf mtools-4.0.48
# bcachefs-tools.
tar -xf ../sources/bcachefs-tools-1.25.1.tar.gz
pushd bcachefs-tools-1.25.1
make PREFIX=/usr ROOT_SBINDIR=/usr/bin INITRAMFS_DIR=/tmp/trash
make PREFIX=/usr ROOT_SBINDIR=/usr/bin INITRAMFS_DIR=/tmp/trash install
bcachefs completions bash > /usr/share/bash-completion/completions/bcachefs
bcachefs completions zsh > /usr/share/zsh/site-functions/_bcachefs
bcachefs completions fish > /usr/share/fish/vendor_completions.d/bcachefs.fish
install -t /usr/share/licenses/bcachefs-tools -Dm644 COPYING
popd
rm -rf bcachefs-tools-1.25.1
# Polkit.
tar -xf ../sources/polkit-126.tar.gz
pushd polkit-126
patch -Np1 -i ../../patches/polkit-125-massos-undetected-distro.patch
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dman=true -Dpam_prefix=/etc/pam.d -Dsession_tracking=logind -Dtests=false
ninja -C build
ninja -C build install
systemd-sysusers
install -t /usr/share/licenses/polkit -Dm644 COPYING
popd
rm -rf polkit-126
# OpenSSH.
tar -xf ../sources/openssh-10.0p1.tar.gz
pushd openssh-10.0p1
install -o root -g sys -dm700 /var/lib/sshd
echo 'u sshd - "sshd PrivSep" /var/lib/sshd' > /usr/lib/sysusers.d/sshd.conf
systemd-sysusers
./configure --prefix=/usr --sysconfdir=/etc/ssh --sbindir=/usr/bin --with-default-path="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin" --with-kerberos5=/usr --with-libedit --with-pam --with-pid-dir=/run --with-privsep-path=/var/lib/sshd --with-privsep-user=sshd --with-ssl-engine --with-xauth=/usr/bin/xauth
make
make install
install -t /usr/bin -Dm755 contrib/ssh-copy-id
install -t /usr/share/man/man1 -Dm644 contrib/ssh-copy-id.1
cp /etc/pam.d/{login,sshd}
sed -i 's/#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
install -t /usr/share/licenses/openssh -Dm644 LICENCE
popd
rm -rf openssh-10.0p1
# sshfs.
tar -xf ../sources/sshfs-3.7.3.tar.xz
pushd sshfs-3.7.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/sshfs -Dm644 COPYING
popd
rm -rf sshfs-3.7.3
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
tar -xf ../sources/freeglut-3.6.0.tar.gz
pushd freeglut-3.6.0
patch -Np1 -i ../../patches/freeglut-3.6.0-cmake400.patch
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DFREEGLUT_BUILD_DEMOS=OFF -DFREEGLUT_BUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/freeglut -Dm644 COPYING
popd
rm -rf freeglut-3.6.0
# GLEW.
tar -xf ../sources/glew-2.2.0.tgz
pushd glew-2.2.0
sed -i 's|lib64|lib|g' config/Makefile.linux
make
make install.all
chmod 755 /usr/lib/libGLEW.so.2.2.0
rm -f /usr/lib/libGLEW.a
install -t /usr/share/licenses/glew -Dm644 LICENSE.txt
popd
rm -rf glew-2.2.0
# libtiff.
tar -xf ../sources/libtiff-v4.7.0.tar.bz2
pushd libtiff-v4.7.0
sed -i '/cmake_minimum_required/d' doc/CMakeLists.txt
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libtiff -Dm644 LICENSE.md
popd
rm -rf libtiff-v4.7.0
# lcms2.
tar -xf ../sources/lcms2-2.17.tar.gz
pushd lcms2-2.17
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/lcms2 -Dm644 LICENSE
popd
rm -rf lcms2-2.17
# JasPer.
tar -xf ../sources/jasper-4.2.5.tar.gz
pushd jasper-4.2.5
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=YES -DALLOW_IN_SOURCE_BUILD=YES -DJAS_ENABLE_DOC=NO -DJAS_ENABLE_LIBJPEG=ON -DJAS_ENABLE_OPENGL=ON -Wno-dev -G Ninja -B build1
ninja -C build1
ninja -C build1 install
install -t /usr/share/licenses/jasper -Dm644 LICENSE.txt
popd
rm -rf jasper-4.2.5
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
tar -xf ../sources/wlroots-0.18.2.tar.bz2
pushd wlroots-0.18.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/wlroots -Dm644 LICENSE
popd
rm -rf wlroots-0.18.2
# libsysprof-capture.
tar -xf ../sources/sysprof-48.0.tar.gz
pushd sysprof-48.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dgtk=false -Dhelp=false -Dlibsysprof=false -Dsysprofd=none -Dtests=false -Dtools=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsysprof-capture -Dm644 COPYING{,.gpl-2}
popd
rm -rf sysprof-48.0
# at-spi2-core (now provides ATK and at-spi2-atk).
tar -xf ../sources/at-spi2-core-2.56.1.tar.gz
pushd at-spi2-core-2.56.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/at-spi2-core -Dm644 COPYING
ln -sf at-spi2-core /usr/share/licenses/at-spi2-atk
ln -sf at-spi2-core /usr/share/licenses/atk
popd
rm -rf at-spi2-core-2.56.1
# Atkmm.
tar -xf ../sources/atkmm-2.28.4.tar.gz
pushd atkmm-2.28.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-documentation=false -Dmaintainer-mode=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/atkmm -Dm644 COPYING{,.tools}
popd
rm -rf atkmm-2.28.4
# GDK-Pixbuf.
tar -xf ../sources/gdk-pixbuf-2.42.12.tar.gz
pushd gdk-pixbuf-2.42.12
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dinstalled_tests=false -Dothers=enabled -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gdk-pixbuf -Dm644 COPYING
popd
rm -rf gdk-pixbuf-2.42.12
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
tar -xf ../sources/cairomm-1.14.5.tar.bz2
pushd cairomm-1.14.5
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-examples=false -Dbuild-tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/cairomm -Dm644 COPYING
popd
rm -rf cairomm-1.14.5
# HarfBuzz (rebuild to support Cairo).
tar -xf ../sources/harfbuzz-11.1.0.tar.xz
pushd harfbuzz-11.1.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled
ninja -C build
ninja -C build install
popd
rm -rf harfbuzz-11.1.0
# Pango.
tar -xf ../sources/pango-1.56.3.tar.gz
pushd pango-1.56.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dintrospection=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pango -Dm644 COPYING
popd
rm -rf pango-1.56.3
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
tar -xf ../sources/libwebp-1.5.0.tar.gz
pushd libwebp-1.5.0
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=ON -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libwebp -Dm644 COPYING
popd
rm -rf libwebp-1.5.0
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
tar -xf ../sources/graphviz-12.2.1.tar.bz2
pushd graphviz-12.2.1
sed -i '/LIBPOSTFIX="64"/s/64//' configure.ac
./autogen.sh
./configure --prefix=/usr --disable-php --enable-lefty --with-webp
sed -i "s|0|$(date +%Y%m%d)|" builddate.h
make
make -j1 install
install -t /usr/share/licenses/graphviz -Dm644 COPYING
popd
rm -rf graphviz-12.2.1
# Vala.
tar -xf ../sources/vala-0.56.18.tar.xz
pushd vala-0.56.18
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/vala -Dm644 COPYING
popd
rm -rf vala-0.56.18
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
tar -xf ../sources/librsvg-2.60.0.tar.gz
pushd librsvg-2.60.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/librsvg -Dm644 COPYING.LIB
popd
rm -rf librsvg-2.60.0
# Colord.
tar -xf ../sources/colord-1.4.7.tar.xz
pushd colord-1.4.7
patch -Np1 -i ../../patches/colord-1.4.7-upstreamfixes.patch
sed -i '/class="manual"/i<refmiscinfo class="source">colord</refmiscinfo>' man/*.xml
echo 'u colord - "Color Daemon Owner" /var/lib/colord' > /usr/lib/sysusers.d/colord.conf
systemd-sysusers
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddaemon_user=colord -Dvapi=true -Dsystemd=true -Dlibcolordcompat=true -Dargyllcms_sensor=false -Dman=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/colord -Dm644 COPYING
popd
rm -rf colord-1.4.7
# CUPS.
tar -xf ../sources/cups-2.4.12-source.tar.gz
pushd cups-2.4.12
cat > /usr/lib/sysusers.d/cups.conf << "END"
u cups 420 "CUPS Service User" /var/spool/cups
m cups lp
END
systemd-sysusers
patch -Np1 -i ../../patches/cups-2.4.11-pamconfig.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --sbindir=/usr/bin --with-docdir=/usr/share/cups/doc --with-rundir=/run/cups --with-cups-group=420 --with-cups-user=420 --with-system-groups=lpadmin --enable-libpaper
make
make install
echo "ServerName /run/cups/cups.sock" > /etc/cups/client.conf
sed -e "s|#User 420|User 420|" -e "s|#Group 420|Group 420|" -i /etc/cups/cups-files.conf{,.default}
systemctl enable cups
install -t /usr/share/licenses/cups -Dm644 LICENSE NOTICE
popd
rm -rf cups-2.4.12
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
tar -xf ../sources/gtk-3.24.49.tar.gz
pushd gtk-3.24.49
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbroadway_backend=true -Dcloudproviders=true -Dcolord=yes -Ddemos=false -Dexamples=false -Dman=true -Dprint_backends=cups,file,lpr -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk3 -Dm644 COPYING
popd
rm -rf gtk-3.24.49
# Gtkmm3.
tar -xf ../sources/gtkmm-3.24.10.tar.gz
pushd gtkmm-3.24.10
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-demos=false -Dbuild-documentation=false -Dbuild-tests=false -Dmaintainer-mode=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtkmm3 -Dm644 COPYING{,.tools}
popd
rm -rf gtkmm-3.24.10
# libhandy.
tar -xf ../sources/libhandy-1.8.3.tar.gz
pushd libhandy-1.8.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libhandy -Dm644 COPYING
popd
rm -rf libhandy-1.8.3
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
tar -xf ../sources/adwaita-icon-theme-48.0.tar.gz
pushd adwaita-icon-theme-48.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/adwaita-icon-theme -Dm644 COPYING{,_CCBYSA3,_LGPL}
popd
rm -rf adwaita-icon-theme-48.0
# gnome-themes-extra (for accessibility - provides high contrast theme).
tar -xf ../sources/gnome-themes-extra-3.28.tar.xz
pushd gnome-themes-extra-3.28
./configure --prefix=/usr --disable-gtk2-engine
make
make install
install -t /usr/share/licenses/gnome-themes-extra -Dm644 LICENSE
popd
rm -rf gnome-themes-extra-3.28
# webp-pixbuf-loader.
tar -xf ../sources/webp-pixbuf-loader-0.2.7.tar.gz
pushd webp-pixbuf-loader-0.2.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/webp-pixbuf-loader -Dm644 LICENSE.LGPL-2
popd
rm -rf webp-pixbuf-loader-0.2.7
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
tar -xf ../sources/exiv2-0.28.5.tar.gz
pushd exiv2-0.28.5
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DEXIV2_ENABLE_CURL=YES -DEXIV2_ENABLE_NLS=YES -DEXIV2_ENABLE_VIDEO=YES -DEXIV2_ENABLE_WEBREADY=YES -DEXIV2_BUILD_SAMPLES=NO -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/exiv2 -Dm644 COPYING
popd
rm -rf exiv2-0.28.5
# meson-python.
tar -xf ../sources/meson_python-0.17.1.tar.gz
pushd meson_python-0.17.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/meson-python -Dm644 LICENSE LICENSES/MIT.txt
popd
rm -rf meson_python-0.17.1
# PyCairo.
tar -xf ../sources/pycairo-1.27.0.tar.gz
pushd pycairo-1.27.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pycairo -Dm644 COPYING{,-LGPL-2.1,-MPL-1.1}
popd
rm -rf pycairo-1.27.0
# PyGObject.
tar -xf ../sources/pygobject-3.52.3.tar.gz
pushd pygobject-3.52.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/pygobject -Dm644 COPYING
popd
rm -rf pygobject-3.52.3
# dbus-python.
tar -xf ../sources/dbus-python-1.4.0.tar.xz
pushd dbus-python-1.4.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
tools/generate-pkginfo.py 1.4.0 PKG-INFO
ninja -C build install
install -t "/usr/lib/$(readlink /usr/bin/python3)/site-packages/dbus_python-1.4.0-py$(readlink /usr/bin/python3 | sed -e 's/python//').egg-info" -Dm644 PKG-INFO
install -t /usr/share/licenses/dbus-python -Dm644 COPYING
popd
rm -rf dbus-python-1.4.0
# python-dbusmock.
tar -xf ../sources/python_dbusmock-0.34.3.tar.gz
pushd python_dbusmock-0.34.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/python-dbusmock -Dm644 COPYING
popd
rm -rf python_dbusmock-0.34.3
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
systemctl enable firewalld
install -t /usr/share/licenses/firewalld -Dm644 COPYING
popd
rm -rf firewalld-2.3.0
# gexiv2.
tar -xf ../sources/gexiv2-0.14.3.tar.gz
pushd gexiv2-gexiv2-0.14.3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gexiv2 -Dm644 COPYING
popd
rm -rf gexiv2-gexiv2-0.14.3
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
tar -xf ../sources/LibRaw-0.21.3.tar.gz
pushd LibRaw-0.21.3
autoreconf -fi
./configure --prefix=/usr --enable-jasper --enable-jpeg --enable-lcms --disable-static
make
make install
install -t /usr/share/licenses/libraw -Dm644 COPYRIGHT LICENSE.LGPL
popd
rm -rf LibRaw-0.21.3
# libogg.
tar -xf ../sources/libogg-1.3.5.tar.xz
pushd libogg-1.3.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libogg -Dm644 COPYING
popd
rm -rf libogg-1.3.5
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
tar -xf ../sources/opus-1.5.2.tar.gz
pushd opus-1.5.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/opus -Dm644 COPYING
popd
rm -rf opus-1.5.2
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
tar -xf ../sources/alsa-utils-1.2.14.tar.bz2
pushd alsa-utils-1.2.14
./configure --prefix=/usr --sbindir=/usr/bin --disable-alsaconf --with-systemdsystemunitdir=/usr/lib/systemd/system --with-udev-rules-dir=/usr/lib/udev/rules.d
make
make install
install -t /usr/share/licenses/alsa-utils -Dm644 COPYING
popd
rm -rf alsa-utils-1.2.14
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
tar -xf ../sources/sbc-2.1.tar.xz
pushd sbc-2.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/sbc -Dm644 COPYING COPYING.LIB
popd
rm -rf sbc-2.1
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
tar -xf ../sources/libical-3.0.20.tar.gz
pushd libical-3.0.20
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DGOBJECT_INTROSPECTION=ON -DICAL_BUILD_DOCS=OFF -DLIBICAL_BUILD_TESTING=OFF -DICAL_GLIB_VAPI=ON -DSHARED_ONLY=ON -Wno-dev -G Ninja -B build
ninja -C build -j1
ninja -C build install
install -t /usr/share/licenses/libical -Dm644 COPYING LICENSE LICENSE.LGPL21.txt
popd
rm -rf libical-3.0.20
# BlueZ.
tar -xf ../sources/bluez-5.82.tar.xz
pushd bluez-5.82
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
rm -rf bluez-5.82
# Avahi.
tar -xf ../sources/avahi-0.8.tar.gz
pushd avahi-0.8
echo 'u avahi - "Avahi Daemon Owner" /var/run/avahi-daemon' > /usr/lib/sysusers.d/avahi.conf
systemd-sysusers
patch -Np1 -i ../../patches/avahi-0.8-unifiedfixes.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-mono --disable-monodoc --disable-python --disable-qt3 --disable-qt4 --disable-qt5 --disable-rpath --disable-static --enable-compat-libdns_sd --with-distro=none
make
make install
systemctl enable avahi-daemon
install -t /usr/share/licenses/avahi -Dm644 LICENSE
popd
rm -rf avahi-0.8
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
tar -xf ../sources/speech-dispatcher-0.12.0.tar.gz
pushd speech-dispatcher-0.12.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --without-baratinoo --without-espeak --without-flite --without-ibmtts --without-kali --without-voxin
make
make install
rm -f /etc/speech-dispatcher/modules/{cicero,espeak,espeak-mbrola-generic,flite}.conf
rm -f /usr/libexec/speech-dispatcher-modules/sd_cicero
sed -i 's/#AddModule "espeak-ng"/AddModule "espeak-ng"/' /etc/speech-dispatcher/speechd.conf
systemctl enable speech-dispatcherd
install -t /usr/share/licenses/speech-dispatcher -Dm644 COPYING.{GPL-2,GPL-3,LGPL}
popd
rm -rf speech-dispatcher-0.12.0
# SDL2.
tar -xf ../sources/SDL2-2.32.4.tar.gz
pushd SDL2-2.32.4
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSDL_HIDAPI_LIBUSB=ON -DSDL_RPATH=OFF -DSDL_STATIC=OFF -DSDL_TEST=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/sdl2 -Dm644 LICENSE.txt
popd
rm -rf SDL2-2.32.4
# sdl12-compat (provides SDL).
tar -xf ../sources/sdl12-compat-release-1.2.68.tar.gz
pushd sdl12-compat-release-1.2.68
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSDL12TESTS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/sdl12-compat -Dm644 LICENSE.txt
ln -sf sdl12-compat /usr/share/licenses/sdl
popd
rm -rf sdl12-compat-release-1.2.68
# biosdevname.
tar -xf ../sources/biosdevname-0.7.3.tar.gz
pushd biosdevname-0.7.3
./autogen.sh --prefix=/usr --sbindir=/usr/bin --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/biosdevname -Dm644 COPYING
popd
rm -rf biosdevname-0.7.3
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
tar -xf ../sources/flashrom-v1.5.1.tar.xz
pushd flashrom-v1.5.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dprogrammer=all -Dtests=disabled
ninja -C build
ninja -C build install
rm -f /usr/lib/libflashrom.a
sed 's|GROUP="plugdev"|TAG+="uaccess"|g' util/flashrom_udev.rules > /usr/lib/udev/rules.d/70-flashrom.rules
install -t /usr/share/licenses/flashrom -Dm644 COPYING
popd
rm -rf flashrom-v1.5.1
# rrdtool.
tar -xf ../sources/rrdtool-1.9.0.tar.gz
pushd rrdtool-1.9.0
sed -i 's|/ruby/extconf.rb|/ruby/extconf.rb --vendor|' bindings/Makefile.am
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-rpath --disable-static --enable-lua --enable-lua-site-install --enable-perl --enable-perl-site-install --with-perl-options="INSTALLDIRS=vendor" --enable-python --enable-ruby --enable-ruby-site-install --enable-tcl
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
tar -xf ../sources/libpcap-1.10.5.tar.xz
pushd libpcap-1.10.5
autoreconf -fi
./configure --prefix=/usr --enable-ipv6 --enable-bluetooth --enable-usb --with-libnl
make
make install
rm -f /usr/lib/libpcap.a
install -t /usr/share/licenses/libpcap -Dm644 LICENSE
popd
rm -rf libpcap-1.10.5
# Net-SNMP.
tar -xf ../sources/net-snmp-5.9.4.tar.gz
pushd net-snmp-5.9.4
patch -Np1 -i ../../patches/net-snmp-5.9.4-upstreamfixes.patch
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --mandir=/usr/share/man --disable-static --enable-blumenthal-aes --enable-ipv6 --enable-ucd-snmp-compatibility --with-default-snmp-version=3 --with-logfile=/var/log/snmpd.log --with-mib-modules="host misc/ipfwacc ucd-snmp/diskio tunnel ucd-snmp/dlmod ucd-snmp/lmsensorsMib" --with-persistent-directory=/var/net-snmp --with-python-modules --with-sys-contact=root@localhost --with-sys-location=Unknown --without-pcre
make NETSNMP_DONT_CHECK_VERSION=1
make -j1 INSTALLDIRS=vendor install
install -t /usr/share/licenses/net-snmp -Dm644 COPYING
popd
rm -rf net-snmp-5.9.4
# ppp.
tar -xf ../sources/ppp-2.5.1.tar.gz
pushd ppp-2.5.1
patch -Np1 -i ../../patches/ppp-2.4.9-extrafiles.patch
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
chmod 0755 /usr/lib/pppd/2.5.1/*.so
install -dm755 /usr/share/licenses/ppp
cat > /usr/share/licenses/ppp/LICENSE << "END"
All of the code can be freely used and redistributed.  The individual
source files each have their own copyright and permission notice.
Pppd, pppstats and pppdump are under BSD-style notices.  Some of the
pppd plugins are GPL'd.  Chat is public domain.
END
popd
rm -rf ppp-2.5.1
# Vim.
tar -xf ../sources/vim-9.1.1320.tar.gz
pushd vim-9.1.1320
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
rm -rf vim-9.1.1320
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
tar -xf ../sources/openjpeg-2.5.3.tar.gz
pushd openjpeg-2.5.3
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
cp -r doc/man /usr/share
install -t /usr/share/licenses/openjpeg -Dm644 LICENSE
popd
rm -rf openjpeg-2.5.3
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
# pinentry.
tar -xf ../sources/pinentry-1.3.1.tar.bz2
pushd pinentry-1.3.1
./configure --prefix=/usr --enable-pinentry-tty
make
make install
install -t /usr/share/licenses/pinentry -Dm644 COPYING
popd
rm -rf pinentry-1.3.1
# AccountsService.
tar -xf ../sources/accountsservice-23.13.9.tar.xz
pushd accountsservice-23.13.9
sed -i '/sys.exit(77)/d' tests/test-daemon.py
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dadmin_group=wheel
ninja -C build
ninja -C build install
install -t /usr/share/licenses/accountsservice -Dm644 COPYING
popd
rm -rf accountsservice-23.13.9
# polkit-gnome.
tar -xf ../sources/polkit-gnome-0.105.tar.xz
pushd polkit-gnome-0.105
patch -Np1 -i ../../patches/polkit-gnome-0.105-upstreamfixes.patch
./configure --prefix=/usr
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
tar -xf ../sources/poppler-25.04.0.tar.xz
pushd poppler-25.04.0
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_CPP_TESTS=OFF -DBUILD_GTK_TESTS=OFF -DBUILD_MANUAL_TESTS=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF -DENABLE_UNSTABLE_API_ABI_HEADERS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/poppler -Dm644 COPYING{,3}
popd
rm -rf poppler-25.04.0
# poppler-data.
tar -xf ../sources/poppler-data-0.4.12.tar.gz
pushd poppler-data-0.4.12
make prefix=/usr install
install -t /usr/share/licenses/poppler-data -Dm644 COPYING{,.adobe,.gpl2}
popd
rm -rf poppler-data-0.4.12
# GhostScript.
tar -xf ../sources/ghostscript-10.05.0.tar.xz
pushd ghostscript-10.05.0
rm -rf cups/libs freetype lcms2mt jpeg leptonica libpng openjpeg tesseract zlib
./configure --prefix=/usr --disable-compile-inits --disable-hidden-visibility --enable-dynamic --enable-fontconfig --enable-freetype --enable-openjpeg --with-drivers=ALL --with-system-libtiff --with-x
make so
make soinstall
install -t /usr/include/ghostscript -Dm644 base/*.h
ln -sf gsc /usr/bin/gs
ln -sfn ghostscript /usr/include/ps
install -t /usr/share/licenses/ghostscript -Dm644 LICENSE
popd
rm -rf ghostscript-10.05.0
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
install -t /usr/share/cups/model -Dm644 ../extra/CUPS-PDF_{,no}opt.ppd
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
install -t /usr/share/licenses/gutenprint -Dm644 COPYING
popd
rm -rf gutenprint-5.3.5
# SANE.
tar -xf ../sources/sane-1.3.1.tar.gz
pushd backends-1.3.1-3ff55fd8ee04ae459e199088ebe11ac979671d0e
echo "1.3.1" > .tarball-version
echo "1.3.1" > .version
autoreconf -fi
mkdir -p build; pushd build
../configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-rpath --with-group=scanner --with-lockdir=/run/lock
make
make install
install -Dm644 tools/udev/libsane.rules /usr/lib/udev/rules.d/65-scanner.rules
install -t /usr/share/licenses/sane -Dm644 ../COPYING ../LICENSE ../README.djpeg
popd; popd
rm -rf backends-1.3.1-3ff55fd8ee04ae459e199088ebe11ac979671d0e
# HPLIP.
tar -xf ../sources/hplip-3.25.2.tar.gz
pushd hplip-3.25.2
patch -Np1 -i ../../patches/hplip-3.24.4-manyfixes.patch
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
rm -rf hplip-3.25.2
# system-config-printer.
tar -xf ../sources/system-config-printer-1.5.18.tar.xz
pushd system-config-printer-1.5.18
patch -Np1 -i ../../patches/system-config-printer-1.5.18-pythonbuild.patch
./bootstrap
./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --disable-rpath --with-cups-serverbin-dir=/usr/lib/cups --with-systemdsystemunitdir=/usr/lib/systemd/system --with-udev-rules --with-udevdir=/usr/lib/udev
sed -i '/^SUBDIRS/s/po//' Makefile
make
make install
install -t /usr/share/licenses/system-config-printer -Dm644 COPYING
popd
rm -rf system-config-printer-1.5.18
# Tk.
tar -xf ../sources/tk8.6.16-src.tar.gz
pushd tk8.6.16/unix
./configure --prefix=/usr --mandir=/usr/share/man --enable-64bit
make
sed -e "s@^\(TK_SRC_DIR='\).*@\1/usr/include'@" -e "/TK_B/s@='\(-L\)\?.*unix@='\1/usr/lib@" -i tkConfig.sh
make install
make install-private-headers
ln -sf wish8.6 /usr/bin/wish
chmod 755 /usr/lib/libtk8.6.so
install -t /usr/share/licenses/tk -Dm644 license.terms
popd
rm -rf tk8.6.16
# Python (rebuild to support SQLite and Tk).
tar -xf ../sources/Python-3.13.3.tar.xz
pushd Python-3.13.3
./configure --prefix=/usr --enable-shared --enable-optimizations --with-system-expat --with-system-libmpdec --without-ensurepip --disable-test-modules
make
make install
popd
rm -rf Python-3.13.3
# dnspython.
tar -xf ../sources/dnspython-2.7.0.tar.gz
pushd dnspython-2.7.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/dnspython -Dm644 LICENSE
popd
rm -rf dnspython-2.7.0
# chardet.
tar -xf ../sources/chardet-5.2.0.tar.gz
pushd chardet-5.2.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/chardet -Dm644 LICENSE
popd
rm -rf chardet-5.2.0
# charset-normalizer.
tar -xf ../sources/charset_normalizer-3.4.1.tar.gz
pushd charset_normalizer-3.4.1
python -m build -nw -o dist --skip-dependency-check
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/charset-normalizer -Dm644 LICENSE
popd
rm -rf charset_normalizer-3.4.1
# idna.
tar -xf ../sources/idna-3.10.tar.gz
pushd idna-3.10
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/idna -Dm644 LICENSE.md
popd
rm -rf idna-3.10
# pycparser.
tar -xf ../sources/pycparser-release_v2.22.tar.gz
pushd pycparser-release_v2.22
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pycparser -Dm644 LICENSE
popd
rm -rf pycparser-release_v2.22
# cffi.
tar -xf ../sources/cffi-1.17.1.tar.gz
pushd cffi-1.17.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/cffi -Dm644 LICENSE
popd
rm -rf cffi-1.17.1
# setuptools-rust.
tar -xf ../sources/setuptools-rust-1.11.1.tar.gz
pushd setuptools-rust-1.11.1
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/setuptools-rust -Dm644 LICENSE
popd
rm -rf setuptools-rust-1.11.1
# maturin.
tar -xf ../sources/maturin-1.8.3.tar.gz
pushd maturin-1.8.3
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/maturin -Dm644 license-{apache,mit}
popd
rm -rf maturin-1.8.3
# cryptography.
tar -xf ../sources/cryptography-44.0.2.tar.gz
pushd cryptography-44.0.2
CC=clang RUSTFLAGS="$RUSTFLAGS -Clinker-plugin-lto -Clinker=clang -Clink-arg=-fuse-ld=lld" python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/cryptography -Dm644 LICENSE{,.APACHE,.BSD}
popd
rm -rf cryptography-44.0.2
# pyopenssl.
tar -xf ../sources/pyopenssl-25.0.0.tar.gz
pushd pyopenssl-25.0.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/pyopenssl -Dm644 LICENSE
popd
rm -rf pyopenssl-25.0.0
# urllib3.
tar -xf ../sources/urllib3-2.3.0.tar.gz
pushd urllib3-2.3.0
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/urllib3 -Dm644 LICENSE.txt
popd
rm -rf urllib3-2.3.0
# requests.
tar -xf ../sources/requests-2.32.3.tar.gz
pushd requests-2.32.3
patch -Np1 -i ../../patches/requests-2.32.3-systemcertificates.patch
python -m build -nw -o dist
python -m installer --compile-bytecode 1 dist/*.whl
install -t /usr/share/licenses/requests -Dm644 LICENSE
popd
rm -rf requests-2.32.3
# libplist.
tar -xf ../sources/libplist-2.6.0.tar.bz2
pushd libplist-2.6.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libplist -Dm644 COPYING COPYING.LESSER
popd
rm -rf libplist-2.6.0
# libimobiledevice-glue.
tar -xf ../sources/libimobiledevice-glue-1.3.1.tar.bz2
pushd libimobiledevice-glue-1.3.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libimobiledevice-glue -Dm644 COPYING
popd
rm -rf libimobiledevice-glue-1.3.1
# libusbmuxd.
tar -xf ../sources/libusbmuxd-2.1.0.tar.bz2
pushd libusbmuxd-2.1.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libusbmuxd -Dm644 COPYING
popd
rm -rf libusbmuxd-2.1.0
# libimobiledevice.
tar -xf ../sources/libimobiledevice-1.3.0-217-g1ec2c2c.tar.gz
pushd libimobiledevice-1ec2c2c5e3609cc02b302bcbd79ed2872260d350
echo "1.3.0-217-g1ec2c2c" > .tarball-version
./autogen.sh --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libimobiledevice -Dm644 COPYING COPYING.LESSER
popd
rm -rf libimobiledevice-1ec2c2c5e3609cc02b302bcbd79ed2872260d350
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
cat lib/JSON.pm | tail -n9 | head -n6 | install -Dm644 /dev/stdin /usr/share/licenses/json/COPYING
popd
rm -rf JSON-4.10
# Parse-Yapp.
tar -xf ../sources/Parse-Yapp-1.21.tar.gz
pushd Parse-Yapp-1.21
perl Makefile.PL INSTALLDIRS=vendor
make
make install
install -dm755 /usr/share/licenses/parse-yapp
cat lib/Parse/Yapp.pm | tail -n14 | head -n12 > /usr/share/licenses/parse-yapp/COPYING
popd
rm -rf Parse-Yapp-1.21
# smbclient (client portion of Samba).
tar -xf ../sources/samba-4.21.5.tar.gz
pushd samba-4.21.5
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --with-pammodulesdir=/usr/lib/security --with-piddir=/run/samba --systemd-install-services --enable-fhs --with-acl-support --with-ads --with-cluster-support --with-ldap --with-pam --with-profiling-data --with-systemd --with-winbind
make
make install
ln -sfr /usr/bin/smbspool /usr/lib/cups/backend/smb
rm -f /etc/sysconfig/samba
rm -f /usr/bin/{cifsdd,ctdb,ctdb_diagnostics,dbwrap_tool,dumpmscat,gentest,ldbadd,ldbdel,ldbedit,ldbmodify,ldbrename,ldbsearch,locktest,ltdbtool,masktest,mdsearch,mvxattr,ndrdump,ntlm_auth,oLschema2ldif,onnode,pdbedit,ping_pong,profiles,regdiff,regpatch,regshell,regtree,samba-regedit,samba-tool,sharesec,smbcontrol,smbpasswd,smbstatus,smbtorture,tdbbackup,tdbdump,tdbrestore,tdbtool,testparm,wbinfo}
rm -f /usr/bin/{ctdbd,ctdbd_wrapper,eventlogadm,nmbd,samba,samba_dnsupdate,samba_downgrade_db,samba-gpupdate,samba_kcc,samba_spnupdate,samba_upgradedns,smbd,winbindd}
rm -rf /usr/include/samba-4.0/{charset.h,core,credentials.h,dcerpc.h,dcerpc_server.h,dcesrv_core.h,domain_credentials.h,gen_ndr,ldb_wrap.h,lookup_sid.h,machine_sid.h,ndr,ndr.h,param.h,passdb.h,policy.h,rpc_common.h,samba,share.h,smb2_lease_struct.h,smbconf.h,smb_ldap.h,smbldap.h,tdr.h,tsocket.h,tsocket_internal.h,util,util_ldb.h}
rm -rf /usr/lib/samba/{bind9,gensec,idmap,krb5,ldb,nss_info,process_model,service,vfs}
rm -rf /usr/lib/$(readlink /usr/bin/python3)/{samba,talloc.cpython-310-x86_64-linux-gnu.so,tdb.cpython-310-x86_64-linux-gnu.so,_tdb_text.py,_tevent.cpython-310-x86_64-linux-gnu.so,tevent.py}
rm -f /usr/lib/pkgconfig/{dcerpc,dcerpc_samr,dcerpc_server,ndr_krb5pac,ndr_nbt,ndr,ndr_standard,netapi,samba-credentials,samba-hostconfig,samba-policy.cpython-310-x86_64-linux-gnu,samba-util,samdb}.pc
rm -f /usr/lib/security/pam_winbind.so
rm -f /usr/lib/systemd/system/{nmb,samba,smb,winbind}.service
rm -rf /usr/share/{ctdb,samba}
rm -f /usr/share/man/man1/{ctdb,ctdbd,ctdb_diagnostics,ctdbd_wrapper,dbwrap_tool,gentest,ldbadd,ldbdel,ldbedit,ldbmodify,ldbrename,ldbsearch,locktest,log2pcap,ltdbtool,masktest,mdsearch,mvxattr,ndrdump,ntlm_auth,oLschema2ldif,onnode,ping_pong,profiles,regdiff,regpatch,regshell,regtree,sharesec,smbcontrol,smbstatus,smbtorture,testparm,vfstest,wbinfo}.1
rm -f /usr/share/man/man3/{ldb,talloc}.3
rm -f /usr/share/man/man5/{ctdb.conf,ctdb-script.options,ctdb.sysconfig,lmhosts,pam_winbind.conf,smb.conf,smbgetrc,smbpasswd}.5
rm -f /usr/share/man/man7/{ctdb,ctdb-statistics,ctdb-tunables,samba,traffic_learner,traffic_replay}.7
rm -f /usr/share/man/man8/{cifsdd,eventlogadm,idmap_ad,idmap_autorid,idmap_hash,idmap_ldap,idmap_nss,idmap_rfc2307,idmap_rid,idmap_script,idmap_tdb2,idmap_tdb,nmbd,pam_winbind,pdbedit,samba,samba-bgqd,samba_downgrade_db,samba-gpupdate,samba-regedit,samba-tool,smbd,smbpasswd,smbspool_krb5_wrapper,tdbbackup,tdbdump,tdbrestore,tdbtool,vfs_acl_tdb,vfs_acl_xattr,vfs_aio_fork,vfs_aio_pthread,vfs_audit,vfs_btrfs,vfs_cap,vfs_catia,vfs_commit,vfs_crossrename,vfs_default_quota,vfs_dirsort,vfs_extd_audit,vfs_fake_perms,vfs_fileid,vfs_fruit,vfs_full_audit,vfs_glusterfs_fuse,vfs_gpfs,vfs_linux_xfs_sgid,vfs_media_harmony,vfs_offline,vfs_preopen,vfs_readahead,vfs_readonly,vfs_recycle,vfs_shadow_copy2,vfs_shadow_copy,vfs_shell_snap,vfs_snapper,vfs_streams_depot,vfs_streams_xattr,vfs_syncops,vfs_time_audit,vfs_unityed_media,vfs_virusfilter,vfs_widelinks,vfs_worm,vfs_xattr_tdb,winbindd,winbind_krb5_locator}.8
rm -rf /var/cache/samba /var/lib/{ctdb,samba} /var/lock/samba /var/log/samba /var/run/{ctdb,samba}
install -t /usr/share/licenses/smbclient -Dm644 COPYING VFS-License-clarification.txt
popd
rm -rf samba-4.21.5
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
tar -xf ../sources/ModemManager-1.24.0.tar.gz
pushd ModemManager-1.24.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dpolkit=permissive -Dvapi=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/modemmanager -Dm644 COPYING COPYING.LIB
popd
rm -rf ModemManager-1.24.0
# libndp.
tar -xf ../sources/libndp_1.9.orig.tar.gz
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
tar -xf ../sources/upower-v1.90.9.tar.bz2
pushd upower-v1.90.9
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/upower -Dm644 COPYING
systemctl enable upower
popd
rm -rf upower-v1.90.9
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
tar -xf ../sources/NetworkManager-1.52.0.tar.gz
pushd NetworkManager-1.52.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dnmtui=true -Dqt=false -Dselinux=false -Dsession_tracking=systemd -Dtests=no
ninja -C build
ninja -C build install
cat >> /etc/NetworkManager/NetworkManager.conf << "END"
# Put your custom configuration files in '/etc/NetworkManager/conf.d/'.
[main]
plugins=keyfile
END
install -t /usr/share/licenses/networkmanager -Dm644 COPYING{,.{GFD,LGP}L}
systemctl enable NetworkManager
popd
rm -rf NetworkManager-1.52.0
# libnma (initial build; will be rebuilt later for libnma-gtk4).
tar -xf ../sources/libnma-1.10.6.tar.gz
pushd libnma-1.10.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgcr=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnma -Dm644 COPYING{,.LGPL}
popd
rm -rf libnma-1.10.6
# libnotify.
tar -xf ../sources/libnotify-0.8.6.tar.gz
pushd libnotify-0.8.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dman=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnotify -Dm644 COPYING
popd
rm -rf libnotify-0.8.6
# startup-notification.
tar -xf ../sources/startup-notification-0.12.tar.gz
pushd startup-notification-0.12
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/startup-notification -Dm644 COPYING
popd
rm -rf startup-notification-0.12
# libwnck.
tar -xf ../sources/libwnck-43.2.tar.gz
pushd libwnck-43.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libwnck -Dm644 COPYING
popd
rm -rf libwnck-43.2
# network-manager-applet.
tar -xf ../sources/network-manager-applet-1.36.0.tar.bz2
pushd network-manager-applet-1.36.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dappindicator=no -Dselinux=false
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
echo 'u nm-openvpn - "NetworkManager OpenVPN" -' > /usr/lib/sysusers.d/nm-openvpn.conf
systemd-sysusers
install -t /usr/share/licenses/networkmanager-openvpn -Dm644 COPYING
popd
rm -rf NetworkManager-openvpn-1.12.0
# UDisks.
tar -xf ../sources/udisks-2.10.1.tar.bz2
pushd udisks-2.10.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --enable-available-modules
make
make install
install -t /usr/share/licenses/udisks -Dm644 COPYING
popd
rm -rf udisks-2.10.1
# gsettings-desktop-schemas.
tar -xf ../sources/gsettings-desktop-schemas-48.0.tar.gz
pushd gsettings-desktop-schemas-48.0
sed -i -r 's|"(/system)|"/org/gnome\1|g' schemas/*.in
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gsettings-desktop-schemas -Dm644 COPYING
popd
rm -rf gsettings-desktop-schemas-48.0
# libproxy.
tar -xf ../sources/libproxy-0.5.9.tar.gz
pushd libproxy-0.5.9
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Drelease=true -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libproxy -Dm644 COPYING
popd
rm -rf libproxy-0.5.9
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
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false -Dvapi=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libsoup -Dm644 COPYING
popd
rm -rf libsoup-2.74.3
# libsoup3.
tar -xf ../sources/libsoup-3.6.5.tar.gz
pushd libsoup-3.6.5
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
tar -xf ../sources/libostree-2025.2.tar.xz
pushd libostree-2025.2
patch -Np1 -i ../../patches/ostree-2025.2-upstreamfix.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --enable-experimental-api --enable-gtk-doc --with-curl --with-dracut --with-ed25519-libsodium --with-modern-grub --with-grub2-mkconfig-path=/usr/bin/grub-mkconfig --with-openssl --without-soup
make
make install
rm -f /etc/dracut.conf.d/ostree.conf
install -t /usr/share/licenses/libostree -Dm644 COPYING
popd
rm -rf libostree-2025.2
# libxmlb.
tar -xf ../sources/libxmlb-0.3.22.tar.xz
pushd libxmlb-0.3.22
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dstemmer=true -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libxmlb -Dm644 LICENSE
popd
rm -rf libxmlb-0.3.22
# AppStream.
tar -xf ../sources/AppStream-1.0.4.tar.xz
pushd AppStream-1.0.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dvapi=true -Dcompose=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/appstream -Dm644 COPYING
popd
rm -rf AppStream-1.0.4
# appstream-glib.
tar -xf ../sources/appstream_glib_0_8_3.tar.gz
pushd appstream-glib-appstream_glib_0_8_3
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Drpm=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/appstream-glib -Dm644 COPYING
popd
rm -rf appstream-glib-appstream_glib_0_8_3
# Bubblewrap.
tar -xf ../sources/bubblewrap-0.11.0.tar.xz
pushd bubblewrap-0.11.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/bubblewrap -Dm644 COPYING
popd
rm -rf bubblewrap-0.11.0
# xdg-dbus-proxy.
tar -xf ../sources/xdg-dbus-proxy-0.1.6.tar.xz
pushd xdg-dbus-proxy-0.1.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xdg-dbus-proxy -Dm644 COPYING
popd
rm -rf xdg-dbus-proxy-0.1.6
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
tar -xf ../sources/flatpak-1.16.0.tar.xz
pushd flatpak-1.16.0
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
sed -i 's|"Flatpak system helper" -|"Flatpak system helper" /var/lib/flatpak|' /usr/lib/sysusers.d/flatpak.conf
systemd-sysusers
flatpak remote-add --if-not-exists flathub ./flathub.flatpakrepo
install -t /usr/share/licenses/flatpak -Dm644 COPYING
popd
rm -rf flatpak-1.16.0
# libportal / libportal-gtk3.
tar -xf ../sources/libportal-0.9.1.tar.xz
pushd libportal-0.9.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbackend-gtk3=enabled -Dbackend-gtk4=disabled -Dbackend-qt5=disabled -Dbackend-qt6=disabled -Ddocs=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libportal -Dm644 COPYING
install -t /usr/share/licenses/libportal-gtk3 -Dm644 COPYING
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
tar -xf ../sources/geoclue-2.7.2.tar.bz2
pushd geoclue-2.7.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/geoclue -Dm644 COPYING{,.LIB}
popd
rm -rf geoclue-2.7.2
# passim.
tar -xf ../sources/passim-0.1.9.tar.xz
pushd passim-0.1.9
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
systemd-sysusers
install -t /usr/share/licenses/passim -Dm644 LICENSE
popd
rm -rf passim-0.1.9
# fwupd-efi.
tar -xf ../sources/fwupd-efi-1.7.tar.gz
pushd fwupd-efi-1.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Defi_sbat_distro_id="massos" -Defi_sbat_distro_summary="MassOS" -Defi_sbat_distro_pkgname="fwupd-efi" -Defi_sbat_distro_version="1.5" -Defi_sbat_distro_url="https://massos.org"
ninja -C build
ninja -C build install
install -t /usr/share/licenses/fwupd-efi -Dm644 COPYING
popd
rm -rf fwupd-efi-1.7
# fwupd.
tar -xf ../sources/fwupd-2.0.7.tar.xz
pushd fwupd-2.0.7
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Defi_binary=false -Dsupported_build=enabled -Dsystemd_unit_user=fwupd -Dtests=false
ninja -C build
ninja -C build install
systemd-sysusers
install -t /usr/share/licenses/fwupd -Dm644 COPYING
popd
rm -rf fwupd-2.0.7
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
tar -xf ../sources/libass-0.17.3.tar.xz
pushd libass-0.17.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libass -Dm644 COPYING
popd
rm -rf libass-0.17.3
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
tar -xf ../sources/libde265-1.0.15.tar.gz
pushd libde265-1.0.15
./configure --prefix=/usr --disable-static --disable-sherlock265
make
make install
rm -f /usr/bin/tests
install -t /usr/share/licenses/libde265 -Dm644 COPYING
popd
rm -rf libde265-1.0.15
# cdparanoia.
tar -xf ../sources/cdparanoia-III-10.2.src.tgz
pushd cdparanoia-III-10.2
patch -Np1 -i ../../patches/cdparanoia-III-10.2-buildfix.patch
./configure --prefix=/usr --mandir=/usr/share/man
make -j1
make -j1 install
chmod 755 /usr/lib/libcdda_*.so.0.10.2
install -t /usr/share/licenses/cdparanoia -Dm644 COPYING-GPL COPYING-LGPL
popd
rm -rf cdparanoia-III-10.2
# mpg123.
tar -xf ../sources/mpg123-1.32.10.tar.bz2
pushd mpg123-1.32.10
./configure --prefix=/usr --enable-int-quality=yes --with-audio="alsa jack oss pulse sdl"
make
make install
install -t /usr/share/licenses/mpg123 -Dm644 COPYING
popd
rm -rf mpg123-1.32.10
# libvpx.
tar -xf ../sources/libvpx-1.15.1.tar.gz
pushd libvpx-1.15.1
sed -i 's/cp -p/cp/' build/make/Makefile
./configure --prefix=/usr --enable-shared --disable-static --disable-examples --disable-unit-tests
make
make install
install -t /usr/share/licenses/libvpx -Dm644 LICENSE
popd
rm -rf libvpx-1.15.1
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
tar -xf ../sources/taglib-2.0.2.tar.gz
pushd taglib-2.0.2
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/taglib -Dm644 COPYING.{LGPL,MPL}
popd
rm -rf taglib-2.0.2
# SoundTouch.
tar -xf ../sources/soundtouch-2.4.0.tar.gz
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
./configure --prefix=/usr --disable-static
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
tar -xf ../sources/x264-0.164.3215.tar.bz2
pushd x264-32c3b80-32c3b801191522961102d4bea292cdb61068d0dd
cat > version.sh << "END"
#!/usr/bin/env bash
# Hardcode the version because the git tarball lacks the required data.
cat > /dev/stdout << "EOS"
#define X264_REV 3215
#define X264_REV_DIFF 0
#define X264_VERSION " r3215 32c3b80"
#define X264_POINTVER "0.164.3215 32c3b80"
EOS
END
./configure --prefix=/usr --enable-shared --enable-strip --extra-cflags="-DX264_BIT_DEPTH=0 -DX264_CHROMA_FORMAT=0 -DX264_GPL=1 -DX264_INTERLACED=1"
make
make install
install -t /usr/share/licenses/x264 -Dm644 COPYING
popd
rm -rf x264-32c3b80-32c3b801191522961102d4bea292cdb61068d0dd
# x265.
tar -xf ../sources/x265_4.1.tar.gz
pushd x265_4.1
patch -Np1 -i ../../patches/x265-4.1-cmake400.patch
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DGIT_ARCHETYPE=1 -Wno-dev -G Ninja -B build -S source
ninja -C build
ninja -C build install
rm -f /usr/lib/libx265.a
install -t /usr/share/licenses/x265 -Dm644 COPYING
popd
rm -rf x265_4.1
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
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libavc1394 -Dm644 COPYING
popd
rm -rf libavc1394-0.5.4
# libiec61883.
tar -xf ../sources/libiec61883-1.2.0.tar.xz
pushd libiec61883-1.2.0
./configure --prefix=/usr --disable-static
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
./configure --prefix=/usr --disable-static
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
pushd xvidcore/build/generic
./configure --prefix=/usr
make
make install
chmod 755 /usr/lib/libxvidcore.so.4.3
rm -f /usr/lib/libxvidcore.a
install -t /usr/share/licenses/xvidcore -Dm644 ../../LICENSE
popd
rm -rf xvidcore
# libaom.
tar -xf ../sources/libaom-3.12.1.tar.gz
pushd libaom-3.12.1
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
rm -f /usr/lib/libaom.a
install -t /usr/share/licenses/libaom -Dm644 LICENSE PATENTS
popd
rm -rf libaom-3.12.1
# SVT-AV1.
tar -xf ../sources/SVT-AV1-v3.0.2.tar.bz2
pushd SVT-AV1-v3.0.2
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DNATIVE=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/svt-av1 -Dm644 {LICENSE{,-BSD2},PATENTS}.md
popd
rm -rf SVT-AV1-v3.0.2
# dav1d.
tar -xf ../sources/dav1d-1.5.1.tar.bz2
pushd dav1d-1.5.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Denable_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/dav1d -Dm644 COPYING
popd
rm -rf dav1d-1.5.1
# rav1e.
tar -xf ../sources/rav1e-0.7.1.tar.gz
pushd rav1e-0.7.1
cargo build --release
cargo cbuild --release
sed -i 's|/usr/local|/usr|' target/x86_64-unknown-linux-gnu/release/rav1e.pc
install -t /usr/bin -Dm755 target/release/rav1e
install -t /usr/include/rav1e -Dm644 target/x86_64-unknown-linux-gnu/release/include/rav1e/rav1e.h
install -t /usr/lib/pkgconfig -Dm644 target/x86_64-unknown-linux-gnu/release/rav1e.pc
install -Dm755 target/x86_64-unknown-linux-gnu/release/librav1e.so /usr/lib/librav1e.so.0.7.1
ln -sf librav1e.so.0.7.1 /usr/lib/librav1e.so.0
ln -sf librav1e.so.0.7.1 /usr/lib/librav1e.so
ldconfig
install -t /usr/share/licenses/rav1e -Dm644 LICENSE PATENTS
popd
rm -rf rav1e-0.7.1
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
./configure --prefix=/usr --enable-shared --disable-static
find . -name Makefile -exec sed -i 's|-Wl,-rpath,/usr/lib||' {} ';'
make
make install
install -t /usr/share/licenses/libmpeg2 -Dm644 COPYING
popd
rm -rf libmpeg2-upstream-0.5.1
# libheif.
tar -xf ../sources/libheif-1.19.7.tar.gz
pushd libheif-1.19.7
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -DWITH_AOM_DECODER=ON -DWITH_AOM_ENCODER=ON -DWITH_DAV1D=ON -DWITH_JPEG_DECODER=ON -DWITH_JPEG_ENCODER=ON -DWITH_LIBDE265=ON -DWITH_OpenJPEG_DECODER=ON -DWITH_OpenJPEG_ENCODER=ON -DWITH_RAV1E=ON -DWITH_SvtEnc=ON -DWITH_X265=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libheif -Dm644 COPYING
popd
rm -rf libheif-1.19.7
# libavif.
tar -xf ../sources/libavif-1.2.1.tar.gz
pushd libavif-1.2.1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DAVIF_BUILD_APPS=ON -DAVIF_BUILD_GDK_PIXBUF=ON -DAVIF_CODEC_AOM=SYSTEM -DAVIF_CODEC_SVT=SYSTEM -DAVIF_CODEC_DAV1D=SYSTEM -DAVIF_CODEC_RAV1E=SYSTEM -DAVIF_LIBYUV=LOCAL -DAVIF_ENABLE_WERROR=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libavif -Dm644 LICENSE
popd
rm -rf libavif-1.2.1
# highway.
tar -xf ../sources/highway-1.2.0.tar.gz
pushd highway-1.2.0
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -t /usr/share/licenses/highway -Dm644 LICENSE{,-BSD3}
popd
rm -rf highway-1.2.0
# libjxl.
tar -xf ../sources/libjxl-0.11.1.tar.gz
pushd libjxl-0.11.1
tar -xf ../../sources/sjpeg-e5ab130.tar.gz -C third_party/sjpeg --strip-components=1
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_PLUGINS=ON -DJPEGXL_ENABLE_PLUGIN_GIMP210=OFF -DJPEGXL_ENABLE_SKCMS=OFF -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
gdk-pixbuf-query-loaders --update-cache
install -t /usr/share/licenses/libjxl -Dm644 LICENSE PATENTS
popd
rm -rf libjxl-0.11.1
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
tar -xf ../sources/harfbuzz-11.1.0.tar.xz
pushd harfbuzz-11.1.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled
ninja -C build
ninja -C build install
popd
rm -rf harfbuzz-11.1.0
# FAAC.
tar -xf ../sources/faac-1.31.1.tar.gz
pushd faac-faac-1.31.1
autoreconf -fi
./configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/faac -Dm644 COPYING README
popd
rm -rf faac-faac-1.31.1
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
tar --no-same-owner -xf ../sources/AMF-headers-v1.4.36.0.tar.gz -C /usr/include --strip-components=1
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
tar -xf ../sources/ffmpeg-7.1.1.tar.xz
pushd ffmpeg-7.1.1
patch -Np1 -i ../../patches/ffmpeg-7.1-chromium.patch
sed -i '/svt_av1_enc_init_handle/s/svt_enc, //' libavcodec/libsvtav1.c
./configure --prefix=/usr --disable-debug --disable-htmlpages --disable-nonfree --disable-podpages --disable-rpath --disable-static --disable-txtpages --enable-alsa --enable-amf --enable-bzlib --enable-cuvid --enable-ffnvcodec --enable-gmp --enable-gpl --enable-iconv --enable-libaom --enable-libass --enable-libbluray --enable-libbs2b --enable-libcdio --enable-libdav1d --enable-libdrm --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libiec61883 --enable-libjack --enable-libjxl --enable-libkvazaar --enable-liblc3 --enable-libmodplug --enable-libmp3lame --enable-libopenh264 --enable-libopenjpeg --enable-libopus --enable-libpulse --enable-libqrencode --enable-librav1e --enable-librsvg --enable-librtmp --enable-libshaderc --enable-libspeex --enable-libsvtav1 --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxcb --enable-libxcb-shape --enable-libxcb-shm --enable-libxcb-xfixes --enable-libxml2 --enable-libxvid --enable-manpages --enable-nvdec --enable-nvenc --enable-openal --enable-opengl --enable-openssl --enable-optimizations --enable-sdl2 --enable-shared --enable-small --enable-stripping --enable-vaapi --enable-vdpau --enable-version3 --enable-vulkan --enable-xlib --enable-zlib
make
gcc $CFLAGS tools/qt-faststart.c -o tools/qt-faststart $LDFLAGS
make install
install -t /usr/bin -Dm755 tools/qt-faststart
install -t /usr/share/licenses/ffmpeg -Dm644 COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md
popd
rm -rf ffmpeg-7.1.1
# OpenAL (rebuild - circular dependency with FFmpeg).
tar -xf ../sources/openal-soft-1.24.3.tar.gz
pushd openal-soft-1.24.3
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
popd
rm -rf openal-soft-1.24.3
# GStreamer / gst-plugins-{base,good,bad,ugly} / gst-libav / gstreamer-vaapi / gst-editing-services / gst-python
tar -xf ../sources/gstreamer-1.26.0.tar.bz2
pushd gstreamer-1.26.0
mkdir -p subprojects/gl-headers
tar -xf ../../sources/gl-headers-5c8c7c0.tar.bz2 -C subprojects/gl-headers --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddevtools=disabled -Dexamples=disabled -Dglib_assert=false -Dglib_checks=false -Dglib_debug=disabled -Dgpl=enabled -Dgst-examples=disabled -Dlibnice=disabled -Dorc-source=system -Dpackage-name="MassOS GStreamer 1.26.0" -Dpackage-origin="https://massos.org" -Drtsp_server=disabled -Dtests=disabled -Dvaapi=enabled -Dgst-plugins-bad:aja=disabled -Dgst-plugins-bad:avtp=disabled -Dgst-plugins-bad:fdkaac=disabled -Dgst-plugins-bad:gpl=enabled -Dgst-plugins-bad:iqa=disabled -Dgst-plugins-bad:srtp=disabled -Dgst-plugins-bad:tinyalsa=disabled -Dgst-plugins-bad:webrtcdsp=disabled -Dgst-plugins-ugly:gpl=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gstreamer -Dm644 LICENSE
install -t /usr/share/licenses/gst-plugins-base -Dm644 subprojects/gst-plugins-base/COPYING
install -t /usr/share/licenses/gst-plugins-good -Dm644 subprojects/gst-plugins-good/COPYING
install -t /usr/share/licenses/gst-plugins-bad -Dm644 subprojects/gst-plugins-bad/COPYING
install -t /usr/share/licenses/gst-plugins-ugly -Dm644 subprojects/gst-plugins-ugly/COPYING
install -t /usr/share/licenses/gst-libav -Dm644 subprojects/gst-libav/COPYING
install -t /usr/share/licenses/gstreamer-vaapi -Dm644 subprojects/gstreamer-vaapi/COPYING.LIB
install -t /usr/share/licenses/gst-editing-services -Dm644 subprojects/gst-editing-services/COPYING{,.LIB}
install -t /usr/share/licenses/gst-python -Dm644 subprojects/gst-python/COPYING
popd
rm -rf gstreamer-1.26.0
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
tar -xf ../sources/pipewire-1.4.2.tar.bz2
pushd pipewire-1.4.2
mkdir -p subprojects/wireplumber
tar -xf ../../sources/wireplumber-0.5.8.tar.bz2 -C subprojects/wireplumber --strip-components=1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbluez5-backend-native-mm=enabled -Dexamples=disabled -Dffmpeg=enabled -Dpw-cat-ffmpeg=enabled -Dtests=disabled -Dvulkan=enabled -Dsession-managers=wireplumber -Dwireplumber:system-lua=true -Dwireplumber:tests=false
ninja -C build
ninja -C build install
systemctl --global enable pipewire.socket pipewire-pulse.socket
systemctl --global enable wireplumber
echo "autospawn = no" >> /etc/pulse/client.conf
install -t /usr/share/licenses/pipewire -Dm644 COPYING
install -t /usr/share/licenses/wireplumber -Dm644 subprojects/wireplumber/LICENSE
popd
rm -rf pipewire-1.4.2
# GTK4.
tar -xf ../sources/gtk-4.18.4.tar.gz
pushd gtk-4.18.4
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbroadway-backend=true -Dbuild-demos=false -Dbuild-examples=false -Dbuild-tests=false -Dbuild-testsuite=false -Dcloudproviders=enabled -Dcolord=enabled -Dintrospection=enabled -Dman-pages=true -Dsysprof=enabled -Dtracker=enabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtk4 -Dm644 COPYING
popd
rm -rf gtk-4.18.4
# libadwaita.
tar -xf ../sources/libadwaita-1.7.2.tar.gz
pushd libadwaita-1.7.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dexamples=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libadwaita -Dm644 COPYING
popd
rm -rf libadwaita-1.7.2
# gst-plugin-gtk4.
tar -xf ../sources/gst-plugins-rs-0.13.5.tar.bz2
pushd gst-plugins-rs-0.13.5/video/gtk4
cargo build --release
install -t /usr/lib/gstreamer-1.0 -Dm755 ../../target/release/libgstgtk4.so
install -t /usr/share/licenses/gst-plugin-gtk4 -Dm644 LICENSE-MPL-2.0
popd
rm -rf gst-plugins-rs-0.13.5
# Gcr4.
tar -xf ../sources/gcr-4.4.0.1.tar.gz
pushd gcr-4.4.0.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gcr4 -Dm644 COPYING
popd
rm -rf gcr-4.4.0.1
# colord-gtk.
tar -xf ../sources/colord-gtk-0.3.1.tar.gz
pushd colord-gtk-0.3.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Ddocs=false -Dgtk3=true -Dgtk4=true -Dintrospection=true -Dman=false -Dtests=false -Dvapi=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/colord-gtk -Dm644 COPYING
popd
rm -rf colord-gtk-0.3.1
# libnma (rebuild for libnma-gtk4).
tar -xf ../sources/libnma-1.10.6.tar.gz
pushd libnma-1.10.6
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dgcr=true -Dlibnma_gtk4=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libnma-gtk4 -Dm644 COPYING{,.LGPL}
popd
rm -rf libnma-1.10.6
# libportal-gtk4.
tar -xf ../sources/libportal-0.9.1.tar.xz
pushd libportal-0.9.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbackend-gtk3=disabled -Dbackend-gtk4=enabled -Dbackend-qt5=disabled -Dbackend-qt6=disabled -Ddocs=false -Dtests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libportal-gtk4 -Dm644 COPYING
popd
rm -rf libportal-0.9.1
# xdg-desktop-portal.
tar -xf ../sources/xdg-desktop-portal-1.20.0.tar.xz
pushd xdg-desktop-portal-1.20.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dtests=disabled
ninja -C build
ninja -C build install
install -t /usr/share/licenses/xdg-desktop-portal -Dm644 COPYING
popd
rm -rf xdg-desktop-portal-1.20.0
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
Exec=/bin/bash -c "dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY; systemctl start --user xdg-desktop-portal-gtk.service"
END
install -t /usr/share/licenses/xdg-desktop-portal-gtk -Dm644 COPYING
popd
rm -rf xdg-desktop-portal-gtk-1.15.3
# WebKitGTK.
tar -xf ../sources/webkitgtk-2.48.1.tar.xz
pushd webkitgtk-2.48.1
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_RPATH=ON -DPORT=GTK -DLIB_INSTALL_DIR=/usr/lib -DENABLE_BUBBLEWRAP_SANDBOX=ON -DENABLE_GAMEPAD=ON -DENABLE_MINIBROWSER=ON -DENABLE_SPEECH_SYNTHESIS=OFF -DUSE_AVIF=ON -DUSE_GTK4=OFF -DUSE_LIBBACKTRACE=OFF -DUSE_LIBHYPHEN=OFF -DUSE_WOFF2=ON -Wno-dev -G Ninja -B build
ninja -C build
ninja -C build install
install -dm755 /usr/share/licenses/webkitgtk
while IFS= read -r file; do echo "### $file ###"; cat "$file"; done <<< "$(find Source -name 'COPYING*' -o -name 'LICENSE*')" > /usr/share/licenses/webkitgtk/LICENSE
popd
rm -rf webkitgtk-2.48.1
# Cogl.
tar -xf ../sources/cogl-1.22.8.tar.xz
pushd cogl-1.22.8
CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration" ./configure --prefix=/usr --enable-gles1 --enable-gles2 --enable-kms-egl-platform --enable-wayland-egl-platform --enable-xlib-egl-platform --enable-wayland-egl-server --enable-cogl-gst
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
tar -xf ../sources/gspell-1.14.0.tar.gz
pushd gspell-1.14.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gspell -Dm644 LICENSES/LGPL-2.1-or-later.txt
popd
rm -rf gspell-1.14.0
# gnome-online-accounts.
tar -xf ../sources/gnome-online-accounts-3.54.2.tar.gz
pushd gnome-online-accounts-3.54.2
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dfedora=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gnome-online-accounts -Dm644 COPYING
popd
rm -rf gnome-online-accounts-3.54.2
# libgdata.
tar -xf ../sources/libgdata-0.18.1.tar.gz
pushd libgdata-0.18.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dalways_build_tests=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/libgdata -Dm644 COPYING
popd
rm -rf libgdata-0.18.1
# VTE / VTE4.
tar -xf ../sources/vte-0.80.1.tar.gz
pushd vte-0.80.1
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize
ninja -C build
ninja -C build install
rm -f /etc/profile.d/vte.*
rm -f /usr/share/applications/org.gnome.Vte.App.Gtk{3,4}.desktop
install -t /usr/share/licenses/vte -Dm644 COPYING.{CC-BY-4-0,GPL3,LGPL3,XTERM}
install -t /usr/share/licenses/vte4 -Dm644 COPYING.{CC-BY-4-0,GPL3,LGPL3,XTERM}
popd
rm -rf vte-0.80.1
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
tar -xf ../sources/gtksourceview-5.16.0.tar.gz
pushd gtksourceview-5.16.0
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dbuild-testsuite=false
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gtksourceview5 -Dm644 COPYING
popd
rm -rf gtksourceview-5.16.0
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
tar -xf ../sources/gvfs-1.57.2.tar.gz
pushd gvfs-1.57.2
LDFLAGS="$LDFLAGS -lgnutls" meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dburn=true -Dman=true
ninja -C build
ninja -C build install
install -t /usr/share/licenses/gvfs -Dm644 COPYING
popd
rm -rf gvfs-1.57.2
# Plymouth.
tar -xf ../sources/plymouth-24.004.60.tar.bz2
pushd plymouth-24.004.60
meson setup build --prefix=/usr --sbindir=bin --buildtype=minsize -Dlogo=/usr/share/massos/massos-logo-sidetext.png -Drelease-file=/etc/os-release
ninja -C build
ninja -C build install
sed -i 's/dracut -f/mkinitramfs/' /usr/libexec/plymouth/plymouth-update-initrd
sed -i 's/WatermarkVerticalAlignment=.96/WatermarkVerticalAlignment=.5/' /usr/share/plymouth/themes/spinner/spinner.plymouth
cp /usr/share/massos/massos-logo-sidetext.png /usr/share/plymouth/themes/spinner/watermark.png
plymouth-set-default-theme bgrt
install -t /usr/share/licenses/plymouth -Dm644 COPYING
popd
rm -rf plymouth-24.004.60
# Busybox.
tar -xf ../sources/busybox-1.37.0.tar.bz2
pushd busybox-1.37.0
patch -Np1 -i ../../patches/busybox-1.37.0-linuxheaders68.patch
cp ../../extras/build-configs/busybox-config .config
make
install -t /usr/bin -Dm755 busybox
install -t /usr/share/licenses/busybox -Dm644 LICENSE
popd
rm -rf busybox-1.37.0
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
tar -xf ../sources/qemu-10.0.0.tar.xz
pushd qemu-10.0.0
patch -Np1 -i ../../patches/qemu-9.2.3-libnfs6fix.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-docs --target-list=x86_64-linux-user,x86_64-softmmu
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
rm -rf qemu-10.0.0
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
tar -xf ../sources/open-vm-tools-stable-12.5.0.tar.gz
pushd open-vm-tools-stable-12.5.0/open-vm-tools
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin --disable-static --with-udev-rules-dir=/usr/lib/udev/rules.d --disable-docs --disable-tests --without-kernel-modules --disable-containerinfo
make
make install
chmod 7755 /usr/bin/vmware-user-suid-wrapper
install -t /usr/bin -Dm755 scripts/common/vmware-xdg-detect-de
cp /etc/pam.d/{polkit-1,vmtoolsd}
systemctl enable vmtoolsd
systemctl enable vmware-vmblock-fuse
install -t /usr/share/licenses/open-vm-tools -Dm644 COPYING LICENSE
popd
rm -rf open-vm-tools-stable-12.5.0
# Linux / Linux-Headers.
tar -xf ../sources/linux-6.14.4.tar.xz
pushd linux-6.14.4
make mrproper
cp ../../extras/build-configs/kernel-config .config
make olddefconfig
make
make -s kernelrelease > version
make INSTALL_MOD_STRIP=1 modules_install
install -Dm644 version /usr/share/massos/.krel
cp arch/x86/boot/bzImage /boot/vmlinuz-"$(cat version)"
cp arch/x86/boot/bzImage /usr/lib/modules/"$(cat version)"/vmlinuz
cp System.map /boot/System.map-"$(cat version)"
cp .config /boot/config-"$(cat version)"
rm -f /usr/lib/modules/"$(cat version)"/{build,source}
install -t /usr/lib/modules/"$(cat version)"/build -Dm644 .config Makefile Module.symvers System.map version vmlinux
install -t /usr/lib/modules/"$(cat version)"/build/kernel -Dm644 kernel/Makefile
install -t /usr/lib/modules/"$(cat version)"/build/arch/x86 -Dm644 arch/x86/Makefile
cp -t /usr/lib/modules/"$(cat version)"/build -a scripts
install -t /usr/lib/modules/"$(cat version)"/build/tools/objtool -Dm755 tools/objtool/objtool
mkdir -p /usr/lib/modules/"$(cat version)"/build/{fs/xfs,mm}
cp -t /usr/lib/modules/"$(cat version)"/build -a include
cp -t /usr/lib/modules/"$(cat version)"/build/arch/x86 -a arch/x86/include
install -t /usr/lib/modules/"$(cat version)"/build/arch/x86/kernel -Dm644 arch/x86/kernel/asm-offsets.s
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
install -t /usr/share/licenses/linux -Dm644 COPYING LICENSES/exceptions/* LICENSES/preferred/*
install -t /usr/share/licenses/linux-headers -Dm644 COPYING LICENSES/exceptions/* LICENSES/preferred/*
popd
rm -rf linux-6.14.4
# nvidia-modules-open (provides nvidia-modules).
tar -xf ../sources/open-gpu-kernel-modules-575.51.02.tar.gz
pushd open-gpu-kernel-modules-575.51.02
patch -Np1 -i ../../patches/nvidia-modules-open-570.86.16.patch
make modules SYSSRC=/usr/src/linux
install -t /usr/lib/modules/"$(cat /usr/share/massos/.krel)"/extramodules -Dm644 kernel-open/*.ko
strip --strip-debug /usr/lib/modules/"$(cat /usr/share/massos/.krel)"/extramodules/*.ko
for i in /usr/lib/modules/"$(cat /usr/share/massos/.krel)"/extramodules/*.ko; do xz --threads=$(nproc) "$i"; done
echo "options nvidia NVreg_OpenRmEnableUnsupportedGpus=1" > /usr/lib/modprobe.d/nvidia.conf
depmod "$(cat /usr/share/massos/.krel)"
install -t /usr/share/licenses/nvidia-modules-open -Dm644 COPYING
ln -sf nvidia-modules-open /usr/share/licenses/nvidia-modules
popd
rm -rf open-gpu-kernel-modules-575.51.02
# MassOS release detection utility.
gcc $CFLAGS ../sources/massos-release.c -o massos-release
install -t /usr/bin -Dm755 massos-release
# Determine the version of osinstallgui that should be used by the Live CD.
echo "0.7.2" > /usr/share/massos/.osinstallguiver
# Determine firmware versions that should be installed.
cat > /usr/share/massos/firmwareversions << "END"
# DO NOT EDIT THIS FILE!

# This file defines the firmware versions corresponding to this MassOS build.
# Firmware is not included in the rootfs image; only in the Live CD ISO.
# The ISO creator will use this file to know what firmware versions to install.

# Eventually, a utility called 'massos-firmware' will be created, to allow
# installing/uninstalling firmware on the fly. If you are reading this, chances
# are it already exists. In any case, it will also reference this file.

linux-firmware: 20250311
intel-microcode: 20250211
sof-firmware: 2025.01.1
END
# snapd version, for when the snapd installation program is finally written.
cat > /usr/share/massos/snapdversion << "END"
# DO NOT EDIT THIS FILE!

# This file defines the version of snapd corresponding to this MassOS build.
# snapd is not installed by default due to its controversy.
# But we still want to offer it, as it provides some packages not in Flatpak.

# Eventually, a utility called 'massos-snapd' will be created, to allow
# installing snapd and uninstalling it. It will need to reference to this file
# to know which version of snapd to install.

# The snapd version, see <https://github.com/canonical/snapd/releases>.
version: 2.68.3

# Whether or not snapd is installed ('massos-snapd' sets this automatically).
installed: no
END
# Clean up the entire mbs directory and self-destruct.
popd
rm -rf /root/mbs
