#!/bin/bash
#
# Builds the core MassOS system (Stage 2) in a chroot environment.
# Copyright (C) 2021-2022 MassOS Developers.
#
# This script is part of the MassOS build system. It is licensed under GPLv3+.
# See the 'LICENSE' file for the full license text. On a MassOS system, this
# document can also be found at '/usr/share/massos/LICENSE'.
#
# === IF RESUMING A FAILED BUILD, DO NOT REMOVE ANY LINES BEFORE LINE 38 ===
#
# Exit if something goes wrong.
set -e
# Disabling hashing is useful so the newly built tools are detected.
set +h
# Ensure we're running in the MassOS chroot.
if [ $EUID -ne 0 ] || [ ! -d /sources ]; then
  echo "This script should not be run manually." >&2
  echo "stage2.sh will automatically run it in a chroot environment." >&2
  exit 1
fi
# Set the source directory correctly.
export SRC=/sources
cd $SRC
# Set the PATH correctly.
export PATH=/usr/bin:/usr/sbin:/sources/sphinx/bin:/sources/cargoc
# Set the locale correctly.
export LC_ALL="en_US.UTF-8" 2>/dev/null
# Build in parallel using all available CPU cores.
export MAKEFLAGS="-j$(nproc)"
# Allow building some packages as root.
export FORCE_UNSAFE_CONFIGURE=1
# SHELL may not be set in chroot by default.
export SHELL=/bin/bash
# Compiler flags for MassOS. We prefer to optimise for size.
CFLAGS="-Os -pipe"
CXXFLAGS="-Os -pipe"
export CFLAGS CXXFLAGS
# === REMOVE LINES BELOW THIS FOR RESUMING A FAILED BUILD ===
# Mark the build as started, for Stage 2 resume.
touch .BUILD_HAS_STARTED
# Setup the full filesystem structure.
mkdir -p /{boot,home,mnt,opt,srv}
mkdir -p /boot/efi
mkdir -p /etc/{opt,sysconfig}
mkdir -p /usr/lib/firmware
mkdir -p /usr/{,local/}{include,src}
mkdir -p /usr/local/{bin,lib,libexec,sbin}
mkdir -p /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -p /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -p /var/{cache,local,log,mail,opt,spool}
mkdir -p /var/lib/{color,misc,locate}
ln -sf lib /usr/local/lib64
ln -sf /run /var/run
ln -sf /run/lock /var/lock
ln -sf /run/media /media
install -dm0750 /root
cp -r /etc/skel/. /root
install -dm1777 /tmp /var/tmp
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp utmp /var/log/lastlog
chmod 664 /var/log/lastlog
chmod 600 /var/log/btmp
# Install man pages for MassOS system utilities.
cp -r man/* /usr/share/man
# Install MassOS Backgrounds.
install -t /usr/share/backgrounds/xfce -Dm644 backgrounds/*
# Set the locale correctly.
mkdir -p /usr/lib/locale
mklocales 2>/dev/null
# Gettext utilities (for circular dependencies; full Gettext is built later).
tar -xf gettext-0.21.tar.xz
cd gettext-0.21
./configure --disable-shared
make
install -t /usr/bin -Dm755 gettext-tools/src/{msgfmt,msgmerge,xgettext}
cd ..
rm -rf gettext-0.21
# Bison (circular deps; rebuilt later).
tar -xf bison-3.8.2.tar.xz
cd bison-3.8.2
./configure --prefix=/usr
make
make install
cd ..
rm -rf bison-3.8.2
# Perl (circular deps; rebuilt later).
tar -xf perl-5.36.0.tar.xz
cd perl-5.36.0
./Configure -des -Doptimize="$CFLAGS" -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.36/core_perl -Darchlib=/usr/lib/perl5/5.36/core_perl -Dsitelib=/usr/lib/perl5/5.36/site_perl -Dsitearch=/usr/lib/perl5/5.36/site_perl -Dvendorlib=/usr/lib/perl5/5.36/vendor_perl -Dvendorarch=/usr/lib/perl5/5.36/vendor_perl
make
make install
cd ..
rm -rf perl-5.36.0
# Python (circular deps; rebuilt later).
tar -xf Python-3.10.7.tar.xz
cd Python-3.10.7
./configure --prefix=/usr --enable-shared --without-ensurepip --disable-test-modules
make
make install
cd ..
rm -rf Python-3.10.7
# Texinfo (circular deps; rebuilt later).
tar -xf texinfo-6.8.tar.xz
cd texinfo-6.8
sed -e 's/__attribute_nonnull__/__nonnull/' -i gnulib/lib/malloc/dynarray-skeleton.c
./configure --prefix=/usr
make
make install
cd ..
rm -rf texinfo-6.8
# util-linux (circular deps; rebuilt later).
tar -xf util-linux-2.38.1.tar.xz
cd util-linux-2.38.1
mkdir -p /var/lib/hwclock
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --without-python runstatedir=/run
make
make install
cd ..
rm -rf util-linux-2.38.1
# man-pages.
tar -xf man-pages-5.13.tar.xz
cd man-pages-5.13
make prefix=/usr install
cd ..
rm -rf man-pages-5.13
# iana-etc.
tar -xf iana-etc-20220922.tar.gz
install -t /etc -Dm644 iana-etc-20220922/{protocols,services}
rm -rf iana-etc-20220922
# Neofetch (an enhanced fork since upstream seems to be unmaintained).
tar -xf hyfetch-1.4.0.tar.gz
cd hyfetch-1.4.0
install -t /usr/bin -Dm755 neofetch
install -t /usr/share/man/man1 -Dm644 neofetch.1
install -t /usr/share/licenses/neofetch -Dm644 LICENSE.md
cd ..
rm -rf hyfetch-1.4.0
# Glibc.
tar -xf glibc-2.36.tar.xz
cd glibc-2.36
patch -Np1 -i ../patches/glibc-2.36-multiplefixes.patch
mkdir build; cd build
echo "rootsbindir=/usr/sbin" > configparms
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --enable-kernel=3.2 --enable-stack-protector=strong --disable-default-pie --disable-werror --with-headers=/usr/include libc_cv_slibdir=/usr/lib
make
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
install -t /usr/share/licenses/glibc -Dm644 ../COPYING ../COPYING.LIB ../LICENSES
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
cp ../nscd/nscd.conf /etc/nscd.conf
mkdir -p /var/cache/nscd
install -Dm644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
install -Dm644 ../nscd/nscd.service /usr/lib/systemd/system/nscd.service
mklocales
cat > /etc/nsswitch.conf << END
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
END
tar -xf ../../tzdata2022d.tar.gz
ZONEINFO=/usr/share/zoneinfo
mkdir -p $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
  zic -L /dev/null   -d $ZONEINFO       ${tz}
  zic -L /dev/null   -d $ZONEINFO/posix ${tz}
  zic -L leapseconds -d $ZONEINFO/right ${tz}
done
cp zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
# Default timezone is UTC, can be changed by the user later.
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
cat > /etc/ld.so.conf << END
/usr/local/lib
include /etc/ld.so.conf.d/*.conf
END
cd ../..
rm -rf glibc-2.36
# zlib.
tar -xf zlib-1.2.12.tar.xz
cd zlib-1.2.12
patch -Np1 -i ../patches/zlib-1.2.12-upstreamfix.patch
./configure --prefix=/usr
make
make install
install -dm755 /usr/share/licenses/zlib
cat zlib.h | head -n28 | tail -n25 > /usr/share/licenses/zlib/LICENSE
rm -f /usr/lib/libz.a
cd ..
rm -rf zlib-1.2.12
# bzip2.
tar -xf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
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
cd ..
rm -rf bzip2-1.0.8
# XZ.
tar -xf xz-5.2.6.tar.xz
cd xz-5.2.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xz -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1
cd ..
rm -rf xz-5.2.6
# LZ4.
tar -xf lz4-1.9.4.tar.gz
cd lz4-1.9.4
make PREFIX=/usr CFLAGS="$CFLAGS" -C lib
make PREFIX=/usr CFLAGS="$CFLAGS" -C programs lz4 lz4c
make PREFIX=/usr install
rm -f /usr/lib/liblz4.a
install -t /usr/share/licenses/lz4 -Dm644 LICENSE
cd ..
rm -rf lz4-1.9.4
# ZSTD.
tar -xf zstd-1.5.2.tar.gz
cd zstd-1.5.2
make CFLAGS="$CFLAGS -fPIC"
make prefix=/usr install
rm -f /usr/lib/libzstd.a
sed -i 's|/usr/local|/usr|' /usr/lib/pkgconfig/libzstd.pc
install -t /usr/share/licenses/zstd -Dm644 COPYING LICENSE
cd ..
rm -rf zstd-1.5.2
# pigz.
tar -xf pigz_2.6.orig.tar.xz
cd pigz-2.6
sed -i 's/O3/Os/' Makefile
sed -i 's/LDFLAGS=/LDFLAGS=-s/' Makefile
make
install -m755 pigz /usr/bin/pigz
install -m755 unpigz /usr/bin/unpigz
install -m644 pigz.1 /usr/share/man/man1/pigz.1
install -dm755 /usr/share/licenses/pigz
cat README | tail -n18 > /usr/share/licenses/pigz/LICENSE
cd ..
rm -rf pigz-2.6
# lzip.
tar -xf lzip-1.22.tar.gz
cd lzip-1.22
./configure CXXFLAGS="$CXXFLAGS" --prefix=/usr
make
make install
install -t /usr/share/licenses/lzip -Dm644 COPYING
cd ..
rm -rf lzip-1.22
# Readline.
tar -xf readline-8.2.tar.gz
cd readline-8.2
./configure --prefix=/usr --disable-static --with-curses
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
install -t /usr/share/licenses/readline -Dm644 COPYING
cd ..
rm -rf readline-8.2
# m4.
tar -xf m4-1.4.19.tar.xz
cd m4-1.4.19
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/m4 -Dm644 COPYING
cd ..
rm -rf m4-1.4.19
# bc.
tar -xf bc-6.0.2.tar.xz
cd bc-6.0.2
CC=gcc ./configure.sh --prefix=/usr --disable-generated-tests
make
make install
install -t /usr/share/licenses/bc -Dm644 LICENSE.md
cd ..
rm -rf bc-6.0.2
# Flex.
tar -xf flex-2.6.4.tar.gz
cd flex-2.6.4
./configure --prefix=/usr --disable-static
make
make install
ln -sf flex /usr/bin/lex
ln -sf flex.1 /usr/share/man/man1/lex.1
ln -sf flex.info /usr/share/info/lex.info
install -t /usr/share/licenses/flex -Dm644 COPYING
cd ..
rm -rf flex-2.6.4
# Tcl.
tar -xf tcl8.6.12-src.tar.gz
cd tcl8.6.12
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr --mandir=/usr/share/man --enable-64bit
make
sed -e "s|$SRCDIR/unix|/usr/lib|" -e "s|$SRCDIR|/usr/include|" -i tclConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.3|/usr/lib/tdbc1.1.3|" -e "s|$SRCDIR/pkgs/tdbc1.1.3/generic|/usr/include|" -e "s|$SRCDIR/pkgs/tdbc1.1.3/library|/usr/lib/tcl8.6|" -e "s|$SRCDIR/pkgs/tdbc1.1.3|/usr/include|" -i pkgs/tdbc1.1.3/tdbcConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.2|/usr/lib/itcl4.2.2|" -e "s|$SRCDIR/pkgs/itcl4.2.2/generic|/usr/include|" -e "s|$SRCDIR/pkgs/itcl4.2.2|/usr/include|" -i pkgs/itcl4.2.2/itclConfig.sh
unset SRCDIR
make install
chmod u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sf tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
install -t /usr/share/licenses/tcl -Dm644 ../license.terms
cd ../..
rm -rf tcl8.6.12
# Binutils.
tar -xf binutils-2.39.tar.xz
cd binutils-2.39
mkdir build; cd build
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --sysconfdir=/etc --with-pkgversion="MassOS Binutils 2.39" --with-system-zlib --enable-gold --enable-install-libiberty --enable-ld=default --enable-plugins --enable-relro --enable-shared --disable-werror
make tooldir=/usr
make -j1 tooldir=/usr install
rm -f /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
install -t /usr/share/licenses/binutils -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB
cd ../..
rm -rf binutils-2.39
# GMP.
tar -xf gmp-6.2.1.tar.xz
cd gmp-6.2.1
cp configfsf.guess config.guess
cp configfsf.sub config.sub
./configure --prefix=/usr --enable-cxx --disable-static
make
make install
install -t /usr/share/licenses/gmp -Dm644 COPYING COPYINGv2 COPYINGv3 COPYING.LESSERv3
cd ..
rm -rf gmp-6.2.1
# MPFR.
tar -xf mpfr-4.1.0.tar.xz
cd mpfr-4.1.0
./configure --prefix=/usr --disable-static --enable-thread-safe
make
make install
install -t /usr/share/licenses/mpfr -Dm644 COPYING COPYING.LESSER
cd ..
rm -rf mpfr-4.1.0
# MPC.
tar -xf mpc-1.2.1.tar.gz
cd mpc-1.2.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/mpc -Dm644 COPYING.LESSER
cd ..
rm -rf mpc-1.2.1
# Attr.
tar -xf attr-2.5.1.tar.gz
cd attr-2.5.1
./configure --prefix=/usr --disable-static --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/attr -Dm644 doc/COPYING doc/COPYING.LGPL
cd ..
rm -rf attr-2.5.1
# Acl.
tar -xf acl-2.3.1.tar.xz
cd acl-2.3.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/acl -Dm644 doc/COPYING doc/COPYING.LGPL
cd ..
rm -rf acl-2.3.1
# Libcap.
tar -xf libcap-2.66.tar.xz
cd libcap-2.66
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib CFLAGS="$CFLAGS -fPIC"
make prefix=/usr lib=lib install
chmod 755 /usr/lib/lib{cap,psx}.so.2.66
install -t /usr/share/licenses/libcap -Dm644 License
cd ..
rm -rf libcap-2.66
# Cracklib.
tar -xf cracklib-2.9.8.tar.bz2
cd cracklib-2.9.8
sed -i '15212 s/.*/am_cv_python_version=3.10/' configure
./configure --prefix=/usr --disable-static --with-default-dict=/usr/lib/cracklib/pw_dict
make
make install
install -dm755 /usr/lib/cracklib
bzip2 -cd ../cracklib-words-2.9.8.bz2 > /usr/share/dict/cracklib-words
ln -sf cracklib-words /usr/share/dict/words
echo "massos" > /usr/share/dict/cracklib-extra-words
create-cracklib-dict /usr/share/dict/cracklib-words /usr/share/dict/cracklib-extra-words
install -t /usr/share/licenses/cracklib -Dm644 COPYING.LIB
cd ..
rm -rf cracklib-2.9.8
# Linux-PAM (initial build, will be rebuilt later to support Audit).
tar -xf Linux-PAM-1.5.2.tar.xz
cd Linux-PAM-1.5.2
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --enable-securedir=/usr/lib/security --disable-doc --disable-pie
make
make install
chmod 4755 /usr/sbin/unix_chkpwd
install -dm755 /etc/pam.d
cat > /etc/pam.d/system-account << END
account   required    pam_unix.so
END
cat > /etc/pam.d/system-session << END
session   required    pam_unix.so
END
cat > /etc/pam.d/other << END
auth        required        pam_warn.so
auth        required        pam_deny.so
account     required        pam_warn.so
account     required        pam_deny.so
password    required        pam_warn.so
password    required        pam_deny.so
session     required        pam_warn.so
session     required        pam_deny.so
END
install -t /usr/share/licenses/linux-pam -Dm644 COPYING Copyright
cd ..
rm -rf Linux-PAM-1.5.2
# libpwquality.
tar -xf libpwquality-1.4.4.tar.bz2
cd libpwquality-1.4.4
./configure --prefix=/usr --disable-static --with-securedir=/usr/lib/security --with-python-binary=python3
make
make install
cat > /etc/pam.d/system-password << END
password  required    pam_pwquality.so   authtok_type=UNIX retry=1 difok=1 \
                                         minlen=8 dcredit=0 ucredit=0 \
                                         lcredit=0 ocredit=0 minclass=1 \
                                         maxrepeat=0 maxsequence=0 \
                                         maxclassrepeat=0 geoscheck=0 \
                                         dictcheck=1 usercheck=1 \
                                         enforcing=1 badwords="" \
                                         dictpath=/usr/lib/cracklib/pw_dict
password  required    pam_unix.so        sha512 shadow use_authtok
END
install -t /usr/share/licenses/libpwquality -Dm644 COPYING
cd ..
rm -rf libpwquality-1.4.4
# PAM module for libcap.
tar -xf libcap-2.66.tar.xz
cd libcap-2.66
make CFLAGS="$CFLAGS -fPIC" -C pam_cap
install -m755 pam_cap/pam_cap.so /usr/lib/security
install -m644 pam_cap/capability.conf /etc/security
cat > /etc/pam.d/system-auth << END
auth      optional    pam_cap.so
auth      required    pam_unix.so
END
cd ..
rm -rf libcap-2.66
# Shadow (initial build; will be rebuilt later to support AUDIT).
tar -xf shadow-4.12.3.tar.xz
cd shadow-4.12.3
patch -Np1 -i ../patches/shadow-4.12.2-MassOS.patch
touch /usr/bin/passwd
./configure --sysconfdir=/etc --disable-static --with-group-name-max-length=32 --with-libcrack
make
make exec_prefix=/usr install
make -C man install-man
mkdir -p /etc/default
useradd -D --gid 999
sed -i 's/yes/no/' /etc/default/useradd
pwconv
grpconv
for FUNCTION in FAIL_DELAY FAILLOG_ENAB LASTLOG_ENAB MAIL_CHECK_ENAB OBSCURE_CHECKS_ENAB PORTTIME_CHECKS_ENAB QUOTAS_ENAB CONSOLE MOTD_FILE FTMP_FILE NOLOGINS_FILE ENV_HZ PASS_MIN_LEN SU_WHEEL_ONLY CRACKLIB_DICTPATH PASS_CHANGE_TRIES PASS_ALWAYS_WARN CHFN_AUTH ENCRYPT_METHOD ENVIRON_FILE; do sed -i "s/^${FUNCTION}/# &/" /etc/login.defs; done
cat > /etc/pam.d/login << END
auth      optional    pam_faildelay.so  delay=3000000
auth      requisite   pam_nologin.so
auth      include     system-auth
account   required    pam_access.so
account   include     system-account
session   required    pam_env.so
session   required    pam_limits.so
session   optional    pam_lastlog.so
session   include     system-session
password  include     system-password
END
cat > /etc/pam.d/passwd << END
password  include     system-password
END
cat > /etc/pam.d/su << END
auth      sufficient  pam_rootok.so
auth      include     system-auth
auth      required    pam_wheel.so use_uid
account   include     system-account
session   required    pam_env.so
session   include     system-session
END
cat > /etc/pam.d/chage << END
auth      sufficient  pam_rootok.so
auth      include     system-auth
account   include     system-account
session   include     system-session
password  required    pam_permit.so
END
for PROGRAM in chfn chgpasswd chpasswd chsh groupadd groupdel groupmems groupmod newusers useradd userdel usermod; do
  install -m644 /etc/pam.d/chage /etc/pam.d/${PROGRAM}
  sed -i "s/chage/$PROGRAM/" /etc/pam.d/${PROGRAM}
done
rm -f /etc/login.access /etc/limits
install -t /usr/share/licenses/shadow -Dm644 COPYING
cd ..
rm -rf shadow-4.12.3
# GCC.
tar -xf gcc-12.2.0.tar.xz
cd gcc-12.2.0
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir build; cd build
CFLAGS="-O2" CXXFLAGS="-O2" LD=ld ../configure --prefix=/usr --enable-languages=c,c++ --with-pkgversion="MassOS GCC 12.2.0" --with-system-zlib --enable-default-ssp --enable-linker-build-id --disable-bootstrap --disable-multilib
make
make install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion)/include-fixed/bits/
ln -sr /usr/bin/cpp /usr/lib
ln -sf ../../libexec/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion)/liblto_plugin.so /usr/lib/bfd-plugins/
mkdir -p /usr/share/gdb/auto-load/usr/lib
mv /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
find /usr -depth -name x86_64-stage1-linux-gnu\* | xargs rm -rf
install -t /usr/share/licenses/gcc -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB ../COPYING.RUNTIME
cd ../..
rm -rf gcc-12.2.0
# pkg-config.
tar -xf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --prefix=/usr --with-internal-glib --disable-host-tool
make
make install
install -t /usr/share/licenses/pkg-config -Dm644 COPYING
cd ..
rm -rf pkg-config-0.29.2
# Ncurses.
tar -xf ncurses-6.3.tar.gz
cd ncurses-6.3
./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug --without-normal --enable-pc-files --enable-widec --with-pkg-config-libdir=/usr/lib/pkgconfig
make
make install
for lib in ncurses form panel menu; do
    rm -f /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sf ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
done
rm -f /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
chmod 755 /usr/lib/libcursesw.so
ln -sf libncurses.so /usr/lib/libcurses.so
rm -f /usr/lib/libncurses++w.a
install -t /usr/share/licenses/ncurses -Dm644 COPYING
cd ..
rm -rf ncurses-6.3
# libedit.
tar -xf libedit-20210910-3.1.tar.gz
cd libedit-20210910-3.1
sed -i 's/history.3//g' doc/Makefile.in
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libedit -Dm644 COPYING
cd ..
rm -rf libedit-20210910-3.1
# libsigsegv.
tar -xf libsigsegv-2.14.tar.gz
cd libsigsegv-2.14
./configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/libsigsegv -Dm644 COPYING
cd ..
rm -rf libsigsegv-2.14
# Sed.
tar -xf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sed -Dm644 COPYING
cd ..
rm -rf sed-4.8
# Gettext.
tar -xf gettext-0.21.tar.xz
cd gettext-0.21
./configure --prefix=/usr --disable-static
make
make install
chmod 0755 /usr/lib/preloadable_libintl.so
install -t /usr/share/licenses/gettext -Dm644 COPYING
cd ..
rm -rf gettext-0.21
# Bison.
tar -xf bison-3.8.2.tar.xz
cd bison-3.8.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/bison -Dm644 COPYING
cd ..
rm -rf bison-3.8.2
# Grep.
tar -xf grep-3.8.tar.xz
cd grep-3.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/grep -Dm644 COPYING
cd ..
rm -rf grep-3.8
# Bash.
tar -xf bash-5.2.tar.gz
cd bash-5.2
./configure --prefix=/usr --without-bash-malloc --with-installed-readline
make
make install
ln -sf bash.1 /usr/share/man/man1/sh.1
install -t /usr/share/licenses/bash -Dm644 COPYING
cd ..
rm -rf bash-5.2
# bash-completion.
tar -xf bash-completion-2.11.tar.xz
cd bash-completion-2.11
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/bash-completion -Dm644 COPYING
cd ..
rm -rf bash-completion-2.11
# libtool.
tar -xf libtool-2.4.7.tar.xz
cd libtool-2.4.7
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libltdl.a
install -t /usr/share/licenses/libtool -Dm644 COPYING
cd ..
rm -rf libtool-2.4.7
# GDBM.
tar -xf gdbm-1.23.tar.gz
cd gdbm-1.23
./configure --prefix=/usr --disable-static --enable-libgdbm-compat
make
make install
install -t /usr/share/licenses/gdbm -Dm644 COPYING
cd ..
rm -rf gdbm-1.23
# gperf.
tar -xf gperf-3.1.tar.gz
cd gperf-3.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gperf -Dm644 COPYING
cd ..
rm -rf gperf-3.1
# Expat.
tar -xf expat-2.4.9.tar.xz
cd expat-2.4.9
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/expat -Dm644 COPYING
cd ..
rm -rf expat-2.4.9
# libmetalink.
tar -xf libmetalink-0.1.3.tar.bz2
cd libmetalink-0.1.3
./configure --prefix=/usr --enable-static=no
make
make install
install -t /usr/share/licenses/libmetalink -Dm644 COPYING
cd ..
rm -rf libmetalink-0.1.3
# Inetutils.
tar -xf inetutils-2.3.tar.xz
cd inetutils-2.3
./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var --disable-logger --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh
make
make install
mv /usr/bin/ifconfig /usr/sbin/ifconfig
install -t /usr/share/licenses/inetutils -Dm644 COPYING
cd ..
rm -rf inetutils-2.3
# Netcat.
tar -xf netcat-0.7.1.tar.bz2
cd netcat-0.7.1
./configure --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -t /usr/share/licenses/netcat -Dm644 COPYING
cd ..
rm -rf netcat-0.7.1
# Less.
tar -xf less-608.tar.gz
cd less-608
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/less -Dm644 COPYING LICENSE
cd ..
rm -rf less-608
# Lua.
tar -xf lua-5.4.4.tar.gz
cd lua-5.4.4
patch -Np1 -i ../patches/lua-5.4.4-sharedlib+pkgconfig.patch
cat src/lua.h | tail -n24 | head -n20 | sed -e 's/* //g' -e 's/*//g' > COPYING
make MYCFLAGS="$CFLAGS -fPIC" linux-readline
make INSTALL_DATA="cp -d" INSTALL_TOP=/usr INSTALL_MAN=/usr/share/man/man1 TO_LIB="liblua.so liblua.so.5.4 liblua.so.5.4.4" install
install -t /usr/lib/pkgconfig -Dm644 lua.pc
install -t /usr/share/licenses/lua -Dm644 COPYING
cd ..
rm -rf lua-5.4.4
# Perl.
tar -xf perl-5.36.0.tar.xz
cd perl-5.36.0
export BUILD_ZLIB=False BUILD_BZIP2=0
./Configure -des -Doptimize="$CFLAGS" -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.36/core_perl -Darchlib=/usr/lib/perl5/5.36/core_perl -Dsitelib=/usr/lib/perl5/5.36/site_perl -Dsitearch=/usr/lib/perl5/5.36/site_perl -Dvendorlib=/usr/lib/perl5/5.36/vendor_perl -Dvendorarch=/usr/lib/perl5/5.36/vendor_perl -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 -Dpager="/usr/bin/less -isR" -Duseshrplib -Dusethreads
make
make install
unset BUILD_ZLIB BUILD_BZIP2
install -t /usr/share/licenses/perl -Dm644 Copying
cd ..
rm -rf perl-5.36.0
# SGMLSpm
tar -xf SGMLSpm-1.1.tar.gz
cd SGMLSpm-1.1
chmod +w MYMETA.yml
perl Makefile.PL
make
make install
rm -f /usr/lib/perl5/5.36/core_perl/perllocal.pod
ln -sf sgmlspl.pl /usr/bin/sgmlspl
install -t /usr/share/licenses/sgmlspm -Dm644 COPYING
cd ..
rm -rf SGMLSpm-1.1
# XML::Parser.
tar -xf XML-Parser-2.46.tar.gz
cd XML-Parser-2.46
perl Makefile.PL
make
make install
cd ..
rm -rf XML-Parser-2.46
# Intltool.
tar -xf intltool-0.51.0.tar.gz
cd intltool-0.51.0
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/intltool -Dm644 COPYING
cd ..
rm -rf intltool-0.51.0
# Autoconf.
tar -xf autoconf-2.71.tar.xz
cd autoconf-2.71
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/autoconf -Dm644 COPYING COPYINGv3 COPYING.EXCEPTION
cd ..
rm -rf autoconf-2.71
# Autoconf (legacy version 2.13).
tar -xf autoconf-2.13.tar.gz
cd autoconf-2.13
patch -Np1 -i ../patches/autoconf-2.13-consolidated_fixes-1.patch
mv autoconf.texi autoconf213.texi
rm autoconf.info
./configure --prefix=/usr --infodir=/usr/share/info --program-suffix=2.13
make
make install
install -m644 autoconf213.info /usr/share/info
install-info --info-dir=/usr/share/info autoconf213.info
install -t /usr/share/licenses/autoconf213 -Dm644 COPYING
cd ..
rm -rf autoconf-2.13
# Automake.
tar -xf automake-1.16.5.tar.xz
cd automake-1.16.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/automake -Dm644 COPYING
cd ..
rm -rf automake-1.16.5
# autoconf-archive.
tar -xf autoconf-archive-2021.02.19.tar.xz
cd autoconf-archive-2021.02.19
./configure --prefix=/usr
make
make install
cd ..
rm -rf autoconf-archive-2021.02.19
# PSmisc.
tar -xf psmisc-v23.5.tar.bz2
cd psmisc-v23.5
sed -i 's/UNKNOWN/23.5/g' misc/git-version-gen
./autogen.sh
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/psmisc -Dm644 COPYING
cd ..
rm -rf psmisc-v23.5
# elfutils.
tar -xf elfutils-0.187.tar.bz2
cd elfutils-0.187
CFLAGS="-O2" CXXFLAGS="-O2" ./configure --prefix=/usr --program-prefix="eu-" --disable-debuginfod --enable-libdebuginfod=dummy
make
make install
rm -f /usr/lib/lib{asm,dw,elf}.a
install -t /usr/share/licenses/elfutils -Dm644 COPYING COPYING-GPLV2 COPYING-LGPLV3
cd ..
rm -rf elfutils-0.187
# libbpf.
tar -xf libbpf-1.0.0.tar.gz
cd libbpf-1.0.0/src
make
make LIBSUBDIR=lib install
rm -f /usr/lib/libbpf.a
install -t /usr/share/licenses/libbpf -Dm644 ../LICENSE{,.BSD-2-Clause,.LGPL-2.1}
cd ../..
rm -rf libbpf-1.0.0
# patchelf.
tar -xf patchelf-0.14.5.tar.bz2
cd patchelf-0.14.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/patchelf -Dm644 COPYING
cd ..
rm -rf patchelf-0.14.5
# strace.
tar -xf strace-5.19.tar.xz
cd strace-5.19
./configure --prefix=/usr --with-libdw
make
make install
install -t /usr/share/licenses/strace -Dm644 COPYING LGPL-2.1-or-later
cd ..
rm -rf strace-5.19
# libffi.
tar -xf libffi-3.4.3.tar.gz
cd libffi-3.4.3
./configure --prefix=/usr --disable-static --disable-exec-static-tramp
make
make install
install -t /usr/share/licenses/libffi -Dm644 LICENSE
cd ..
rm -rf libffi-3.4.3
# OpenSSL.
tar -xf openssl-3.0.5.tar.gz
cd openssl-3.0.5
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
install -t /usr/share/licenses/openssl -Dm644 LICENSE.txt
cd ..
rm -rf openssl-3.0.5
# easy-rsa.
tar -xf EasyRSA-3.1.0.tgz
cd EasyRSA-3.1.0
install -Dm755 easyrsa /usr/bin/easyrsa
install -Dm644 openssl-easyrsa.cnf /etc/easy-rsa/openssl-easyrsa.cnf
install -Dm644 vars.example /etc/easy-rsa/vars
install -dm755 /etc/easy-rsa/x509-types/
install -m644 x509-types/* /etc/easy-rsa/x509-types/
install -t /usr/share/licenses/easy-rsa -Dm644 COPYING.md gpl-2.0.txt
cd ..
rm -rf EasyRSA-3.1.0
# mpdecimal.
tar -xf mpdecimal-2.5.1.tar.gz
cd mpdecimal-2.5.1
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libmpdec{,++}.a
install -t /usr/share/licenses/mpdecimal -Dm644 LICENSE.txt
cd ..
rm -rf mpdecimal-2.5.1
# kmod.
tar -xf kmod-30.tar.xz
cd kmod-30
./configure --prefix=/usr --sysconfdir=/etc --with-xz --with-zstd --with-zlib --with-openssl
make
make install
for target in depmod insmod modinfo modprobe rmmod; do ln -sf ../bin/kmod /usr/sbin/$target; done
ln -sf kmod /usr/bin/lsmod
install -t /usr/share/licenses/kmod -Dm644 COPYING
cd ..
rm -rf kmod-30
# Python (initial build; will be rebuilt later to support SQLite and Tk).
tar -xf Python-3.10.7.tar.xz
cd Python-3.10.7
./configure --prefix=/usr --enable-shared --with-system-expat --with-system-ffi --with-system-libmpdec --with-ensurepip=yes --enable-optimizations --disable-test-modules
make
make install
ln -sf python3 /usr/bin/python
ln -sf pydoc3 /usr/bin/pydoc
ln -sf idle3 /usr/bin/idle
ln -sf python3-config /usr/bin/python-config
ln -sf pip3 /usr/bin/pip
install -t /usr/share/licenses/python -Dm644 LICENSE
cd ..
rm -rf Python-3.10.7
# Sphinx (required to build man pages of some packages).
mkdir -p sphinx
tar -xf sphinx-5.1.1-x86_64-py3.10-venv.tar.xz -C sphinx --strip-components=1
# Ninja.
tar -xf ninja-1.11.1.tar.gz
cd ninja-1.11.1
python configure.py --bootstrap
install -m755 ninja /usr/bin
install -Dm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -Dm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja
install -t /usr/share/licenses/ninja -Dm644 COPYING
cd ..
rm -rf ninja-1.11.1
# Meson.
tar -xf meson-0.63.2.tar.gz
cd meson-0.63.2
python setup.py build
python setup.py install --root=meson-destination-directory
cp -r meson-destination-directory/* /
install -Dm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -Dm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
install -t /usr/share/licenses/meson -Dm644 COPYING
cd ..
rm -rf meson-0.63.2
# PyParsing.
tar -xf pyparsing_3.0.7.tar.gz
cd pyparsing-pyparsing_3.0.7
python setup.py build
python setup.py install --prefix=/usr --optimize=1
install -t /usr/share/licenses/pyparsing -Dm644 LICENSE
cd ..
rm -rf pyparsing-pyparsing_3.0.7
# packaging (required by UPower since 0.99.18).
tar -xf packaging-21.3.tar.gz
cd packaging-21.3
python setup.py install --optimize=1
install -t /usr/share/licenses/packaging -Dm644 LICENSE{,.APACHE,.BSD}
cd ..
rm -rf packaging-21.3
# six.
tar -xf six-1.16.0.tar.gz
cd six-1.16.0
python setup.py install --optimize=1
install -t /usr/share/licenses/six -Dm644 LICENSE
cd ..
rm -rf six-1.16.0
# distro.
tar -xf distro-1.6.0.tar.gz
cd distro-1.6.0
python setup.py build
python setup.py install --skip-build
install -t /usr/share/licenses/distro -Dm644 LICENSE
cd ..
rm -rf distro-1.6.0
# libseccomp.
tar -xf libseccomp-2.5.4.tar.gz
cd libseccomp-2.5.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libseccomp -Dm644 LICENSE
cd ..
rm -rf libseccomp-2.5.4
# File.
tar -xf file-5.43.tar.gz
cd file-5.43
./configure --prefix=/usr --enable-libseccomp
make
make install
install -t /usr/share/licenses/file -Dm644 COPYING
cd ..
rm -rf file-5.43
# Coreutils.
tar -xf coreutils-9.1.tar.xz
cd coreutils-9.1
patch -Np1 -i ../patches/coreutils-9.1-progressbar.patch
./configure --prefix=/usr --enable-no-install-program=kill,uptime --with-packager="MassOS"
make
make install
mv /usr/bin/chroot /usr/sbin
mv /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
dircolors -p > /etc/dircolors
install -t /usr/share/licenses/coreutils -Dm644 COPYING
cd ..
rm -rf coreutils-9.1
# Diffutils.
tar -xf diffutils-3.8.tar.xz
cd diffutils-3.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/diffutils -Dm644 COPYING
cd ..
rm -rf diffutils-3.8
# Gawk.
tar -xf gawk-5.1.0.tar.xz
cd gawk-5.1.0
./configure --prefix=/usr
make
make install
ln -sf gawk.1 /usr/share/man/man1/awk.1
install -t /usr/share/licenses/gawk -Dm644 COPYING
cd ..
rm -rf gawk-5.1.0
# Findutils.
tar -xf findutils-4.9.0.tar.xz
cd findutils-4.9.0
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make install
install -t /usr/share/licenses/findutils -Dm644 COPYING
cd ..
rm -rf findutils-4.9.0
# Groff.
tar -xf groff-1.22.4.tar.gz
cd groff-1.22.4
./configure --prefix=/usr
make -j1
make install
install -t /usr/share/licenses/groff -Dm644 COPYING LICENSES
cd ..
rm -rf groff-1.22.4
# Gzip.
tar -xf gzip-1.12.tar.xz
cd gzip-1.12
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gzip -Dm644 COPYING
cd ..
rm -rf gzip-1.12
# Texinfo.
tar -xf texinfo-6.8.tar.xz
cd texinfo-6.8
./configure --prefix=/usr
sed -e 's/__attribute_nonnull__/__nonnull/' -i gnulib/lib/malloc/dynarray-skeleton.c
make
make install
install -t /usr/share/licenses/texinfo -Dm644 COPYING
cd ..
rm -rf texinfo-6.8
# Sharutils.
tar -xf sharutils-4.15.2.tar.xz
cd sharutils-4.15.2
sed -i 's/BUFSIZ/rw_base_size/' src/unshar.c
sed -i '/program_name/s/^/extern /' src/*opts.h
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sharutils -Dm644 COPYING
cd ..
rm -rf sharutils-4.15.2
# Berkeley DB.
tar -xf db-5.3.28.tar.gz
cd db-5.3.28
sed -i 's/\(__atomic_compare_exchange\)/\1_db/' src/dbinc/atomic.h
./dist/configure --prefix=/usr --enable-compat185 --enable-cxx --enable-dbm --disable-static
make
make docdir=/usr/share/doc/db install
chown -R root:root /usr/bin/db_* /usr/include/db{,_185,_cxx}.h /usr/lib/libdb*.{so,la}
install -t /usr/share/licenses/db -Dm644 LICENSE
cd ..
rm -rf db-5.3.28
# LMDB.
tar -xf LMDB_0.9.29.tar.gz
cd lmdb-LMDB_0.9.29/libraries/liblmdb
make CFLAGS="$CFLAGS"
sed -i 's| liblmdb.a||' Makefile
make prefix=/usr install
install -t /usr/share/licenses/lmdb -Dm644 COPYRIGHT LICENSE
cd ../../..
rm -rf lmdb-LMDB_0.9.29
# Cyrus SASL (will be rebuilt later to support krb5 and OpenLDAP).
tar -xf cyrus-sasl-2.1.28.tar.gz
cd cyrus-sasl-2.1.28
./configure --prefix=/usr --sysconfdir=/etc --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
install -t /usr/share/licenses/cyrus-sasl -Dm644 COPYING
cd ..
rm -rf cyrus-sasl-2.1.28
# iptables.
tar -xf iptables-1.8.8.tar.bz2
cd iptables-1.8.8
rm -f include/linux/types.h
ln -sfr libiptc/linux_list.h include/libiptc
./configure --prefix=/usr --disable-nftables --enable-libipq
make
make install
install -t /usr/share/licenses/iptables -Dm644 COPYING
cd ..
rm -rf iptables-1.8.8
# UFW.
tar -xf ufw-0.36.1.tar.gz
cd ufw-0.36.1
python setup.py install
install -t /usr/share/licenses/ufw -Dm644 COPYING
cd ..
rm -rf ufw-0.36.1
# IPRoute2.
tar -xf iproute2-5.19.0.tar.xz
cd iproute2-5.19.0
make
make SBINDIR=/usr/sbin install
install -t /usr/share/licenses/iproute2 -Dm644 COPYING
cd ..
rm -rf iproute2-5.19.0
# Kbd.
tar -xf kbd-2.5.1.tar.xz
cd kbd-2.5.1
patch -Np1 -i ../patches/kbd-2.4.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-tests
make
make install
install -t /usr/share/licenses/kbd -Dm644 COPYING
cd ..
rm -rf kbd-2.5.1
# libpipeline.
tar -xf libpipeline-1.5.6.tar.gz
cd libpipeline-1.5.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libpipeline -Dm644 COPYING
cd ..
rm -rf libpipeline-1.5.6
# libunwind.
tar -xf libunwind-1.6.2.tar.gz
cd libunwind-1.6.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libunwind -Dm644 COPYING
cd ..
rm -rf libunwind-1.6.2
# libuv.
tar -xf libuv-v1.44.2.tar.gz
cd libuv-v1.44.2
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libuv -Dm644 LICENSE
cd ..
rm -rf libuv-v1.44.2
# Make.
tar -xf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr
make
make install
ln -sf make /usr/bin/gmake
ln -sf make.1 /usr/share/man/gmake.1
install -t /usr/share/licenses/make -Dm644 COPYING
cd ..
rm -rf make-4.3
# Ed.
tar -xf ed-1.18.tar.lz
cd ed-1.18
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/ed -Dm644 COPYING
cd ..
rm -rf ed-1.18
# Patch.
tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/patch -Dm644 COPYING
cd ..
rm -rf patch-2.7.6
# gtar.
tar -xf tar-1.34.tar.xz
cd tar-1.34
./configure --prefix=/usr --program-prefix=g
make
make install
install -t /usr/share/licenses/gtar -Dm644 COPYING
cd ..
rm -rf tar-1.34
# Nano (Vim will be installed later, after X and GTK, to support a GUI).
tar -xf nano-6.4.tar.xz
cd nano-6.4
./configure --prefix=/usr --sysconfdir=/etc --enable-utf8
make
make install
cp doc/sample.nanorc /etc/nanorc
sed -i '0,/# include/{s/# include/include/}' /etc/nanorc
install -t /usr/share/licenses/nano -Dm644 COPYING
cd ..
rm -rf nano-6.4
# dos2unix.
tar -xf dos2unix-7.4.2.tar.gz
cd dos2unix-7.4.2
make
make install
install -t /usr/share/licenses/dos2unix -Dm644 COPYING.txt
cd ..
rm -rf dos2unix-7.4.2
# docutils.
tar -xf docutils-0.18.1.tar.gz
cd docutils-0.18.1
python setup.py build
python setup.py install --optimize=1
for i in /usr/bin/rst2*.py; do ln -sf $(basename $i) /usr/bin/$(basename $i .py); done
install -t /usr/share/licenses/docutils -Dm644 COPYING.txt
cd ..
rm -rf docutils-0.18.1
# MarkupSafe.
tar -xf MarkupSafe-2.1.1.tar.gz
cd MarkupSafe-2.1.1
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/markupsafe -Dm644 LICENSE.rst
cd ..
rm -rf MarkupSafe-2.1.1
# Jinja2.
tar -xf Jinja2-3.1.1.tar.gz
cd Jinja2-3.1.1
python setup.py install --optimize=1
install -t /usr/share/licenses/jinja2 -Dm644 LICENSE.rst
cd ..
rm -rf Jinja2-3.1.1
# Mako.
tar -xf Mako-1.2.3.tar.gz
cd Mako-1.2.3
python setup.py install --optimize=1
install -t /usr/share/licenses/mako -Dm644 LICENSE
cd ..
rm -rf Mako-1.2.3
# Pygments.
tar -xf Pygments-2.13.0.tar.gz
cd Pygments-2.13.0
python setup.py install --optimize=1
install -t /usr/share/licenses/pygments -Dm644 LICENSE
cd ..
rm -rf Pygments-2.13.0
# toml.
tar -xf toml-0.10.2.tar.gz
cd toml-0.10.2
python setup.py build
python setup.py install --prefix=/usr --optimize=1 --skip-build
install -t /usr/share/licenses/toml -Dm644 LICENSE
cd ..
rm -rf toml-0.10.2
# smartypants.
tar -xf smartypants.py-2.0.1.tar.gz
cd smartypants.py-2.0.1
python setup.py install --optimize=1
install -t /usr/share/licenses/smartypants -Dm644 COPYING
cd ..
rm -rf smartypants.py-2.0.1
# typogrify.
tar -xf typogrify-2.0.7.tar.gz
cd typogrify-2.0.7
python setup.py install --optimize=1
install -t /usr/share/licenses/typogrify -Dm644 LICENSE.txt
cd ..
rm -rf typogrify-2.0.7
# zipp (precompiled for now, to avoid dependency hell).
pip install zipp-3.7.0-py3-none-any.whl
install -t /usr/share/licenses/zipp -Dm644 /usr/lib/python3.10/site-packages/zipp-3.7.0.dist-info/LICENSE
# importlib-metadata
tar -xf importlib_metadata-4.10.1.tar.gz
cd importlib_metadata-4.10.1
rm -f exercises.py
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/importlib-metadata -Dm644 LICENSE
cd ..
rm -rf importlib_metadata-4.10.1
# Markdown.
tar -xf Markdown-3.3.6.tar.gz
cd Markdown-3.3.6
python setup.py build
python setup.py install --optimize=1 --skip-build
install -t /usr/share/licenses/markdown -Dm644 LICENSE.md
cd ..
rm -rf Markdown-3.3.6
# gi-docgen (dependency of librsvg since 2.54.0).
tar -xf gi-docgen-2022.1.tar.xz
cd gi-docgen-2022.1
mkdir gi-docgen-build; cd gi-docgen-build
meson --prefix=/usr --buildtype=minsize -Ddevelopment_tests=false ..
ninja
ninja install
install -t /usr/share/licenses/gi-docgen -Dm644 ../LICENSES/{Apache-2.0.txt,GPL-3.0-or-later.txt}
cd ../..
rm -rf gi-docgen-2022.1
# Locale-gettext.
tar -xf Locale-gettext-1.07.tar.gz
cd Locale-gettext-1.07
perl Makefile.PL
make
make install
install -dm755 /usr/share/licenses/locale-gettext
cat README | head -n16 | tail -n6 > /usr/share/licenses/locale-gettext/COPYING
cd ..
rm -rf Locale-gettext-1.07
# help2man.
tar -xf help2man-1.49.2.tar.xz
cd help2man-1.49.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/help2man -Dm644 COPYING
cd ..
rm -rf help2man-1.49.2
# dialog.
tar -xf dialog-1.3-20220728.tgz
cd dialog-1.3-20220728
./configure --prefix=/usr --enable-nls --with-libtool --with-ncursesw
make
make install
rm -f /usr/lib/libdialog.a
chmod 755 /usr/lib/libdialog.so.15.0.0
install -t /usr/share/licenses/dialog -Dm644 COPYING
cd ..
rm -rf dialog-1.3-20220728
# acpi.
tar -xf acpi-1.7.tar.gz
cd acpi-1.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/acpi -Dm644 COPYING
cd ..
rm -rf acpi-1.7
# rpcsvc-proto.
tar -xf rpcsvc-proto-1.4.3.tar.xz
cd rpcsvc-proto-1.4.3
./configure --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/rpcsvc-proto -Dm644 COPYING
cd ..
rm -rf rpcsvc-proto-1.4.3
# Which.
tar -xf which-2.21.tar.gz
cd which-2.21
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/which -Dm644 COPYING
cd ..
rm -rf which-2.21
# tree.
tar -xf unix-tree-2.0.4.tar.bz2
cd unix-tree-2.0.4
make CFLAGS="$CFLAGS"
make PREFIX=/usr MANDIR=/usr/share/man install
chmod 644 /usr/share/man/man1/tree.1
install -t /usr/share/licenses/tree -Dm644 LICENSE
cd ..
rm -rf unix-tree-2.0.4
# GPM.
tar --no-same-owner -xf gpm-1.20.7-38-ge82d1a6-x86_64-Precompiled-MassOS.tar.xz
cp -r gpm-1.20.7-38-ge82d1a6-x86_64-Precompiled-MassOS/BINARY/* /
install-info --dir-file=/usr/share/info/dir /usr/share/info/gpm.info
install -t /usr/share/licenses/gpm -Dm644 gpm-1.20.7-38-ge82d1a6-x86_64-Precompiled-MassOS/SOURCE/COPYING
rm -rf gpm-1.20.7-38-ge82d1a6-x86_64-Precompiled-MassOS
# pv.
tar -xf pv-1.6.20.tar.bz2
cd pv-1.6.20
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/pv -Dm644 doc/COPYING
cd ..
rm -rf pv-1.6.20
# liburing.
tar -xf liburing-2.1.tar.bz2
cd liburing-2.1
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
rm -f /usr/lib/liburing.a
cd ..
rm -rf liburing-2.1
# duktape.
tar -xf duktape-2.7.0.tar.xz
cd duktape-2.7.0
CFLAGS="$CFLAGS -DDUK_USE_FASTINT" make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr
make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr install
install -t /usr/share/licenses/duktape -Dm644 LICENSE.txt
cd ..
rm -rf duktape-2.7.0
# oniguruma.
tar -xf onig-6.9.8.tar.gz
cd onig-6.9.8
./configure --prefix=/usr --disable-static --enable-posix-api
make
make install
install -t /usr/share/licenses/oniguruma -Dm644 COPYING
cd ..
rm -rf onig-6.9.8
# jq.
tar -xf jq-1.6.tar.gz
cd jq-1.6
autoreconf -fi
./configure --prefix=/usr --disable-docs --disable-static
make
make install
install -t /usr/share/licenses/jq -Dm644 COPYING
cd ..
rm -rf jq-1.6
# ICU.
tar -xf icu4c-71_1-src.tgz
cd icu/source
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/icu -Dm644 ../LICENSE
cd ../..
rm -rf icu
# Boost.
tar -xf boost_1_80_0.tar.bz2
cd boost_1_80_0
./bootstrap.sh --prefix=/usr --with-icu
./b2 stage -j$(nproc) threading=multi link=shared
./b2 install threading=multi link=shared
install -t /usr/share/licenses/boost -Dm644 LICENSE_1_0.txt
cd ..
rm -rf boost_1_80_0
# libgpg-error.
tar -xf libgpg-error-1.45.tar.bz2
cd libgpg-error-1.45
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libgpg-error -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libgpg-error-1.45
# libgcrypt.
tar -xf libgcrypt-1.10.1.tar.bz2
cd libgcrypt-1.10.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libgcrypt -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libgcrypt-1.10.1
# Unzip.
tar -xf unzip60.tar.gz
cd unzip60
patch -Np1 -i ../patches/unzip-6.0-consolidated_fixes-1.patch
sed -i 's/O3/Os/' unix/configure
sed -i 's/O3/Os/' unix/Makefile
make -f unix/Makefile generic
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
install -t /usr/share/licenses/unzip -Dm644 LICENSE
cd ..
rm -rf unzip60
# Zip.
tar -xf zip30.tar.gz
cd zip30
sed -i 's/O3/Os/' unix/configure
make -f unix/Makefile generic_gcc
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
install -t /usr/share/licenses/zip -Dm644 LICENSE
cd ..
rm -rf zip30
# minizip.
tar -xf zlib-1.2.12.tar.xz
cd zlib-1.2.12/contrib/minizip
autoreconf -fi
./configure --prefix=/usr --enable-static=no
make
make install
ln -sf zlib /usr/share/licenses/minizip
cd ../../..
rm -rf zlib-1.2.12
# libmicrodns.
tar -xf microdns-0.2.0.tar.xz
cd microdns-0.2.0
mkdir mdns-build; cd mdns-build
meson --prefix=/usr --buildtype=minsize -Dexamples=disabled -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/libmicrodns -Dm644 ../COPYING
cd ../..
rm -rf microdns-0.2.0
# libsodium.
tar -xf libsodium-1.0.18.tar.gz
cd libsodium-1.0.18
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libsodium -Dm644 LICENSE
cd ..
rm -rf libsodium-1.0.18
# sgml-common.
tar -xf sgml-common-0.6.3.tgz
cd sgml-common-0.6.3
patch -Np1 -i ../patches/sgml-common-0.6.3-manpage-1.patch
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc
make
make docdir=/usr/share/doc install
install-catalog --add /etc/sgml/sgml-ent.cat /usr/share/sgml/sgml-iso-entities-8879.1986/catalog
install-catalog --add /etc/sgml/sgml-docbook.cat /etc/sgml/sgml-ent.cat
cd ..
rm -rf sgml-common-0.6.3
# Docbook 3.1 DTD.
mkdir docbk31
cd docbk31
unzip -q ../docbk31.zip
sed -i -e '/ISO 8879/d' -e 's|DTDDECL "-//OASIS//DTD DocBook V3.1//EN"|SGMLDECL|g' docbook.cat
install -dm755 /usr/share/sgml/docbook/sgml-dtd-3.1
chown -R root:root .
install docbook.cat /usr/share/sgml/docbook/sgml-dtd-3.1/catalog
cp -af *.dtd *.mod *.dcl /usr/share/sgml/docbook/sgml-dtd-3.1
install-catalog --add /etc/sgml/sgml-docbook-dtd-3.1.cat /usr/share/sgml/docbook/sgml-dtd-3.1/catalog
install-catalog --add /etc/sgml/sgml-docbook-dtd-3.1.cat /etc/sgml/sgml-docbook.cat
cat >> /usr/share/sgml/docbook/sgml-dtd-3.1/catalog << END
  -- Begin Single Major Version catalog changes --

PUBLIC "-//Davenport//DTD DocBook V3.0//EN" "docbook.dtd"

  -- End Single Major Version catalog changes --
END
cd ..
rm -rf docbk31
# Docbook 4.5 DTD.
mkdir docbook-4.5
cd docbook-4.5
unzip -q ../docbook-4.5.zip
sed -i -e '/ISO 8879/d' -e '/gml/d' docbook.cat
install -d /usr/share/sgml/docbook/sgml-dtd-4.5
chown -R root:root .
install docbook.cat /usr/share/sgml/docbook/sgml-dtd-4.5/catalog
cp -af *.dtd *.mod *.dcl /usr/share/sgml/docbook/sgml-dtd-4.5
install-catalog --add /etc/sgml/sgml-docbook-dtd-4.5.cat /usr/share/sgml/docbook/sgml-dtd-4.5/catalog
install-catalog --add /etc/sgml/sgml-docbook-dtd-4.5.cat /etc/sgml/sgml-docbook.cat
cat >> /usr/share/sgml/docbook/sgml-dtd-4.5/catalog << END
  -- Begin Single Major Version catalog changes --

PUBLIC "-//OASIS//DTD DocBook V4.4//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.3//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.2//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.1//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.0//EN" "docbook.dtd"

  -- End Single Major Version catalog changes --
END
cd ..
rm -rf docbook-4.5
# libxml2.
tar -xf libxml2-2.9.14.tar.xz
cd libxml2-2.9.14
./configure --prefix=/usr --disable-static --with-history --with-icu --with-python=/usr/bin/python3 --with-threads
make
make install
install -t /usr/share/licenses/libxml2 -Dm644 COPYING
cd ..
rm -rf libxml2-2.9.14
# libarchive.
tar -xf libarchive-3.6.1.tar.xz
cd libarchive-3.6.1
patch -Np1 -i ../patches/libarchive-3.6.1-glibc236.patch
./configure --prefix=/usr --disable-static
make
make install
ln -sf bsdtar /usr/bin/tar
ln -sf bsdcpio /usr/bin/cpio
ln -sf bsdtar.1 /usr/share/man/man1/tar.1
ln -sf bsdcpio.1 /usr/share/man/man1/cpio.1
install -t /usr/share/licenses/libarchive -Dm644 COPYING
cd ..
rm -rf libarchive-3.6.1
# Docbook XML 4.5.
mkdir docbook-xml-4.5
cd docbook-xml-4.5
unzip -q ../docbook-xml-4.5.zip
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
cd ..
rm -rf docbook-xml-4.5
# docbook-xsl-nons.
tar -xf docbook-xsl-nons-1.79.2.tar.bz2
cd docbook-xsl-nons-1.79.2
patch -Np1 -i ../patches/docbook-xsl-nons-1.79.2-stack_fix-1.patch
install -dm755 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
cp -R VERSION assembly common eclipse epub epub3 extensions fo highlighting html htmlhelp images javahelp lib manpages params profiling roundtrip slides template tests tools webhelp website xhtml xhtml-1_1 xhtml5 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
ln -s VERSION /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl
install -Dm644 README /usr/share/doc/docbook-xsl-nons-1.79.2/README.txt
install -m644 RELEASE-NOTES* NEWS* /usr/share/doc/docbook-xsl-nons-1.79.2
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
cd ..
rm -rf docbook-xsl-nons-1.79.2
# libxslt.
tar -xf libxslt-1.1.37.tar.xz
cd libxslt-1.1.37
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxslt -Dm644 COPYING
cd ..
rm -rf libxslt-1.1.37
# Lynx.
tar -xf lynx2.8.9rel.1.tar.bz2
cd lynx2.8.9rel.1
./configure --prefix=/usr --sysconfdir=/etc/lynx --datadir=/usr/share/doc/lynx --with-bzlib --with-screen=ncursesw --with-ssl --with-zlib --enable-gzip-help --enable-ipv6 --enable-locale-charset
make
make install-full
sed -i 's/#LOCALE_CHARSET:FALSE/LOCALE_CHARSET:TRUE/' /etc/lynx/lynx.cfg
sed -i 's/#DEFAULT_EDITOR:/DEFAULT_EDITOR:nano/' /etc/lynx/lynx.cfg
sed -i 's/#PERSISTENT_COOKIES:FALSE/PERSISTENT_COOKIES:TRUE/' /etc/lynx/lynx.cfg
install -t /usr/share/licenses/lynx -Dm644 COPYHEADER COPYING
cd ..
rm -rf lynx2.8.9rel.1
# xmlto.
tar -xf xmlto-0.0.28.tar.bz2
cd xmlto-0.0.28
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xmlto -Dm644 COPYING
cd ..
rm -rf xmlto-0.0.28
# OpenSP.
tar -xf OpenSP-1.5.2.tar.gz
cd OpenSP-1.5.2
sed -i 's/32,/253,/' lib/Syntax.cxx
sed -i 's/LITLEN          240 /LITLEN          8092/' unicode/{gensyntax.pl,unicode.syn}
./configure --prefix=/usr --disable-static --enable-default-catalog=/etc/sgml/catalog --enable-default-search-path=/usr/share/sgml --enable-http
make pkgdatadir=/usr/share/sgml/OpenSP-1.5.2
make pkgdatadir=/usr/share/sgml/OpenSP-1.5.2 docdir=/usr/share/doc/OpenSP-1.5.2 install
ln -sf onsgmls /usr/bin/nsgmls
ln -sf osgmlnorm /usr/bin/sgmlnorm
ln -sf ospam /usr/bin/spam
ln -sf ospcat /usr/bin/spcat
ln -sf ospent /usr/bin/spent
ln -sf osx /usr/bin/sx
ln -sf osx /usr/bin/sgml2xml
ln -sf libosp.so /usr/lib/libsp.so
install -t /usr/share/licenses/opensp -Dm644 COPYING
cd ..
rm -rf OpenSP-1.5.2
# OpenJade.
tar -xf openjade-1.3.2.tar.gz
cd openjade-1.3.2
patch -Np1 -i ../patches/openjade-1.3.2-upstream-1.patch
sed -i -e '/getopts/{N;s#&G#g#;s#do .getopts.pl.;##;}' -e '/use POSIX/ause Getopt::Std;' msggen.pl
CXXFLAGS="$CXXFLAGS -fno-lifetime-dse" ./configure --prefix=/usr --mandir=/usr/share/man --enable-http --disable-static --enable-default-catalog=/etc/sgml/catalog --enable-default-search-path=/usr/share/sgml --datadir=/usr/share/sgml/openjade-1.3.2
make
make install
make install-man
ln -sf openjade /usr/bin/jade
ln -sf libogrove.so /usr/lib/libgrove.so
ln -sf libospgrove.so /usr/lib/libspgrove.so
ln -sf libostyle.so /usr/lib/libstyle.so
install -m644 dsssl/catalog /usr/share/sgml/openjade-1.3.2/
install -m644 dsssl/*.{dtd,dsl,sgm} /usr/share/sgml/openjade-1.3.2
install-catalog --add /etc/sgml/openjade-1.3.2.cat /usr/share/sgml/openjade-1.3.2/catalog
install-catalog --add /etc/sgml/sgml-docbook.cat /etc/sgml/openjade-1.3.2.cat
echo "SYSTEM \"http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd\" \"/usr/share/xml/docbook/xml-dtd-4.5/docbookx.dtd\"" >> /usr/share/sgml/openjade-1.3.2/catalog
install -t /usr/share/licenses/openjade -Dm644 COPYING
cd ..
rm -rf openjade-1.3.2
# docbook-dsssl.
tar -xf docbook-dsssl-1.79.tar.bz2
cd docbook-dsssl-1.79
install -m755 bin/collateindex.pl /usr/bin
install -m644 bin/collateindex.pl.1 /usr/share/man/man1
install -dm755 /usr/share/sgml/docbook/dsssl-stylesheets-1.79
cp -R * /usr/share/sgml/docbook/dsssl-stylesheets-1.79
install-catalog --add /etc/sgml/dsssl-docbook-stylesheets.cat /usr/share/sgml/docbook/dsssl-stylesheets-1.79/catalog
install-catalog --add /etc/sgml/dsssl-docbook-stylesheets.cat /usr/share/sgml/docbook/dsssl-stylesheets-1.79/common/catalog
install-catalog --add /etc/sgml/sgml-docbook.cat /etc/sgml/dsssl-docbook-stylesheets.cat
cd ..
rm -rf docbook-dsssl-1.79
# docbook-utils.
tar -xf docbook-utils-0.6.14.tar.gz
cd docbook-utils-0.6.14
patch -Np1 -i ../patches/docbook-utils-0.6.14-grep_fix-1.patch
sed -i 's:/html::' doc/HTML/Makefile.in
./configure --prefix=/usr --mandir=/usr/share/man
make
make docdir=/usr/share/doc install
for doctype in html ps dvi man pdf rtf tex texi txt; do ln -svf docbook2$doctype /usr/bin/db2$doctype; done
install -t /usr/share/licenses/docbook-utils -Dm644 COPYING
cd ..
rm -rf docbook-utils-0.6.14
# Docbook XML 5.0.
unzip -q docbook-5.0.zip
cd docbook-5.0
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
cd ..
rm -rf docbook-5.0
# Docbook XML 5.1.
mkdir docbook-5.1
cd docbook-5.1
unzip -q ../docbook-v5.1-os.zip
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
cd ..
rm -rf docbook-5.1
# lxml.
tar -xf lxml-4.9.1.tar.gz
cd lxml-4.9.1
python setup.py install --optimize=1
install -t /usr/share/licenses/lxml -Dm644 LICENSE.txt LICENSES.txt
cd ..
rm -rf lxml-4.9.1
# itstool.
tar -xf itstool-2.0.7.tar.bz2
cd itstool-2.0.7
PYTHON=/usr/bin/python3 ./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/itstool -Dm644 COPYING COPYING.GPL3
cd ..
rm -rf itstool-2.0.7
# Asciidoc.
tar -xf asciidoc-10.2.0.tar.gz
cd asciidoc-10.2.0
python setup.py install --optimize=1
cd ..
rm -rf asciidoc-10.2.0
# Moreutils.
tar -xf moreutils_0.67.orig.tar.gz
cd moreutils-0.67
make CFLAGS="$CFLAGS" DOCBOOKXSL=/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
make install
install -t /usr/share/licenses/moreutils -Dm644 COPYING
cd ..
rm -rf moreutils-0.67
# GNU-EFI.
tar -xf gnu-efi-3.0.15.tar.bz2
cd gnu-efi-3.0.15
make
make -C lib
make -C gnuefi
make -C inc
make -C apps
make PREFIX=/usr install
install -Dm644 apps/*.efi -t /usr/share/gnu-efi/apps/x86_64
install -t /usr/share/licenses/gnu-efi -Dm644 README.efilib
cd ..
rm -rf gnu-efi-3.0.15
# hwdata.
tar -xf hwdata-0.362.tar.gz
cd hwdata-0.362
./configure --prefix=/usr
make
make install
rm -f /usr/lib/modprobe.d/dist-blacklist.conf
install -t /usr/share/licenses/hwdata -Dm644 COPYING
cd ..
rm -rf hwdata-0.362
# Systemd (initial build; will be rebuilt later to support more features).
tar -xf systemd-stable-251.4.tar.gz
cd systemd-stable-251.4
sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
mkdir systemd-build; cd systemd-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var --buildtype=minsize -Dmode=release -Dversion-tag=251.4-massos -Dshared-lib-tag=251.4-massos -Dbpf-framework=false -Dcryptolib=openssl -Ddefault-compression=xz -Ddefault-dnssec=no -Ddns-over-tls=openssl -Dfallback-hostname=massos -Dhomed=false -Dinstall-tests=false -Dman=true -Dpamconfdir=/etc/pam.d -Drpmmacrosdir=no -Dsysusers=false -Dtests=false -Duserdb=false ..
ninja
ninja install
systemd-machine-id-setup
systemctl preset-all
systemctl disable systemd-time-wait-sync.service
cat >> /etc/pam.d/system-session << END
session  required    pam_loginuid.so
session  optional    pam_systemd.so
END
cat > /etc/pam.d/systemd-user << END
account  required    pam_access.so
account  include     system-account
session  required    pam_env.so
session  required    pam_limits.so
session  required    pam_unix.so
session  required    pam_loginuid.so
session  optional    pam_keyinit.so force revoke
session  optional    pam_systemd.so
auth     required    pam_deny.so
password required    pam_deny.so
END
install -t /usr/share/licenses/systemd -Dm644 ../LICENSE.GPL2 ../LICENSE.LGPL2.1 ../LICENSES/*
cd ../..
cp systemd-units/* /usr/lib/systemd/system
systemctl enable gpm.service
rm -rf systemd-stable-251.4
# D-Bus (initial build; will be rebuilt later for X and libaudit support).
tar -xf dbus-1.14.0.tar.xz
cd dbus-1.14.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run --disable-static --disable-doxygen-docs --with-console-auth-dir=/run/console --with-system-pid-file=/run/dbus/pid --with-system-socket=/run/dbus/system_bus_socket
make
make install
ln -sf /etc/machine-id /var/lib/dbus
install -t /usr/share/licenses/dbus -Dm644 COPYING
cd ..
rm -rf dbus-1.14.0
# Man-DB.
tar -xf man-db-2.10.2.tar.xz
cd man-db-2.10.2
./configure --prefix=/usr --sysconfdir=/etc --with-systemdsystemunitdir=/usr/lib/systemd/system --with-db=gdbm --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx
make
make install
install -t /usr/share/licenses/man-db -Dm644 COPYING COPYING.LIB
cd ..
rm -rf man-db-2.10.2
# Procps-NG.
tar -xf procps-ng-4.0.0.tar.xz
cd procps-ng-4.0.0
./configure --prefix=/usr --disable-static --disable-kill --with-systemd
make
make install
install -t /usr/share/licenses/procps-ng -Dm644 COPYING COPYING.LIB
cd ..
rm -rf procps-ng-4.0.0
# util-linux.
tar -xf util-linux-2.38.1.tar.xz
cd util-linux-2.38.1
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --without-python runstatedir=/run
make
make install
install -t /usr/share/licenses/util-linux -Dm644 COPYING
cd ..
rm -rf util-linux-2.38.1
# FUSE2.
tar -xf fuse-2.9.9.tar.gz
cd fuse-2.9.9
patch -Np1 -i ../patches/fuse-2.9.9-glibc234.patch
autoreconf -fi
UDEV_RULES_PATH=/usr/lib/udev/rules.d MOUNT_FUSE_PATH=/usr/bin ./configure --prefix=/usr --libdir=/usr/lib --enable-lib --enable-util --disable-example --disable-static
make
make install
rm -f /etc/init.d/fuse
chmod 4755 /usr/bin/fusermount
install -t /usr/share/licenses/fuse2 -Dm644 COPYING COPYING.LIB
cd ..
rm -rf fuse-2.9.9
# FUSE3.
tar -xf fuse-3.12.0.tar.xz
cd fuse-3.12.0
sed -i '/^udev/,$ s/^/#/' util/meson.build
mkdir fuse3-build; cd fuse3-build
meson --prefix=/usr --buildtype=minsize -Dexamples=false -Dtests=false ..
ninja
ninja install
chmod u+s /usr/bin/fusermount3
cat > /etc/fuse.conf << END
# Set the maximum number of FUSE mounts allowed to non-root users.
# The default is 1000.
#
#mount_max = 1000

# Allow non-root users to specify the 'allow_other' or 'allow_root'
# mount options.
#
#user_allow_other
END
install -t /usr/share/licenses/fuse3 -Dm644 ../LICENSE ../GPL2.txt ../LGPL2.txt
cd ../..
rm -rf fuse-3.12.0
# e2fsprogs.
tar -xf e2fsprogs-1.46.5.tar.xz
cd e2fsprogs-1.46.5
mkdir e2-build; cd e2-build
../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs --disable-fsck --disable-libblkid --disable-libuuid --disable-uuidd
make
make install
rm -f /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
install -t /usr/share/licenses/e2fsprogs -Dm644 ../../extra-package-licenses/e2fsprogs-license.txt
cd ../..
rm -rf e2fsprogs-1.46.5
# dosfstools.
tar -xf dosfstools-4.2.tar.gz
cd dosfstools-4.2
./configure --prefix=/usr --enable-compat-symlinks --mandir=/usr/share/man --docdir=/usr/share/doc/dosfstools
make
make install
install -t /usr/share/licenses/dosfstools -Dm644 COPYING
cd ..
rm -rf dosfstools-4.2
# dracut.
tar -xf dracut-056.tar.gz
cd dracut-056
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --systemdsystemunitdir=/usr/lib/systemd/system --bashcompletiondir=/usr/share/bash-completion/completions
make
make install
cat > /etc/dracut.conf.d/massos.conf << "END"
# Default dracut configuration file for MassOS.

# Compression to use for the initramfs.
compress="xz"

# Optimise the initramfs by excluding some unnecessary modules.
omit_dracutmodules+=" nbd network network-manager kernel-modules-extra kernel-network-modules qemu qemu-net "
END
install -t /usr/share/licenses/dracut -Dm644 COPYING
cd ..
rm -rf dracut-056
# LZO.
tar -xf lzo-2.10.tar.gz
cd lzo-2.10
./configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/lzo -Dm644 COPYING
cd ..
rm -rf lzo-2.10
# lzop.
tar -xf lzop-1.04.tar.gz
cd lzop-1.04
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/lzop -Dm644 COPYING
cd ..
rm -rf lzop-1.04
# squashfs-tools.
tar -xf squashfs-tools-4.5.1.tar.gz
cd squashfs-tools-4.5.1/squashfs-tools
make GZIP_SUPPORT=1 XZ_SUPPORT=1 LZO_SUPPORT=1 LZMA_XZ_SUPPORT=1 LZ4_SUPPORT=1 ZSTD_SUPPORT=1 XATTR_SUPPORT=1
make INSTALL_PREFIX=/usr INSTALL_MANPAGES_DIR=/usr/share/man/man1 install
install -t /usr/share/licenses/squashfs-tools -Dm644 ../COPYING
cd ../..
rm -rf squashfs-tools-4.5.1
# squashfuse.
tar -xf squashfuse-0.1.105.tar.gz
cd squashfuse-0.1.105
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/include/squashfuse -Dm644 *.h
install -t /usr/share/licenses/squashfuse -Dm644 LICENSE
cd ..
rm -rf squashfuse-0.1.105
# libaio.
tar -xf libaio-libaio-0.3.113.tar.gz
cd libaio-libaio-0.3.113
sed -i '/install.*libaio.a/s/^/#/' src/Makefile
make
make install
install -t /usr/share/licenses/libaio -Dm644 COPYING
cd ..
rm -rf libaio-libaio-0.3.113
# mdadm.
tar -xf mdadm-4.2.tar.xz
cd mdadm-4.2
make
make BINDIR=/usr/sbin install
install -t /usr/share/licenses/mdadm -Dm644 COPYING
cd ..
rm -rf mdadm-4.2
# thin-provisioning-tools.
tar -xf thin-provisioning-tools-0.9.0.tar.gz
cd thin-provisioning-tools-0.9.0
autoconf
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/thin-provisioning-tools -Dm644 COPYING
cd ..
rm -rf thin-provisioning-tools-0.9.0
# LVM2.
tar -xf LVM2.2.03.16.tgz
cd LVM2.2.03.16
sed -i 201,202d configure.ac
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-cmdlib --enable-dmeventd --enable-lvmpolld --enable-pkgconfig --enable-readline --enable-udev_rules --enable-udev_sync
make
make install
make install_systemd_units
install -t /usr/share/licenses/lvm2 -Dm644 COPYING{,.BSD,.LIB}
cd ..
rm -rf LVM2.2.03.16
# dmraid.
tar -xf dmraid-1.0.0.rc16-3.tar.bz2
cd dmraid/1.0.0.rc16-3/dmraid
./configure --prefix=/usr --enable-led --enable-intel_led
make -j1
make -j1 install
install -t /usr/share/licenses/dmraid -Dm644 LICENSE{,_GPL,_LGPL}
cd ../../..
rm -rf dmraid
# btrfs-progs.
tar -xf btrfs-progs-v5.19.1.tar.xz
cd btrfs-progs-v5.19.1
sed -i 18d common/device-utils.c
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/btrfs-progs -Dm644 COPYING
cd ..
rm -rf btrfs-progs-v5.19.1
# inih.
tar -xf inih-r56.tar.gz
cd inih-r56
mkdir inih-build; cd inih-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/inih -Dm644 ../LICENSE.txt
cd ../..
rm -rf inih-r56
# Userspace-RCU (dependency of xfsprogs since 5.14.0).
tar -xf userspace-rcu-0.13.2.tar.bz2
cd userspace-rcu-0.13.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/userspace-rcu -Dm644 LICENSE gpl-2.0.txt lgpl-2.1.txt lgpl-relicensing.txt
cd ..
rm -rf userspace-rcu-0.13.2
# xfsprogs.
tar -xf xfsprogs-5.19.0.tar.xz
cd xfsprogs-5.19.0
make DEBUG=-DNDEBUG INSTALL_USER=root INSTALL_GROUP=root
make install
make install-dev
cd ..
rm -rf xfsprogs-5.19.0
# ntfs-3g.
tar -xf ntfs-3g-2022.5.17.tar.gz
cd ntfs-3g-2022.5.17
./autogen.sh
./configure --prefix=/usr --disable-static --with-fuse=external
make
make install
ln -s ../bin/ntfs-3g /usr/sbin/mount.ntfs
ln -s ntfs-3g.8 /usr/share/man/man8/mount.ntfs.8
install -t /usr/share/licenses/ntfs-3g -Dm644 COPYING COPYING.LIB
cd ..
rm -rf ntfs-3g-2022.5.17
# exfatprogs.
tar -xf exfatprogs-1.1.3.tar.xz
cd exfatprogs-1.1.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/exfatprogs -Dm644 COPYING
cd ..
rm -rf exfatprogs-1.1.3
# udftools.
tar -xf udftools-2.3.tar.gz
cd udftools-2.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/udftools -Dm644 COPYING
cd ..
rm -rf udftools-2.3
# Fakeroot.
tar -xf fakeroot_1.29.orig.tar.gz
cd fakeroot-1.29
./configure --prefix=/usr --libdir=/usr/lib/libfakeroot --disable-static --with-ip=sysv
make
make install
mkdir -p /etc/ld.so.conf.d
echo "/usr/lib/libfakeroot" > /etc/ld.so.conf.d/fakeroot.conf
ldconfig
install -t /usr/share/licenses/fakeroot -Dm644 COPYING
cd ..
rm -rf fakeroot-1.29
# Parted.
tar -xf parted-3.5.tar.xz
cd parted-3.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/parted -Dm644 COPYING
cd ..
rm -rf parted-3.5
# Popt.
tar -xf popt-popt-1.19-release.tar.gz
cd popt-popt-1.19-release
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/popt -Dm644 COPYING
cd ..
rm -rf popt-popt-1.19-release
# gptfdisk.
tar -xf gptfdisk-1.0.9.tar.gz
cd gptfdisk-1.0.9
patch -Np1 -i ../patches/gptfdisk-1.0.9-upstreamfix.patch
sed -i 's|ncursesw/||' gptcurses.cc
make
install -t /usr/sbin -Dm755 gdisk cgdisk sgdisk fixparts
install -t /usr/share/man/man8 -Dm644 gdisk.8 cgdisk.8 sgdisk.8 fixparts.8
install -t /usr/share/licenses/gptfdisk -Dm644 COPYING
cd ..
rm -rf gptfdisk-1.0.9
# run-parts (from debianutils).
tar -xf debianutils-5.5.tar.gz
cd debianutils-5.5
./configure --prefix=/usr
make run-parts
install -t /usr/bin -Dm755 run-parts
install -t /usr/share/man/man8 -Dm644 run-parts.8
install -t /usr/share/licenses/run-parts -Dm644 /usr/share/licenses/gptfdisk/COPYING
cd ..
rm -rf debianutils-5.5
# libpaper.
tar -xf libpaper_1.1.28.tar.gz
cd libpaper-1.1.28
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
cat > /etc/papersize << "END"
# Specify the default paper size here. See papersize(5) for more information.
END
install -dm755 /etc/libpaper.d
install -t /usr/share/licenses/libpaper -Dm644 COPYING
cd ..
rm -rf libpaper-1.1.28
# xxhash.
tar -xf xxHash-0.8.1.tar.gz
cd xxHash-0.8.1
make PREFIX=/usr CFLAGS="$CFLAGS -fPIC"
make PREFIX=/usr install
rm -f /usr/lib/libxxhash.a
ln -sf xxhsum.1 /usr/share/man/man1/xxh32sum.1
ln -sf xxhsum.1 /usr/share/man/man1/xxh64sum.1
ln -sf xxhsum.1 /usr/share/man/man1/xxh128sum.1
install -t /usr/share/licenses/xxhash -Dm644 LICENSE
cd ..
rm -rf xxHash-0.8.1
# rsync.
tar -xf rsync-3.2.6.tar.gz
cd rsync-3.2.6
./configure --prefix=/usr --without-included-popt --without-included-zlib
make
make install
install -t /usr/share/licenses/rsync -Dm644 COPYING
cd ..
rm -rf rsync-3.2.6
# Brotli.
tar -xf brotli-1.0.9.tar.gz
cd brotli-1.0.9
./bootstrap
./configure --prefix=/usr
make
python setup.py build
make install
python setup.py install --optimize=1
rm -f /usr/lib/libbrotli{common,dec,enc}.a
install -t /usr/share/licenses/brotli -Dm644 LICENSE
cd ..
rm -rf brotli-1.0.9
# libnghttp2.
tar -xf nghttp2-1.50.0.tar.xz
cd nghttp2-1.50.0
./configure --prefix=/usr --disable-static --enable-lib-only
make
make install
install -t /usr/share/licenses/libnghttp2 -Dm644 COPYING
cd ..
rm -rf nghttp2-1.50.0
# curl (INITIAL BUILD; will be rebuilt later to support FAR MORE FEATURES).
tar -xf curl-7.85.0.tar.xz
cd curl-7.85.0
./configure --prefix=/usr --disable-static --with-openssl --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
install -t /usr/share/licenses/curl -Dm644 COPYING
cd ..
rm -rf curl-7.85.0
# jsoncpp.
tar -xf jsoncpp-1.9.5.tar.gz
cd jsoncpp-1.9.5
mkdir jsoncpp-build; cd jsoncpp-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/jsoncpp -Dm644 ../LICENSE
cd ../..
rm -rf jsoncpp-1.9.5
# rhash.
tar -xf RHash-1.4.2.tar.gz
cd RHash-1.4.2
./configure --prefix=/usr --sysconfdir=/etc --extra-cflags="$CFLAGS"
make
make -j1 install
make -j1 -C librhash install-lib-headers install-lib-shared install-so-link
chmod 755 /usr/lib/librhash.so.0
install -t /usr/share/licenses/rhash -Dm644 COPYING
cd ..
rm -rf RHash-1.4.2
# CMake.
tar -xf cmake-3.24.2.tar.gz
cd cmake-3.24.2
sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake
./bootstrap --prefix=/usr --parallel=$(nproc) --generator=Ninja --docdir=/share/doc/cmake --mandir=/share/man --system-libs --sphinx-man
ninja
ninja install
install -t /usr/share/licenses/cmake -Dm644 Copyright.txt
cd ..
rm -rf cmake-3.24.2
# c-ares.
tar -xf c-ares-1.18.1.tar.gz
cd c-ares-1.18.1
mkdir c-ares-build; cd c-ares-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/c-ares -Dm644 ../LICENSE.md
cd ../..
rm -rf c-ares-1.18.1
# JSON-C.
tar -xf json-c-0.16.tar.gz
cd json-c-0.16
mkdir json-c-build; cd json-c-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/json-c -Dm644 ../COPYING
cd ../..
rm -rf json-c-0.16
# cryptsetup.
tar -xf cryptsetup-2.5.0.tar.xz
cd cryptsetup-2.5.0
./configure --prefix=/usr --disable-asciidoc --disable-ssh-token
make
make install
install -t /usr/share/licenses/cryptsetup -Dm644 COPYING COPYING.LGPL
cd ..
rm -rf cryptsetup-2.5.0
# libtpms.
tar -xf libtpms-0.9.2.tar.gz
cd libtpms-0.9.2
./autogen.sh --prefix=/usr --with-openssl --with-tpm2
make
make install
rm -f /usr/lib/libtpms.a
install -t /usr/share/licenses/libtpms -Dm644 LICENSE
cd ..
rm -rf libtpms-0.9.2
# tpm2-tss.
tar -xf tpm2-tss-3.2.0.tar.gz
cd tpm2-tss-3.2.0
cat > lib/tss2-tcti-libtpms.map << "END"
{
    global:
        Tss2_Tcti_Info;
        Tss2_Tcti_Libtpms_Init;
    local:
        *;
};
END
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-runstatedir=/run --with-sysusersdir=/usr/lib/sysusers.d --with-tmpfilesdir=/usr/lib/tmpfiles.d --with-udevrulesprefix="60-" --disable-static
make
make install
install -t /usr/share/licenses/tpm2-tss -Dm644 LICENSE
cd ..
rm -rf tpm2-tss-3.2.0
# libusb.
tar -xf libusb-1.0.26.tar.bz2
cd libusb-1.0.26
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libusb -Dm644 COPYING
cd ..
rm -rf libusb-1.0.26
# libmtp.
tar -xf libmtp-1.1.20.tar.gz
cd libmtp-1.1.20
./configure --prefix=/usr --disable-rpath --disable-static --with-udev=/usr/lib/udev
make
make install
install -t /usr/share/licenses/libmtp -Dm644 COPYING
cd ..
rm -rf libmtp-1.1.20
# libnfs.
tar -xf libnfs-4.0.0.tar.gz
cd libnfs-libnfs-4.0.0
./bootstrap
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libnfs -Dm644 COPYING LICENCE-BSD.txt LICENCE-GPL-3.txt LICENCE-LGPL-2.1.txt
cd ..
rm -rf libnfs-libnfs-4.0.0
# libieee1284.
tar -xf libieee1284-0_2_11-12-g0663326.tar.xz
cd libieee1284-0_2_11-12-g0663326
patch -Np1 -i ../patches/libieee1284-0.2.11-python3.patch
./bootstrap
./configure --prefix=/usr --mandir=/usr/share/man --disable-static --with-python
make -j1
make -j1 install
install -t /usr/share/licenses/libieee1284 -Dm644 COPYING
cd ..
rm -rf libieee1284-0_2_11-12-g0663326
# PCRE.
tar -xf pcre-8.45.tar.bz2
cd pcre-8.45
./configure --prefix=/usr --enable-unicode-properties --enable-jit --enable-pcre16 --enable-pcre32 --enable-pcregrep-libz --enable-pcregrep-libbz2 --enable-pcretest-libreadline --disable-static
make
make install
install -t /usr/share/licenses/pcre -Dm644 LICENCE
cd ..
rm -rf pcre-8.45
# PCRE2.
tar -xf pcre2-10.40.tar.bz2
cd pcre2-10.40
./configure --prefix=/usr --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline --disable-static
make
make install
install -t /usr/share/licenses/pcre2 -Dm644 LICENCE
cd ..
rm -rf pcre2-10.40
# Grep (rebuild for PCRE support).
tar -xf grep-3.8.tar.xz
cd grep-3.8
./configure --prefix=/usr
make
make install
cd ..
rm -rf grep-3.8
# Less (rebuild for PCRE2 support).
tar -xf less-608.tar.gz
cd less-608
./configure --prefix=/usr --sysconfdir=/etc --with-regex=pcre2
make
make install
cd ..
rm -rf less-608
# libunistring.
tar -xf libunistring-1.0.tar.xz
cd libunistring-1.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libunistring -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libunistring-1.0
# libidn2.
tar -xf libidn2-2.3.3.tar.gz
cd libidn2-2.3.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libidn2 -Dm644 COPYING COPYINGv2 COPYING.LESSERv3 COPYING.unicode
cd ..
rm -rf libidn2-2.3.3
# whois.
tar -xf whois-5.5.13.tar.gz
cd whois-5.5.13
make
make prefix=/usr install-whois
make prefix=/usr install-mkpasswd
make prefix=/usr install-pos
install -t /usr/share/licenses/whois -Dm644 COPYING
cd ..
rm -rf whois-5.5.13
# libpsl.
tar -xf libpsl-0.21.1.tar.gz
cd libpsl-0.21.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpsl -Dm644 COPYING
cd ..
rm -rf libpsl-0.21.1
# usbutils.
tar -xf usbutils-014.tar.xz
cd usbutils-014
./configure --prefix=/usr --datadir=/usr/share/hwdata
make
make install
install -t /usr/share/licenses/usbutils -Dm644 LICENSES/*
cd ..
rm -rf usbutils-014
# pciutils.
tar -xf pciutils-3.8.0.tar.xz
cd pciutils-3.8.0
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes install install-lib
chmod 755 /usr/lib/libpci.so
install -t /usr/share/licenses/pciutils -Dm644 COPYING
cd ..
rm -rf pciutils-3.8.0
# libtasn1.
tar -xf libtasn1-4.19.0.tar.gz
cd libtasn1-4.19.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libtasn1 -Dm644 COPYING
cd ..
rm -rf libtasn1-4.19.0
# p11-kit.
tar -xf p11-kit-0.24.1.tar.xz
cd p11-kit-0.24.1
sed '20,$ d' -i trust/trust-extract-compat
cat >> trust/trust-extract-compat << END
/usr/libexec/make-ca/copy-trust-modifications
/usr/sbin/make-ca -f -g
END
mkdir p11-build; cd p11-build
meson --prefix=/usr --buildtype=minsize -Dtrust_paths=/etc/pki/anchors ..
ninja
ninja install
ln -sf /usr/libexec/p11-kit/trust-extract-compat /usr/bin/update-ca-certificates
ln -sf ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
install -t /usr/share/licenses/p11-kit -Dm644 ../COPYING
cd ../..
rm -rf p11-kit-0.24.1
# make-ca.
tar -xf make-ca-1.10.tar.xz
cd make-ca-1.10
make install
mkdir -p /etc/ssl/local
make-ca -fg
systemctl enable update-pki.timer
install -t /usr/share/licenses/make-ca -Dm644 LICENSE{,.GPLv3,.MIT}
cd ..
rm -rf make-ca-1.10
# pkcs11-helper.
tar -xf pkcs11-helper-1.29.0.tar.bz2
cd pkcs11-helper-1.29.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/pkcs11-helper -Dm644 COPYING COPYING.BSD COPYING.GPL
cd ..
rm -rf pkcs11-helper-1.29.0
# certifi (Python module).
tar -xf python-certifi-2022.06.15.tar.gz
cd python-certifi-2022.06.15
python setup.py install --optimize=1
install -t /usr/share/licenses/certifi -Dm644 LICENSE
cd ..
rm -rf python-certifi-2022.06.15
# libssh2.
tar -xf libssh2-1.10.0.tar.gz
cd libssh2-1.10.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libssh2 -Dm644 COPYING
cd ..
rm -rf libssh2-1.10.0
# Jansson.
tar -xf jansson-2.13.1.tar.gz
cd jansson-2.13.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/jansson -Dm644 LICENSE
cd ..
rm -rf jansson-2.13.1
# libassuan.
tar -xf libassuan-2.5.5.tar.bz2
cd libassuan-2.5.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libassuan -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libassuan-2.5.5
# Nettle.
tar -xf nettle-3.8.1.tar.gz
cd nettle-3.8.1
./configure --prefix=/usr --disable-static
make
make install
chmod 755 /usr/lib/lib{hogweed,nettle}.so
install -t /usr/share/licenses/nettle -Dm644 COPYINGv2 COPYINGv3 COPYING.LESSERv3
cd ..
rm -rf nettle-3.8.1
# GNUTLS.
tar -xf gnutls-3.7.7.tar.xz
cd gnutls-3.7.7
./configure --prefix=/usr --disable-guile --disable-rpath --with-default-trust-store-pkcs11="pkcs11:" --enable-openssl-compatibility --enable-ssl3-support
make
make install
install -t /usr/share/licenses/gnutls -Dm644 LICENSE
cd ..
rm -rf gnutls-3.7.7
# libevent.
tar -xf libevent-2.1.12-stable.tar.gz
cd libevent-2.1.12-stable
mkdir EVENT-build; cd EVENT-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DEVENT__LIBRARY_TYPE=SHARED -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libevent -Dm644 ../LICENSE
cd ../..
rm -rf libevent-2.1.12-stable
# OpenLDAP.
tar -xf openldap-2.6.3.tgz
cd openldap-2.6.3
groupadd -g 83 ldap
useradd -c "OpenLDAP Server Daemon" -d /var/lib/openldap -u 83 -g ldap -s /sbin/nologin ldap
sed -i 's/-m 644 $(LIBRARY)/-m 755 $(LIBRARY)/' libraries/{liblber,libldap}/Makefile.in
sed -i 's/#define LDAPI_SOCK LDAP_RUNDIR LDAP_DIRSEP "run" LDAP_DIRSEP "ldapi"/#define LDAPI_SOCK LDAP_DIRSEP "run" LDAP_DIRSEP "openldap" LDAP_DIRSEP "ldapi"/' include/ldap_defaults.h
sed -i 's|%LOCALSTATEDIR%/run|/run/openldap|' servers/slapd/slapd.{conf,ldif}
sed -i 's|-$(MKDIR) $(DESTDIR)$(localstatedir)/run|-$(MKDIR) $(DESTDIR)/run/openldap|' servers/slapd/Makefile.in
autoconf
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var/lib/openldap --with-cyrus-sasl --with-threads --enable-backends --enable-balancer --enable-crypt --enable-dynamic --enable-ipv6 --enable-modules --enable-overlays=mod --enable-rlookups --enable-slapd --enable-spasswd --enable-syslog --enable-versioning --disable-debug --disable-sql --disable-static --disable-wt
make depend
make
make install
ln -sf ../libexec/slapd /usr/sbin/slapd
chmod 700 /var/lib/openldap
chown -R ldap:ldap /var/lib/openldap
chmod 640 /etc/openldap/slapd.{conf,ldif}
chown root:ldap /etc/openldap/slapd.{conf,ldif}
sed -e "s/\.la/.so/" -i /etc/openldap/slapd.{conf,ldif}{,.default}
install -t /usr/share/licenses/openldap -Dm644 COPYRIGHT LICENSE
cd ..
rm -rf openldap-2.6.3
# npth.
tar -xf npth-1.6.tar.bz2
cd npth-1.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/npth -Dm644 COPYING.LIB
cd ..
rm -rf npth-1.6
# libksba.
tar -xf libksba-1.6.1.tar.bz2
cd libksba-1.6.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libksba -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv3
cd ..
rm -rf libksba-1.6.1
# GNUPG.
tar -xf gnupg-2.3.7.tar.bz2
cd gnupg-2.3.7
sed -i '/noinst_SCRIPTS = gpg-zip/c sbin_SCRIPTS += gpg-zip' tools/Makefile.in
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-g13
make
make install
install -t /usr/share/licenses/gnupg -Dm644 COPYING COPYING.CC0 COPYING.GPL2 COPYING.LGPL21 COPYING.LGPL3 COPYING.other
cd ..
rm -rf gnupg-2.3.7
# krb5.
tar -xf krb5-1.20.tar.gz
cd krb5-1.20/src
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var/lib --runstatedir=/run --disable-rpath --enable-dns-for-realm --with-system-et --with-system-ss --without-system-verto
make
make install
install -t /usr/share/licenses/krb5 -Dm644 ../NOTICE
cd ../..
rm -rf krb5-1.20
# rtmpdump.
tar -xf rtmpdump-2.4-20210219-gf1b83c1.tar.xz
cd rtmpdump-2.4-20210219-gf1b83c1
patch -Np1 -i ../patches/rtmpdump-2.4-openssl.patch
make prefix=/usr mandir=/usr/share/man OPT="$CFLAGS"
make prefix=/usr mandir=/usr/share/man install
rm -f /usr/lib/librtmp.a
install -t /usr/share/licenses/rtmpdump -Dm644 COPYING
cd ..
rm -rf rtmpdump-2.4-20210219-gf1b83c1
# curl (rebuild to support more features).
tar -xf curl-7.85.0.tar.xz
cd curl-7.85.0
./configure --prefix=/usr --disable-static --with-openssl --with-libssh2 --with-gssapi --enable-ares --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
cd ..
rm -rf curl-7.85.0
# OpenVPN.
tar -xf openvpn-2.5.7.tar.gz
cd openvpn-2.5.7
sed -i '/^CONFIGURE_DEFINES=/s/set/env/g' configure.ac
autoreconf -fi
./configure --prefix=/usr --enable-pkcs11 --enable-plugins --enable-systemd --enable-x509-alt-username
make
make install
while read -r line; do
  case "$(file -bS --mime-type "$line")" in
    "text/x-shellscript") install -Dm755 "$line" "/usr/share/openvpn/$line" ;;
    *) install -Dm644 "$line" "/usr/share/openvpn/$line" ;;
  esac
done <<< $(find contrib -type f)
cp -r sample/sample-config-files /usr/share/openvpn/examples
install -t /usr/share/licenses/openvpn -Dm644 COPYING COPYRIGHT.GPL
cd ..
rm -rf openvpn-2.5.7
# SWIG.
tar -xf swig-4.0.2.tar.gz
cd swig-4.0.2
./autogen.sh
./configure --prefix=/usr --without-maximum-compile-warnings
make
make install
install -t /usr/share/licenses/swig -Dm644 COPYRIGHT LICENSE LICENSE-GPL LICENSE-UNIVERSITIES
cd ..
rm -rf swig-4.0.2
# libcap-ng.
tar -xf libcap-ng-0.8.3.tar.gz
cd libcap-ng-0.8.3
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libcap-ng -Dm644 COPYING COPYING.LIB LICENSE
cd ..
rm -rf libcap-ng-0.8.3
# GPGME.
tar -xf gpgme-1.18.0.tar.bz2
cd gpgme-1.18.0
patch -Np1 -i ../patches/gpgme-1.18.0-python3.10.patch
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gpgme -Dm644 COPYING COPYING.LESSER LICENSES
cd ..
rm -rf gpgme-1.18.0
# SQLite.
tar -xf sqlite-autoconf-3390300.tar.gz
cd sqlite-autoconf-3390300
CPPFLAGS+=" -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS4=1 -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 -DSQLITE_ENABLE_DBSTAT_VTAB=1 -DSQLITE_SECURE_DELETE=1 -DSQLITE_ENABLE_FTS3_TOKENIZER=1" ./configure --prefix=/usr --disable-static --enable-fts5
make
make install
install -dm755 /usr/share/licenses/sqlite
cat > /usr/share/licenses/sqlite/LICENSE << "END"
The code and documentation of SQLite is dedicated to the public domain.
See https://www.sqlite.org/copyright.html for more information.
END
cd ..
rm -rf sqlite-autoconf-3390300
# Cyrus SASL (rebuild to support krb5 and OpenLDAP).
tar -xf cyrus-sasl-2.1.28.tar.gz
cd cyrus-sasl-2.1.28
./configure --prefix=/usr --sysconfdir=/etc --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-ldap --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
cd ..
rm -rf cyrus-sasl-2.1.28
# libtirpc.
tar -xf libtirpc-1.3.3.tar.bz2
cd libtirpc-1.3.3
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libtirpc -Dm644 COPYING
cd ..
rm -rf libtirpc-1.3.3
# libnsl.
tar -xf libnsl-2.0.0.tar.xz
cd libnsl-2.0.0
./configure --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libnsl -Dm644 COPYING
cd ..
rm -rf libnsl-2.0.0
# Wget.
tar -xf wget-1.21.3.tar.gz
cd wget-1.21.3
./configure --prefix=/usr --sysconfdir=/etc --with-cares --with-metalink
make
make install
install -t /usr/share/licenses/wget -Dm644 COPYING
cd ..
rm -rf wget-1.21.3
# Audit.
tar -xf audit-userspace-3.0.9.tar.gz
cd audit-userspace-3.0.9
patch -Np1 -i ../patches/audit-3.0.7-WorkaroundBuildIssue.patch
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --enable-gssapi-krb5 --enable-systemd --with-libcap-ng CFLAGS="$CFLAGS -fno-PIE" LDFLAGS="$LDFLAGS -no-pie"
make
make install
sed -i 's|"audit.h"|<linux/audit.h>|' /usr/include/libaudit.h
install -dm0700 /var/log/audit
install -dm0750 /etc/audit/rules.d
cat > /etc/audit/rules.d/default.rules << END
-w /etc/passwd -p rwxa
-w /etc/security -p rwxa
-A always,exclude -F msgtype=BPF
-A always,exclude -F msgtype=SERVICE_STOP
-A always,exclude -F msgtype=SERVICE_START
END
systemctl enable auditd
install -t /usr/share/licenses/audit -Dm644 COPYING COPYING.LIB
cd ..
rm -rf audit-userspace-3.0.9
# AppArmor.
tar -xf apparmor-3.1.1.tar.gz
cd apparmor-3.1.1/libraries/libapparmor
./configure --prefix=/usr --with-perl --with-python
make
cd ../..
make -C binutils
make -C parser
make -C profiles
make -C utils
make -C changehat/pam_apparmor
make -C libraries/libapparmor install
make -C changehat/pam_apparmor install
make -C parser -j1 install install-systemd
make -C profiles install
make -C utils install
rm -f /usr/lib/libapparmor.a
chmod 755 /usr/lib/perl5/*/vendor_perl/auto/LibAppArmor/LibAppArmor.so
systemctl enable apparmor
install -t /usr/share/licenses/apparmor -Dm644 LICENSE libraries/libapparmor/COPYING.LGPL changehat/pam_apparmor/COPYING
cd ..
rm -rf apparmor-3.1.1
# Linux-PAM (rebuild to support Audit).
tar -xf Linux-PAM-1.5.2.tar.xz
cd Linux-PAM-1.5.2
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --enable-securedir=/usr/lib/security --disable-pie
make
make install
chmod 4755 /usr/sbin/unix_chkpwd
cd ..
rm -rf Linux-PAM-1.5.2
# Shadow (rebuild to support Audit).
tar -xf shadow-4.12.3.tar.xz
cd shadow-4.12.3
patch -Np1 -i ../patches/shadow-4.12.2-MassOS.patch
./configure --sysconfdir=/etc --disable-static --with-audit --with-group-name-max-length=32 --with-libcrack
make
make exec_prefix=/usr install
make -C man install-man
useradd -D --gid 999
sed -i 's/yes/no/' /etc/default/useradd
for FUNCTION in FAIL_DELAY FAILLOG_ENAB LASTLOG_ENAB MAIL_CHECK_ENAB OBSCURE_CHECKS_ENAB PORTTIME_CHECKS_ENAB QUOTAS_ENAB CONSOLE MOTD_FILE FTMP_FILE NOLOGINS_FILE ENV_HZ PASS_MIN_LEN SU_WHEEL_ONLY CRACKLIB_DICTPATH PASS_CHANGE_TRIES PASS_ALWAYS_WARN CHFN_AUTH ENCRYPT_METHOD ENVIRON_FILE; do sed -i "s/^${FUNCTION}/# &/" /etc/login.defs; done
cat > /etc/pam.d/login << END
auth      optional    pam_faildelay.so  delay=3000000
auth      requisite   pam_nologin.so
auth      include     system-auth
account   required    pam_access.so
account   include     system-account
session   required    pam_env.so
session   required    pam_limits.so
session   optional    pam_lastlog.so
session   include     system-session
password  include     system-password
END
cat > /etc/pam.d/passwd << END
password  include     system-password
END
cat > /etc/pam.d/su << END
auth      sufficient  pam_rootok.so
auth      include     system-auth
auth      required    pam_wheel.so use_uid
account   include     system-account
session   required    pam_env.so
session   include     system-session
END
cat > /etc/pam.d/chage << END
auth      sufficient  pam_rootok.so
auth      include     system-auth
account   include     system-account
session   include     system-session
password  required    pam_permit.so
END
for PROGRAM in chfn chgpasswd chpasswd chsh groupadd groupdel groupmems groupmod newusers useradd userdel usermod; do
  install -m644 /etc/pam.d/chage /etc/pam.d/${PROGRAM}
  sed -i "s/chage/$PROGRAM/" /etc/pam.d/${PROGRAM}
done
rm -f /etc/login.access /etc/limits
cd ..
rm -rf shadow-4.12.3
# Sudo.
tar -xf sudo-SUDO_1_9_11p3.tar.gz
cd sudo-SUDO_1_9_11p3
./configure --prefix=/usr --libexecdir=/usr/lib --disable-pie --with-linux-audit --with-secure-path --with-insults --with-all-insults --with-passwd-tries=5 --with-env-editor --with-passprompt="[sudo] password for %p: "
make
make install
ln -sf libsudo_util.so.0.0.0 /usr/lib/sudo/libsudo_util.so.0
sed -i 's|# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers
sed -i 's|# Defaults secure_path|Defaults secure_path|' /etc/sudoers
sed -i 's|/sbin:/bin|/home/linuxbrew/.linuxbrew/bin:/var/lib/flatpak/exports/bin:/snap/bin|' /etc/sudoers
cat > /etc/sudoers.d/pwfeedback << "END"
# Show astericks when typing the password.
Defaults pwfeedback
END
cat > /etc/pam.d/sudo << "END"
auth      include     system-auth
account   include     system-account
session   required    pam_env.so
session   include     system-session
END
install -t /usr/share/licenses/sudo -Dm644 LICENSE.md
cd ..
rm -rf sudo-SUDO_1_9_11p3
# fcron.
tar -xf fcron-ver3_3_1.tar.gz
cd fcron-ver3_3_1
groupadd -g 22 fcron
useradd -d /dev/null -c "Fcron User" -g fcron -s /sbin/nologin -u 22 fcron
autoupdate
autoconf
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --without-sendmail --with-piddir=/run --with-boot-install=no --with-editor=/usr/bin/nano --with-dsssl-dir=/usr/share/sgml/docbook/dsssl-stylesheets-1.79
make
make install
for i in crondyn cronsighup crontab; do ln -sf f$i /usr/bin/$i; done
ln -sf fcron /usr/sbin/cron
for i in crontab.1 crondyn.1; do ln -sf f$i /usr/share/man/man1/$i; done
for i in crontab.1 crondyn.1; do ln -sf f$i /usr/share/man/fr/man1/$i; done
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
cd ..
rm -rf fcron-ver3_3_1
# lsof.
tar -xf lsof-4.96.3.tar.gz
cd lsof-4.96.3
./Configure linux -n
sed -i "s/-O/$CFLAGS/" Makefile
make
install -m755 lsof /usr/sbin/lsof
install -m644 lsof.8 /usr/share/man/man8/lsof.8
install -dm755 /usr/share/licenses/lsof
cat main.c | head -n31 | tail -n23 > /usr/share/licenses/lsof/LICENSE
cd ..
rm -rf lsof-4.96.3
# NSPR.
tar -xf nspr-4.35.tar.gz
cd nspr-4.35/nspr
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit
make
make install
rm -f /usr/lib/lib{nspr,plc,plds}4.a
rm -f /usr/bin/{compile-et.pl,prerr.properties}
install -t /usr/share/licenses/nspr -Dm644 LICENSE
cd ../..
rm -rf nspr-4.35
# NSS (NOTE: UPDATE BELOW SED WHEN VERSION CHANGES).
tar -xf nss-3.83.tar.gz
cd nss-3.83/nss
mkdir gyp
tar -xf ../../gyp-9ecf45.tar.gz -C gyp --strip-components=1
PATH="$PATH:$PWD/gyp" ./build.sh --target=x64 --enable-libpkix --disable-tests --opt --system-nspr --system-sqlite
install -t /usr/lib -Dm755 ../dist/Release/lib/*.so
install -t /usr/lib -Dm644 ../dist/Release/lib/*.chk
install -t /usr/bin -Dm755 ../dist/Release/bin/{*util,shlibsign,signtool,signver,ssltap}
install -t /usr/share/man/man1 -Dm644 doc/nroff/{*util,signtool,signver,ssltap}.1
install -dm755 /usr/include/nss
cp -r ../dist/{public,private}/nss/* /usr/include/nss
sed pkg/pkg-config/nss.pc.in -e 's|%prefix%|/usr|g' -e 's|%libdir%|${prefix}/lib|g' -e 's|%exec_prefix%|${prefix}|g' -e 's|%includedir%|${prefix}/include/nss|g' -e "s|%NSPR_VERSION%|$(pkg-config --modversion nspr)|g" -e "s|%NSS_VERSION%|3.83.0|g" > /usr/lib/pkgconfig/nss.pc
sed pkg/pkg-config/nss-config.in -e 's|@prefix@|/usr|g' -e "s|@MOD_MAJOR_VERSION@|$(pkg-config --modversion nss | cut -d. -f1)|g" -e "s|@MOD_MINOR_VERSION@|$(pkg-config --modversion nss | cut -d. -f2)|g" -e "s|@MOD_PATCH_VERSION@|$(pkg-config --modversion nss | cut -d. -f3)|g" > /usr/bin/nss-config
chmod 755 /usr/bin/nss-config
ln -sf ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
install -t /usr/share/licenses/nss -Dm644 COPYING
cd ../..
rm -rf nss-3.83
# Git.
tar -xf git-2.37.3.tar.xz
cd git-2.37.3
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --with-libpcre2
make all man
make perllibdir=/usr/lib/perl5/5.36/site_perl install install-man
install -t /usr/share/licenses/git -Dm644 COPYING LGPL-2.1
cd ..
rm -rf git-2.37.3
# libstemmer.
tar -xf snowball-2.2.0.tar.gz
cd snowball-2.2.0
patch -Np1 -i ../patches/libstemmer-2.2.0-sharedlibrary.patch
make
install -m755 libstemmer.so.0 /usr/lib/libstemmer.so.0.0.0
ln -s libstemmer.so.0.0.0 /usr/lib/libstemmer.so.0
ln -s libstemmer.so.0 /usr/lib/libstemmer.so
install -m644 include/libstemmer.h /usr/include/libstemmer.h
ldconfig
install -t /usr/share/licenses/libstemmer -Dm644 COPYING
cd ..
rm -rf snowball-2.2.0
# Pahole.
tar -xf pahole-1.24.tar.gz
cd pahole-1.24
tar -xf ../libbpf-1.0.0.tar.gz -C lib/bpf --strip-components=1
mkdir pahole-build; cd pahole-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -D__LIB=lib -Wno-dev -G Ninja ..
ninja
ninja install
mv /usr/share/dwarves/runtime/python/ostra.py /usr/lib/python3.10/ostra.py
rm -rf /usr/share/dwarves/runtime/python
install -t /usr/share/licenses/pahole -Dm644 ../COPYING
cd ../..
rm -rf pahole-1.24
# libsmbios.
tar -xf libsmbios-2.4.3.tar.gz
cd libsmbios-2.4.3
./autogen.sh --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
patchelf --remove-rpath /usr/sbin/smbios-sys-info-lite
cp -r out/public-include/* /usr/include
install -t /usr/share/licenses/libsmbios -Dm644 COPYING COPYING-GPL
cd ..
rm -rf libsmbios-2.4.3
# DKMS.
tar -xf dkms-3.0.6.tar.gz
cd dkms-3.0.6
patch -Np1 -i ../patches/dkms-3.0.6-egrep.patch
make BASHDIR=/usr/share/bash-completion/completions install
install -t /usr/share/licenses/dkms -Dm644 COPYING
cd ..
rm -rf dkms-3.0.6
# GLib.
tar -xf glib-2.74.0.tar.xz
cd glib-2.74.0
patch -Np1 -i ../patches/glib-2.72.0-lessnoisy.patch
patch -Np1 -i ../patches/glib-2.74.0-upstreamfix.patch
mkdir glib-build; cd glib-build
meson --prefix=/usr --buildtype=minsize -Dman=true -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/glib -Dm644 ../COPYING
cd ../..
rm -rf glib-2.74.0
# GTK-Doc.
tar -xf gtk-doc-1.33.2.tar.xz
cd gtk-doc-1.33.2
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gtk-doc -Dm644 COPYING COPYING-DOCS
cd ..
rm -rf gtk-doc-1.33.2
# pkg-config (rebuild to link against external GLib).
tar -xf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --prefix=/usr --disable-host-tool
make
make install
cd ..
rm -rf pkg-config-0.29.2
# libsigc++.
tar -xf libsigc++-2.10.8.tar.xz
cd libsigc++-2.10.8
mkdir sigc++-build; cd sigc++-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libsigc++ -Dm644 ../COPYING
cd ../..
rm -rf libsigc++-2.10.8
# GLibmm.
tar -xf glibmm-2.66.5.tar.xz
cd glibmm-2.66.5
mkdir glibmm-build; cd glibmm-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/glibmm -Dm644 ../COPYING ../COPYING.tools
cd ../..
rm -rf glibmm-2.66.5
# gobject-introspection.
tar -xf gobject-introspection-1.74.0.tar.xz
cd gobject-introspection-1.74.0
mkdir gobj-build; cd gobj-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/gobject-introspection -Dm644 ../COPYING ../COPYING.GPL ../COPYING.LGPL
cd ../..
rm -rf gobject-introspection-1.74.0
# shared-mime-info.
tar -xf shared-mime-info-2.2.tar.gz
cd shared-mime-info-2.2
mkdir smi-build; cd smi-build
meson --prefix=/usr --buildtype=minsize -Dupdate-mimedb=true ..
ninja
ninja install
install -t /usr/share/licenses/shared-mime-info -Dm644 ../COPYING
cd ../..
rm -rf shared-mime-info-2.2
# desktop-file-utils.
tar -xf desktop-file-utils-0.26.tar.xz
cd desktop-file-utils-0.26
patch -Np1 -i ../patches/desktop-file-utils-0.26-specification1.5.patch
mkdir dfu-build; cd dfu-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -dm755 /usr/share/applications
update-desktop-database /usr/share/applications
install -t /usr/share/licenses/desktop-file-utils -Dm644 ../COPYING
cd ../..
rm -rf desktop-file-utils-0.26
# Graphene.
tar -xf graphene-1.10.8.tar.gz
cd graphene-1.10.8
mkdir graphene-build; cd graphene-build
meson --prefix=/usr --buildtype=minsize -Dtests=false -Dinstalled_tests=false ..
ninja
ninja install
install -t /usr/share/licenses/graphene -Dm644 ../LICENSE.txt
cd ../..
rm -rf graphene-1.10.8
# LLVM/Clang/LLD.
tar -xf llvm-14.0.6.src.tar.xz
mkdir -p libunwind
tar -xf libunwind-14.0.6.src.tar.xz -C libunwind --strip-components=1
cd llvm-14.0.6.src
mkdir -p tools/{clang,lld}
tar -xf ../clang-14.0.6.src.tar.xz -C tools/clang --strip-components=1
tar -xf ../lld-14.0.6.src.tar.xz -C tools/lld --strip-components=1
mkdir LLVM-build; cd LLVM-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_DOCDIR=share/doc -DLLVM_HOST_TRIPLE=x86_64-pc-linux-gnu -DLLVM_BINUTILS_INCDIR=/usr/include -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_FFI=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_USE_PERF=ON -DLLVM_TARGETS_TO_BUILD="AMDGPU;BPF;X86" -DLLVM_BUILD_DOCS=ON -DLLVM_ENABLE_SPHINX=ON -DSPHINX_WARNINGS_AS_ERRORS=OFF -Wno-dev -G Ninja ..
ninja -j$(nproc)
ninja install
install -t /usr/share/licenses/llvm -Dm644 ../LICENSE.TXT
ln -sf llvm /usr/share/licenses/clang
ln -sf llvm /usr/share/licenses/lld
cd ../..
rm -rf libunwind llvm-14.0.6.src
# Rust (build dependency of some packages; will be uninstalled later).
tar -xf rust-1.62.1-x86_64-unknown-linux-gnu.tar.gz
cd rust-1.62.1-x86_64-unknown-linux-gnu
./install.sh --prefix=/usr --sysconfdir=/etc --without=rust-docs
cd ..
rm -rf rust-1.62.1-x86_64-unknown-linux-gnu
# cargo-c (also a build dependency...)
mkdir -p cargoc
tar -xf cargo-c-linux.tar.gz -C cargoc
# bpftool.
tar -xf bpftool-7.0.0.tar.gz
tar -xf libbpf-1.0.0.tar.gz -C bpftool-7.0.0/libbpf --strip-components=1
cd bpftool-7.0.0/src
make all doc
make install doc-install prefix=/usr mandir=/usr/share/man
install -t /usr/share/licenses/bpftool -Dm644 ../LICENSE{,.BSD-2-Clause,.GPL-2.0}
cd ../..
rm -rf bpftool-7.0.0
# volume-key.
tar -xf volume_key-0.3.12.tar.gz
cd volume_key-volume_key-0.3.12
autoreconf -fi
./configure --prefix=/usr --without-python
make
make install
install -t /usr/share/licenses/volume-key -Dm644 COPYING
cd ..
rm -rf volume_key-volume_key-0.3.12
# JSON-GLib.
tar -xf json-glib-1.6.6.tar.xz
cd json-glib-1.6.6
mkdir json-build; cd json-build
meson --prefix=/usr --buildtype=minsize -Dman=true -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/json-glib -Dm644 ../COPYING
cd ../..
rm -rf json-glib-1.6.6
# mandoc (needed by efivar 38+).
tar -xf mandoc-1.14.6.tar.gz
cd mandoc-1.14.6
./configure --prefix=/usr
make mandoc
install -m755 mandoc /usr/bin/mandoc
install -m644 mandoc.1 /usr/share/man/man1/mandoc.1
install -t /usr/share/licenses/mandoc -Dm644 LICENSE
cd ..
rm -rf mandoc-1.14.6
# efivar.
tar -xf efivar-38.tar.bz2
cd efivar-38
patch -Np1 -i ../patches/efivar-38-glibc236.patch
sed '/prep :/a\\ttouch prep' -i src/Makefile
: > src/include/gcc.specs
make CFLAGS="$CFLAGS"
make LIBDIR=/usr/lib install
install -t /usr/share/licenses/efivar -Dm644 COPYING
cd ..
rm -rf efivar-38
# efibootmgr.
tar -xf efibootmgr-18.tar.bz2
cd efibootmgr-18
make EFIDIR=massos EFI_LOADER=grubx64.efi
make EFIDIR=massos EFI_LOADER=grubx64.efi install
install -t /usr/share/licenses/efibootmgr -Dm644 COPYING
cd ..
rm -rf efibootmgr-18
# libpng.
tar -xf libpng-1.6.38.tar.xz
cd libpng-1.6.38
patch -Np1 -i ../patches/libpng-1.6.38-apng.patch
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpng -Dm644 LICENSE
cd ..
rm -rf libpng-1.6.38
# FreeType (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf freetype-2.12.1.tar.xz
cd freetype-2.12.1
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static --with-harfbuzz=no
make
make install
install -t /usr/share/licenses/freetype -Dm644 LICENSE.TXT docs/GPLv2.TXT
cd ..
rm -rf freetype-2.12.1
# Graphite2 (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf graphite2-1.3.14.tgz
cd graphite2-1.3.14
sed -i '/cmptest/d' tests/CMakeLists.txt
mkdir graphite2-build; cd graphite2-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/graphite2 -Dm644 ../COPYING ../LICENSE
cd ../..
rm -rf graphite2-1.3.14
# HarfBuzz.
tar -xf harfbuzz-5.2.0.tar.xz
cd harfbuzz-5.2.0
mkdir hb-build; cd hb-build
meson --prefix=/usr --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/harfbuzz -Dm644 ../COPYING
cd ../..
rm -rf harfbuzz-5.2.0
# FreeType (rebuild to support HarfBuzz).
tar -xf freetype-2.12.1.tar.xz
cd freetype-2.12.1
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static --with-harfbuzz=yes
make
make install
cd ..
rm -rf freetype-2.12.1
# Graphite2 (rebuild to support HarfBuzz).
tar -xf graphite2-1.3.14.tgz
cd graphite2-1.3.14
sed -i '/cmptest/d' tests/CMakeLists.txt
mkdir graphite2-build; cd graphite2-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf graphite2-1.3.14
# Woff2.
tar -xf woff2-1.0.2.tar.gz
cd woff2-1.0.2
mkdir WF2-build; cd WF2-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/woff2 -Dm644 ../LICENSE
cd ../..
rm -rf woff2-1.0.2
# Unifont.
mkdir -p /usr/share/fonts/unifont
pigz -cd unifont-15.0.01.pcf.gz > /usr/share/fonts/unifont/unifont.pcf
install -t /usr/share/licenses/unifont -Dm644 extra-package-licenses/LICENSE-unifont.txt
# GRUB.
tar -xf grub-2.06.tar.xz
cd grub-2.06
mkdir build-pc; cd build-pc
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --enable-grub-mkfont --enable-grub-mount --with-platform=pc --disable-werror
make
cd ..
mkdir build-efi; cd build-efi
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --enable-grub-mkfont --enable-grub-mount --with-platform=efi --disable-werror
make
make bashcompletiondir="/usr/share/bash-completion/completions" install
cd ../build-pc
make bashcompletiondir="/usr/share/bash-completion/completions" install
mkdir -p /etc/default
cat > /etc/default/grub << "END"
# Configuration file for GRUB bootloader

GRUB_DEFAULT="0"
GRUB_TIMEOUT="5"
GRUB_DISTRIBUTOR="MassOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""

# Preload both GPT and MBR modules so that they are not missed
GRUB_PRELOAD_MODULES="part_gpt part_msdos"

# Uncomment to enable booting from LUKS encrypted devices
#GRUB_ENABLE_CRYPTODISK="y"

# Set to 'countdown' or 'hidden' to change timeout behavior,
# press ESC key to display menu.
GRUB_TIMEOUT_STYLE="menu"

# Uncomment to use basic console
GRUB_TERMINAL_INPUT="console"

# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT="console"

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command 'vbeinfo'
GRUB_GFXMODE="auto"

# Uncomment to allow the kernel use the same resolution used by grub
GRUB_GFXPAYLOAD_LINUX="keep"

# Uncomment if you want GRUB to pass to the Linux kernel the old parameter
# format "root=/dev/xxx" instead of "root=/dev/disk/by-uuid/xxx"
#GRUB_DISABLE_LINUX_UUID="true"

# Uncomment to disable generation of recovery mode menu entries
#GRUB_DISABLE_RECOVERY="true"

# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
#GRUB_COLOR_NORMAL="light-blue/black"
#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"

# Uncomment one of them for the gfx desired, a image background or a gfxtheme
GRUB_BACKGROUND="/usr/share/backgrounds/xfce/MassOS-Futuristic-Dark.png"
#GRUB_THEME="/path/to/theme"

# Uncomment to get a beep at GRUB start
#GRUB_INIT_TUNE="480 440 1"

# Uncomment to make GRUB remember the last selection. This requires
# setting 'GRUB_DEFAULT=saved' above.
#GRUB_SAVEDEFAULT="true"

# Uncomment to disable submenus in boot menu
#GRUB_DISABLE_SUBMENU="y"

# Uncomment to enable detection of other OSes when generating grub.cfg
GRUB_DISABLE_OS_PROBER="false"
END
install -t /usr/share/licenses/grub -Dm644 ../COPYING
cd ../..
rm -rf grub-2.06
# os-prober.
tar -xf os-prober_1.79.tar.xz
cd os-prober
sed -i -e "s:/lib/ld\*\.so\*:/lib*/ld*.so*:g" os-probes/mounted/common/90linux-distro
rm -f Makefile
make CFLAGS="$CFLAGS -s" newns
install -Dm755 os-prober linux-boot-prober -t /usr/bin
install -Dm755 newns -t /usr/lib/os-prober
install -Dm755 common.sh -t /usr/share/os-prober
for dir in os-probes os-probes/mounted os-probes/init linux-boot-probes linux-boot-probes/mounted; do
  install -dm755 /usr/lib/$dir
  install -m755 -t /usr/lib/$dir $dir/common/*
  if [ -d $dir/x86 ]; then
    cp -r $dir/x86/* /usr/lib/$dir
  fi
done
install -Dm755 os-probes/mounted/powerpc/20macosx /usr/lib/os-probes/mounted/20macosx
install -dm755 /var/lib/os-prober
install -t /usr/share/licenses/os-prober -Dm644 debian/copyright
install -t /usr/share/licenses/os-prober /usr/share/licenses/systemd/LICENSE.GPL2
cd ..
rm -rf os-prober
# libyaml.
tar -xf yaml-0.2.5.tar.gz
cd yaml-0.2.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libyaml -Dm644 License
cd ..
rm -rf yaml-0.2.5
# libatasmart.
tar -xf libatasmart_0.19.orig.tar.xz
cd libatasmart-0.19
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libatasmart -Dm644 LGPL
cd ..
rm -rf libatasmart-0.19
# libbytesize.
tar -xf libbytesize-2.7.tar.gz
cd libbytesize-2.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libbytesize -Dm644 LICENSE
cd ..
rm -rf libbytesize-2.7
# libblockdev.
tar -xf libblockdev-2.28.tar.gz
cd libblockdev-2.28
./configure --prefix=/usr --sysconfdir=/etc --with-python3 --without-nvdimm
make
make install
install -t /usr/share/licenses/libblockdev -Dm644 LICENSE
cd ..
rm -rf libblockdev-2.28
# libdaemon.
tar -xf libdaemon_0.14.orig.tar.gz
cd libdaemon-0.14
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdaemon -Dm644 LICENSE
cd ..
rm -rf libdaemon-0.14
# libgudev.
tar -xf libgudev-237.tar.xz
cd libgudev-237
mkdir libgudev-build; cd libgudev-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libgudev -Dm644 ../COPYING
cd ../..
rm -rf libgudev-237
# libmbim.
tar -xf libmbim-1.26.4.tar.xz
cd libmbim-1.26.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libmbim -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libmbim-1.26.4
# libqmi.
tar -xf libqmi-1.30.8.tar.xz
cd libqmi-1.30.8
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libqmi -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libqmi-1.30.8
# libwacom.
tar -xf libwacom-2.4.0.tar.xz
cd libwacom-2.4.0
mkdir wacom-build; cd wacom-build
meson --prefix=/usr --buildtype=minsize -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/libwacom -Dm644 ../COPYING
cd ../..
rm -rf libwacom-2.4.0
# mtdev.
tar -xf mtdev-1.1.6.tar.bz2
cd mtdev-1.1.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/mtdev -Dm644 COPYING
cd ..
rm -rf mtdev-1.1.6
# Wayland.
tar -xf wayland-1.21.0.tar.xz
cd wayland-1.21.0
mkdir wayland-build; cd wayland-build
meson --prefix=/usr --buildtype=minsize -Ddocumentation=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/wayland -Dm644 ../COPYING
cd ../..
rm -rf wayland-1.21.0
# Wayland-Protocols.
tar -xf wayland-protocols-1.26.tar.xz
cd wayland-protocols-1.26
mkdir wayland-protocols-build; cd wayland-protocols-build
meson --prefix=/usr --buildtype=minsize -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/wayland-protocols -Dm644 ../COPYING
cd ../..
rm -rf wayland-protocols-1.26
# Aspell.
tar -xf aspell-0.60.8.tar.gz
cd aspell-0.60.8
./configure --prefix=/usr
make
make install
ln -sfn aspell-0.60 /usr/lib/aspell
install -m755 scripts/ispell /usr/bin/
install -m755 scripts/spell /usr/bin/
install -t /usr/share/licenses/aspell -Dm644 COPYING
cd ..
rm -rf aspell-0.60.8
# Aspell English Dictionary.
tar -xf aspell6-en-2020.12.07-0.tar.bz2
cd aspell6-en-2020.12.07-0
./configure
make
make install
cd ..
rm -rf aspell6-en-2020.12.07-0
# Enchant.
tar -xf enchant-2.3.3.tar.gz
cd enchant-2.3.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/enchant -Dm644 COPYING.LIB
cd ..
rm -rf enchant-2.3.3
# Fontconfig.
tar -xf fontconfig-2.14.0.tar.bz2
cd fontconfig-2.14.0
mkdir FC-build; cd FC-build
meson --prefix=/usr --buildtype=minsize -Ddoc-pdf=disabled -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/fontconfig -Dm644 ../COPYING
cd ../..
rm -rf fontconfig-2.14.0
# Fribidi.
tar -xf fribidi-1.0.12.tar.xz
cd fribidi-1.0.12
mkdir fribidi-build; cd fribidi-build
meson --prefix=/usr --buildtype=minsize -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/fribidi -Dm644 ../COPYING
cd ../..
rm -rf fribidi-1.0.12
# giflib.
tar -xf giflib-5.2.1.tar.gz
cd giflib-5.2.1
make
make PREFIX=/usr install
rm -f /usr/lib/libgif.a
install -t /usr/share/licenses/giflib -Dm644 COPYING
cd ..
rm -rf giflib-5.2.1
# libexif.
tar -xf libexif-0.6.23.tar.xz
cd libexif-0.6.23
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libexif -Dm644 COPYING
cd ..
rm -rf libexif-0.6.23
# lolcat.
tar -xf lolcat-1.2.tar.gz
cd lolcat-1.2
make CFLAGS="$CFLAGS"
install -t /usr/bin -Dm755 censor lolcat
help2man -N lolcat > /usr/share/man/man1/lolcat.1
install -t /usr/share/licenses/lolcat -Dm644 LICENSE
cd ..
rm -rf lolcat-1.2
# NASM.
tar -xf nasm-2.15.05.tar.xz
cd nasm-2.15.05
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/nasm -Dm644 LICENSE
cd ..
rm -rf nasm-2.15.05
# libjpeg-turbo.
tar -xf libjpeg-turbo-2.1.3.tar.gz
cd libjpeg-turbo-2.1.3
mkdir jpeg-build; cd jpeg-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DENABLE_STATIC=FALSE -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libjpeg-turbo -Dm644 ../LICENSE.md ../README.ijg
cd ../..
rm -rf libjpeg-turbo-2.1.3
# libgphoto2
tar -xf libgphoto2-2.5.30.tar.xz
cd libgphoto2-2.5.30
./configure --prefix=/usr --disable-rpath
make
make install
install -t /usr/share/licenses/libgphoto2 -Dm644 COPYING
cd ..
rm -rf libgphoto2-2.5.30
# Pixman.
tar -xf pixman-0.40.0.tar.xz
cd pixman-0.40.0
mkdir pixman-build; cd pixman-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/pixman -Dm644 ../COPYING
cd ../..
rm -rf pixman-0.40.0
# Qpdf.
tar -xf qpdf-11.1.0.tar.gz
cd qpdf-11.1.0
mkdir qpdf-build; cd qpdf-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -DINSTALL_EXAMPLES=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/bash-completion/completions -Dm644 ../completions/bash/qpdf
install -t /usr/share/zsh/site-functions -Dm644 ../completions/zsh/_qpdf
install -t /usr/share/licenses/qpdf -Dm644 ../{Artistic-2.0,LICENSE.txt,NOTICE.md}
cd ../..
rm -rf qpdf-11.1.0
# qrencode.
tar -xf qrencode-4.1.1.tar.bz2
cd qrencode-4.1.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/qrencode -Dm644 COPYING
cd ..
rm -rf qrencode-4.1.1
# libsass.
tar -xf libsass-3.6.5.tar.gz
cd libsass-3.6.5
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libsass -Dm644 COPYING LICENSE
cd ..
rm -rf libsass-3.6.5
# sassc.
tar -xf sassc-3.6.2.tar.gz
cd sassc-3.6.2
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sassc -Dm644 LICENSE
cd ..
rm -rf sassc-3.6.2
# ISO-Codes.
tar -xf iso-codes-v4.11.0.tar.bz2
cd iso-codes-v4.11.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/iso-codes -Dm644 COPYING
cd ..
rm -rf iso-codes-v4.11.0
# xdg-user-dirs.
tar -xf xdg-user-dirs-0.18.tar.gz
cd xdg-user-dirs-0.18
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xdg-user-dirs -Dm644 COPYING
cd ..
rm -rf xdg-user-dirs-0.18
# LSB-Tools.
tar -xf LSB-Tools-0.10.tar.gz
cd LSB-Tools-0.10
python setup.py install --optimize=1
rm -rf /usr/lib/lsb
install -t /usr/share/licenses/lsb-tools -Dm644 LICENSE
cd ..
rm -rf LSB-Tools-0.10
# p7zip.
tar -xf p7zip-17.04.tar.gz
cd p7zip-17.04
sed -i '160a if(_buffer == nullptr || _size == _pos) return E_FAIL;' CPP/7zip/Common/StreamObjects.cpp
make OPTFLAGS="$CFLAGS" all3
make DEST_HOME=/usr DEST_MAN=/usr/share/man DEST_SHARE_DOC=/usr/share/doc/p7zip install
install -t /usr/share/licenses/p7zip -Dm644 DOC/License.txt
cd ..
rm -rf p7zip-17.04
# Ruby.
tar -xf ruby-3.1.2.tar.xz
cd ruby-3.1.2
./configure --prefix=/usr --enable-shared
make
make install
install -t /usr/share/licenses/ruby -Dm644 COPYING
cd ..
rm -rf ruby-3.1.2
# slang.
tar -xf slang-2.3.3.tar.bz2
cd slang-2.3.3
./configure --prefix=/usr --sysconfdir=/etc --with-readline=gnu
make -j1
make -j1 install_doc_dir=/usr/share/doc/slang SLSH_DOC_DIR=/usr/share/doc/slang/slsh install-all
chmod 755 /usr/lib/libslang.so.2.3.3 /usr/lib/slang/v2/modules/*.so
rm -f /usr/lib/libslang.a
install -t /usr/share/licenses/slang -Dm644 COPYING
cd ..
rm -rf slang-2.3.3
# BIND Utils.
tar -xf bind-9.18.6.tar.xz
cd bind-9.18.6
./configure --prefix=/usr --with-json-c --with-libidn2 --with-libxml2 --with-lmdb --with-openssl
make -C lib/isc
make -C lib/dns
make -C lib/ns
make -C lib/isccfg
make -C lib/bind9
make -C lib/irs
make -C bin/dig
make -C doc/man
make -C lib/isc install
make -C lib/dns install
make -C lib/ns install
make -C lib/isccfg install
make -C lib/bind9 install
make -C lib/irs install
make -C bin/dig install
install -Dm644 doc/man/{dig.1,host.1,nslookup.1} /usr/share/man/man1
install -t /usr/share/licenses/bind-utils -Dm644 COPYRIGHT LICENSE
cd ..
rm -rf bind-9.18.6
# dhcpcd.
tar -xf dhcpcd-9.4.1.tar.xz
cd dhcpcd-9.4.1
groupadd -g 52 dhcpcd
useradd -c "dhcpcd PrivSep" -d /var/lib/dhcpcd -g dhcpcd -s /sbin/nologin -u 52 dhcpcd
install -o dhcpcd -g dhcpcd -dm700 /var/lib/dhcpcd
./configure --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib/dhcpcd --runstatedir=/run --dbdir=/var/lib/dhcpcd --privsepuser=dhcpcd
make
make install
rm -f /usr/lib/dhcpcd/dhcpcd-hooks/30-hostname
install -t /usr/share/licenses/dhcpcd -Dm644 LICENSE
cd ..
rm -rf dhcpcd-9.4.1
# xdg-utils.
tar -xf xdg-utils-1.1.3.tar.gz
cd xdg-utils-1.1.3
sed -i 's/egrep/grep -E/' scripts/xdg-open.in
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/xdg-utils -Dm644 LICENSE
cd ..
rm -rf xdg-utils-1.1.3
# libnl.
tar -xf libnl-3.7.0.tar.gz
cd libnl-3.7.0
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libnl -Dm644 COPYING
cd ..
rm -rf libnl-3.7.0
# wpa_supplicant.
tar -xf wpa_supplicant-2.10.tar.gz
cd wpa_supplicant-2.10/wpa_supplicant
cat > .config << END
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
CONFIG_MESH=y
CONFIG_PEERKEY=y
CONFIG_PKCS12=y
CONFIG_READLINE=y
CONFIG_SMARTCARD=y
CONFIG_WNM=y
CONFIG_WPS=y
CFLAGS += -I/usr/include/libnl3
END
make BINDIR=/usr/sbin LIBDIR=/usr/lib
install -m755 wpa_{cli,passphrase,supplicant} /usr/sbin/
install -m644 doc/docbook/wpa_supplicant.conf.5 /usr/share/man/man5/
install -m644 doc/docbook/wpa_{cli,passphrase,supplicant}.8 /usr/share/man/man8/
install -m644 systemd/*.service /usr/lib/systemd/system/
install -m644 dbus/fi.w1.wpa_supplicant1.service /usr/share/dbus-1/system-services/
install -dm755 /etc/dbus-1/system.d
install -m644 dbus/dbus-wpa_supplicant.conf /etc/dbus-1/system.d/wpa_supplicant.conf
systemctl enable wpa_supplicant
install -t /usr/share/licenses/wpa-supplicant -Dm644 ../COPYING ../README
cd ../..
rm -rf wpa_supplicant-2.10
# wireless-tools.
tar -xf wireless_tools.30.pre9.tar.gz
cd wireless_tools.30
sed -i '/BUILD_STATIC =/d' Makefile
make CFLAGS="$CFLAGS -I."
make INSTALL_DIR=/usr/bin INSTALL_LIB=/usr/lib INSTALL_INC=/usr/include INSTALL_MAN=/usr/share/man install
install -t /usr/share/licenses/wireless-tools -Dm644 COPYING
cd ..
rm -rf wireless_tools.30
# fmt.
tar -xf fmt-9.1.0.tar.gz
cd fmt-9.1.0
mkdir fmt-build; cd fmt-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DFMT_TEST=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/fmt -Dm644 ../LICENSE.rst
cd ../..
rm -rf fmt-9.1.0
# libzip.
tar -xf libzip-1.9.2.tar.xz
cd libzip-1.9.2
mkdir libzip-build; cd libzip-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libzip -Dm644 ../LICENSE
cd ../..
rm -rf libzip-1.9.2
# gz2xz.
tar -xf gz2xz-1.1.0.tar.gz
cd gz2xz-1.1.0
make INSTALL_DIR=/usr/bin MAN_DIR=/usr/share/man install-vendored
install -t /usr/share/licenses/gz2xz -Dm644 LICENSE
cd ..
rm -rf gz2xz-1.1.0
# dmg2img.
tar -xf dmg2img_1.6.7.orig.tar.gz
cd dmg2img-1.6.7
patch --ignore-whitespace -Np1 -i ../patches/dmg2img-1.6.7-openssl.patch
make PREFIX=/usr CFLAGS="$CFLAGS"
install -m755 dmg2img vfdecrypt /usr/bin
install -t /usr/share/licenses/dmg2img -Dm644 COPYING
cd ..
rm -rf dmg2img-1.6.7
# libcbor.
tar -xf libcbor-0.9.0.tar.gz
cd libcbor-0.9.0
mkdir cbor-build; cd cbor-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DWITH_EXAMPLES=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libcbor -Dm644 ../LICENSE.md
cd ../..
rm -rf libcbor-0.9.0
# libfido2.
tar -xf libfido2-1.12.0.tar.gz
cd libfido2-1.12.0
sed -i '28s/ ON/ OFF/' CMakeLists.txt
mkdir fido2-build; cd fido2-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_EXAMPLES=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libfido2 -Dm644 ../LICENSE
cd ../..
rm -rf libfido2-1.12.0
# util-macros.
tar -xf util-macros-1.19.3.tar.bz2
cd util-macros-1.19.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
install -t /usr/share/licenses/util-macros -Dm644 COPYING
cd ..
rm -rf util-macros-1.19.3
# xorgproto.
tar -xf xorgproto-2022.2.tar.xz
cd xorgproto-2022.2
mkdir xorgproto-build; cd xorgproto-build
meson --prefix=/usr -Dlegacy=true ..
ninja
ninja install
install -t /usr/share/licenses/xorgproto -Dm644 ../COPYING*
cd ../..
rm -rf xorgproto-2022.2
# libXau.
tar -xf libXau-1.0.10.tar.xz
cd libXau-1.0.10
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libxau -Dm644 COPYING
cd ..
rm -rf libXau-1.0.10
# libXdmcp.
tar -xf libXdmcp-1.1.3.tar.bz2
cd libXdmcp-1.1.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libxdmcp -Dm644 COPYING
cd ..
rm -rf libXdmcp-1.1.3
# xcb-proto.
tar -xf xcb-proto-1.15.2.tar.xz
cd xcb-proto-1.15.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make install
install -t /usr/share/licenses/xcb-proto -Dm644 COPYING
cd ..
rm -rf xcb-proto-1.15.2
# libxcb.
tar -xf libxcb-1.15.tar.xz
cd libxcb-1.15
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --without-doxygen
make
make install
install -t /usr/share/licenses/libxcb -Dm644 COPYING
cd ..
rm -rf libxcb-1.15
# Xorg Libraries.
for i in xtrans-1.4.0 libX11-1.8.1 libXext-1.3.4 libFS-1.0.9 libICE-1.0.10 libSM-1.2.3 libXScrnSaver-1.2.3 libXt-1.2.1 libXmu-1.1.3 libXpm-3.5.13 libXaw-1.0.14 libXfixes-6.0.0 libXcomposite-0.4.5 libXrender-0.9.10 libXcursor-1.2.1 libXdamage-1.1.5 libfontenc-1.1.6 libXfont2-2.0.6 libXft-2.3.6 libXi-1.8 libXinerama-1.1.4 libXrandr-1.5.2 libXres-1.2.1 libXtst-1.2.3 libXv-1.0.11 libXvMC-1.0.13 libXxf86dga-1.1.5 libXxf86vm-1.1.4 libdmx-1.1.4 libpciaccess-0.16 libxkbfile-1.1.0 libxshmfence-1.3; do
  tar -xf $i.tar.*
  cd $i
  case $i in
    libXt-*) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-appdefaultdir=/etc/X11/app-defaults ;;
    *) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  esac
  make
  make install
  install -t /usr/share/licenses/$(echo $i | cut -d- -f1 | tr '[:upper:]' '[:lower:]') -Dm644 COPYING
  cd ..
  rm -rf $i
  ldconfig
done
# xcb-util.
tar -xf xcb-util-0.4.0.tar.bz2
cd xcb-util-0.4.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xcb-util -Dm644 COPYING
cd ..
rm -rf xcb-util-0.4.0
# xcb-util-image.
tar -xf xcb-util-image-0.4.0.tar.bz2
cd xcb-util-image-0.4.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-image -Dm644 COPYING
cd ..
rm -rf xcb-util-image-0.4.0
# xcb-util-keysyms.
tar -xf xcb-util-keysyms-0.4.0.tar.bz2
cd xcb-util-keysyms-0.4.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cat keysyms/keysyms.c | head -n29 | tail -n27 | install -Dm644 /dev/stdin /usr/share/licenses/xcb-util-keysyms/COPYING
cd ..
rm -rf xcb-util-keysyms-0.4.0
# xcb-util-renderutil.
tar -xf xcb-util-renderutil-0.3.9.tar.bz2
cd xcb-util-renderutil-0.3.9
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-renderutil -Dm644 COPYING
cd ..
rm -rf xcb-util-renderutil-0.3.9
# xcb-util-wm.
tar -xf xcb-util-wm-0.4.1.tar.bz2
cd xcb-util-wm-0.4.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-wm -Dm644 COPYING
cd ..
rm -rf xcb-util-wm-0.4.1
# xcb-util-cursor.
tar -xf xcb-util-cursor-0.1.3.tar.bz2
cd xcb-util-cursor-0.1.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-cursor -Dm644 COPYING
cd ..
rm -rf xcb-util-cursor-0.1.3
# xcb-util-xrm.
tar -xf xcb-util-xrm-1.3.tar.bz2
cd xcb-util-xrm-1.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xcb-util-xrm -Dm644 COPYING
cd ..
rm -rf xcb-util-xrm-1.3
# libdrm.
tar -xf libdrm-2.4.113.tar.xz
cd libdrm-2.4.113
mkdir libdrm-build; cd libdrm-build
meson --prefix=/usr --buildtype=minsize -Dtests=false -Dudev=true -Dvalgrind=disabled ..
ninja
ninja install
install -t /usr/share/licenses/libdrm -Dm644 ../../extra-package-licenses/libdrm-license.txt
cd ../..
rm -rf libdrm-2.4.113
# DirectX-Headers.
tar -xf DirectX-Headers-1.606.3.tar.gz
cd DirectX-Headers-1.606.3
mkdir DXH-build; cd DXH-build
meson --prefix=/usr --buildtype=minsize -Dbuild-test=false ..
ninja
ninja install
install -t /usr/share/licenses/directx-headers -Dm644 ../LICENSE
cd ../..
rm -rf DirectX-Headers-1.606.3
# SPIRV-Headers.
tar -xf SPIRV-Headers-sdk-1.3.216.0.tar.gz
cd SPIRV-Headers-sdk-1.3.216.0
mkdir SPIRV-Headers-build; cd SPIRV-Headers-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/spirv-headers -Dm644 ../LICENSE
cd ../..
rm -rf SPIRV-Headers-sdk-1.3.216.0
# glslang / SPIRV-Tools.
tar -xf glslang-11.11.0.tar.gz
cd glslang-11.11.0
mkdir -p External/spirv-tools
tar -xf ../SPIRV-Tools-2022.2.tar.gz -C External/spirv-tools --strip-components=1
mkdir static-build; cd static-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DSPIRV-Headers_SOURCE_DIR=/usr -Wno-dev -G Ninja ..
ninja
mkdir ../shared-build; cd ../shared-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -DSPIRV-Headers_SOURCE_DIR=/usr -Wno-dev -G Ninja ..
ninja
cd ..
ninja -C static-build install
ninja -C shared-build install
install -t /usr/share/licenses/glslang -Dm644 LICENSE.txt
install -t /usr/share/licenses/spirv-tools -Dm644 External/spirv-tools/LICENSE
cd ..
rm -rf glslang-11.11.0
# Vulkan-Headers.
tar -xf Vulkan-Headers-1.3.223.tar.gz
cd Vulkan-Headers-1.3.223
mkdir VH-build; cd VH-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/vulkan-headers -Dm644 ../LICENSE.txt
cd ../..
rm -rf Vulkan-Headers-1.3.223
# Vulkan-Loader.
tar -xf Vulkan-Loader-1.3.223.tar.gz
cd Vulkan-Loader-1.3.223
mkdir VL-build; cd VL-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DVULKAN_HEADERS_INSTALL_DIR=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_INSTALL_DATADIR=/share -DCMAKE_SKIP_RPATH=TRUE -DBUILD_TESTS=OFF -DBUILD_WSI_XCB_SUPPORT=ON -DBUILD_WSI_XLIB_SUPPORT=ON -DBUILD_WSI_WAYLAND_SUPPORT=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/vulkan-loader -Dm644 ../LICENSE.txt
cd ../..
rm -rf Vulkan-Loader-1.3.223
# Vulkan-Tools.
tar -xf Vulkan-Tools-1.3.223.tar.gz
cd Vulkan-Tools-1.3.223
mkdir VT-build; cd VT-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DGLSLANG_INSTALL_DIR=/usr -DCMAKE_SKIP_RPATH=TRUE -DBUILD_WSI_XCB_SUPPORT=ON -DBUILD_WSI_XLIB_SUPPORT=ON -DBUILD_WSI_WAYLAND_SUPPORT=ON -DBUILD_CUBE=ON -DBUILD_ICD=OFF -DBUILD_VULKANINFO=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/vulkan-tools -Dm644 ../LICENSE.txt
cd ../..
rm -rf Vulkan-Tools-1.3.223
# libva (circular dependency; will be rebuilt later to support Mesa).
tar -xf libva-2.15.0.tar.gz
cd libva-2.15.0
patch -Np1 -i ../patches/libva-2.15.0-upstreamfix.patch
mkdir build; cd build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libva -Dm644 ../COPYING
cd ../..
rm -rf libva-2.15.0
# libvdpau.
tar -xf libvdpau-1.5.tar.bz2
cd libvdpau-1.5
mkdir vdpau-build; cd vdpau-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libvdpau -Dm644 ../COPYING
cd ../..
rm -rf libvdpau-1.5
# libglvnd.
tar -xf libglvnd-v1.5.0.tar.bz2
cd libglvnd-v1.5.0
cat README.md | tail -n211 | head -n22 | sed 's/    //g' > COPYING
mkdir glvnd-build; cd glvnd-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libglvnd -Dm644 ../COPYING
cd ../..
rm -rf libglvnd-v1.5.0
# Mesa.
tar -xf mesa-22.1.7.tar.xz
cd mesa-22.1.7
mkdir mesa-build; cd mesa-build
meson --prefix=/usr --buildtype=minsize -Dgallium-drivers=crocus,d3d12,i915,iris,nouveau,r300,r600,radeonsi,svga,swrast,virgl,zink -Dvulkan-drivers=amd,intel,swrast -Dvulkan-layers=device-select,intel-nullhw,overlay -Dglx=dri -Dglvnd=true -Dosmesa=true -Dvalgrind=disabled ..
ninja
ninja install
install -t /usr/share/licenses/mesa -Dm644 ../docs/license.rst
cd ../..
rm -rf mesa-22.1.7
# libva (rebuild to support Mesa).
tar -xf libva-2.15.0.tar.gz
cd libva-2.15.0
patch -Np1 -i ../patches/libva-2.15.0-upstreamfix.patch
mkdir build; cd build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libva -Dm644 ../COPYING
cd ../..
rm -rf libva-2.15.0
# xbitmaps.
tar -xf xbitmaps-1.1.2.tar.bz2
cd xbitmaps-1.1.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
install -t /usr/share/licenses/xbitmaps -Dm644 COPYING
cd ..
rm -rf xbitmaps-1.1.2
# Xorg Applications.
for i in iceauth-1.0.9 luit-1.1.1 mkfontscale-1.2.2 sessreg-1.1.2 setxkbmap-1.3.3 smproxy-1.0.6 x11perf-1.6.1 xauth-1.1.2 xbacklight-1.2.3 xcmsdb-1.0.6 xcursorgen-1.0.7 xdpyinfo-1.3.3 xdriinfo-1.0.6 xev-1.2.5 xgamma-1.0.6 xhost-1.0.8 xinput-1.6.3 xkbcomp-1.4.5 xkbevd-1.1.4 xkbutils-1.0.5 xkill-1.0.5 xlsatoms-1.1.3 xlsclients-1.1.4 xmessage-1.0.6 xmodmap-1.0.11 xpr-1.1.0 xprop-1.2.5 xrandr-1.5.1 xrdb-1.2.1 xrefresh-1.0.7 xset-1.2.4 xsetroot-1.1.2 xvinfo-1.1.4 xwd-1.0.8 xwininfo-1.1.5 xwud-1.0.6; do
  tar -xf $i.tar.*
  cd $i
  case $i in
    luit-[0-9]* ) sed -i -e "/D_XOPEN/s/5/6/" configure ;;
  esac
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  make
  make install
  install -t /usr/share/licenses/$(echo $i | cut -d- -f1) -Dm644 COPYING
  cd ..
  rm -rf $i
done
rm -f /usr/bin/xkeystone
# font-util.
tar -xf font-util-1.3.3.tar.xz
cd font-util-1.3.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/font-util -Dm644 COPYING
cd ..
rm -rf font-util-1.3.3
# Noto Fonts.
tar --no-same-owner --same-permissions -xf noto-fonts-20220920.tar.xz -C / --strip-components=1
sed -i 's|<string>sans-serif</string>|<string>Noto Sans</string>|' /etc/fonts/fonts.conf
sed -i 's|<string>monospace</string>|<string>Noto Sans Mono</string>|' /etc/fonts/fonts.conf
fc-cache
# XKeyboard-Config.
tar -xf xkeyboard-config-2.36.tar.xz
cd xkeyboard-config-2.36
patch -Np1 -i ../patches/xkeyboard-config-2.36-upstreamfix.patch
mkdir XKeyboard-Config-BUILD; cd XKeyboard-Config-BUILD
meson --prefix=/usr -Dcompat-rules=true -Dxkb-base=/usr/share/X11/xkb -Dxorg-rules-symlinks=true ..
ninja
ninja install
install -t /usr/share/licenses/xkeyboard-config -Dm644 ../COPYING
cd ../..
rm -rf xkeyboard-config-2.36
# libxklavier.
tar -xf libxklavier-5.4.tar.bz2
cd libxklavier-5.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxklavier -Dm644 COPYING.LIB
cd ..
rm -rf libxklavier-5.4
# libxkbcommon.
tar -xf libxkbcommon-1.4.1.tar.xz
cd libxkbcommon-1.4.1
mkdir xkb-build; cd xkb-build
meson --prefix=/usr --buildtype=minsize -Denable-docs=false ..
ninja
ninja install
install -t /usr/share/licenses/libxkbcommon -Dm644 ../LICENSE
cd ../..
rm -rf libxkbcommon-1.4.1
# Systemd (rebuild to support more features).
tar -xf systemd-stable-251.4.tar.gz
cd systemd-stable-251.4
sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
mkdir systemd-build; cd systemd-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var --buildtype=minsize -Dmode=release -Dversion-tag=251.4-massos -Dshared-lib-tag=251.4-massos -Dbpf-framework=true -Dcryptolib=openssl -Ddefault-compression=xz -Ddefault-dnssec=no -Ddns-over-tls=openssl -Dfallback-hostname=massos -Dhomed=true -Dinstall-tests=false -Dman=true -Dpamconfdir=/etc/pam.d -Drpmmacrosdir=no -Dsysusers=false -Dtests=false -Duserdb=true ..
ninja
ninja install
cat > /etc/pam.d/systemd-user << END
account  required    pam_access.so
account  include     system-account
session  required    pam_env.so
session  required    pam_limits.so
session  required    pam_unix.so
session  required    pam_loginuid.so
session  optional    pam_keyinit.so force revoke
session  optional    pam_systemd.so
auth     required    pam_deny.so
password required    pam_deny.so
END
cd ../..
rm -rf systemd-stable-251.4
# D-Bus (rebuild for X and libaudit support).
tar -xf dbus-1.14.0.tar.xz
cd dbus-1.14.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run --disable-static --enable-libaudit --enable-user-session --disable-doxygen-docs --with-console-auth-dir=/run/console --with-system-pid-file=/run/dbus/pid --with-system-socket=/run/dbus/system_bus_socket
make
make install
chown root:messagebus /usr/libexec/dbus-daemon-launch-helper
chmod 4750 /usr/libexec/dbus-daemon-launch-helper
cat > /etc/dbus-1/session-local.conf << END
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>

  <!-- Search for .service files in /usr/local -->
  <servicedir>/usr/local/share/dbus-1/services</servicedir>

</busconfig>
END
cd ..
rm -rf dbus-1.14.0
# D-Bus GLib.
tar -xf dbus-glib-0.112.tar.gz
cd dbus-glib-0.112
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/dbus-glib -Dm644 COPYING
cd ..
rm -rf dbus-glib-0.112
# alsa-lib.
tar -xf alsa-lib-1.2.7.2.tar.bz2
cd alsa-lib-1.2.7.2
./configure --prefix=/usr --without-debug
make
make install
install -t /usr/share/licenses/alsa-lib -Dm644 COPYING
cd ..
rm -rf alsa-lib-1.2.7.2
# libepoxy.
tar -xf libepoxy-1.5.10.tar.gz
cd libepoxy-1.5.10
mkdir epoxy-build; cd epoxy-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libepoxy -Dm644 ../COPYING
cd ../..
rm -rf libepoxy-1.5.10
# libxcvt (dependency of Xorg-Server since 21.1.1).
tar -xf libxcvt-0.1.2.tar.xz
cd libxcvt-0.1.2
mkdir xcvt-build; cd xcvt-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libxcvt -Dm644 ../COPYING
cd ../..
rm -rf libxcvt-0.1.2
# Xorg-Server.
tar -xf xorg-server-21.1.4.tar.xz
cd xorg-server-21.1.4
patch -Np1 -i ../patches/xorg-server-21.1.2-addxvfbrun.patch
mkdir XSRV-BUILD; cd XSRV-BUILD
meson --prefix=/usr -Dglamor=true -Dlibunwind=true -Dsuid_wrapper=true -Dxephyr=true -Dxvfb=true -Dxkb_output_dir=/var/lib/xkb ..
ninja
ninja install
install -m755 ../xvfb-run /usr/bin/xvfb-run
install -m644 ../xvfb-run.1 /usr/share/man/man1/xvfb-run.1
mkdir -p /etc/X11/xorg.conf.d
install -t /usr/share/licenses/xorg-server -Dm644 ../COPYING
cd ../..
rm -rf xorg-server-21.1.4
# Xwayland.
tar -xf xwayland-22.1.3.tar.xz
cd xwayland-22.1.3
mkdir XWLD-BUILD; cd XWLD-BUILD
meson --prefix=/usr -Dxvfb=false -Dxkb_output_dir=/var/lib/xkb ..
ninja
ninja install
install -t /usr/share/licenses/xwayland -Dm644 ../COPYING
cd ../..
rm -rf xwayland-22.1.3
# libevdev.
tar -xf libevdev-1.13.0.tar.xz
cd libevdev-1.13.0
mkdir EVDEV-build; cd EVDEV-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var -Ddocumentation=disabled -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/libevdev -Dm644 ../COPYING
cd ../..
rm -rf libevdev-1.13.0
# xf86-input-evdev.
tar -xf xf86-input-evdev-2.10.6.tar.bz2
cd xf86-input-evdev-2.10.6
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-evdev -Dm644 COPYING
cd ..
rm -rf xf86-input-evdev-2.10.6
# libinput.
tar -xf libinput-1.21.0.tar.bz2
cd libinput-1.21.0
mkdir libinput-build; cd libinput-build
meson --prefix=/usr --buildtype=minsize -Ddebug-gui=false -Dtests=false -Ddocumentation=false ..
ninja
ninja install
install -t /usr/share/licenses/libinput -Dm644 ../COPYING
cd ../..
rm -rf libinput-1.21.0
# xf86-input-libinput.
tar -xf xf86-input-libinput-1.2.1.tar.xz
cd xf86-input-libinput-1.2.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-libinput -Dm644 COPYING
cd ..
rm -rf xf86-input-libinput-1.2.1
# xf86-input-synaptics.
tar -xf xf86-input-synaptics-1.9.2.tar.xz
cd xf86-input-synaptics-1.9.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-synaptics -Dm644 COPYING
cd ..
rm -rf xf86-input-synaptics-1.9.2
# xf86-input-wacom.
tar -xf xf86-input-wacom-1.1.0.tar.bz2
cd xf86-input-wacom-1.1.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-wacom -Dm644 GPL
cd ..
rm -rf xf86-input-wacom-1.1.0
# xf86-video-amdgpu.
tar -xf xf86-video-amdgpu-22.0.0.tar.xz
cd xf86-video-amdgpu-22.0.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-video-amdgpu -Dm644 COPYING
cd ..
rm -rf xf86-video-amdgpu-22.0.0
# xf86-video-ati.
tar -xf xf86-video-ati-19.1.0.tar.bz2
cd xf86-video-ati-19.1.0
patch -Np1 -i ../patches/xf86-video-ati-19.1.0-backportfixes.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-video-ati -Dm644 COPYING
cd ..
rm -rf xf86-video-ati-19.1.0
# xf86-video-fbdev.
tar -xf xf86-video-fbdev-0.5.0.tar.bz2
cd xf86-video-fbdev-0.5.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-video-fbdev -Dm644 COPYING
cd ..
rm -rf xf86-video-fbdev-0.5.0
# xf86-video-intel.
tar -xf xf86-video-intel-2.99.917-916-g31486f40.tar.xz
cd xf86-video-intel-2.99.917-916-g31486f40
./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --enable-uxa
make
make install
mv /usr/share/man/man4/intel-virtual-output.4 /usr/share/man/man1/intel-virtual-output.1
sed -i '/\.TH/s/4/1/' /usr/share/man/man1/intel-virtual-output.1
install -t /usr/share/licenses/xf86-video-intel -Dm644 COPYING
cd ..
rm -rf xf86-video-intel-2.99.917-916-g31486f40
# xf86-video-nouveau.
tar -xf xf86-video-nouveau-1.0.17.tar.bz2
cd xf86-video-nouveau-1.0.17
patch -Np1 -i ../patches/xf86-video-nouveau-1.0.17-XORGSERVER21.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-video-nouveau -Dm644 COPYING
cd ..
rm -rf xf86-video-nouveau-1.0.17
# xf86-video-vesa.
tar -xf xf86-video-vesa-2.5.0.tar.bz2
cd xf86-video-vesa-2.5.0
patch -Np1 -i ../patches/xf86-video-vesa-2.5.0-upstreamfix.patch
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xf86-video-vesa -Dm644 COPYING
cd ..
rm -rf xf86-video-vesa-2.5.0
# xf86-video-vmware.
tar -xf xf86-video-vmware-13.3.0.tar.bz2
cd xf86-video-vmware-13.3.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-selective-werror
make
make install
install -t /usr/share/licenses/xf86-input-vmware -Dm644 COPYING
cd ..
rm -rf xf86-video-vmware-13.3.0
# intel-vaapi-driver.
tar -xf intel-vaapi-driver-2.4.1.tar.bz2
cd intel-vaapi-driver-2.4.1
mkdir IVD-build; cd IVD-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/intel-vaapi-driver -Dm644 ../COPYING
cd ../..
rm -rf intel-vaapi-driver-2.4.1
# xinit.
tar -xf xinit-1.4.1.tar.bz2
cd xinit-1.4.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-xinitdir=/etc/X11/app-defaults
make
make install
ldconfig
install -t /usr/share/licenses/xinit -Dm644 COPYING
cd ..
rm -rf xinit-1.4.1
# Prefer libinput for handling input devices.
ln -sr /usr/share/X11/xorg.conf.d/40-libinput.conf /etc/X11/xorg.conf.d/40-libinput.conf
# cdrkit.
tar -xf cdrkit_1.1.11.orig.tar.gz
cd cdrkit-1.1.11
patch -Np1 -i ../patches/cdrkit-1.1.11-gcc10.patch
mkdir cdrkit-build; cd cdrkit-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
ln -sf genisoimage /usr/bin/mkisofs
ln -sf genisoimage.1 /usr/share/man/man1/mkisofs.1
install -t /usr/share/licenses/cdrkit -Dm644 ../COPYING
cd ../..
rm -rf cdrkit-1.1.11
# dvd+rw-tools.
tar -xf dvd+rw-tools-7.1.tar.gz
cd dvd+rw-tools-7.1
patch -Np1 -i ../patches/dvd+rw-tools-7.1-genericfixes.patch
make CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
install -t /usr/bin -m755 growisofs dvd+rw-booktype dvd+rw-format dvd+rw-mediainfo dvd-ram-control
install -t /usr/share/man/man1 -m644 growisofs.1
install -t /usr/share/licenses/dvd+rw-tools -Dm644 LICENSE
cd ..
rm -rf dvd+rw-tools-7.1
# libburn.
tar -xf libburn-1.5.4.tar.gz
cd libburn-1.5.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libburn -Dm644 COPYING COPYRIGHT
cd ..
rm -rf libburn-1.5.4
# libisofs.
tar -xf libisofs-1.5.4.tar.gz
cd libisofs-1.5.4
./configure --prefix=/usr --disable-static --enable-libacl --enable-xattr
make
make install
install -t /usr/share/licenses/libisofs -Dm644 COPYING COPYRIGHT
cd ..
rm -rf libisofs-1.5.4
# libisoburn.
tar -xf libisoburn-1.5.4.tar.gz
cd libisoburn-1.5.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libisoburn -Dm644 COPYING COPYRIGHT
cd ..
rm -rf libisoburn-1.5.4
# tealdeer.
tar -xf tealdeer-1.5.0.tar.gz
cd tealdeer-1.5.0
RUSTFLAGS="-C relocation-model=dynamic-no-pic" cargo build --release
install -Dm755 target/release/tldr /usr/bin/tldr
install -Dm644 bash_tealdeer /usr/share/bash-completion/completions/tldr
install -Dm644 fish_tealdeer /usr/share/fish/vendor_completions.d/tldr.fish
install -Dm644 zsh_tealdeer /usr/share/zsh/site-functions/_tldr
install -t /usr/share/licenses/tealdeer -Dm644 LICENSE-APACHE LICENSE-MIT
ln -sf tealdeer /usr/share/licenses/tldr
cd ..
rm -rf tealdeer-1.5.0
# htop.
tar -xf htop-3.2.1.tar.xz
cd htop-3.2.1
./configure --prefix=/usr --sysconfdir=/etc --enable-delayacct --enable-openvz --enable-unicode --enable-vserver
make
make install
mv /usr/bin/{,p}top
mv /usr/share/man/man1/{,p}top.1
ln -sf htop /usr/bin/top
ln -sf htop.1 /usr/share/man/man1/top.1
rm -f /usr/share/applications/htop.desktop
install -t /usr/share/licenses/htop -Dm644 COPYING
cd ..
rm -rf htop-3.2.1
# bsd-games.
tar -xf bsd-games-3.2.tar.gz
cd bsd-games-3.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/bsd-games -Dm644 LICENSE
cd ..
rm -rf bsd-games-3.2
# sl.
tar -xf sl-5.02.tar.gz
cd sl-5.02
gcc $CFLAGS sl.c -o sl -s -lncursesw
install -m755 sl /usr/bin/sl
install -m644 sl.1 /usr/share/man/man1/sl.1
install -t /usr/share/licenses/sl -Dm644 LICENSE
cd ..
rm -rf sl-5.02
# cowsay.
tar -xf cowsay-3.04.tar.gz
cd rank-amateur-cowsay-cowsay-3.04
patch -Np1 -i ../patches/cowsay-3.04-prefix.patch
sed -i 's|/man/|/share/man/|' install.sh
echo "/usr" | ./install.sh
rm /usr/share/cows/mech-and-cow
install -t /usr/share/licenses/cowsay -Dm644 LICENSE
cd ..
rm -rf rank-amateur-cowsay-cowsay-3.04
# figlet.
tar -xf figlet_2.2.5.orig.tar.gz
cd figlet-2.2.5
make BINDIR=/usr/bin MANDIR=/usr/share/man DEFAULTFONTDIR=/usr/share/figlet/fonts all
make BINDIR=/usr/bin MANDIR=/usr/share/man DEFAULTFONTDIR=/usr/share/figlet/fonts install
install -t /usr/share/licenses/figlet -Dm644 LICENSE
cd ..
rm -rf figlet-2.2.5
# CMatrix.
tar -xf cmatrix-v2.0-Butterscotch.tar
cd cmatrix
mkdir cmatrix-build; cd cmatrix-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
cd ..
install -Dm644 mtx.pcf /usr/share/fonts/misc/mtx.pcf
install -Dm644 matrix.fnt /usr/share/kbd/consolefonts/matrix.fnt
install -Dm644 matrix.psf.gz /usr/share/kbd/consolefonts/matrix.psf.gz
install -Dm644 cmatrix.1 /usr/share/man/man1/cmatrix.1
install -t /usr/share/licenses/cmatrix -Dm644 COPYING
cd ..
rm -rf cmatrix
# vitetris.
tar -xf vitetris-0.59.1.tar.gz
cd vitetris-0.59.1
sed -i 's|#define CONFIG_FILENAME ".vitetris"|#define CONFIG_FILENAME ".config/vitetris"|' src/config2.h
./configure --prefix=/usr --with-ncurses --without-x
make
make gameserver
make install
mv /usr/bin/tetris /usr/bin/vitetris
install -m755 gameserver /usr/bin/vitetris-gameserver
for i in tetris tetris-gameserver; do ln -sf vi$i /usr/bin/$i; done
rm -f /usr/share/applications/vitetris.desktop
rm -f /usr/share/pixmaps/vitetris.xpm
install -t /usr/share/licenses/vitetris -Dm644 licence.txt
cd ..
rm -rf vitetris-0.59.1
# mtools.
tar -xf mtools-4.0.40.tar.gz
cd mtools-4.0.40
sed -e '/^SAMPLE FILE$/s:^:# :' -i mtools.conf
./configure --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -m644 mtools.conf /etc/mtools.conf
install -t /usr/share/licenses/mtools -Dm644 COPYING
cd ..
rm -rf mtools-4.0.40
# Polkit.
tar -xf polkit-121.tar.gz
cd polkit-v.121
groupadd -fg 27 polkitd
useradd -c "PolicyKit Daemon Owner" -d /etc/polkit-1 -u 27 -g polkitd -s /sbin/nologin polkitd
mkdir polkit-build; cd polkit-build
meson --prefix=/usr --buildtype=minsize -Dman=true -Dsession_tracking=libsystemd-login ..
ninja
ninja install
cat > /etc/pam.d/polkit-1 << "END"
auth     include        system-auth
account  include        system-account
password include        system-password
session  include        system-session
END
install -t /usr/share/licenses/polkit -Dm644 ../COPYING
cd ../..
rm -rf polkit-v.121
# OpenSSH.
tar -xf openssh-9.0p1.tar.gz
cd openssh-9.0p1
install -dm700 /var/lib/sshd
chown root:sys /var/lib/sshd
groupadd -g 50 sshd
useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /sbin/nologin -u 50 sshd
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-default-path="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin" --with-kerberos5=/usr --with-pam --with-pid-dir=/run --without-pie --with-privsep-path=/var/lib/sshd --with-ssl-engine --with-xauth=/usr/bin/xauth
make
make install
install -m755 contrib/ssh-copy-id /usr/bin
install -m644 contrib/ssh-copy-id.1 /usr/share/man/man1
sed 's@d/login@d/sshd@g' /etc/pam.d/login > /etc/pam.d/sshd
chmod 644 /etc/pam.d/sshd
sed -i 's/#UsePAM/UsePAM/' /etc/ssh/sshd_config
sed -i 's/UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
install -t /usr/share/licenses/openssh -Dm644 LICENCE
cd ..
rm -rf openssh-9.0p1
# sshfs.
tar -xf sshfs-3.7.3.tar.xz
cd sshfs-3.7.3
mkdir sshfs-build; cd sshfs-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/sshfs -Dm644 ../COPYING
cd ../..
rm -rf sshfs-3.7.3
# GLU.
tar -xf glu-9.0.2.tar.xz
cd glu-9.0.2
mkdir glu-build; cd glu-build
meson --prefix=/usr --buildtype=minsize -Dgl_provider=gl ..
ninja
ninja install
rm -f /usr/lib/libGLU.a
cd ../..
rm -rf glu-9.0.2
# FreeGLUT.
tar -xf freeglut-3.2.2.tar.gz
cd freeglut-3.2.2
mkdir fg-build; cd fg-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DFREEGLUT_BUILD_DEMOS=OFF -DFREEGLUT_BUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/freeglut -Dm644 ../COPYING
cd ../..
rm -rf freeglut-3.2.2
# GLEW.
tar -xf glew-2.2.0.tgz
cd glew-2.2.0
sed -i 's|lib64|lib|g' config/Makefile.linux
make
make install.all
chmod 755 /usr/lib/libGLEW.so.2.2.0
rm -f /usr/lib/libGLEW.a
install -t /usr/share/licenses/glew -Dm644 LICENSE.txt
cd ..
rm -rf glew-2.2.0
# mesa-utils.
tar -xf mesa-demos-8.5.0.tar.bz2
cd mesa-demos-8.5.0
mkdir build; cd build
meson --prefix=/usr --buildtype=minsize ..
ninja
install -t /usr/bin -Dm755 src/{egl/opengl/eglinfo,xdemos/glx{info,gears}}
ln -sf mesa /usr/share/licenses/mesa-utils
cd ../..
rm -rf mesa-demos-8.5.0
# libtiff.
tar -xf libtiff-v4.4.0.tar.bz2
cd libtiff-v4.4.0
patch -Np1 -i ../patches/libtiff-4.4.0-upstreamfix.patch
mkdir libtiff-build; cd libtiff-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libtiff -Dm644 ../COPYRIGHT
cd ../..
rm -rf libtiff-v4.4.0
# lcms2.
tar -xf lcms2-2.13.1.tar.gz
cd lcms2-2.13.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/lcms2 -Dm644 COPYING
cd ..
rm -rf lcms2-2.13.1
# JasPer.
tar -xf jasper-version-3.0.6.tar.gz
cd jasper-version-3.0.6
mkdir jasper-build; cd jasper-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=YES -DJAS_ENABLE_DOC=NO -DJAS_ENABLE_LIBJPEG=ON -DJAS_ENABLE_OPENGL=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/jasper -Dm644 ../LICENSE.txt
cd ../..
rm -rf jasper-version-3.0.6
# libsysprof-capture.
tar -xf sysprof-3.46.0.tar.xz
cd sysprof-3.46.0
mkdir build; cd build
meson --prefix=/usr --buildtype=minsize -Dgtk=false -Dlibsysprof=false -Dexamples=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libsysprof-capture -Dm644 ../COPYING ../COPYING.gpl-2
cd ../..
rm -rf sysprof-3.46.0
# ATK.
tar -xf atk-2.38.0.tar.xz
cd atk-2.38.0
mkdir atk-build; cd atk-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/atk -Dm644 ../COPYING
cd ../..
rm -rf atk-2.38.0
# Atkmm.
tar -xf atkmm-2.28.3.tar.xz
cd atkmm-2.28.3
mkdir atkmm-build; cd atkmm-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/atkmm -Dm644 ../COPYING ../COPYING.tools
cd ../..
rm -rf atkmm-2.28.3
# GDK-Pixbuf.
tar -xf gdk-pixbuf-2.42.9.tar.xz
cd gdk-pixbuf-2.42.9
mkdir pixbuf-build; cd pixbuf-build
meson --prefix=/usr --buildtype=minsize -Dinstalled_tests=false ..
ninja
ninja install
gdk-pixbuf-query-loaders --update-cache
install -t /usr/share/licenses/gdk-pixbuf -Dm644 ../COPYING
cd ../..
rm -rf gdk-pixbuf-2.42.9
# Cairo.
tar -xf cairo-1.17.6.tar.bz2
cd cairo-1.17.6
patch -Np1 -i ../patches/cairo-1.17.6-upstreamfix.patch
mkdir cairo-build; cd cairo-build
meson --prefix=/usr --buildtype=minsize -Dgl-backend=auto -Dtee=enabled -Dtests=disabled -Dxlib-xcb=enabled -Dxml=enabled ..
ninja
ninja install
install -t /usr/share/licenses/cairo -Dm644 ../COPYING ../COPYING-LGPL-2.1
cd ../..
rm -rf cairo-1.17.6
# cairomm.
tar -xf cairomm-1.14.3.tar.bz2
cd cairomm-1.14.3
mkdir cmm-build; cd cmm-build
meson --prefix=/usr --buildtype=minsize -Dbuild-examples=false -Dbuild-tests=false ..
ninja
ninja install
install -t /usr/share/licenses/cairomm -Dm644 ../COPYING
cd ../..
rm -rf cairomm-1.14.3
# HarfBuzz (rebuild to support Cairo).
tar -xf harfbuzz-5.2.0.tar.xz
cd harfbuzz-5.2.0
mkdir hb-build; cd hb-build
meson --prefix=/usr --buildtype=minsize -Dgraphite2=enabled -Dtests=disabled ..
ninja
ninja install
cd ../..
rm -rf harfbuzz-5.2.0
# Pango.
tar -xf pango-1.50.10.tar.bz2
cd pango-1.50.10
mkdir pango-build; cd pango-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/pango -Dm644 ../COPYING
cd ../..
rm -rf pango-1.50.10
# Pangomm.
tar -xf pangomm-2.46.2.tar.xz
cd pangomm-2.46.2
mkdir pmm-build; cd pmm-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/pangomm -Dm644 ../COPYING ../COPYING.tools
cd ../..
rm -rf pangomm-2.46.2
# hicolor-icon-theme.
tar -xf hicolor-icon-theme-0.17.tar.xz
cd hicolor-icon-theme-0.17
./configure --prefix=/usr
make install
install -t /usr/share/licenses/hicolor-icon-theme -Dm644 COPYING
cd ..
rm -rf hicolor-icon-theme-0.17
# sound-theme-freedesktop.
tar -xf sound-theme-freedesktop-0.8.tar.bz2
cd sound-theme-freedesktop-0.8
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/sound-theme-freedesktop -Dm644 CREDITS
cd ..
rm -rf sound-theme-freedesktop-0.8
# GTK2.
tar -xf gtk+-2.24.33.tar.xz
cd gtk+-2.24.33
sed -e 's#l \(gtk-.*\).sgml#& -o \1#' -i docs/{faq,tutorial}/Makefile.in
./configure --prefix=/usr --sysconfdir=/etc
make
make install
gtk-query-immodules-2.0 --update-cache
install -t /usr/share/licenses/gtk2 -Dm644 COPYING
cd ..
rm -rf gtk+-2.24.33
# libwebp.
tar -xf libwebp-1.2.4.tar.gz
cd libwebp-1.2.4
mkdir webp-build; cd webp-build
LDFLAGS+=" -lglut" cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libwebp -Dm644 ../COPYING
cd ../..
rm -rf libwebp-1.2.4
# libglade.
tar -xf libglade-2.6.4.tar.bz2
cd libglade-2.6.4
sed -i '/DG_DISABLE_DEPRECATED/d' glade/Makefile.in
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libglade -Dm644 COPYING
cd ..
rm -rf libglade-2.6.4
# Graphviz.
tar -xf graphviz-6.0.1.tar.bz2
cd graphviz-6.0.1
sed -i '/LIBPOSTFIX="64"/s/64//' configure.ac
./autogen.sh
./configure --prefix=/usr --disable-php --enable-lefty --with-webp
make
make -j1 install
install -t /usr/share/licenses/graphviz -Dm644 COPYING
cd ..
rm -rf graphviz-6.0.1
# Vala.
tar -xf vala-0.56.3.tar.xz
cd vala-0.56.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/vala -Dm644 COPYING
cd ..
rm -rf vala-0.56.3
# libgusb.
tar -xf libgusb-0.4.0.tar.xz
cd libgusb-0.4.0
mkdir GUSB-build; cd GUSB-build
meson --prefix=/usr --buildtype=minsize -Ddocs=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libgusb -Dm644 ../COPYING
cd ../..
rm -rf libgusb-0.4.0
# librsvg.
tar -xf librsvg-2.54.5.tar.xz
cd librsvg-2.54.5
./configure --prefix=/usr --enable-vala --disable-static
RUSTFLAGS="-C relocation-model=dynamic-no-pic" make
RUSTFLAGS="-C relocation-model=dynamic-no-pic" make install
gdk-pixbuf-query-loaders --update-cache
install -t /usr/share/licenses/librsvg -Dm644 COPYING.LIB
cd ..
rm -rf librsvg-2.54.5
# adwaita-icon-theme.
tar -xf adwaita-icon-theme-41.0.tar.xz
cd adwaita-icon-theme-41.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf adwaita-icon-theme-41.0
tar -xf adwaita-icon-theme-43.tar.xz
cd adwaita-icon-theme-43
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/adwaita-icon-theme -Dm644 COPYING COPYING_CCBYSA3 COPYING_LGPL
cd ..
rm -rf adwaita-icon-theme-43
# at-spi2-core.
tar -xf at-spi2-core-2.46.0.tar.xz
cd at-spi2-core-2.46.0
mkdir spi2-build; cd spi2-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/at-spi2-core -Dm644 ../COPYING
cd ../..
rm -rf at-spi2-core-2.46.0
# at-spi2-atk.
tar -xf at-spi2-atk-2.38.0.tar.xz
cd at-spi2-atk-2.38.0
mkdir spi2-build; cd spi2-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/at-spi2-atk -Dm644 ../COPYING
cd ../..
rm -rf at-spi2-atk-2.38.0
# Colord.
tar -xf colord-1.4.6.tar.xz
cd colord-1.4.6
groupadd -g 71 colord
useradd -c "Color Daemon Owner" -d /var/lib/colord -u 71 -g colord -s /sbin/nologin colord
mv po/fur.po po/ur.po
sed -i 's/fur/ur/' po/LINGUAS
mkdir colord-build; cd colord-build
meson --prefix=/usr --buildtype=minsize -Ddaemon_user=colord -Dvapi=true -Dsystemd=true -Dlibcolordcompat=true -Dargyllcms_sensor=false -Dman=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/colord -Dm644 ../COPYING
cd ../..
rm -rf colord-1.4.6
# CUPS.
tar -xf cups-2.4.2-source.tar.gz
cd cups-2.4.2
useradd -c "Print Service User" -d /var/spool/cups -g lp -s /sbin/nologin -u 9 lp
sed -e 8198d -e 8213d -e 8228d -e 8243d -i configure
./configure --libdir=/usr/lib --with-system-groups=lpadmin --with-docdir=/usr/share/cups/doc
make
make install
echo "ServerName /run/cups/cups.sock" > /etc/cups/client.conf
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
cat > /etc/pam.d/cups << END
auth    include system-auth
account include system-account
session include system-session
END
systemctl enable cups
install -t /usr/share/licenses/cups -Dm644 LICENSE
cd ..
rm -rf cups-2.4.2
# GTK3.
tar -xf gtk-3.24.34.tar.bz2
cd gtk-3.24.34
mkdir gtk3-build; cd gtk3-build
meson --prefix=/usr --buildtype=minsize -Dbroadway_backend=true -Dcolord=yes -Dexamples=false -Dman=true -Dprint_backends=cups,file,lpr -Dtests=false ..
ninja
ninja install
gtk-query-immodules-3.0 --update-cache
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/gtk3 -Dm644 ../COPYING
cd ../..
rm -rf gtk-3.24.34
# Gtkmm3.
tar -xf gtkmm-3.24.7.tar.xz
cd gtkmm-3.24.7
mkdir gmm-build; cd gmm-build
meson --prefix=/usr --buildtype=minsize -Dbuild-demos=false -Dbuild-tests=false ..
ninja
ninja install
install -t /usr/share/licenses/gtkmm3 -Dm644 ../COPYING ../COPYING.tools
cd ../..
rm -rf gtkmm-3.24.7
# libhandy.
tar -xf libhandy-1.8.0.tar.xz
cd libhandy-1.8.0
mkdir handy-build; cd handy-build
meson --prefix=/usr --buildtype=minsize -Dexamples=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libhandy -Dm644 ../COPYING
cd ../..
rm -rf libhandy-1.8.0
# gnome-themes-extra (for accessibility - provides high contrast theme).
tar -xf gnome-themes-extra-3.28.tar.xz
cd gnome-themes-extra-3.28
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gnome-themes-extra -Dm644 LICENSE
cd ..
rm -rf gnome-themes-extra-3.28
# VTE.
tar -xf vte-0.70.0.tar.bz2
cd vte-0.70.0
mkdir vte-build; cd vte-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
rm -f /etc/profile.d/vte.*
install -t /usr/share/licenses/vte -Dm644 ../COPYING.CC-BY-4-0 ../COPYING.GPL3 ../COPYING.LGPL3 ../COPYING.XTERM
cd ../..
rm -rf vte-0.70.0
# gcab.
tar -xf gcab-1.5.tar.xz
cd gcab-1.5
sed -i 's/check: true/check: false/' meson.build
mkdir gcab-build; cd gcab-build
meson --prefix=/usr --buildtype=minsize -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/gcab -Dm644 ../COPYING
cd ../..
rm -rf gcab-1.5
# keybinder.
tar -xf keybinder-3.0-0.3.2.tar.gz
cd keybinder-3.0-0.3.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/keybinder -Dm644 COPYING
cd ..
rm -rf keybinder-3.0-0.3.2
# libgee.
tar -xf libgee-0.20.6.tar.xz
cd libgee-0.20.6
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libgee -Dm644 COPYING
cd ..
rm -rf libgee-0.20.6
# exiv2.
tar -xf exiv2-0.27.5-Source.tar.gz
cd exiv2-0.27.5-Source
mkdir exiv2-build; cd exiv2-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DEXIV2_ENABLE_VIDEO=yes -DEXIV2_ENABLE_WEBREADY=yes -DEXIV2_ENABLE_CURL=yes -DEXIV2_BUILD_SAMPLES=no -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/exiv2 -Dm644 ../COPYING
cd ../..
rm -rf exiv2-0.27.5-Source
# PyCairo.
tar -xf pycairo-1.21.0.tar.gz
cd pycairo-1.21.0
python setup.py build
python setup.py install --optimize=1
python setup.py install_pycairo_header
python setup.py install_pkgconfig
install -t /usr/share/licenses/pycairo -Dm644 COPYING COPYING-LGPL-2.1
cd ..
rm -rf pycairo-1.21.0
# PyGObject.
tar -xf pygobject-3.42.2.tar.xz
cd pygobject-3.42.2
mkdir pygo-build; cd pygo-build
meson --prefix=/usr --buildtype=minsize -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/pygobject -Dm644 ../COPYING
cd ../..
rm -rf pygobject-3.42.2
# dbus-python.
tar -xf dbus-python-1.3.2.tar.gz
cd dbus-python-1.3.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/dbus-python -Dm644 COPYING
cd ..
rm -rf dbus-python-1.3.2
# python-dbusmock.
tar -xf python-dbusmock-0.28.4.tar.gz
cd python-dbusmock-0.28.4
python setup.py install --optimize=1
install -t /usr/share/licenses/python-dbusmock -Dm644 COPYING
cd ..
rm -rf python-dbusmock-0.28.4
# gexiv2.
tar -xf gexiv2-0.14.0.tar.xz
cd gexiv2-0.14.0
mkdir gexiv2-build; cd gexiv2-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/gexiv2 -Dm644 ../COPYING
cd ../..
rm -rf gexiv2-0.14.0
# libpeas.
tar -xf libpeas-1.34.0.tar.xz
cd libpeas-1.34.0
mkdir libpeas-build; cd libpeas-build
meson --prefix=/usr --buildtype=minsize -Ddemos=false ..
ninja
ninja install
install -t /usr/share/licenses/libpeas -Dm644 ../COPYING
cd ../..
rm -rf libpeas-1.34.0
# libjcat.
tar -xf libjcat-0.1.11.tar.gz
cd libjcat-0.1.11
mkdir jcat-build; cd jcat-build
meson --prefix=/usr --buildtype=minsize -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libjcat -Dm644 ../LICENSE
cd ../..
rm -rf libjcat-0.1.11
# libgxps.
tar -xf libgxps-0.3.2.tar.xz
cd libgxps-0.3.2
mkdir gxps-build; cd gxps-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libgxps -Dm644 ../COPYING
cd ../..
rm -rf libgxps-0.3.2
# djvulibre.
tar -xf djvulibre-3.5.28.tar.gz
cd djvulibre-3.5.28
./configure --prefix=/usr --disable-desktopfiles
make
make install
for i in 22 32 48 64; do install -m644 desktopfiles/prebuilt-hi${i}-djvu.png /usr/share/icons/hicolor/${i}x${i}/mimetypes/image-vnd.djvu.mime.png; done
install -t /usr/share/licenses/djvulibre -Dm644 COPYING COPYRIGHT
cd ..
rm -rf djvulibre-3.5.28
# libraw.
tar -xf LibRaw-0.20.2.tar.gz
cd LibRaw-0.20.2
autoreconf -fi
./configure --prefix=/usr --enable-jasper --enable-jpeg --enable-lcms --disable-static
make
make install
install -t /usr/share/licenses/libraw -Dm644 COPYRIGHT LICENSE.LGPL
cd ..
rm -rf LibRaw-0.20.2
# libogg.
tar -xf libogg-1.3.5.tar.xz
cd libogg-1.3.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libogg -Dm644 COPYING
cd ..
rm -rf libogg-1.3.5
# libvorbis.
tar -xf libvorbis-1.3.7.tar.xz
cd libvorbis-1.3.7
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libvorbis -Dm644 COPYING
cd ..
rm -rf libvorbis-1.3.7
# libtheora.
tar -xf libtheora-1.1.1.tar.xz
cd libtheora-1.1.1
sed -i 's/png_\(sizeof\)/\1/g' examples/png2theora.c
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libtheora -Dm644 COPYING LICENSE
cd ..
rm -rf libtheora-1.1.1
# Speex.
tar -xf speex-1.2.1.tar.gz
cd speex-1.2.1
./configure --prefix=/usr --disable-static --enable-binaries
make
make install
install -t /usr/share/licenses/speex -Dm644 COPYING
cd ..
rm -rf speex-1.2.1
# SpeexDSP.
tar -xf speexdsp-1.2.1.tar.gz
cd speexdsp-1.2.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/speexdsp -Dm644 COPYING
cd ..
rm -rf speexdsp-1.2.1
# Opus.
tar -xf opus-1.3.1.tar.gz
cd opus-1.3.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/opus -Dm644 COPYING
cd ..
rm -rf opus-1.3.1
# FLAC.
tar -xf flac-1.4.1.tar.xz
cd flac-1.4.1
./configure --prefix=/usr --disable-thorough-tests
make
make install
install -t /usr/share/licenses/flac -Dm644 COPYING.FDL COPYING.GPL COPYING.LGPL COPYING.Xiph
cd ..
rm -rf flac-1.4.1
# libsndfile (will be rebuilt later with LAME/mpg123 for MPEG support).
tar -xf libsndfile-1.1.0.tar.xz
cd libsndfile-1.1.0
./configure --prefix=/usr --disable-static --disable-mpeg
make
make install
install -t /usr/share/licenses/libsndfile -Dm644 COPYING
cd ..
rm -rf libsndfile-1.1.0
# libsamplerate.
tar -xf libsamplerate-0.2.2.tar.xz
cd libsamplerate-0.2.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libsamplerate -Dm644 COPYING
cd ..
rm -rf libsamplerate-0.2.2
# JACK2.
tar -xf jack2-1.9.21.tar.gz
cd jack2-1.9.21
./waf configure --prefix=/usr --htmldir=/usr/share/doc/jack2 --autostart=none --classic --dbus --systemd-unit
./waf build -j$(nproc)
./waf install
install -t /usr/share/licenses/jack2 -Dm644 COPYING
cd ..
rm -rf jack2-1.9.21
# SBC.
tar -xf sbc-2.0.tar.xz
cd sbc-2.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/sbc -Dm644 COPYING COPYING.LIB
cd ..
rm -rf sbc-2.0
# ldac.
tar -xf ldacBT-2.0.2.3.tar.gz
cd ldacBT
mkdir ldac-build; cd ldac-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/ldac -Dm644 ../LICENSE
cd ../..
rm -rf ldacBT
# libical.
tar -xf libical-3.0.14.tar.gz
cd libical-3.0.14
mkdir ical-build; cd ical-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSHARED_ONLY=yes -DICAL_BUILD_DOCS=false -DGOBJECT_INTROSPECTION=true -DICAL_GLIB_VAPI=true -Wno-dev -G Ninja ..
ninja -j1
ninja -j1 install
install -t /usr/share/licenses/libical -Dm644 ../COPYING ../LICENSE ../LICENSE.LGPL21.txt
cd ../..
rm -rf libical-3.0.14
# BlueZ.
tar -xf bluez-5.65.tar.xz
cd bluez-5.65
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-library
make
make install
ln -sf ../libexec/bluetooth/bluetoothd /usr/sbin
install -dm755 /etc/bluetooth
install -m644 src/main.conf /etc/bluetooth/main.conf
install -dm755 /var/lib/bluetooth
systemctl enable bluetooth
systemctl enable --global obex
install -t /usr/share/licenses/bluez -Dm644 COPYING COPYING.LIB
cd ..
rm -rf bluez-5.65
# Avahi.
tar -xf avahi-0.8.tar.gz
cd avahi-0.8
groupadd -fg 84 avahi
useradd -c "Avahi Daemon Owner" -d /var/run/avahi-daemon -u 84 -g avahi -s /sbin/nologin avahi
patch -Np1 -i ../patches/avahi-0.8-upstreamfixes.patch
patch -Np1 -i ../patches/avahi-0.8-add-missing-script.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-mono --disable-monodoc --disable-qt3 --disable-qt4 --disable-qt5 --disable-rpath --disable-static --enable-compat-libdns_sd --with-distro=none
make
make install
systemctl enable avahi-daemon
install -t /usr/share/licenses/avahi -Dm644 LICENSE
cd ..
rm -rf avahi-0.8
# ORC.
tar -xf orc-0.4.32.tar.gz
cd orc-0.4.32
mkdir orc-build; cd orc-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
rm -f /usr/lib/liborc-test-0.4.a
install -t /usr/share/licenses/orc -Dm644 ../COPYING
cd ../..
rm -rf orc-0.4.32
# PulseAudio.
tar -xf pulseaudio-16.1.tar.xz
cd pulseaudio-16.1
mkdir pulse-build; cd pulse-build
meson --prefix=/usr --buildtype=minsize -Ddatabase=gdbm -Ddoxygen=false -Dtests=false ..
ninja
ninja install
rm -f /etc/dbus-1/system.d/pulseaudio-system.conf
install -t /usr/share/licenses/pulseaudio -Dm644 ../LICENSE ../GPL ../LGPL
cd ../..
rm -rf pulseaudio-16.1
# SDL.
tar -xf SDL-1.2.15.tar.gz
cd SDL-1.2.15
sed -i '/_XData32/s:register long:register _Xconst long:' src/video/x11/SDL_x11sym.h
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf SDL-1.2.15
# SDL2.
tar -xf SDL2-2.24.0.tar.gz
cd SDL2-2.24.0
mkdir SDL2-build; cd SDL2-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSDL_HIDAPI_LIBUSB=ON -DSDL_RPATH=OFF -DSDL_STATIC=OFF -DSDL_TEST=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/sdl2 -Dm644 ../LICENSE.txt
cd ../..
rm -rf SDL2-2.24.0
# dmidecode.
tar -xf dmidecode-3.4.tar.xz
cd dmidecode-3.4
make prefix=/usr CFLAGS="$CFLAGS"
make prefix=/usr install
install -t /usr/share/licenses/dmidecode -Dm644 LICENSE
cd ..
rm -rf dmidecode-3.4
# laptop-detect.
tar -xf laptop-detect_0.16.tar.xz
cd laptop-detect-0.16
sed -e "s/@VERSION@/0.16/g" < laptop-detect.in > laptop-detect
install -Dm755 laptop-detect /usr/bin/laptop-detect
install -Dm644 laptop-detect.1 /usr/share/man/man1/laptop-detect.1
install -t /usr/share/licenses/laptop-detect -Dm644 debian/copyright
cd ..
rm -rf laptop-detect-0.16
# flashrom.
tar -xf flashrom-v1.2.tar.bz2
cd flashrom-v1.2
mkdir flashrom-build; cd flashrom-build
meson --prefix=/usr --buildtype=minsize -Dconfig_ft2232_spi=false -Dconfig_usbblaster_spi=false ..
ninja
make -C .. flashrom.8
ninja install
install -m644 ../flashrom.8 /usr/share/man/man8/flashrom.8
install -t /usr/share/licenses/flashrom -Dm644 ../COPYING
cd ../..
rm -rf flashrom-v1.2
# rrdtool.
tar -xf rrdtool-1.8.0.tar.gz
cd rrdtool-1.8.0
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-rpath --disable-static --enable-lua --enable-perl --enable-perl-site-install --enable-python --enable-ruby --enable-ruby-site-install --enable-tcl
make
make install
install -t /usr/share/licenses/rrdtool -Dm644 COPYRIGHT LICENSE
cd ..
rm -rf rrdtool-1.8.0
# lm-sensors.
tar -xf lm-sensors-3-6-0.tar.gz
cd lm-sensors-3-6-0
make PREFIX=/usr MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord CFLAGS="$CFLAGS"
make PREFIX=/usr MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord install
install -t /usr/share/licenses/lm-sensors -Dm644 COPYING COPYING.LGPL
cd ..
rm -rf lm-sensors-3-6-0
# libpcap.
tar -xf libpcap-1.10.1.tar.gz
cd libpcap-1.10.1
autoreconf -fi
./configure --prefix='/usr' --enable-ipv6 --enable-bluetooth --enable-usb --with-libnl
make
make install
rm -f /usr/lib/libpcap.a
install -t /usr/share/licenses/libpcap -Dm644 LICENSE
cd ..
rm -rf libpcap-1.10.1
# Net-SNMP.
tar -xf net-snmp-5.9.3.tar.gz
cd net-snmp-5.9.3
./configure --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --enable-ucd-snmp-compatibility --enable-ipv6 --with-python-modules --with-default-snmp-version="3" --with-sys-contact="root@massos" --with-sys-location="Unknown" --with-logfile="/var/log/snmpd.log" --with-mib-modules="host misc/ipfwacc ucd-snmp/diskio tunnel ucd-snmp/dlmod ucd-snmp/lmsensorsMib" --with-persistent-directory="/var/net-snmp"
make NETSNMP_DONT_CHECK_VERSION=1
make -j1 install
rm -f /usr/lib/lib{netsnmp{,agent,helpers,mibs,trapd},snmp}.a
install -t /usr/share/licenses/net-snmp -Dm644 COPYING
cd ..
rm -rf net-snmp-5.9.3
# ppp.
tar -xf ppp-2.4.9.tar.gz
cd ppp-2.4.9
patch -Np1 -i ../patches/ppp-2.4.9-extrafiles.patch
sed -i "s|-O2 -g -pipe|$CFLAGS|" configure
sed -e "s:^#FILTER=y:FILTER=y:" -e "s:^#HAVE_INET6=y:HAVE_INET6=y:" -e "s:^#CBCP=y:CBCP=y:" -i pppd/Makefile.linux
./configure --prefix=/usr
make
make install
install -t /etc/ppp -Dm755 etc/ip{,v6}-{down,up}
install -t /etc/ppp -Dm644 etc/options
install -m755 scripts/{pon,poff,plog} /usr/bin
install -m644 scripts/pon.1 /usr/share/man/man1/pon.1
ln -sf pon.1 /usr/share/man/man1/poff.1
ln -sf pon.1 /usr/share/man/man1/plog.1
install -m600 etc.ppp/pap-secrets /etc/ppp/pap-secrets
install -m600 etc.ppp/chap-secrets /etc/ppp/chap-secrets
install -dm755 /etc/ppp/peers
chmod 0755 /usr/lib/pppd/2.4.9/*.so
install -t /usr/share/licenses/ppp -Dm644 ../extra-package-licenses/ppp-license.txt
cd ..
rm -rf ppp-2.4.9
# Vim.
tar -xf vim-9.0.0300.tar.gz
cd vim-9.0.0300
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
echo '#define SYS_GVIMRC_FILE "/etc/gvimrc"' >> src/feature.h
./configure --prefix=/usr --with-features=huge --enable-gpm --enable-gui=gtk3 --with-tlib=ncursesw --enable-luainterp --enable-perlinterp --enable-python3interp --enable-rubyinterp --enable-tclinterp --with-tclsh=tclsh --with-compiledby="MassOS"
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
cd ..
rm -rf vim-9.0.0300
# libwpe.
tar -xf libwpe-1.13.3.tar.xz
cd libwpe-1.13.3
mkdir wpe-build; cd wpe-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libwpe -Dm644 ../COPYING
cd ../..
rm -rf libwpe-1.13.3
# OpenJPEG.
tar -xf openjpeg-2.5.0.tar.gz
cd openjpeg-2.5.0
mkdir ojpg-build; cd ojpg-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
cd ../doc
for man in man/man?/*; do install -v -D -m 644 $man /usr/share/$man; done
install -t /usr/share/licenses/openjpeg -Dm644 ../LICENSE
cd ../..
rm -rf openjpeg-2.5.0
# libsecret.
tar -xf libsecret-0.20.5.tar.xz
cd libsecret-0.20.5
mkdir secret-build; cd secret-build
meson --prefix=/usr --buildtype=minsize -Dgtk_doc=false ..
ninja
ninja install
install -t /usr/share/licenses/libsecret -Dm644 ../COPYING ../COPYING.TESTS
cd ../..
rm -rf libsecret-0.20.5
# Gcr.
tar -xf gcr-3.41.1.tar.xz
cd gcr-3.41.1
mkdir gcr-build; cd gcr-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/gcr -Dm644 ../COPYING
cd ../..
rm -rf gcr-3.41.1
# pinentry.
tar -xf pinentry-1.2.1.tar.bz2
cd pinentry-1.2.1
./configure --prefix=/usr --enable-pinentry-tty
make
make install
install -t /usr/share/licenses/pinentry -Dm644 COPYING
cd ..
rm -rf pinentry-1.2.1
# AccountsService.
tar -xf accountsservice-22.08.8.tar.xz
cd accountsservice-22.08.8
sed -i '/PrivateTmp/d' data/accounts-daemon.service.in
mkdir as-build; cd as-build
meson --prefix=/usr --buildtype=minsize -Dadmin_group=wheel ..
ninja
ninja install
install -t /usr/share/licenses/accountsservice -Dm644 ../COPYING
cd ../..
rm -rf accountsservice-22.08.8
# polkit-gnome.
tar -xf polkit-gnome-0.105.tar.xz
cd polkit-gnome-0.105
patch -Np1 -i ../patches/polkit-gnome-0.105-upstreamfixes.patch
./configure --prefix=/usr
make
make install
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop << END
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
cd ..
rm -rf polkit-gnome-0.105
# gnome-keyring.
tar -xf gnome-keyring-42.1.tar.xz
cd gnome-keyring-42.1
./configure --prefix=/usr --sysconfdir=/etc --disable-debug
make
make install
install -t /usr/share/licenses/gnome-keyring -Dm644 COPYING COPYING.LIB
cd ..
rm -rf gnome-keyring-42.1
# Poppler.
tar -xf poppler-22.09.0.tar.xz
cd poppler-22.09.0
mkdir poppler-build; cd poppler-build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_CPP_TESTS=OFF -DBUILD_GTK_TESTS=OFF -DBUILD_MANUAL_TESTS=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF -DENABLE_UNSTABLE_API_ABI_HEADERS=ON -DENABLE_ZLIB_UNCOMPRESS=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/poppler -Dm644 ../COPYING ../COPYING3
tar -xf ../../poppler-data-0.4.11.tar.gz
cd poppler-data-0.4.11
make prefix=/usr install
cd ../../..
rm -rf poppler-22.09.0
# GhostScript.
tar -xf ghostscript-10.0.0.tar.xz
cd ghostscript-10.0.0
rm -rf cups/libs freetype lcms2mt jpeg leptonica libpng openjpeg tesseract zlib
./configure --prefix=/usr --disable-compile-inits --enable-dynamic --enable-fontconfig --enable-freetype --enable-openjpeg --with-drivers=ALL --with-system-libtiff --with-x
make so
make soinstall
ln -sf gsc /usr/bin/gs
install -m644 base/*.h /usr/include/ghostscript
ln -sfn ghostscript /usr/include/ps
install -t /usr/share/licenses/ghostscript -Dm644 LICENSE
cd ..
rm -rf ghostscript-10.0.0
# cups-filters.
tar -xf cups-filters-1.28.16.tar.xz
cd cups-filters-1.28.16
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-mutool --without-rcdir --with-test-font-path=/usr/share/fonts/noto/NotoSans-Regular.ttf
make
make install
install -m644 utils/cups-browsed.service /usr/lib/systemd/system/cups-browsed.service
systemctl enable cups-browsed
install -t /usr/share/licenses/cups-filters -Dm644 COPYING
cd ..
rm -rf cups-filters-1.28.16
# Gutenprint.
tar -xf gutenprint-5.3.4.tar.xz
cd gutenprint-5.3.4
./configure --prefix=/usr --disable-static --disable-static-genppd --disable-test
make
make install
install -t /usr/share/licenses/gutenprint -Dm644 COPYING
cd ..
rm -rf gutenprint-5.3.4
# SANE.
tar -xf backends-1.1.1.tar.gz
cd backends-1.1.1
groupadd -g 70 scanner
echo "1.1.1" > .tarball-version
echo "1.1.1" > .version
autoreconf -fi
mkdir build; cd build
../configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-rpath --with-group=scanner --with-lockdir=/run/lock
make
make install
install -m644 tools/udev/libsane.rules /usr/lib/udev/rules.d/65-scanner.rules
install -t /usr/share/licenses/sane -Dm644 ../COPYING ../LICENSE ../README.djpeg
cd ../..
rm -rf backends-1.1.1
# HPLIP.
tar -xf hplip-3.22.6.tar.gz
cd hplip-3.22.6
patch -Np1 -i ../patches/hplip-3.22.6-manyfixes.patch
AUTOMAKE="automake --foreign" autoreconf -fi
./configure --prefix=/usr --enable-cups-drv-install --enable-hpcups-install --disable-imageProcessor-build --enable-pp-build --disable-qt4
make
make -j1 rulesdir=/usr/lib/udev/rules.d install
rm -rf /usr/share/hal
rm -f /etc/xdg/autostart/hplip-systray.desktop
rm -f /usr/share/applications/hp{lip,-uiscan}.desktop
rm -f /usr/bin/hp-{uninstall,upgrade} /usr/share/hplip/{uninstall,upgrade}.py
install -t /usr/share/licenses/hplip -Dm644 COPYING
cd ..
rm -rf hplip-3.22.6
# Tk.
tar -xf tk8.6.12-src.tar.gz
cd tk8.6.12/unix
./configure --prefix=/usr --mandir=/usr/share/man --enable-64bit
make
sed -e "s@^\(TK_SRC_DIR='\).*@\1/usr/include'@" -e "/TK_B/s@='\(-L\)\?.*unix@='\1/usr/lib@" -i tkConfig.sh
make install
make install-private-headers
ln -sf wish8.6 /usr/bin/wish
chmod 755 /usr/lib/libtk8.6.so
install -t /usr/share/licenses/tk -Dm644 license.terms
cd ../..
rm -rf tk8.6.12
# Python (rebuild to support SQLite and Tk).
tar -xf Python-3.10.7.tar.xz
cd Python-3.10.7
./configure --prefix=/usr --enable-shared --with-system-expat --with-system-ffi --with-system-libmpdec --with-ensurepip=yes --enable-optimizations --disable-test-modules
make
make install
cd ..
rm -rf Python-3.10.7
# python-distutils-extra.
tar -xf python-distutils-extra-2.39.tar.gz
cd python-distutils-extra-2.39
python setup.py install
install -t /usr/share/licenses/python-distutils-extra -Dm644 LICENSE
cd ..
rm -rf python-distutils-extra-2.39
# ptyprocess.
tar -xf ptyprocess-0.7.0.tar.gz
cd ptyprocess-0.7.0
python setup.py install --prefix=/usr --optimize=1
install -t /usr/share/licenses/ptyprocess -Dm644 LICENSE
cd ..
rm -rf ptyprocess-0.7.0
# pexpect.
tar -xf pexpect-4.8.0.tar.gz
cd pexpect-4.8.0
python setup.py install
install -t /usr/share/licenses/pexpect -Dm644 LICENSE
cd ..
rm -rf pexpect-4.8.0
# Cython.
tar -xf Cython-0.29.25.tar.gz
cd Cython-0.29.25
python setup.py build
python setup.py install --skip-build
install -t /usr/share/licenses/cython -Dm644 COPYING.txt LICENSE.txt
cd ..
rm -rf Cython-0.29.25
# dnspython.
tar -xf dnspython-2.2.0.tar.gz
cd dnspython-2.2.0
python setup.py build
python setup.py install --optimize=1 --skip-build
install -t /usr/share/licenses/dnspython -Dm644 LICENSE
cd ..
rm -rf dnspython-2.2.0
# chardet.
tar -xf chardet-5.0.0.tar.gz
cd chardet-5.0.0
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/chardet -Dm644 LICENSE
cd ..
rm -rf chardet-5.0.0
# idna.
tar -xf idna-3.4.tar.gz
cd idna-3.4
python setup.py install --optimize=1
install -t /usr/share/licenses/idna -Dm644 LICENSE.md
cd ..
rm -rf idna-3.4
# ply.
tar -xf ply-3.11.tar.gz
cd ply-3.11
python setup.py install --optimize=1
install -t /usr/share/licenses/ply -Dm644 ../extra-package-licenses/ply-license.txt
cd ..
rm -rf ply-3.11
# pycparser.
tar -xf pycparser-release_v2.21.tar.gz
cd pycparser-release_v2.21
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/pycparser -Dm644 LICENSE
cd ..
rm -rf pycparser-release_v2.21
# cffi.
tar -xf cffi-1.15.0.tar.gz
cd cffi-1.15.0
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/cffi -Dm644 LICENSE
cd ..
rm -rf cffi-1.15.0
# cryptography.
tar -xf cryptography-37.0.1.tar.gz
cd cryptography-37.0.1
## First, install the build dependencies.
pip install ../typing_extensions-4.1.1-py3-none-any.whl ../semantic_version-2.9.0-py2.py3-none-any.whl ../setuptools_rust-1.2.0-py3-none-any.whl
## Now build and install the package.
python setup.py install --optimize=1
install -t /usr/share/licenses/cryptography -Dm644 LICENSE*
## Now uninstall the build dependencies since they aren't needed.
pip uninstall setuptools-rust semantic-version typing-extensions -y
cd ..
rm -rf cryptography-37.0.1
# pyopenssl.
tar -xf pyopenssl-22.0.0.tar.gz
cd pyopenssl-22.0.0
python setup.py build
python setup.py install --optimize=1 --skip-build
install -t /usr/share/licenses/pyopenssl -Dm644 LICENSE
cd ..
rm -rf pyopenssl-22.0.0
# urllib3.
tar -xf urllib3-1.26.11.tar.gz
cd urllib3-1.26.11
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/urllib3 -Dm644 LICENSE.txt
cd ..
rm -rf urllib3-1.26.11
# requests.
tar -xf requests-2.28.1.tar.gz
cd requests-2.28.1
sed -e "/certifi/d" -e "s/,<.*'/'/" -e "/charset_normalizer/d" -i setup.py
python setup.py build
python setup.py install --optimize=1 --skip-build
install -t /usr/share/licenses/requests -Dm644 LICENSE
cd ..
rm -rf requests-2.28.1
# libplist.
tar -xf libplist-2.2.0.tar.bz2
cd libplist-2.2.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libplist -Dm644 COPYING COPYING.LESSER
cd ..
rm -rf libplist-2.2.0
# libusbmuxd.
tar -xf libusbmuxd-2.0.2.tar.bz2
cd libusbmuxd-2.0.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libusbmuxd -Dm644 COPYING
cd ..
rm -rf libusbmuxd-2.0.2
# libimobiledevice.
tar -xf libimobiledevice-1.3.0.tar.bz2
cd libimobiledevice-1.3.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/mupdf -Dm644 COPYING COPYING.LESSER
cd ..
rm -rf libimobiledevice-1.3.0
# JSON (required by smblient 4.16+).
tar -xf JSON-4.09.tar.gz
cd JSON-4.09
perl Makefile.PL
make
make install
install -dm755 /usr/share/licenses/json
cat lib/JSON.pm | tail -n9 | head -n6 > /usr/share/licenses/json/COPYING
cd ..
rm -rf JSON-4.09
# Parse-Yapp.
tar -xf Parse-Yapp-1.21.tar.gz
cd Parse-Yapp-1.21
perl Makefile.PL
make
make install
install -dm755 /usr/share/licenses/parse-yapp
cat lib/Parse/Yapp.pm | tail -n14 | head -n12 > /usr/share/licenses/parse-yapp/COPYING
cd ..
rm -rf Parse-Yapp-1.21
# smbclient (client portion of Samba).
tar -xf samba-4.17.0.tar.gz
cd samba-4.17.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-pammodulesdir=/usr/lib/security --with-piddir=/run/samba --systemd-install-services --enable-fhs --without-pie --with-acl-support --with-ads --with-cluster-support --with-ldap --with-pam --with-profiling-data --with-systemd --with-winbind
make
make install
ln -sfr /usr/bin/smbspool /usr/lib/cups/backend/smb
rm -f /usr/bin/{cifsdd,ctdb,ctdb_diagnostics,dbwrap_tool,dumpmscat,gentest,ldbadd,ldbdel,ldbedit,ldbmodify,ldbrename,ldbsearch,locktest,ltdbtool,masktest,mdsearch,mvxattr,ndrdump,ntlm_auth,oLschema2ldif,onnode,pdbedit,ping_pong,profiles,regdiff,regpatch,regshell,regtree,samba-regedit,samba-tool,sharesec,smbcontrol,smbpasswd,smbstatus,smbtorture,tdbbackup,tdbdump,tdbrestore,tdbtool,testparm,wbinfo}
rm -f /usr/sbin/{ctdbd,ctdbd_wrapper,eventlogadm,nmbd,samba,samba_dnsupdate,samba_downgrade_db,samba-gpupdate,samba_kcc,samba_spnupdate,samba_upgradedns,smbd,winbindd}
rm -rf /usr/include/samba-4.0/{charset.h,core,credentials.h,dcerpc.h,dcerpc_server.h,dcesrv_core.h,domain_credentials.h,gen_ndr,ldb_wrap.h,lookup_sid.h,machine_sid.h,ndr,ndr.h,param.h,passdb.h,policy.h,rpc_common.h,samba,share.h,smb2_lease_struct.h,smbconf.h,smb_ldap.h,smbldap.h,tdr.h,tsocket.h,tsocket_internal.h,util,util_ldb.h}
rm -rf /usr/lib/samba/{bind9,gensec,idmap,krb5,ldb,nss_info,process_model,service,vfs}
rm -rf /usr/lib/python3.10/{samba,talloc.cpython-310-x86_64-linux-gnu.so,tdb.cpython-310-x86_64-linux-gnu.so,_tdb_text.py,_tevent.cpython-310-x86_64-linux-gnu.so,tevent.py}
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
cd ..
rm -rf samba-4.17.0
# mobile-broadband-provider-info.
tar -xf mobile-broadband-provider-info-20220725.tar.bz2
cd mobile-broadband-provider-info-20220725
./autogen.sh --prefix=/usr
make
make install
install -t /usr/share/licenses/mobile-broadband-provider-info -Dm644 COPYING
cd ..
rm -rf mobile-broadband-provider-info-20220725
# ModemManager.
tar -xf ModemManager-1.18.8.tar.xz
cd ModemManager-1.18.8
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-systemd-journal --with-systemd-suspend-resume --disable-static
make
make install
install -t /usr/share/licenses/modemmanager -Dm644 COPYING COPYING.LIB
cd ..
rm -rf ModemManager-1.18.8
# libndp.
tar -xf libndp_1.8.orig.tar.gz
cd libndp-1.8
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libndp -Dm644 COPYING
cd ..
rm -rf libndp-1.8
# newt.
tar -xf newt-0.52.21.tar.gz
cd newt-0.52.21
sed -e 's/^LIBNEWT =/#&/' -e '/install -m 644 $(LIBNEWT)/ s/^/#/' -e 's/$(LIBNEWT)/$(LIBNEWTSONAME)/g' -i Makefile.in
./configure --prefix=/usr --with-gpm-support --with-python=python3.10
make
make install
install -t /usr/share/licenses/newt -Dm644 COPYING
cd ..
rm -rf newt-0.52.21
# UPower.
tar -xf upower-v1.90.0.tar.bz2
cd upower-v1.90.0
mkdir upower-build; cd upower-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/upower -Dm644 ../COPYING
systemctl enable upower
cd ../..
rm -rf upower-v1.90.0
# power-profiles-daemon.
tar -xf power-profiles-daemon-0.12.tar.bz2
cd power-profiles-daemon-0.12
mkdir build; cd build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/power-profiles-daemon -Dm644 ../COPYING
systemctl enable power-profiles-daemon
cd ../..
rm -rf power-profiles-daemon-0.12
# NetworkManager.
tar -xf NetworkManager-1.40.0.tar.xz
cd NetworkManager-1.40.0
mkdir NM-build; cd NM-build
meson --prefix=/usr --buildtype=minsize -Dnmtui=true -Dqt=false -Dselinux=false -Dsession_tracking=systemd -Dtests=no ..
ninja
ninja install
cat >> /etc/NetworkManager/NetworkManager.conf << END
[main]
plugins=keyfile
END
cat > /etc/NetworkManager/conf.d/polkit.conf << END
[main]
auth-polkit=true
END
cat > /etc/NetworkManager/conf.d/dns.conf << END
[main]
dns=systemd-resolved
END
cat > /usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules << END
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) {
        return polkit.Result.YES;
    }
});
END
install -t /usr/share/licenses/networkmanager -Dm644 ../COPYING ../COPYING.GFDL ../COPYING.LGPL
systemctl enable NetworkManager
cd ../..
rm -rf NetworkManager-1.40.0
# libnma.
tar -xf libnma-1.10.2.tar.xz
cd libnma-1.10.2
mkdir nma-build; cd nma-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libnma -Dm644 ../COPYING ../COPYING.LGPL
cd ../..
rm -rf libnma-1.10.2
# libnotify.
tar -xf libnotify-0.8.1.tar.xz
cd libnotify-0.8.1
mkdir notify-build; cd notify-build
meson --prefix=/usr --buildtype=minsize -Dman=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libnotify -Dm644 ../COPYING
cd ../..
rm -rf libnotify-0.8.1
# startup-notification.
tar -xf startup-notification-0.12.tar.gz
cd startup-notification-0.12
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/startup-notification -Dm644 COPYING
cd ..
rm -rf startup-notification-0.12
# libwnck.
tar -xf libwnck-43.0.tar.xz
cd libwnck-43.0
patch -Np1 -i ../patches/libwnck-43.0-upstreamfix.patch
mkdir wnck-build; cd wnck-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libwnck -Dm644 ../COPYING
cd ../..
rm -rf libwnck-43.0
# network-manager-applet.
tar -xf network-manager-applet-1.28.0.tar.xz
cd network-manager-applet-1.28.0
mkdir nma-build; cd nma-build
meson --prefix=/usr --buildtype=minsize -Dappindicator=no -Dselinux=false ..
ninja
ninja install
install -t /usr/share/licenses/network-manager-applet -Dm644 ../COPYING
cd ../..
rm -rf network-manager-applet-1.28.0
# NetworkManager-openvpn.
tar -xf NetworkManager-openvpn-1.10.0.tar.xz
cd NetworkManager-openvpn-1.10.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
groupadd -g 85 nm-openvpn
useradd -c "NetworkManager OpenVPN" -d /dev/null -u 85 -g nm-openvpn -s /sbin/nologin nm-openvpn
install -t /usr/share/licenses/networkmanager-openvpn -Dm644 COPYING
cd ..
rm -rf NetworkManager-openvpn-1.10.0
# UDisks.
tar -xf udisks-2.9.4.tar.bz2
cd udisks-2.9.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/udisks -Dm644 COPYING
cd ..
rm -rf udisks-2.9.4
# gsettings-desktop-schemas.
tar -xf gsettings-desktop-schemas-42.0.tar.xz
cd gsettings-desktop-schemas-42.0
sed -i -r 's:"(/system):"/org/gnome\1:g' schemas/*.in
mkdir gsds-build; cd gsds-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/gsettings-desktop-schemas -Dm644 ../COPYING
cd ../..
rm -rf gsettings-desktop-schemas-42.0
# glib-networking.
tar -xf glib-networking-2.74.0.tar.xz
cd glib-networking-2.74.0
mkdir glibnet-build; cd glibnet-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/glib-networking -Dm644 ../COPYING
cd ../..
rm -rf glib-networking-2.74.0
# libsoup.
tar -xf libsoup-2.74.2.tar.xz
cd libsoup-2.74.2
mkdir soup-build; cd soup-build
meson --prefix=/usr --buildtype=minsize -Dtests=false -Dvapi=enabled ..
ninja
ninja install
install -t /usr/share/licenses/libsoup -Dm644 ../COPYING
cd ../..
rm -rf libsoup-2.74.2
# libsoup3.
tar -xf libsoup-3.2.0.tar.xz
cd libsoup-3.2.0
mkdir soup3-build; cd soup3-build
meson --prefix=/usr --buildtype=minsize -Dpkcs11_tests=disabled -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libsoup3 -Dm644 ../COPYING
cd ../..
rm -rf libsoup-3.2.0
# ostree.
tar -xf libostree-2022.5.tar.xz
cd libostree-2022.5
patch -Np1 -i ../patches/ostree-2022.5-glibc236.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-curl --with-dracut --with-ed25519-libsodium --with-openssl
make
make install
sed -i '/reproducible/d' /etc/dracut.conf.d/ostree.conf
install -t /usr/share/licenses/libostree -Dm644 COPYING
cd ..
rm -rf libostree-2022.5
# libxmlb.
tar -xf libxmlb-0.3.6.tar.gz
cd libxmlb-0.3.6
mkdir xmlb-build; cd xmlb-build
meson --prefix=/usr --buildtype=minsize -Dstemmer=true -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libxmlb -Dm644 ../LICENSE
cd ../..
rm -rf libxmlb-0.3.6
# AppStream.
tar -xf AppStream-0.15.5.tar.xz
cd AppStream-0.15.5
mkdir appstream-build; cd appstream-build
meson --prefix=/usr --buildtype=minsize -Dvapi=true -Dcompose=true ..
ninja
ninja install
install -t /usr/share/licenses/appstream -Dm644 ../COPYING
cd ../..
rm -rf AppStream-0.15.5
# appstream-glib.
tar -xf appstream_glib_0_8_0.tar.gz
cd appstream-glib-appstream_glib_0_8_0
mkdir appstream-glib-build; cd appstream-glib-build
meson --prefix=/usr --buildtype=minsize -Drpm=false ..
ninja
ninja install
install -t /usr/share/licenses/appstream-glib -Dm644 ../COPYING
cd ../..
rm -rf appstream-glib-appstream_glib_0_8_0
# Bubblewrap.
tar -xf bubblewrap-0.6.2.tar.xz
cd bubblewrap-0.6.2
mkdir bwrap-build; cd bwrap-build
meson --prefix=/usr --buildtype=minsize -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/bubblewrap -Dm644 ../COPYING
cd ../..
rm -rf bubblewrap-0.6.2
# xdg-dbus-proxy.
tar -xf xdg-dbus-proxy-0.1.4.tar.xz
cd xdg-dbus-proxy-0.1.4
mkdir xdp-build; cd xdp-build
meson --prefix=/usr --buildtype=minsize -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/xdg-dbus-proxy -Dm644 ../COPYING
cd ../..
rm -rf xdg-dbus-proxy-0.1.4
# Malcontent (circular dependency; initial build without malcontent-ui).
tar -xf malcontent-0.10.5.tar.xz
cd malcontent-0.10.5
tar -xf ../libglib-testing-0.1.1.tar.bz2 -C subprojects
mv subprojects/libglib-testing{-0.1.1,}
mkdir malcontent-build; cd malcontent-build
meson --prefix=/usr --buildtype=minsize -Dui=disabled ..
ninja
ninja install
install -t /usr/share/licenses/malcontent -Dm644 ../COPYING ../COPYING-DOCS
cd ../..
rm -rf malcontent-0.10.5
# Flatpak.
tar -xf flatpak-1.14.0.tar.xz
cd flatpak-1.14.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-system-bubblewrap --with-system-dbus-proxy --with-dbus-config-dir=/usr/share/dbus-1/system.d
make
make install
cat >> /etc/profile.d/flatpak.sh << "END"
# Ensure PATH includes Flatpak directories.
if [ -n "$XDG_DATA_HOME" ] && [ -d "$XDG_DATA_HOME/flatpak/exports/bin" ]; then
  pathappend "$XDG_DATA_HOME/flatpak/exports/bin"
elif [ -n "$HOME" ] && [ -d "$HOME/.local/share/flatpak/exports/bin" ]; then
  pathappend "$HOME/.local/share/flatpak/exports/bin"
fi
if [ -d /var/lib/flatpak/exports/bin ]; then
  pathappend /var/lib/flatpak/exports/bin
fi
END
groupadd -g 69 flatpak
useradd -c "Flatpak system helper" -d /var/lib/flatpak -u 69 -g flatpak -s /sbin/nologin flatpak
flatpak remote-add flathub ../flathub.flatpakrepo
install -t /usr/share/licenses/flatpak -Dm644 COPYING
cd ..
rm -rf flatpak-1.14.0
# Malcontent (rebuild with malcontent-ui after resolving circular dependency).
tar -xf malcontent-0.10.5.tar.xz
cd malcontent-0.10.5
tar -xf ../libglib-testing-0.1.1.tar.bz2 -C subprojects
mv subprojects/libglib-testing{-0.1.1,}
mkdir malcontent-build; cd malcontent-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/malcontent -Dm644 ../COPYING ../COPYING-DOCS
cd ../..
rm -rf malcontent-0.10.5
# libportal / libportal-gtk3.
tar -xf libportal-0.6.tar.xz
cd libportal-0.6
mkdir portal-build; cd portal-build
meson --prefix=/usr --buildtype=minsize -Dbackends=gtk3 -Ddocs=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/libportal -Dm644 ../COPYING
install -t /usr/share/licenses/libportal-gtk3 -Dm644 ../COPYING
cd ../..
rm -rf libportal-0.6
# GeoClue.
tar -xf geoclue-2.6.0.tar.bz2
cd geoclue-2.6.0
mkdir geoclue-build; cd geoclue-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/geoclue -Dm644 ../COPYING ../COPYING.LIB
cd ../..
rm -rf geoclue-2.6.0
# fwupd-efi.
tar -xf fwupd-efi-1.3.tar.xz
cd fwupd-efi-1.3
mkdir fwupd-efi-build; cd fwupd-efi-build
meson --prefix=/usr --buildtype=minsize -Defi_sbat_distro_id="massos" -Defi_sbat_distro_summary="MassOS" -Defi_sbat_distro_pkgname="fwupd-efi" -Defi_sbat_distro_version="1.3" -Defi_sbat_distro_url="https://massos.org" ..
ninja
ninja install
install -t /usr/share/licenses/fwupd-efi -Dm644 ../COPYING
cd ../..
rm -rf fwupd-efi-1.3
# fwupd.
tar -xf fwupd-1.7.6.tar.xz
cd fwupd-1.7.6
mkdir fwupd-build; cd fwupd-build
meson --prefix=/usr --buildtype=minsize -Db_lto=false -Dplugin_intel_spi=true -Dplugin_logitech_bulkcontroller=false -Dlzma=true -Dplugin_flashrom=true -Dsupported_build=true -Dtests=false ..
ninja
ninja install
systemctl enable fwupd
install -t /usr/share/licenses/fwupd -Dm644 ../COPYING
cd ../..
rm -rf fwupd-1.7.6
# libcdio.
tar -xf libcdio-2.1.0.tar.bz2
cd libcdio-2.1.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libcdio -Dm644 COPYING
cd ..
rm -rf libcdio-2.1.0
# libcdio-paranoia.
tar -xf libcdio-paranoia-10.2+2.0.1.tar.bz2
cd libcdio-paranoia-10.2+2.0.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libcdio-paranoia -Dm644 COPYING
cd ..
rm -rf libcdio-paranoia-10.2+2.0.1
# rest.
tar -xf rest-0.9.1.tar.xz
cd rest-0.9.1
mkdir rest-build; cd rest-build
meson --prefix=/usr --buildtype=minsize -Dexamples=false -Dtests=false ..
ninja
ninja install
install -t /usr/share/licenses/rest -Dm644 ../COPYING
cd ../..
rm -rf rest-0.9.1
# wpebackend-fdo.
tar -xf wpebackend-fdo-1.12.1.tar.xz
cd wpebackend-fdo-1.12.1
mkdir fdo-build; cd fdo-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/wpebackend-fdo -Dm644 ../COPYING
cd ../..
rm -rf wpebackend-fdo-1.12.1
# libass.
tar -xf libass-0.16.0.tar.xz
cd libass-0.16.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libass -Dm644 COPYING
cd ..
rm -rf libass-0.16.0
# OpenH264.
tar -xf openh264-2.1.1.tar.gz
cd openh264-2.1.1
mkdir H264-build; cd H264-build
meson --prefix=/usr --buildtype=minsize -Dtests=disabled ..
ninja
ninja install
rm -f /usr/lib/libopenh264.a
install -t /usr/share/licenses/openh264 -Dm644 ../LICENSE
cd ../..
rm -rf openh264-2.1.1
# libde265.
tar -xf libde265-1.0.8.tar.gz
cd libde265-1.0.8
./configure --prefix=/usr --disable-static --disable-sherlock265
make
make install
rm -f /usr/bin/tests
install -t /usr/share/licenses/libde265 -Dm644 COPYING
cd ..
rm -rf libde265-1.0.8
# cdparanoia.
tar -xf cdparanoia-III-10.2.src.tgz
cd cdparanoia-III-10.2
patch -Np1 -i ../patches/cdparanoia-III-10.2-buildfix.patch
./configure --prefix=/usr --mandir=/usr/share/man
make -j1
make -j1 install
chmod 755 /usr/lib/libcdda_*.so.0.10.2
install -t /usr/share/licenses/cdparanoia -Dm644 COPYING-GPL COPYING-LGPL
cd ..
rm -rf cdparanoia-III-10.2
# mpg123.
tar -xf mpg123-1.30.1.tar.bz2
cd mpg123-1.30.1
./configure --prefix=/usr --enable-int-quality=yes --with-audio="alsa jack oss pulse sdl"
make
make install
install -t /usr/share/licenses/mpg123 -Dm644 COPYING
cd ..
rm -rf mpg123-1.30.1
# libvpx.
tar -xf libvpx-1.12.0.tar.gz
cd libvpx-1.12.0
sed -i 's/cp -p/cp/' build/make/Makefile
mkdir libvpx-build; cd libvpx-build
../configure --prefix=/usr --enable-shared --disable-static --disable-examples --disable-unit-tests
make
make install
install -t /usr/share/licenses/libvpx -Dm644 ../LICENSE
cd ../..
rm -rf libvpx-1.12.0
# LAME.
tar -xf lame3_100.tar.gz
cd LAME-lame3_100
./configure --prefix=/usr --enable-mp3rtp --enable-nasm --disable-static
make
make install
install -t /usr/share/licenses/lame -Dm644 COPYING LICENSE
cd ..
rm -rf LAME-lame3_100
# libsndfile (LAME/mpg123 rebuild).
tar -xf libsndfile-1.1.0.tar.xz
cd libsndfile-1.1.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libsndfile-1.1.0
# twolame.
tar -xf twolame-0.4.0.tar.gz
cd twolame-0.4.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/twolame -Dm644 COPYING
cd ..
rm -rf twolame-0.4.0
# Taglib.
tar -xf taglib-1.12.tar.gz
cd taglib-1.12
mkdir taglib-build; cd taglib-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/taglib -Dm644 ../COPYING.LGPL ../COPYING.MPL
cd ../..
rm -rf taglib-1.12
# SoundTouch.
tar -xf soundtouch-2.3.1.tar.gz
cd soundtouch-2.3.1
./bootstrap
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/soundtouch -Dm644 COPYING.TXT
cd ..
rm -rf soundtouch-2.3.1
# libdv.
tar -xf libdv-1.0.0.tar.gz
cd libdv-1.0.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdv -Dm644 COPYING COPYRIGHT
cd ..
rm -rf libdv-1.0.0
# libdvdread.
tar -xf libdvdread-6.1.3.tar.bz2
cd libdvdread-6.1.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdvdread -Dm644 COPYING
cd ..
rm -rf libdvdread-6.1.3
# libdvdnav.
tar -xf libdvdnav-6.1.1.tar.bz2
cd libdvdnav-6.1.1
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdvdnav -Dm644 COPYING
cd ..
rm -rf libdvdnav-6.1.1
# libcanberra.
tar -xf libcanberra_0.30.orig.tar.xz
cd libcanberra-0.30
patch -Np1 -i ../patches/libcanberra-0.30-wayland.patch
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
cd ..
rm -rf libcanberra-0.30
# x264.
tar -xf x264-0.164.3099.tar.xz
cd x264-0.164.3099
./configure --prefix=/usr --enable-shared
make
make install
install -t /usr/share/licenses/x264 -Dm644 COPYING
cd ..
rm -rf x264-0.164.3099
# x265.
tar -xf x265-3.5-40-g931178347.tar.xz
cd x265-3.5-40-g931178347
mkdir x265-build; cd x265-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ../source
ninja
ninja install
rm -f /usr/lib/libx265.a
install -t /usr/share/licenses/x265 -Dm644 ../COPYING
cd ../..
rm -rf x265-3.5-40-g931178347
# libraw1394.
tar -xf libraw1394-2.1.2.tar.xz
cd libraw1394-2.1.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libraw1394 -Dm644 COPYING.LIB
cd ..
rm -rf libraw1394-2.1.2
# libavc1394.
tar -xf libavc1394-0.5.4.tar.gz
cd libavc1394-0.5.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libavc1394 -Dm644 COPYING
cd ..
rm -rf libavc1394-0.5.4
# libiec61883.
tar -xf libiec61883-1.2.0.tar.xz
cd libiec61883-1.2.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libiec61883 -Dm644 COPYING
cd ..
rm -rf libiec61883-1.2.0
# libnice.
tar -xf libnice-0.1.19.tar.gz
cd libnice-0.1.19
mkdir nice-build; cd nice-build
meson --prefix=/usr --buildtype=minsize -Dexamples=disabled -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/libnice -Dm644 ../COPYING.LGPL
cd ../..
rm -rf libnice-0.1.19
# libbs2b.
tar -xf libbs2b-3.1.0.tar.bz2
cd libbs2b-3.1.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libbs2b -Dm644 COPYING
cd ..
rm -rf libbs2b-3.1.0
# a52dec.
tar -xf a52dec-0.7.4.tar.gz
cd a52dec-0.7.4
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=/usr --mandir=/usr/share/man --enable-shared --disable-static
make
make install
install -Dt /usr/include/a52dec -m644 liba52/a52_internal.h
install -t /usr/share/licenses/a52dec -Dm644 COPYING
cd ..
rm -rf a52dec-0.7.4
# dav1d.
tar -xf dav1d-1.0.0.tar.xz
cd dav1d-1.0.0
mkdir dav1d-build; cd dav1d-build
meson --prefix=/usr --buildtype=minsize -Denable_tests=false ..
ninja
ninja install
install -t /usr/share/licenses/dav1d -Dm644 ../COPYING
cd ../..
rm -rf dav1d-1.0.0
# rav1e.
tar -xf rav1e-0.5.1.tar.gz
cd rav1e-0.5.1
RUSTFLAGS="-C relocation-model=dynamic-no-pic" cargo build --release
cargo cbuild --release
sed -i 's|/usr/local|/usr|' target/x86_64-unknown-linux-gnu/release/rav1e.pc
install -t /usr/bin -Dm755 target/release/rav1e
install -t /usr/include/rav1e -Dm644 target/x86_64-unknown-linux-gnu/release/include/rav1e/rav1e.h
install -t /usr/lib/pkgconfig -Dm644 target/x86_64-unknown-linux-gnu/release/rav1e.pc
install -Dm755 target/x86_64-unknown-linux-gnu/release/librav1e.so /usr/lib/librav1e.so.0.5.1
ln -sf librav1e.so.0.5.1 /usr/lib/librav1e.so.0
ln -sf librav1e.so.0.5.1 /usr/lib/librav1e.so
ldconfig
install -t /usr/share/licenses/rav1e -Dm644 LICENSE
cd ..
rm -rf rav1e-0.5.1
# wavpack.
tar -xf wavpack-5.5.0.tar.xz
cd wavpack-5.5.0
./configure --prefix=/usr --disable-rpath --enable-legacy
make
make install
install -t /usr/share/licenses/wavpack -Dm644 COPYING
cd ..
rm -rf wavpack-5.5.0
# libbluray.
tar -xf libbluray-1.3.3.tar.bz2
cd libbluray-1.3.3
./configure --prefix=/usr --disable-bdjava-jar --disable-examples --disable-static
make
make install
install -t /usr/share/licenses/libbluray -Dm644 COPYING
cd ..
rm -rf libbluray-1.3.3
# libmodplug.
tar -xf libmodplug-0.8.9.0.tar.gz
cd libmodplug-0.8.9.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libmodplug -Dm644 COPYING
cd ..
rm -rf libmodplug-0.8.9.0
# libmpeg2.
tar -xf libmpeg2-0.5.1.tar.gz
cd libmpeg2-0.5.1
sed -i 's/static const/static/' libmpeg2/idct_mmx.c
./configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/libmpeg2 -Dm644 COPYING
cd ..
rm -rf libmpeg2-0.5.1
# libheif.
tar -xf libheif-1.13.0.tar.gz
cd libheif-1.13.0
./configure --prefix=/usr --disable-static --disable-aom
make
make install
install -t /usr/share/licenses/libheif -Dm644 COPYING
cd ..
rm -rf libheif-1.13.0
# libavif.
tar -xf libavif-0.10.1.tar.gz
cd libavif-0.10.1
mkdir libavif-build; cd libavif-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DAVIF_BUILD_APPS=ON -DAVIF_BUILD_GDK_PIXBUF=ON -DAVIF_CODEC_DAV1D=ON -DAVIF_CODEC_RAV1E=ON -DAVIF_ENABLE_WERROR=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libavif -Dm644 ../LICENSE
cd ../..
rm -rf libavif-0.10.1
# FAAD2.
tar -xf faad2-2_10_0.tar.gz
cd faad2-2_10_0
./bootstrap
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/faad2 -Dm644 COPYING
cd ..
rm -rf faad2-2_10_0
# FFmpeg.
tar -xf ffmpeg-5.1.2.tar.xz
cd ffmpeg-5.1.2
./configure --prefix=/usr --disable-debug --disable-nonfree --disable-static --enable-alsa --enable-bzlib --enable-gmp --enable-gpl --enable-iconv --enable-libass --enable-libbluray --enable-libbs2b --enable-libcdio --enable-libdav1d --enable-libdrm --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libglslang --enable-libiec61883 --enable-libjack --enable-libmodplug --enable-libmp3lame --enable-libopenh264 --enable-libopenjpeg --enable-libopus --enable-libpulse --enable-librav1e --enable-librsvg --enable-librtmp --enable-libspeex --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxcb --enable-libxcb-shape --enable-libxcb-shm --enable-libxcb-xfixes --enable-libxml2 --enable-opengl --enable-openssl --enable-sdl2 --enable-shared --enable-small --enable-vaapi --enable-vdpau --enable-version3 --enable-vulkan --enable-xlib --enable-zlib
make
gcc $CFLAGS tools/qt-faststart.c -o tools/qt-faststart
make install
install -m755 tools/qt-faststart /usr/bin
install -t /usr/share/licenses/ffmpeg -Dm644 COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md
cd ..
rm -rf ffmpeg-5.1.2
# OpenAL.
tar -xf openal-soft-1.22.2.tar.gz
cd openal-soft-1.22.2/build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DALSOFT_EXAMPLES=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/openal -Dm644 ../COPYING ../BSD-3Clause
cd ../..
rm -rf openal-soft-1.22.2
# GStreamer.
tar -xf gstreamer-1.20.3.tar.xz
cd gstreamer-1.20.3
mkdir gstreamer-build; cd gstreamer-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dbenchmarks=disabled -Dexamples=disabled -Dgst_debug=false -Dpackage-name="MassOS GStreamer 1.20.3" -Dpackage-origin="https://massos.org" -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/gstreamer -Dm644 ../COPYING
cd ../..
rm -rf gstreamer-1.20.3
# gst-plugins-base.
tar -xf gst-plugins-base-1.20.3.tar.xz
cd gst-plugins-base-1.20.3
mkdir base-build; cd base-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dexamples=disabled -Dpackage-name="MassOS GStreamer 1.20.3" -Dpackage-origin="https://massos.org" -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-base -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-base-1.20.3
# gst-plugins-good.
tar -xf gst-plugins-good-1.20.3.tar.xz
cd gst-plugins-good-1.20.3
mkdir good-build; cd good-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dexamples=disabled -Dpackage-name="MassOS GStreamer 1.20.3" -Dpackage-origin="https://massos.org" -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-good -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-good-1.20.3
# gst-plugins-bad.
tar -xf gst-plugins-bad-1.20.3.tar.xz
cd gst-plugins-bad-1.20.3
mkdir bad-build; cd bad-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dexamples=disabled -Dgpl=enabled -Dpackage-name="MassOS GStreamer 1.20.3" -Dpackage-origin="https://massos.org" -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-bad -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-bad-1.20.3
# gst-plugins-ugly.
tar -xf gst-plugins-ugly-1.20.3.tar.xz
cd gst-plugins-ugly-1.20.3
mkdir ugly-build; cd ugly-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dgpl=enabled -Dpackage-name="MassOS GStreamer 1.20.3" -Dpackage-origin="https://massos.org" -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-ugly -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-ugly-1.20.3
# gst-libav.
tar -xf gst-libav-1.20.3.tar.xz
cd gst-libav-1.20.3
mkdir gst-libav-build; cd gst-libav-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dpackage-name="MassOS GStreamer 1.20.3" -Dpackage-origin="https://massos.org" -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/gst-libav -Dm644 ../COPYING
cd ../..
rm -rf gst-libav-1.20.3
# gstreamer-vaapi.
tar -xf gstreamer-vaapi-1.20.3.tar.xz
cd gstreamer-vaapi-1.20.3
mkdir gstreamer-vaapi-build; cd gstreamer-vaapi-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dexamples=disabled -Dpackage-origin="https://massos.org" -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/gstreamer-vaapi -Dm644 ../COPYING.LIB
cd ../..
rm -rf gstreamer-vaapi-1.20.3
# gst-plugin-dav1d and gst-plugin-rav1e (from gst-plugins-rs).
tar -xf gst-plugins-rs-0.8.4.tar.bz2
cd gst-plugins-rs-0.8.4
sed -i 's/dav1d = "0.7"/dav1d = "0.8"/' video/dav1d/Cargo.toml
mkdir gst-rs-build; cd gst-rs-build
CFLAGS="-O2" CXXFLAGS="-O2" meson --prefix=/usr --buildtype=plain -Dsodium=system -Dcsound=disabled -Dgtk4=disabled ..
ninja
install -t /usr/lib/gstreamer-1.0 -Dm755 libgst{rav1e,rsdav1d}.so
install -t /usr/lib/pkgconfig -Dm644 gst{rav1e,rsdav1d}.pc
install -t /usr/share/licenses/gst-plugin-dav1d -Dm644 ../LICENSE-MIT
install -t /usr/share/licenses/gst-plugin-rav1e -Dm644 ../LICENSE-MIT
cd ../..
rm -rf gst-plugins-rs-0.8.4
# PipeWire + WirePlumber.
tar -xf pipewire-0.3.58.tar.bz2
cd pipewire-0.3.58
mkdir -p subprojects/wireplumber
tar -xf ../wireplumber-0.4.11.tar.bz2 -C subprojects/wireplumber --strip-components=1
patch -d subprojects/wireplumber -Np1 -i ../../../patches/wireplumber-0.4.11-upstreamfix.patch
mkdir pipewire-build; cd pipewire-build
meson --prefix=/usr --buildtype=minsize -Db_pie=false -Dexamples=disabled -Dffmpeg=enabled -Dtests=disabled -Dvulkan=enabled -Dsession-managers=wireplumber -Dwireplumber:system-lua=true -Dwireplumber:tests=false ..
ninja
ninja install
systemctl --global enable pipewire.socket pipewire-pulse.socket
systemctl --global enable wireplumber
echo "autospawn = no" >> /etc/pulse/client.conf
install -t /usr/share/licenses/pipewire -Dm644 ../COPYING
install -t /usr/share/licenses/wireplumber -Dm644 ../subprojects/wireplumber/LICENSE
cd ../..
rm -rf pipewire-0.3.58
# xdg-desktop-portal.
tar -xf xdg-desktop-portal-1.14.6.tar.xz
cd xdg-desktop-portal-1.14.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xdg-desktop-portal -Dm644 COPYING
cd ..
rm -rf xdg-desktop-portal-1.14.6
# xdg-desktop-portal-gtk.
tar -xf xdg-desktop-portal-gtk-1.14.0.tar.xz
cd xdg-desktop-portal-gtk-1.14.0
./configure --prefix=/usr
make
make install
cat > /etc/xdg/autostart/xdg-desktop-portal-gtk.desktop << "END"
[Desktop Entry]
Type=Application
Name=Portal service (GTK/GNOME implementation)
Exec=/bin/bash -c "dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY; systemctl start --user xdg-desktop-portal-gtk.service"
END
install -t /usr/share/licenses/xdg-desktop-portal-gtk -Dm644 COPYING
cd ..
rm -rf xdg-desktop-portal-gtk-1.14.0
# WebKitGTK (precompiled, see https://github.com/MassOS-Linux/webkitgtk-binaries for the reasons why).
tar --no-same-owner --same-permissions -xf webkitgtk-2.38.0-MassOS2022.08-icu71.1-x86_64.tar.xz -C /
# Cogl.
tar -xf cogl-1.22.8.tar.xz
cd cogl-1.22.8
./configure --prefix=/usr --enable-gles1 --enable-gles2 --enable-kms-egl-platform --enable-wayland-egl-platform --enable-xlib-egl-platform --enable-wayland-egl-server --enable-cogl-gst
make -j1
make -j1 install
install -t /usr/share/licenses/cogl -Dm644 COPYING
cd ..
rm -rf cogl-1.22.8
# Clutter.
tar -xf clutter-1.26.4.tar.xz
cd clutter-1.26.4
./configure --prefix=/usr --sysconfdir=/etc --enable-egl-backend --enable-evdev-input --enable-wayland-backend --enable-wayland-compositor
make
make install
install -t /usr/share/licenses/clutter -Dm644 COPYING
cd ..
rm -rf clutter-1.26.4
# Clutter-GTK.
tar -xf clutter-gtk-1.8.4.tar.xz
cd clutter-gtk-1.8.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/clutter-gtk -Dm644 COPYING
cd ..
rm -rf clutter-gtk-1.8.4
# Clutter-GST.
tar -xf clutter-gst-3.0.27.tar.xz
cd clutter-gst-3.0.27
./configure --prefix=/usr --sysconfdir=/etc --disable-debug
make
make install
install -t /usr/share/licenses/clutter-gst -Dm644 COPYING
cd ..
rm -rf clutter-gst-3.0.27
# libchamplain.
tar -xf libchamplain-0.12.20.tar.xz
cd libchamplain-0.12.20
mkdir champlain-build; cd champlain-build
meson --prefix=/usr --buildtype=minsize ..
ninja
ninja install
install -t /usr/share/licenses/libchamplain -Dm644 ../COPYING
cd ../..
rm -rf libchamplain-0.12.20
# gspell.
tar -xf gspell-1.10.0.tar.xz
cd gspell-1.10.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gspell -Dm644 COPYING
cd ..
rm -rf gspell-1.10.0
# gnome-online-accounts.
tar -xf gnome-online-accounts-3.46.0.tar.xz
cd gnome-online-accounts-3.46.0
mkdir goa-build; cd goa-build
meson --prefix=/usr --buildtype=minsize -Dfedora=false -Dman=true -Dmedia_server=true ..
ninja
ninja install
install -t /usr/share/licenses/gnome-online-accounts -Dm644 ../COPYING
cd ../..
rm -rf gnome-online-accounts-3.46.0
# libgdata.
tar -xf libgdata-0.18.1.tar.xz
cd libgdata-0.18.1
mkdir gdata-build; cd gdata-build
meson --prefix=/usr --buildtype=minsize -Dalways_build_tests=false ..
ninja
ninja install
install -t /usr/share/licenses/libgdata -Dm644 ../COPYING
cd ../..
rm -rf libgdata-0.18.1
# GVFS.
tar -xf gvfs-1.50.2.tar.xz
cd gvfs-1.50.2
mkdir gvfs-build; cd gvfs-build
meson --prefix=/usr --buildtype=minsize -Dman=true ..
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/gvfs -Dm644 ../COPYING
cd ../..
rm -rf gvfs-1.50.2
# zap (AppImage package manager).
tar -xf zap-2.2.1.tar.gz
cd zap-2.2.1
tar -xf ../go1.18.3.linux-amd64.tar.gz
GOPATH="$PWD/go" ./go/bin/go build -trimpath -ldflags "-s -w -X main.BuildVersion=2.2.1-MassOS -X main.BuildTime=$(date '+%Y-%m-%dT%H:%M:%S')"
install -t /usr/bin -Dm755 zap
help2man -N zap > /usr/share/man/man1/zap.1
install -t /usr/share/licenses/zap -Dm644 LICENSE
cd ..
rm -rf zap-2.2.1
# Plymouth.
tar -xf plymouth-22.02.122.tar.bz2
cd plymouth-22.02.122
sed -i 49d src/libply/ply-utils.c
LDFLAGS="$LDFLAGS -ludev" ./autogen.sh --prefix=/usr --exec-prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --enable-systemd-integration --enable-drm --enable-pango --with-release-file=/etc/os-release --with-logo=/usr/share/massos/massos-logo-sidetext.png --with-background-color=0x000000 --with-background-start-color-stop=0x000000 --with-background-end-color-stop=0x4D4D4D --without-rhgb-compat-link --without-system-root-install --with-runtimedir=/run
make
make install
sed -i 's/WatermarkVerticalAlignment=.96/WatermarkVerticalAlignment=.5/' /usr/share/plymouth/themes/spinner/spinner.plymouth
plymouth-set-default-theme bgrt
install -t /usr/share/licenses/plymouth -Dm644 COPYING
cd ..
rm -rf plymouth-22.02.122
# Busybox.
tar -xf busybox-1.35.0.tar.bz2
cd busybox-1.35.0
cp ../busybox-config .config
make
install -m755 busybox /usr/bin/busybox
install -t /usr/share/licenses/busybox -Dm644 LICENSE
cd ..
rm -rf busybox-1.35.0
# Linux Kernel.
tar -xf linux-5.19.11.tar.xz
cd linux-5.19.11
cp ../kernel-config .config
make olddefconfig
make
make INSTALL_MOD_PATH=/usr INSTALL_MOD_STRIP=1 modules_install
KREL=$(make -s kernelrelease)
cp arch/x86/boot/bzImage /boot/vmlinuz-$KREL
cp arch/x86/boot/bzImage /usr/lib/modules/$KREL/vmlinuz
cp System.map /boot/System.map-$KREL
cp .config /boot/config-$KREL
rm -f /usr/lib/modules/$KREL/{source,build}
echo $KREL > version
builddir=/usr/lib/modules/$KREL/build
install -t "$builddir" -Dm644 .config Makefile Module.symvers System.map version vmlinux
install -t "$builddir/kernel" -Dm644 kernel/Makefile
install -t "$builddir/arch/x86" -Dm644 arch/x86/Makefile
cp -t "$builddir" -a scripts
install -Dt "$builddir/tools/objtool" tools/objtool/objtool
mkdir -p "$builddir"/{fs/xfs,mm}
cp -t "$builddir" -a include
cp -t "$builddir/arch/x86" -a arch/x86/include
install -t "$builddir/arch/x86/kernel" -Dm644 arch/x86/kernel/asm-offsets.s
install -t "$builddir/drivers/md" -Dm644 drivers/md/*.h
install -t "$builddir/net/mac80211" -Dm644 net/mac80211/*.h
install -t "$builddir/drivers/media/i2c" -Dm644 drivers/media/i2c/msp3400-driver.h
install -t "$builddir/drivers/media/usb/dvb-usb" -Dm644 drivers/media/usb/dvb-usb/*.h
install -t "$builddir/drivers/media/dvb-frontends" -Dm644 drivers/media/dvb-frontends/*.h
install -t "$builddir/drivers/media/tuners" -Dm644 drivers/media/tuners/*.h
install -t "$builddir/drivers/iio/common/hid-sensors" -Dm644 drivers/iio/common/hid-sensors/*.h
find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" ';'
rm -rf "$builddir/Documentation"
find -L "$builddir" -type l -delete
find "$builddir" -type f -name '*.o' -delete
ln -sr "$builddir" "/usr/src/linux"
install -t /usr/share/licenses/linux -Dm644 COPYING LICENSES/exceptions/* LICENSES/preferred/*
cd ..
rm -rf linux-5.19.11
unset builddir
# NVIDIA Open Kernel Modules.
tar -xf open-gpu-kernel-modules-515.76.tar.gz
cd open-gpu-kernel-modules-515.76
make SYSSRC=/usr/src/linux
install -t /usr/lib/modules/$KREL/extramodules -Dm644 kernel-open/*.ko
strip --strip-debug /usr/lib/modules/$KREL/extramodules/*.ko
for i in /usr/lib/modules/$KREL/extramodules/*.ko; do xz "$i"; done
echo "options nvidia NVreg_OpenRmEnableUnsupportedGpus=1" > /usr/lib/modprobe.d/nvidia.conf
depmod $KREL
install -t /usr/share/licenses/nvidia-open-kernel-modules -Dm644 COPYING
cd ..
rm -rf cd open-gpu-kernel-modules-515.76
unset KREL
# MassOS release detection utility.
gcc $CFLAGS massos-release.c -o massos-release -s
install -m755 massos-release /usr/bin/massos-release
# Additional MassOS files.
install -t /usr/share/massos -Dm644 LICENSE builtins massos-logo.png massos-logo-small.png massos-logo-extrasmall.png massos-logo-notext.png massos-logo-sidetext.png
for i in /usr/share/massos/*.png; do ln -sfr $i /usr/share/pixmaps; done
cp /usr/share/massos/massos-logo-sidetext.png /usr/share/plymouth/themes/spinner/watermark.png
# Clean sources directory and self destruct.
cd ..
rm -rf /sources
