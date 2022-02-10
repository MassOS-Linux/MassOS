#!/bin/bash
#
# THIS SCRIPT MUST **ONLY** BE RUN IN THE MASSOS CHROOT ENVIRONMENT!!
# RUNNING IT AS ROOT ON THE HOST SYSTEM **WILL** BREAK YOUR SYSTEM!!
#
# Build the full MassOS system.
set -e
# Disabling hashing is useful so the newly built tools are detected.
set +h
# Ensure we're running as root.
if [ $EUID -ne 0 ]; then
  echo "DO NOT RUN THIS SCRIPT ON YOUR HOST SYSTEM."
  echo "IT WILL RENDER YOUR SYSTEM UNUSABLE."
  echo "YOU HAVE BEEN WARNED!!!"
  exit 1
fi
# Setup the full filesystem structure.
mkdir -p /{boot,home,mnt,opt,srv}
mkdir -p /boot/efi
mkdir -p /etc/{opt,sysconfig}
mkdir -p /lib/firmware
mkdir -p /media/{floppy,cdrom}
mkdir -p /usr/{,local/}{include,src}
mkdir -p /usr/local/{bin,lib,sbin}
mkdir -p /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -p /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -p /usr/{,local/}share/man/man{1..8}
mkdir -p /var/{cache,local,log,mail,opt,spool}
mkdir -p /var/lib/{color,misc,locate}
ln -sf lib /usr/local/lib64
ln -sf /run /var/run
ln -sf /run/lock /var/lock
install -dm0750 /root
cp /etc/skel/.{bashrc,bash_profile,profile,bash_logout} /root
install -dm1777 /tmp /var/tmp
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp utmp /var/log/lastlog
chmod 664 /var/log/lastlog
chmod 600 /var/log/btmp
# Set the source directory correctly.
export SRC=/sources
cd $SRC
# Set the PATH correctly.
export PATH=/usr/bin:/usr/sbin
# Set the locale correctly.
export LC_ALL="POSIX"
# Build in parallel using all available CPU cores.
export MAKEFLAGS="-j$(nproc)"
# Allow building some packages as root.
export FORCE_UNSAFE_CONFIGURE=1
# libstdc++ from GCC (Pass 2).
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
ln -s gthr-posix.h libgcc/gthr-default.h
mkdir build; cd build
../libstdc++-v3/configure CXXFLAGS="-g -O2 -D_GNU_SOURCE" --prefix=/usr --disable-multilib --disable-nls --host=$(uname -m)-massos-linux-gnu --disable-libstdcxx-pch
make
make install
cd ../..
rm -rf gcc-11.2.0
# Compiler flags for MassOS. We prefer to optimise for size.
CFLAGS="-w -Os -pipe"
CXXFLAGS="-w -Os -pipe"
export CFLAGS CXXFLAGS
# 'msgfmt', 'msgmerge', and 'xgettext' from Gettext.
tar -xf gettext-0.21.tar.xz
cd gettext-0.21
./configure --disable-shared
make
cp gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
cd ..
rm -rf gettext-0.21
# Bison.
tar -xf bison-3.8.2.tar.xz
cd bison-3.8.2
./configure --prefix=/usr
make
make install
cd ..
rm -rf bison-3.8.2
# Perl.
tar -xf perl-5.34.0.tar.xz
cd perl-5.34.0
./Configure -des -Doptimize=-Os -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.34/core_perl -Darchlib=/usr/lib/perl5/5.34/core_perl -Dsitelib=/usr/lib/perl5/5.34/site_perl -Dsitearch=/usr/lib/perl5/5.34/site_perl -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl
make
make install
cd ..
rm -rf perl-5.34.0
# Python.
tar -xf Python-3.10.2.tar.xz
cd Python-3.10.2
./configure --prefix=/usr --enable-shared --without-ensurepip
make
make install
cd ..
rm -rf Python-3.10.2
# Texinfo.
tar -xf texinfo-6.8.tar.xz
cd texinfo-6.8
sed -e 's/__attribute_nonnull__/__nonnull/' -i gnulib/lib/malloc/dynarray-skeleton.c
./configure --prefix=/usr
make
make install
cd ..
rm -rf texinfo-6.8
# util-linux.
tar -xf util-linux-2.37.3.tar.xz
cd util-linux-2.37.3
mkdir -p /var/lib/hwclock
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --without-python runstatedir=/run
make
make install
cd ..
rm -rf util-linux-2.37.3
# Remove documentation from the temporary system.
rm -rf /usr/share/{info,man,doc}/*
# Remove libtool archives (.la).
find /usr/{lib,libexec} -name \*.la -delete
# Remove temporary toolchain directory.
rm -rf /tools
# man-pages.
tar -xf man-pages-5.13.tar.xz
cd man-pages-5.13
make prefix=/usr install
cd ..
rm -rf man-pages-5.13
# iana-etc.
tar -xf iana-etc-20220128.tar.gz
cd iana-etc-20220128
cp services protocols /etc
cd ..
rm -rf iana-etc-20220128
# Glibc.
unset CFLAGS CXXFLAGS
tar -xf glibc-2.34.tar.xz
cd glibc-2.34
sed -e '/NOTIFY_REMOVED)/s/)/ \&\& data.attr != NULL)/' -i sysdeps/unix/sysv/linux/mq_notify.c
patch -Np1 -i ../patches/glibc-2.34-fhs-1.patch
mkdir build; cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --disable-werror --enable-kernel=3.2 --enable-stack-protector=strong --with-headers=/usr/include libc_cv_slibdir=/usr/lib
make
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
install -t /usr/share/licenses/glibc -Dm644 ../COPYING ../COPYING.LIB ../LICENSES
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
cp ../nscd/nscd.conf /etc/nscd.conf
mkdir -p /var/cache/nscd
install -Dm644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
install -Dm644 ../nscd/nscd.service /usr/lib/systemd/system/nscd.service
mkdir -p /usr/lib/locale
mklocales
# Now the en_US.UTF-8 locale is installed, set it as the default.
export LC_ALL="en_US.UTF-8"
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
tar -xf ../../tzdata2021e.tar.gz
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
rm -rf glibc-2.34
CFLAGS="-w -Os -pipe"
CXXFLAGS="-w -Os -pipe"
export CFLAGS CXXFLAGS
# zlib.
tar -xf zlib-1.2.11.tar.xz
cd zlib-1.2.11
./configure --prefix=/usr
make
make install
install -dm755 /usr/share/licenses/zlib
cat zlib.h | head -n28 | tail -n25 > /usr/share/licenses/zlib/LICENSE
rm -f /usr/lib/libz.a
cd ..
rm -rf zlib-1.2.11
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
tar -xf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/xz -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1
cd ..
rm -rf xz-5.2.5
# LZ4.
tar -xf lz4-1.9.3.tar.xz
cd lz4-1.9.3
make PREFIX=/usr CFLAGS="$CFLAGS" -C lib
make PREFIX=/usr CFLAGS="$CFLAGS" -C programs lz4 lz4c
make PREFIX=/usr install
rm -f /usr/lib/liblz4.a
install -t /usr/share/licenses/lz4 -Dm644 LICENSE
cd ..
rm -rf lz4-1.9.3
# ZSTD.
tar -xf zstd-1.5.2.tar.gz
cd zstd-1.5.2
make CFLAGS="$CFLAGS -fPIC"
make prefix=/usr install
rm -f /usr/lib/libzstd.a
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
tar -xf readline-8.1.2.tar.gz
cd readline-8.1.2
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr --disable-static --with-curses
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
install -t /usr/share/licenses/readline -Dm644 COPYING
cd ..
rm -rf readline-8.1.2
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
tar -xf bc-5.2.1.tar.xz
cd bc-5.2.1
CC=gcc ./configure --prefix=/usr -G -Os
make
make install
install -t /usr/share/licenses/bc -Dm644 LICENSE.md
cd ..
rm -rf bc-5.2.1
# Flex.
tar -xf flex-2.6.4.tar.gz
cd flex-2.6.4
./configure --prefix=/usr --disable-static
make
make install
ln -s flex /usr/bin/lex
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
tar -xf binutils-2.37.tar.xz
cd binutils-2.37
patch -Np1 -i ../patches/binutils-2.37-upstream_fix-1.patch
sed -i '63d' etc/texi2pod.pl
find -name \*.1 -delete
sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in
mkdir build; cd build
unset CFLAGS CXXFLAGS
../configure --prefix=/usr --enable-gold --enable-ld=default --enable-plugins --enable-shared --disable-werror --enable-64-bit-bfd --with-system-zlib
make tooldir=/usr
make tooldir=/usr install -j1
rm -f /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
install -t /usr/share/licenses/binutils -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB
cd ../..
rm -rf binutils-2.37
CFLAGS="-w -Os -pipe"
CXXFLAGS="-w -Os -pipe"
export CFLAGS CXXFLAGS
# GMP.
tar -xf gmp-6.2.1.tar.xz
cd gmp-6.2.1
cp configfsf.guess config.guess
cp configfsf.sub config.sub
./configure --prefix=/usr --enable-cxx --disable-static
make
make html
make install
make install-html
install -t /usr/share/licenses/gmp -Dm644 COPYING COPYINGv2 COPYINGv3 COPYING.LESSERv3
cd ..
rm -rf gmp-6.2.1
# MPFR.
tar -xf mpfr-4.1.0.tar.xz
cd mpfr-4.1.0
./configure --prefix=/usr --disable-static --enable-thread-safe
make
make html
make install
make install-html
install -t /usr/share/licenses/mpfr -Dm644 COPYING COPYING.LESSER
cd ..
rm -rf mpfr-4.1.0
# MPC.
tar -xf mpc-1.2.1.tar.gz
cd mpc-1.2.1
./configure --prefix=/usr --disable-static
make
make html
make install
make install-html
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
tar -xf libcap-2.63.tar.xz
cd libcap-2.63
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib CFLAGS="$CFLAGS -fPIC"
make prefix=/usr lib=lib install
chmod 755 /usr/lib/lib{cap,psx}.so.2.63
install -t /usr/share/licenses/libcap -Dm644 License
cd ..
rm -rf libcap-2.63
# CrackLib.
tar -xf cracklib-2.9.7.tar.bz2
cd cracklib-2.9.7
sed -i '/skipping/d' util/packer.c
sed -i '15209 s/.*/am_cv_python_version=3.10/' configure
PYTHON=python3 CPPFLAGS=-I/usr/include/python3.10 ./configure --prefix=/usr --disable-static --with-default-dict=/usr/lib/cracklib/pw_dict
make
make install
install -Dm644 ../cracklib-words-2.9.7.bz2 /usr/share/dict/cracklib-words.bz2
bunzip2 /usr/share/dict/cracklib-words.bz2
ln -sf cracklib-words /usr/share/dict/words
echo "massos" >> /usr/share/dict/cracklib-extra-words
install -dm755 /usr/lib/cracklib
create-cracklib-dict /usr/share/dict/cracklib-words /usr/share/dict/cracklib-extra-words
install -t /usr/share/licenses/cracklib -Dm644 COPYING.LIB
cd ..
rm -rf cracklib-2.9.7
# Linux-PAM.
tar -xf Linux-PAM-1.5.2.tar.xz
cd Linux-PAM-1.5.2
tar -xf ../Linux-PAM-1.5.2-docs.tar.xz --strip-components=1
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --enable-securedir=/usr/lib/security
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
# Libcap (with Linux-PAM).
tar -xf libcap-2.63.tar.xz
cd libcap-2.63
make CFLAGS="$CFLAGS -fPIC" -C pam_cap
install -m755 pam_cap/pam_cap.so /usr/lib/security
install -m644 pam_cap/capability.conf /etc/security
cat > /etc/pam.d/system-auth << END
auth      optional    pam_cap.so
auth      required    pam_unix.so
END
cd ..
rm -rf libcap-2.63
# Shadow (initial build; will be rebuilt later to support AUDIT).
tar -xf shadow-4.11.1.tar.xz
cd shadow-4.11.1
patch -Np1 -i ../patches/shadow-4.11.1-MassOSFixes.patch
touch /usr/bin/passwd
./configure --sysconfdir=/etc --with-group-name-max-length=32 --with-libcrack
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
rm -rf shadow-4.11.1
# GCC.
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
sed -e '/static.*SIGSTKSZ/d' -e 's/return kAltStackSize/return SIGSTKSZ * 4/' -i libsanitizer/sanitizer_common/sanitizer_posix_libcdep.cpp
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir build; cd build
# GCC must not be built with our custom compiler flags, so we unset them here.
unset CFLAGS CXXFLAGS
# Ensure GCC uses the linker from the latest installed binutils.
export LD=ld
../configure --prefix=/usr --enable-languages=c,c++ --with-system-zlib --enable-default-ssp --disable-bootstrap --disable-multilib
make
make install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion)/include-fixed/bits/
ln -sr /usr/bin/cpp /usr/lib
ln -sf ../../libexec/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion)/liblto_plugin.so /usr/lib/bfd-plugins/
mkdir -p /usr/share/gdb/auto-load/usr/lib
mv /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
install -t /usr/share/licenses/gcc -Dm644 ../COPYING ../COPYING.LIB ../COPYING3 ../COPYING3.LIB ../COPYING.RUNTIME
cd ../..
rm -rf gcc-11.2.0
unset LD
# Re-set compiler flags.
CFLAGS="-w -Os -pipe"
CXXFLAGS="-w -Os -pipe"
export CFLAGS CXXFLAGS
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
# Psmisc.
tar -xf psmisc-23.4.tar.xz
cd psmisc-23.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/psmisc -Dm644 COPYING
cd ..
rm -rf psmisc-23.4
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
tar -xf grep-3.7.tar.xz
cd grep-3.7
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/grep -Dm644 COPYING
cd ..
rm -rf grep-3.7
# Bash.
tar -xf bash-5.1.16.tar.gz
cd bash-5.1.16
./configure --prefix=/usr --without-bash-malloc --with-installed-readline
make
make install
install -t /usr/share/licenses/bash -Dm644 COPYING
cd ..
rm -rf bash-5.1.16
# libtool.
tar -xf libtool-2.4.6.tar.xz
cd libtool-2.4.6
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libltdl.a
install -t /usr/share/licenses/libtool -Dm644 COPYING
cd ..
rm -rf libtool-2.4.6
# GDBM.
tar -xf gdbm-1.22.tar.gz
cd gdbm-1.22
./configure --prefix=/usr --disable-static --enable-libgdbm-compat
make
make install
install -t /usr/share/licenses/gdbm -Dm644 COPYING
cd ..
rm -rf gdbm-1.22
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
tar -xf expat-2.4.3.tar.xz
cd expat-2.4.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/expat -Dm644 COPYING
cd ..
rm -rf expat-2.4.3
# Inetutils.
tar -xf inetutils-2.2.tar.xz
cd inetutils-2.2
./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var --disable-logger --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh
make
make install
mv /usr/{,s}bin/ifconfig
install -t /usr/share/licenses/inetutils -Dm644 COPYING
cd ..
rm -rf inetutils-2.2
# Netcat.
tar -xf netcat-0.7.1.tar.xz
cd netcat-0.7.1
./configure --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -t /usr/share/licenses/netcat -Dm644 COPYING
cd ..
rm -rf netcat-0.7.1
# Less.
tar -xf less-590.tar.gz
cd less-590
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/less -Dm644 COPYING LICENSE
cd ..
rm -rf less-590
# Perl.
tar -xf perl-5.34.0.tar.xz
cd perl-5.34.0
patch -Np1 -i ../patches/perl-5.34.0-upstream_fixes-1.patch
export BUILD_ZLIB=False BUILD_BZIP2=0
./Configure -des -Doptimize=-Os -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.34/core_perl -Darchlib=/usr/lib/perl5/5.34/core_perl -Dsitelib=/usr/lib/perl5/5.34/site_perl -Dsitearch=/usr/lib/perl5/5.34/site_perl -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 -Dpager="/usr/bin/less -isR" -Duseshrplib -Dusethreads
make
make install
unset BUILD_ZLIB BUILD_BZIP2
install -t /usr/share/licenses/perl -Dm644 Artistic Copying
cd ..
rm -rf perl-5.34.0
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
# elfutils.
tar -xf elfutils-0.186.tar.bz2
cd elfutils-0.186
./configure --prefix=/usr --program-prefix="eu-" --disable-debuginfod --enable-libdebuginfod=dummy
make
make install
rm -f /usr/lib/lib{asm,dw,elf}.a
install -t /usr/share/licenses/elfutils -Dm644 COPYING COPYING-GPLV2 COPYING-LGPLV3
cd ..
rm -rf elfutils-0.186
# libffi.
tar -xf libffi-3.4.2.tar.gz
cd libffi-3.4.2
./configure --prefix=/usr --disable-static --disable-exec-static-tramp
make
make install
install -t /usr/share/licenses/libffi -Dm644 LICENSE
cd ..
rm -rf libffi-3.4.2
# OpenSSL Legacy (For compatibility with binaries linked to OpenSSL 1.1 libs).
tar -xf openssl-1.1.1m.tar.gz
cd openssl-1.1.1m
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
install -t /usr/share/licenses/openssl-legacy -Dm644 LICENSE
cd ..
rm -rf openssl-1.1.1m
# OpenSSL (Newest version and the default which MassOS programs will use).
tar -xf openssl-3.0.1.tar.gz
cd openssl-3.0.1
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
install -t /usr/share/licenses/openssl -Dm644 LICENSE.txt
cd ..
rm -rf openssl-3.0.1
# kmod.
tar -xf kmod-29.tar.xz
cd kmod-29
./configure --prefix=/usr --sysconfdir=/etc --with-xz --with-zstd --with-zlib --with-openssl
make
make install
for target in depmod insmod modinfo modprobe rmmod; do ln -sf ../bin/kmod /usr/sbin/$target; done
ln -sf kmod /usr/bin/lsmod
install -t /usr/share/licenses/kmod -Dm644 COPYING
cd ..
rm -rf kmod-29
# Python (initial build; will be rebuilt later to support SQLite and Tk).
tar -xf Python-3.10.2.tar.xz
cd Python-3.10.2
./configure --prefix=/usr --enable-shared --with-system-expat --with-system-ffi --with-ensurepip=yes --enable-optimizations
make
make install
ln -sf python3 /usr/bin/python
ln -sf pydoc3 /usr/bin/pydoc
ln -sf idle3 /usr/bin/idle
ln -sf python3-config /usr/bin/python-config
ln -sf pip3 /usr/bin/pip
install -t /usr/share/licenses/python -Dm644 LICENSE
cd ..
rm -rf Python-3.10.2
# Ninja.
tar -xf ninja-1.10.2.tar.gz
cd ninja-1.10.2
python configure.py --bootstrap
install -m755 ninja /usr/bin
install -Dm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -Dm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja
install -t /usr/share/licenses/ninja -Dm644 COPYING
cd ..
rm -rf ninja-1.10.2
# Meson.
tar -xf meson-0.61.1.tar.gz
cd meson-0.61.1
python setup.py build
python setup.py install --root=meson-destination-directory
cp -r meson-destination-directory/* /
install -Dm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -Dm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
install -t /usr/share/licenses/meson -Dm644 COPYING
cd ..
rm -rf meson-0.61.1
# PyParsing.
tar -xf pyparsing_3.0.6.tar.gz
cd pyparsing-pyparsing_3.0.6
python setup.py build
python setup.py install --prefix=/usr --optimize=1
install -t /usr/share/licenses/pyparsing -Dm644 LICENSE
cd ..
rm -rf pyparsing-pyparsing_3.0.6
# distro.
tar -xf distro-1.6.0.tar.gz
cd distro-1.6.0
python setup.py build
python setup.py install --skip-build
install -t /usr/share/licenses/distro -Dm644 LICENSE
cd ..
rm -rf distro-1.6.0
# libseccomp.
tar -xf libseccomp-2.5.3.tar.gz
cd libseccomp-2.5.3
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libseccomp -Dm644 LICENSE
cd ..
rm -rf libseccomp-2.5.3
# File.
tar -xf file-5.41.tar.gz
cd file-5.41
./configure --prefix=/usr --enable-libseccomp
make
make install
install -t /usr/share/licenses/file -Dm644 COPYING
cd ..
rm -rf file-5.41
# Coreutils.
tar -xf coreutils-9.0.tar.xz
cd coreutils-9.0
./configure --prefix=/usr --enable-no-install-program=kill,uptime
make
make install
mv /usr/bin/chroot /usr/sbin
mv /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
install -t /usr/share/licenses/coreutils -Dm644 COPYING
cd ..
rm -rf coreutils-9.0
# Moreutils.
tar -xf moreutils-0.66.tar.xz
cd moreutils-0.66
patch -Np1 -i ../patches/moreutils-0.66-pregenerated-manpages.patch
make CFLAGS="$CFLAGS"
make install
for i in chronic combine errno ifdata ifne isutf8 lckdo mispipe pee sponge vidir vipe zrun; do chmod 644 /usr/share/man/man1/$i.1; done
chmod 644 /usr/share/man/man1/ts.1moreutils
install -t /usr/share/licenses/moreutils -Dm644 COPYING
cd ..
rm -rf moreutils-0.66
# Check.
tar -xf check-0.15.2.tar.gz
cd check-0.15.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/check -Dm644 COPYING.LESSER
cd ..
rm -rf check-0.15.2
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
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
make install
ln -sf gawk.1 /usr/share/man/man1/awk.1
install -t /usr/share/licenses/gawk -Dm644 COPYING
cd ..
rm -rf gawk-5.1.0
# Findutils.
tar -xf findutils-4.8.0.tar.xz
cd findutils-4.8.0
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make install
install -t /usr/share/licenses/findutils -Dm644 COPYING
cd ..
rm -rf findutils-4.8.0
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
tar -xf gzip-1.11.tar.xz
cd gzip-1.11
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gzip -Dm644 COPYING
cd ..
rm -rf gzip-1.11
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
cd build_unix
../dist/configure --prefix=/usr --enable-compat185 --enable-dbm --disable-static --enable-cxx
make
make install
chown -R root:root /usr/bin/db_* /usr/include/db{,_185,_cxx}.h /usr/lib/libdb*.{so,la}
install -t /usr/share/licenses/db -Dm644 ../LICENSE
cd ../..
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
tar -xf cyrus-sasl-2.1.27.tar.gz
cd cyrus-sasl-2.1.27
./configure --prefix=/usr --sysconfdir=/etc --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
install -t /usr/share/licenses/cyrus-sasl -Dm644 COPYING
cd ..
rm -rf cyrus-sasl-2.1.27
# iptables.
tar -xf iptables-1.8.7.tar.bz2
cd iptables-1.8.7
./configure --prefix=/usr --disable-nftables --enable-libipq
make
make install
install -t /usr/share/licenses/iptables -Dm644 COPYING
cd ..
rm -rf iptables-1.8.7
# IPRoute2.
tar -xf iproute2-5.16.0.tar.xz
cd iproute2-5.16.0
make
make SBINDIR=/usr/sbin install
install -t /usr/share/licenses/iproute2 -Dm644 COPYING
cd ..
rm -rf iproute2-5.16.0
# Kbd.
tar -xf kbd-2.4.0.tar.xz
cd kbd-2.4.0
patch -Np1 -i ../patches/kbd-2.4.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/kbd -Dm644 COPYING
cd ..
rm -rf kbd-2.4.0
# libpipeline.
tar -xf libpipeline-1.5.5.tar.gz
cd libpipeline-1.5.5
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libpipeline -Dm644 COPYING
cd ..
rm -rf libpipeline-1.5.5
# libuv.
tar -xf libuv-v1.43.0.tar.gz
cd libuv-v1.43.0
./autogen.sh
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libuv -Dm644 LICENSE
cd ..
rm -rf libuv-v1.43.0
# Make.
tar -xf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/make -Dm644 COPYING
cd ..
rm -rf make-4.3
# Ed.
tar -xf ed-1.17.tar.xz
cd ed-1.17
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/ed -Dm644 COPYING
cd ..
rm -rf ed-1.17
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
# Nano (Vim will be installed later, after Xorg, to support a GUI).
tar -xf nano-6.0.tar.xz
cd nano-6.0
./configure --prefix=/usr --sysconfdir=/etc --enable-utf8
make
make install
cp doc/sample.nanorc /etc/nanorc
sed -i '0,/# include/{s/# include/include/}' /etc/nanorc
install -t /usr/share/licenses/nano -Dm644 COPYING
cd ..
rm -rf nano-6.0
# dos2unix.
tar -xf dos2unix-7.4.2.tar.gz
cd dos2unix-7.4.2
make
make install
install -t /usr/share/licenses/dos2unix -Dm644 COPYING.txt
cd ..
rm -rf dos2unix-7.4.2
# MarkupSafe.
tar -xf MarkupSafe-2.0.1.tar.gz
cd MarkupSafe-2.0.1
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/markupsafe -Dm644 LICENSE.rst
cd ..
rm -rf MarkupSafe-2.0.1
# Jinja2.
tar -xf Jinja2-3.0.3.tar.gz
cd Jinja2-3.0.3
python setup.py install --optimize=1
install -t /usr/share/licenses/jinja2 -Dm644 LICENSE.rst
cd ..
rm -rf Jinja2-3.0.3
# Mako.
tar -xf Mako-1.1.6.tar.gz
cd Mako-1.1.6
python setup.py install --optimize=1
install -t /usr/share/licenses/mako -Dm644 LICENSE
cd ..
rm -rf Mako-1.1.6
# Pygments.
tar -xf Pygments-2.11.2.tar.gz
cd Pygments-2.11.2
python setup.py install --optimize=1
install -t /usr/share/licenses/pygments -Dm644 LICENSE
cd ..
rm -rf Pygments-2.11.2
# dialog.
tar -xf dialog-1.3-20220117.tgz
cd dialog-1.3-20220117
./configure --prefix=/usr --enable-nls --with-libtool --with-ncursesw
make
make install
rm -f /usr/lib/libdialog.a
chmod 755 /usr/lib/libdialog.so.15.0.0
chmod 755 /usr/lib/libdialog.la
install -t /usr/share/licenses/dialog -Dm644 COPYING
cd ..
rm -rf dialog-1.3-20220117
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
tar -xf tree-2.0.1.tgz
cd tree-2.0.1
make CFLAGS="$CFLAGS"
make prefix=/usr MANDIR=/usr/share/man install
chmod 644 /usr/share/man/man1/tree.1
install -t /usr/share/licenses/tree -Dm644 LICENSE
cd ..
rm -rf tree-2.0.1
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
# ICU.
tar -xf icu4c-70_1-src.tgz
cd icu/source
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/icu -Dm644 ../LICENSE
cd ../..
rm -rf icu
# Boost.
tar -xf boost_1_78_0.tar.bz2
cd boost_1_78_0
./bootstrap.sh --prefix=/usr --with-python=python3
./b2 stage -j$(nproc) threading=multi link=shared
./b2 install threading=multi link=shared
install -t /usr/share/licenses/icu -Dm644 LICENSE_1_0.txt
cd ..
rm -rf boost_1_78_0
# libgpg-error.
tar -xf libgpg-error-1.44.tar.bz2
cd libgpg-error-1.44
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libgpg-error -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libgpg-error-1.44
# libgcrypt.
tar -xf libgcrypt-1.9.4.tar.bz2
cd libgcrypt-1.9.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libgcrypt -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libgcrypt-1.9.4
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
tar -xf zlib-1.2.11.tar.xz
cd zlib-1.2.11/contrib/minizip
autoreconf -fi
./configure --prefix=/usr --enable-static=no
make
make install
ln -sf zlib /usr/share/licenses/minizip
cd ../../..
rm -rf zlib-1.2.11
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
unzip ../docbk31.zip
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
unzip ../docbook-4.5.zip
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
tar -xf libxml2_2.9.12+dfsg.orig.tar.xz
cd libxml2-2.9.12
./configure --prefix=/usr --disable-static --with-history --with-python=/usr/bin/python3
make
make install
install -t /usr/share/licenses/libxml2 -Dm644 COPYING
cd ..
rm -rf libxml2-2.9.12
# libarchive.
tar -xf libarchive-3.5.2.tar.xz
cd libarchive-3.5.2
sed -i '436a if ((OSSL_PROVIDER_load(NULL, "legacy")) == NULL) return (ARCHIVE_FAILED);' libarchive/archive_digest.c
./configure --prefix=/usr --disable-static
make
make install
ln -sf bsdtar /usr/bin/tar
ln -sf bsdcpio /usr/bin/cpio
ln -sf bsdtar.1 /usr/share/man/man1/tar.1
ln -sf bsdcpio.1 /usr/share/man/man1/cpio.1
install -t /usr/share/licenses/libarchive -Dm644 COPYING
cd ..
rm -rf libarchive-3.5.2
# Docbook XML 4.5.
mkdir docbook-xml-4.5
cd docbook-xml-4.5
unzip ../docbook-xml-4.5.zip
install -dm755 /usr/share/xml/docbook/xml-dtd-4.5
install -dm755 /etc/xml
chown -R root:root .
cp -af docbook.cat *.dtd ent/ *.mod /usr/share/xml/docbook/xml-dtd-4.5
if [ ! -e /etc/xml/docbook ]; then
  xmlcatalog --noout --create /etc/xml/docbook
fi
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
if [ ! -e /etc/xml/catalog ]; then
  xmlcatalog --noout --create /etc/xml/catalog
fi
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
tar -xf libxslt_1.1.34.orig.tar.gz
cd libxslt-1.1.34
sed -i s/3000/5000/ libxslt/transform.c doc/xsltproc.{1,xml}
./configure --prefix=/usr --disable-static --without-python
make
make install
install -t /usr/share/licenses/libxslt -Dm644 COPYING Copyright
cd ..
rm -rf libxslt-1.1.34
# Lynx.
tar -xf lynx2.8.9rel.1.tar.bz2
cd lynx2.8.9rel.1
./configure --prefix=/usr --sysconfdir=/etc/lynx --datadir=/usr/share/doc/lynx-2.8.9rel.1 --with-zlib --with-bzlib --with-ssl --with-screen=ncursesw --enable-locale-charset
make
make install-full
chgrp -R root /usr/share/doc/lynx-2.8.9rel.1/lynx_doc
sed -e '/#LOCALE/     a LOCALE_CHARSET:TRUE' -i /etc/lynx/lynx.cfg
sed -e '/#DEFAULT_ED/ a DEFAULT_EDITOR:vi' -i /etc/lynx/lynx.cfg
sed -e '/#PERSIST/    a PERSISTENT_COOKIES:TRUE' -i /etc/lynx/lynx.cfg
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
./configure --prefix=/usr --disable-static --enable-default-catalog=/etc/sgml/catalog --enable-http --enable-default-search-path=/usr/share/sgml
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
unzip docbook-5.0.zip
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
unzip ../docbook-v5.1-os.zip
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
tar -xf lxml-4.7.1.tar.gz
cd lxml-4.7.1
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/lxml -Dm644 LICENSE.txt LICENSES.txt
cd ..
rm -rf lxml-4.7.1
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
tar -xf asciidoc-10.1.1.tar.gz
cd asciidoc-10.1.1
python setup.py install --optimize=1
cd ..
rm -rf asciidoc-10.1.1
# GNU-EFI.
tar -xf gnu-efi-3.0.13.tar.bz2
cd gnu-efi-3.0.13
make
make -C lib
make -C gnuefi
make -C inc
make -C apps
make PREFIX=/usr install
install -Dm644 apps/*.efi -t /usr/share/gnu-efi/apps/x86_64
install -t /usr/share/licenses/gnu-efi -Dm644 README.efilib
cd ..
rm -rf gnu-efi-3.0.13
# Systemd (initial build; will be rebuilt later to support more features).
tar -xf systemd-stable-250.3.tar.gz
cd systemd-stable-250.3
sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
mkdir systemd-better-than-the-rest-build; cd systemd-better-than-the-rest-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var --buildtype=release -Dmode=release -Dfallback-hostname=massos -Dversion-tag=250.3-massos -Dblkid=true -Ddefault-dnssec=no -Dfirstboot=false -Dinstall-tests=false -Dldconfig=false -Dsysusers=false -Db_lto=false -Drpmmacrosdir=no -Dhomed=false -Duserdb=false -Dgnu-efi=true -Dman=true -Dpamconfdir=/etc/pam.d ..
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
rm -rf systemd-stable-250.3
# D-Bus (initial build; will be rebuilt later for X support (dbus-launch)).
tar -xf dbus-1.12.20.tar.gz
cd dbus-1.12.20
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-doxygen-docs --with-console-auth-dir=/run/console --with-system-pid-file=/run/dbus/pid --with-system-socket=/run/dbus/system_bus_socket
make
make install
ln -sf /etc/machine-id /var/lib/dbus
install -t /usr/share/licenses/dbus -Dm644 COPYING
cd ..
rm -rf dbus-1.12.20
# Man-DB.
tar -xf man-db-2.9.4.tar.xz
cd man-db-2.9.4
./configure --prefix=/usr --sysconfdir=/etc --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap
make
make install
install -t /usr/share/licenses/man-db -Dm644 docs/COPYING docs/COPYING.LIB
cd ..
rm -rf man-db-2.9.4
# Procps-NG.
tar -xf procps-ng-3.3.17.tar.xz
cd procps-3.3.17
./configure --prefix=/usr --disable-static --disable-kill --with-systemd
make
make install
install -t /usr/share/licenses/procps-ng -Dm644 COPYING COPYING.LIB
cd ..
rm -rf procps-3.3.17
# util-linux.
tar -xf util-linux-2.37.3.tar.xz
cd util-linux-2.37.3
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --without-python runstatedir=/run
make
make install
install -t /usr/share/licenses/util-linux -Dm644 COPYING
cd ..
rm -rf util-linux-2.37.3
# Busybox.
tar -xf busybox-1.35.0.tar.bz2
cd busybox-1.35.0
cp ../busybox-config .config
make
install -m755 busybox /usr/bin/busybox
install -t /usr/share/licenses/busybox -Dm644 LICENSE
cd ..
rm -rf busybox-1.35.0
# fuse2.
tar -xf fuse-2.9.9.tar.gz
cd fuse-2.9.9
patch -Np1 -i ../patches/fuse-2.9.9-glibc234.patch
autoreconf -fi
UDEV_RULES_PATH=/usr/lib/udev/rules.d MOUNT_FUSE_PATH=/usr/bin ./configure --prefix=/usr --libdir=/usr/lib --enable-lib --enable-util --disable-example
make
make DESTDIR=$PWD/dest install
rm -rf dest/etc/init.d
rm -rf dest/dev
rm -f dest/usr/lib/libfuse.a
cp -R dest/* /
ldconfig
chmod 4755 /usr/bin/fusermount
install -t /usr/share/licenses/fuse2 -Dm644 COPYING COPYING.LIB
cd ..
rm -rf fuse-2.9.9
# fuse3.
tar -xf fuse-3.10.5.tar.xz
cd fuse-3.10.5
sed -i '/^udev/,$ s/^/#/' util/meson.build
mkdir fuse3-build; cd fuse3-build
meson --prefix=/usr --buildtype=release ..
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
rm -rf fuse-3.10.5
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
install -t /usr/share/licenses/e2fsprogs -Dm644 ../../extra-package-files/e2fsprogs-license.txt
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
tar -xf dracut-055.tar.gz
cd dracut-055
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
rm -rf dracut-055
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
tar -xf squashfs-tools-4.5.tar.xz
cd squashfs-tools-4.5
make GZIP_SUPPORT=1 XZ_SUPPORT=1 LZO_SUPPORT=1 LZMA_XZ_SUPPORT=1 LZ4_SUPPORT=1 ZSTD_SUPPORT=1 XATTR_SUPPORT=1
make INSTALL_DIR=/usr/bin install
install -t /usr/share/licenses/squashfs-tools -Dm644 COPYING
cd ..
rm -rf squashfs-tools-4.5
# squashfuse.
tar -xf squashfuse-0.1.104.tar.gz
cd squashfuse-0.1.104
./configure --prefix=/usr
make
make install
install -Dm644 *.h /usr/include/squashfuse
install -t /usr/share/licenses/squashfuse -Dm644 LICENSE
cd ..
rm -rf squashfuse-0.1.104
# libaio.
tar -xf libaio_0.3.112.orig.tar.xz
cd libaio-0.3.112
sed -i '/install.*libaio.a/s/^/#/' src/Makefile
make
make install
install -t /usr/share/licenses/libaio -Dm644 COPYING
cd ..
rm -rf libaio-0.3.112
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
# LVM2 (precompiled package, to avoid a segfault at runtime).
tar --no-same-owner -xpf lvm2-2.03.14-x86_64-precompiled-MassOS.tar.xz
cp -r lvm2-2.03.14-x86_64-precompiled-MassOS/{etc,usr} /
ldconfig
install -t /usr/share/licenses/lvm2 -Dm644 lvm2-2.03.14-x86_64-precompiled-MassOS/COPYING*
rm -rf lvm2-2.03.14-x86_64-precompiled-MassOS
# btrfs-progs.
tar -xf btrfs-progs-v5.16.tar.xz
cd btrfs-progs-v5.16
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/btrfs-progs -Dm644 COPYING
cd ..
rm -rf btrfs-progs-v5.16
# inih.
tar -xf libinih_53.orig.tar.gz
cd inih-r53
mkdir inih-build; cd inih-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/inih -Dm644 ../LICENSE.txt
cd ../..
rm -rf inih-r53
# Userspace-RCU (dependency of xfsprogs since 5.14.0).
tar -xf userspace-rcu-0.13.1.tar.bz2
cd userspace-rcu-0.13.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/userspace-rcu -Dm644 LICENSE gpl-2.0.txt lgpl-2.1.txt lgpl-relicensing.txt
cd ..
rm -rf userspace-rcu-0.13.1
# xfsprogs.
tar -xf xfsprogs-5.14.2.tar.xz
cd xfsprogs-5.14.2
make DEBUG=-DNDEBUG INSTALL_USER=root INSTALL_GROUP=root
make install
make install-dev
cd ..
rm -rf xfsprogs-5.14.2
# ntfs-3g.
tar -xf ntfs-3g_ntfsprogs-2021.8.22.tgz
cd ntfs-3g_ntfsprogs-2021.8.22
./configure --prefix=/usr --disable-static --with-fuse=external
make
make install
ln -s ../bin/ntfs-3g /usr/sbin/mount.ntfs
ln -s ntfs-3g.8 /usr/share/man/man8/mount.ntfs.8
install -t /usr/share/licenses/ntfs-3g -Dm644 COPYING COPYING.LIB
cd ..
rm -rf ntfs-3g_ntfsprogs-2021.8.22
# exfatprogs.
tar -xf exfatprogs_1.1.3.orig.tar.xz
cd exfatprogs-1.1.3
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/exfatprogs -Dm644 COPYING
cd ..
rm -rf exfatprogs-1.1.3
# Fakeroot.
tar -xf fakeroot_1.27.orig.tar.gz
cd fakeroot-1.27
./configure --prefix=/usr --libdir=/usr/lib/libfakeroot --disable-static --with-ip=sysv
make
make install
mkdir -p /etc/ld.so.conf.d
echo "/usr/lib/libfakeroot" > /etc/ld.so.conf.d/fakeroot.conf
ldconfig
install -t /usr/share/licenses/fakeroot -Dm644 COPYING
cd ..
rm -rf fakeroot-1.27
# Parted.
tar -xf parted-3.4.tar.xz
cd parted-3.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/parted -Dm644 COPYING
cd ..
rm -rf parted-3.4
# Popt.
tar -xf popt-1.18.tar.gz
cd popt-1.18
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/popt -Dm644 COPYING
cd ..
rm -rf popt-1.18
# gptfdisk.
tar -xf gptfdisk-1.0.8.tar.gz
cd gptfdisk-1.0.8
patch -Np1 -i ../patches/gptfdisk-1.0.8-convenience-1.patch
sed -i 's|ncursesw/||' gptcurses.cc
sed -i 's|sbin|usr/sbin|' Makefile
make
make install
install -t /usr/share/licenses/gptfdisk -Dm644 COPYING
cd ..
rm -rf gptfdisk-1.0.8
# rsync.
tar -xf rsync-3.2.3.tar.gz
cd rsync-3.2.3
./configure --prefix=/usr --disable-lz4 --disable-xxhash --without-included-zlib
make
make install
install -t /usr/share/licenses/rsync -Dm644 COPYING
cd ..
rm -rf rsync-3.2.3
# Brotli.
tar -xf brotli-1.0.9.tar.gz
cd brotli-1.0.9
./bootstrap
./configure --prefix=/usr
make
python setup.py build
make install
python setup.py install --optimize=1
rm -f /usr/lib/libbrotlidec.a
install -t /usr/share/licenses/brotli -Dm644 LICENSE
cd ..
rm -rf brotli-1.0.9
# nghttp2.
tar -xf nghttp2-1.46.0.tar.xz
cd nghttp2-1.46.0
./configure --prefix=/usr --disable-static --enable-lib-only
make
make install
install -t /usr/share/licenses/nghttp2 -Dm644 COPYING
cd ..
rm -rf nghttp2-1.46.0
# curl (INITIAL BUILD; will be rebuilt later to support FAR MORE FEATURES).
tar -xf curl-7.81.0.tar.xz
cd curl-7.81.0
./configure --prefix=/usr --disable-static --with-openssl --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
install -t /usr/share/licenses/curl -Dm644 COPYING
cd ..
rm -rf curl-7.81.0
# CMake.
tar -xf cmake-3.22.2.tar.gz
cd cmake-3.22.2
sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake
./bootstrap --prefix=/usr --parallel=$(nproc) --generator=Ninja --system-libs --no-system-jsoncpp --no-system-librhash --mandir=/share/man --docdir=/share/doc/cmake
ninja
ninja install
rm -rf /usr/share/doc/cmake
install -t /usr/share/licenses/cmake -Dm644 Copyright.txt
cd ..
rm -rf cmake-3.22.2
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
tar -xf json-c-0.15.tar.gz
cd json-c-0.15
mkdir json-c-build; cd json-c-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/json-c -Dm644 ../COPYING
cd ../..
rm -rf json-c-0.15
# cryptsetup.
tar -xf cryptsetup-2.4.3.tar.xz
cd cryptsetup-2.4.3
./configure --prefix=/usr --disable-ssh-token
make
make install
install -t /usr/share/licenses/cryptsetup -Dm644 COPYING COPYING.LGPL
cd ..
rm -rf cryptsetup-2.4.3
# libusb.
tar -xf libusb-1.0.24.tar.bz2
cd libusb-1.0.24
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libusb -Dm644 COPYING
cd ..
rm -rf libusb-1.0.24
# libmtp.
tar -xf libmtp-1.1.19.tar.gz
cd libmtp-1.1.19
./configure --prefix=/usr --with-udev=/usr/lib/udev
make
make install
rm -f /usr/lib/libmtp.a
install -t /usr/share/licenses/libmtp -Dm644 COPYING
cd ..
rm -rf libmtp-1.1.19
# libnfs.
tar -xf libnfs-4.0.0.tar.gz
cd libnfs-libnfs-4.0.0
./bootstrap
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libnfs.a
install -t /usr/share/licenses/libnfs -Dm644 COPYING LICENCE-BSD.txt LICENCE-GPL-3.txt LICENCE-LGPL-2.1.txt
cd ..
rm -rf libnfs-libnfs-4.0.0
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
tar -xf pcre2-10.39.tar.bz2
cd pcre2-10.39
./configure --prefix=/usr --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline --disable-static
make
make install
install -t /usr/share/licenses/pcre2 -Dm644 LICENCE
cd ..
rm -rf pcre2-10.39
# Grep (rebuild for PCRE support).
tar -xf grep-3.7.tar.xz
cd grep-3.7
./configure --prefix=/usr
make
make install
cd ..
rm -rf grep-3.7
# Less (rebuild for PCRE2 support).
tar -xf less-590.tar.gz
cd less-590
./configure --prefix=/usr --sysconfdir=/etc --with-regex=pcre2
make
make install
cd ..
rm -rf less-590
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
tar -xf libidn2-2.3.2.tar.gz
cd libidn2-2.3.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libidn2 -Dm644 COPYING COPYINGv2 COPYING.LESSERv3 COPYING.unicode
cd ..
rm -rf libidn2-2.3.2
# whois.
tar -xf whois_5.5.11.tar.xz
cd whois
make
make prefix=/usr install-whois
make prefix=/usr install-mkpasswd
make prefix=/usr install-pos
install -t /usr/share/licenses/whois -Dm644 COPYING
cd ..
rm -rf whois
# libpsl.
tar -xf libpsl-0.21.1.tar.gz
cd libpsl-0.21.1
sed -i 's/env python/&3/' src/psl-make-dafsa
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpsl -Dm644 COPYING
cd ..
rm -rf libpsl-0.21.1
# Wget.
tar -xf wget-1.21.2.tar.gz
cd wget-1.21.2
./configure --prefix=/usr --sysconfdir=/etc --with-ssl=openssl --with-cares
make
make install
install -t /usr/share/licenses/wget -Dm644 COPYING
cd ..
rm -rf wget-1.21.2
# usbutils.
tar -xf usbutils-014.tar.xz
cd usbutils-014
./configure --prefix=/usr --datadir=/usr/share/hwdata
make
make install
install -dm755 /usr/share/hwdata
cat > /usr/lib/systemd/system/update-usbids.service << END
[Unit]
Description=Update usb.ids file
Documentation=man:lsusb(8)
DefaultDependencies=no
After=local-fs.target network-online.target
Before=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/wget http://www.linux-usb.org/usb.ids -O /usr/share/hwdata/usb.ids
END
cat > /usr/lib/systemd/system/update-usbids.timer << END
[Unit]
Description=Update usb.ids file weekly

[Timer]
OnCalendar=Sun 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
END
systemctl enable update-usbids.timer
install -t /usr/share/licenses/usbutils -Dm644 LICENSES/*
cd ..
rm -rf usbutils-014
# pciutils.
tar -xf pciutils-3.7.0.tar.xz
cd pciutils-3.7.0
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes
make PREFIX=/usr SHAREDIR=/usr/share/hwdata SHARED=yes install install-lib
chmod 755 /usr/lib/libpci.so
cat > /usr/lib/systemd/system/update-pciids.service << END
[Unit]
Description=Update pci.ids file
Documentation=man:update-pciids(8)
DefaultDependencies=no
After=local-fs.target network-online.target
Before=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/update-pciids
END
cat > /usr/lib/systemd/system/update-pciids.timer << END
[Unit]
Description=Update pci.ids file weekly

[Timer]
OnCalendar=Sun 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
END
systemctl enable update-pciids.timer
install -t /usr/share/licenses/pciutils -Dm644 COPYING
cd ..
rm -rf pciutils-3.7.0
# libtasn1.
tar -xf libtasn1-4.18.0.tar.gz
cd libtasn1-4.18.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libtasn1 -Dm644 COPYING
cd ..
rm -rf libtasn1-4.18.0
# p11-kit.
tar -xf p11-kit-0.24.1.tar.xz
cd p11-kit-0.24.1
sed '20,$ d' -i trust/trust-extract-compat
cat >> trust/trust-extract-compat << END
/usr/libexec/make-ca/copy-trust-modifications
/usr/sbin/make-ca -f -g
END
mkdir p11-build; cd p11-build
meson --prefix=/usr --buildtype=release -Dtrust_paths=/etc/pki/anchors ..
ninja
ninja install
ln -sf /usr/libexec/p11-kit/trust-extract-compat /usr/bin/update-ca-certificates
ln -sf ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
install -t /usr/share/licenses/p11-kit -Dm644 ../COPYING
cd ../..
rm -rf p11-kit-0.24.1
# make-ca.
tar -xf make-ca-1.9.tar.xz
cd make-ca-1.9
make install
install -dm755 /etc/ssl/local
make-ca -g
systemctl enable update-pki.timer
install -t /usr/share/licenses/make-ca -Dm644 LICENSE LICENSE.GPLv3 LICENSE.MIT
curl -L http://www.linux-usb.org/usb.ids -o /usr/share/hwdata/usb.ids
update-pciids
cd ..
rm -rf make-ca-1.9
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
# nghttp2 (rebuild to support more features).
tar -xf nghttp2-1.46.0.tar.xz
cd nghttp2-1.46.0
./configure --prefix=/usr --disable-static --enable-lib-only
make
make install
cd ..
rm -rf nghttp2-1.46.0
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
tar -xf nettle-3.7.3.tar.gz
cd nettle-3.7.3
./configure --prefix=/usr --disable-static
make
make install
chmod 755 /usr/lib/lib{hogweed,nettle}.so
install -t /usr/share/licenses/nettle -Dm644 COPYINGv2 COPYINGv3 COPYING.LESSERv3
cd ..
rm -rf nettle-3.7.3
# GNUTLS.
tar -xf gnutls-3.7.3.tar.xz
cd gnutls-3.7.3
./configure --prefix=/usr --disable-guile --disable-rpath --with-default-trust-store-pkcs11="pkcs11:"
make
make install
install -t /usr/share/licenses/gnutls -Dm644 LICENSE
cd ..
rm -rf gnutls-3.7.3
# OpenLDAP.
tar -xf openldap-2.6.0.tgz
cd openldap-2.6.0
patch -Np1 -i ../patches/openldap-2.6.0-MassOS.patch
autoconf
./configure --prefix=/usr --sysconfdir=/etc --disable-static --enable-dynamic --enable-versioning=yes --disable-debug --disable-slapd
make depend
make
make install
install -t /usr/share/licenses/openldap -Dm644 COPYRIGHT LICENSE
cd ..
rm -rf openldap-2.6.0
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
tar -xf libksba-1.6.0.tar.bz2
cd libksba-1.6.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libksba -Dm644 COPYING COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv3
cd ..
rm -rf libksba-1.6.0
# GNUPG.
tar -xf gnupg-2.2.32.tar.bz2
cd gnupg-2.2.32
sed -e '/noinst_SCRIPTS = gpg-zip/c sbin_SCRIPTS += gpg-zip' -i tools/Makefile.in
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/gnupg -Dm644 COPYING COPYING.CC0 COPYING.GPL2 COPYING.LGPL21 COPYING.LGPL3 COPYING.other
cd ..
rm -rf gnupg-2.2.32
# krb5.
tar -xf krb5-1.19.2.tar.gz
cd krb5-1.19.2/src
patch -Np2 -i ../../patches/krb5-1.19.2-OpenSSL3.patch
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var/lib --runstatedir=/run --with-system-et --with-system-ss --with-system-verto=no --enable-dns-for-realm
make
make install
install -t /usr/share/licenses/krb5 -Dm644 ../NOTICE
cd ../..
rm -rf krb5-1.19.2
# gsasl.
tar -xf gsasl-1.10.0.tar.gz
cd gsasl-1.10.0
./configure --prefix=/usr --disable-static --with-gssapi-impl=mit
make
make install
install -t /usr/share/licenses/gsasl -Dm644 COPYING
cd ..
rm -rf gsasl-1.10.0
# rtmpdump.
tar -xf rtmpdump-2.4-20210219-gf1b83c1.tar.xz
cd rtmpdump-2.4-20210219-gf1b83c1
patch -Np1 -i ../patches/rtmpdump-2.4-openssl.patch
make prefix=/usr mandir=/usr/share/man OPT=-Os
make prefix=/usr mandir=/usr/share/man install
rm -f /usr/lib/librtmp.a
install -t /usr/share/licenses/rtmpdump -Dm644 COPYING
cd ..
rm -rf rtmpdump-2.4-20210219-gf1b83c1
# curl (rebuild to support more features).
tar -xf curl-7.81.0.tar.xz
cd curl-7.81.0
./configure --prefix=/usr --disable-static --with-openssl --with-libssh2 --with-gssapi --enable-ares --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
cd ..
rm -rf curl-7.81.0
# SWIG.
tar -xf swig-4.0.2.tar.gz
cd swig-4.0.2
./configure --prefix=/usr --without-maximum-compile-warnings
make
make install
install -t /usr/share/licenses/swig -Dm644 COPYRIGHT LICENSE LICENSE-GPL LICENSE-UNIVERSITIES
cd ..
rm -rf swig-4.0.2
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
# GPGME.
tar -xf gpgme-1.16.0.tar.bz2
cd gpgme-1.16.0
sed 's/defined(__sun.*$/1/' -i src/posix-io.c
sed -e 's/3\.9/3.10/' -e 's/:3/:4/' -e '23657 s/distutils"/setuptools"/' -i configure
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gpgme -Dm644 COPYING COPYING.LESSER LICENSES
cd ..
rm -rf gpgme-1.16.0
# SQLite.
tar -xf sqlite-autoconf-3370200.tar.gz
cd sqlite-autoconf-3370200
CPPFLAGS="-DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS4=1 -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 -DSQLITE_ENABLE_DBSTAT_VTAB=1 -DSQLITE_SECURE_DELETE=1 -DSQLITE_ENABLE_FTS3_TOKENIZER=1" ./configure --prefix=/usr --disable-static --enable-fts5
make
make install
install -dm755 /usr/share/licenses/sqlite
cat > /usr/share/licenses/sqlite/LICENSE << "END"
The code and documentation of SQLite is dedicated to the public domain.
See https://www.sqlite.org/copyright.html for more information.
END
cd ..
rm -rf sqlite-autoconf-3370200
# Cyrus SASL (rebuild to support krb5 and OpenLDAP).
tar -xf cyrus-sasl-2.1.27.tar.gz
cd cyrus-sasl-2.1.27
./configure --prefix=/usr --sysconfdir=/etc --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-ldap --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
cd ..
rm -rf cyrus-sasl-2.1.27
# libtirpc.
tar -xf libtirpc-1.3.2.tar.bz2
cd libtirpc-1.3.2
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libtirpc -Dm644 COPYING
cd ..
rm -rf libtirpc-1.3.2
# libnsl.
tar -xf libnsl-2.0.0.tar.xz
cd libnsl-2.0.0
./configure --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libnsl -Dm644 COPYING
cd ..
rm -rf libnsl-2.0.0
# Audit.
tar -xf audit-3.0.7.tar.gz
cd audit-3.0.7
./configure --prefix=/usr --sysconfdir=/etc --enable-gssapi-krb5=yes --enable-systemd=yes
make
make install
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
rm -rf audit-3.0.7
# AppArmor.
tar -xf apparmor_3.0.3.orig.tar.gz
cd apparmor-3.0.3
patch -Np1 -i ../patches/apparmor-3.0.3-backport_python310_fix.patch
cd libraries/libapparmor
autoreconf -fi
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
chmod 755 /usr/lib/perl5/*/vendor_perl/auto/LibAppArmor/LibAppArmor.so
systemctl enable apparmor
install -t /usr/share/licenses/apparmor -Dm644 LICENSE libraries/libapparmor/COPYING.LGPL changehat/pam_apparmor/COPYING
cd ..
rm -rf apparmor-3.0.3
# Linux-PAM (rebuild to support Audit).
tar -xf Linux-PAM-1.5.2.tar.xz
cd Linux-PAM-1.5.2
tar -xf ../Linux-PAM-1.5.2-docs.tar.xz --strip-components=1
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --enable-securedir=/usr/lib/security
make
make install
chmod 4755 /usr/sbin/unix_chkpwd
cd ..
rm -rf Linux-PAM-1.5.2
# Shadow (rebuild to support Audit).
tar -xf shadow-4.11.1.tar.xz
cd shadow-4.11.1
patch -Np1 -i ../patches/shadow-4.11.1-MassOSFixes.patch
./configure --sysconfdir=/etc --with-group-name-max-length=32 --with-libcrack --with-audit
make
make exec_prefix=/usr install
make -C man install-man
mkdir -p /etc/default
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
rm -rf shadow-4.11.1
# fcron.
tar -xf fcron-3.2.1.src.tar.gz
cd fcron-3.2.1
groupadd -g 22 fcron
useradd -d /dev/null -c "Fcron User" -g fcron -s /bin/false -u 22 fcron
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --without-sendmail --with-piddir=/run --with-boot-install=no --with-editor=/usr/bin/nano
make
make install
for i in crondyn cronsighup crontab; do ln -sf f$i /usr/bin/$i; done
ln -sf fcron /usr/sbin/cron
for i in crontab.1 crondyn.1; do ln -sf f$i /usr/share/man/man1/$i; done
for i in crontab.1 crondyn.1; do ln -sf f$i /usr/share/man/fr/man1/$i; done
for i in fcrontab.5 fcron.conf.5; do ln -sf f$i /usr/share/man/man5/$i; done
for i in fcrontab.5 fcron.conf.5; do ln -sf f$i /usr/share/man/fr/man5/$i; done
ln -sf fcron.8 /usr/share/man/man8/cron.8
ln -sf fcron.8 /usr/share/man/fr/man8/cron.8
systemctl enable fcron
install -t /usr/share/licenses/fcron -Dm644 doc/en/txt/gpl.txt
cd ..
rm -rf fcron-3.2.1
# NSPR.
tar -xf nspr-4.33.tar.gz
cd nspr-4.33/nspr
sed -ri '/^RELEASE/s/^/#/' pr/src/misc/Makefile.in
sed -i 's#$(LIBRARY) ##' config/rules.mk
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit
make
make install
install -t /usr/share/licenses/nspr -Dm644 LICENSE
cd ../..
rm -rf nspr-4.33
# NSS.
tar -xf nss-3.74.tar.gz
cd nss-3.74
patch -Np1 -i ../patches/nss-3.69-standalone-1.patch
cd nss
make BUILD_OPT=1 NSPR_INCLUDE_DIR=/usr/include/nspr USE_SYSTEM_ZLIB=1 ZLIB_LIBS=-lz NSS_ENABLE_WERROR=0 USE_64=1 NSS_USE_SYSTEM_SQLITE=1
cd ../dist
install -m755 Linux*/lib/*.so /usr/lib
install -m644 Linux*/lib/{*.chk,libcrmf.a} /usr/lib
install -dm755 /usr/include/nss
cp -RL {public,private}/nss/* /usr/include/nss
chmod 644 /usr/include/nss/*
install -m755 Linux*/bin/{certutil,nss-config,pk12util} /usr/bin
install -m644 Linux*/lib/pkgconfig/nss.pc /usr/lib/pkgconfig
ln -sf ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
install -t /usr/share/licenses/nss -Dm644 ../nss/COPYING
cd ../..
rm -rf nss-3.74
# Git.
tar -xf git-2.35.1.tar.xz
cd git-2.35.1
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --with-python=python3 --with-libpcre2
make
make man
make perllibdir=/usr/lib/perl5/5.34/site_perl install
make install-man
install -t /usr/share/licenses/git -Dm644 COPYING LGPL-2.1
cd ..
rm -rf git-2.35.1
# libstemmer.
tar -xf libstemmer-2.1.0.tar.xz
cd libstemmer-2.1.0
make
install -m755 libstemmer.so.0.0.0 /usr/lib/libstemmer.so.0.0.0
ln -s libstemmer.so.0.0.0 /usr/lib/libstemmer.so.0
ln -s libstemmer.so.0 /usr/lib/libstemmer.so
install -m644 include/libstemmer.h /usr/include/libstemmer.h
ldconfig
install -t /usr/share/licenses/libstemmer -Dm644 COPYING
cd ..
rm -rf libstemmer-2.1.0
# Pahole.
tar -xf pahole-1.23.tar.xz
cd pahole-1.23
mkdir pahole-build; cd pahole-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -D__LIB=lib -Wno-dev -G Ninja ..
ninja
ninja install
mv /usr/share/dwarves/runtime/python/ostra.py /usr/lib/python3.10/ostra.py
rm -rf /usr/share/dwarves/runtime/python
install -t /usr/share/licenses/pahole -Dm644 ../COPYING
cd ../..
rm -rf pahole-1.23.tar.xz
# DKMS.
tar -xf dkms-3.0.3.tar.gz
make -C dkms-3.0.3 BASHDIR=/usr/share/bash-completion/completions install
install -t /usr/share/licenses/dkms -Dm644 dkms-3.0.3/COPYING
rm -rf dkms-3.0.3
# GLib.
tar -xf glib-2.70.3.tar.xz
cd glib-2.70.3
patch -Np1 -i ../patches/glib-2.68.4-skip_warnings-1.patch
mkdir glib-build; cd glib-build
meson --prefix=/usr --buildtype=release -Dman=true ..
ninja
ninja install
install -t /usr/share/licenses/glib -Dm644 ../COPYING
cd ../..
rm -rf glib-2.70.3
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
# libsigc++
tar -xf libsigc++-2.10.7.tar.xz
cd libsigc++-2.10.7
mkdir sigc++-build; cd sigc++-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libsigc++ -Dm644 ../COPYING
cd ../..
rm -rf libsigc++-2.10.7
# GLibmm
tar -xf glibmm-2.66.2.tar.xz
cd glibmm-2.66.2
mkdir glibmm-build; cd glibmm-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/glibmm -Dm644 ../COPYING ../COPYING.tools
cd ../..
rm -rf glibmm-2.66.2
# gobject-introspection.
tar -xf gobject-introspection-1.70.0.tar.xz
cd gobject-introspection-1.70.0
patch -Np1 -i ../patches/gobject-introspection-1.70.0-meson-0.61.0-fix.patch
mkdir gobj-build; cd gobj-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/gobject-introspection -Dm644 ../COPYING ../COPYING.GPL ../COPYING.LGPL
cd ../..
rm -rf gobject-introspection-1.70.0
# shared-mime-info.
tar -xf shared-mime-info-2.1.tar.gz
cd shared-mime-info-2.1
patch -Np1 -i ../patches/shared-mime-info-2.1-mesonfix.patch
mkdir smi-build; cd smi-build
meson --prefix=/usr --buildtype=release -Dupdate-mimedb=true ..
ninja
ninja install
install -t /usr/share/licenses/shared-mime-info -Dm644 ../COPYING
cd ../..
rm -rf shared-mime-info-2.1
# desktop-file-utils.
tar -xf desktop-file-utils-0.26.tar.xz
cd desktop-file-utils-0.26
mkdir dfu-build; cd dfu-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -dm755 /usr/share/applications
update-desktop-database /usr/share/applications
install -t /usr/share/licenses/desktop-file-utils -Dm644 ../COPYING
cd ../..
rm -rf desktop-file-utils-0.26
# Graphene.
tar -xf graphene-1.10.6.tar.xz
cd graphene-1.10.6
mkdir graphene-build; cd graphene-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/graphene -Dm644 ../LICENSE.txt
cd ../..
rm -rf graphene-1.10.6
# Autoconf (2.13).
tar -xf autoconf-2.13.tar.gz
cd autoconf-2.13
patch -Np1 -i ../patches/autoconf-2.13-consolidated_fixes-1.patch
mv autoconf.texi autoconf213.texi
rm autoconf.info
./configure --prefix=/usr --program-suffix=2.13
make
make install
install -m644 autoconf213.info /usr/share/info
install-info --info-dir=/usr/share/info autoconf213.info
install -t /usr/share/licenses/autoconf213 -Dm644 COPYING
cd ..
rm -rf autoconf-2.13
# LLVM.
tar -xf llvm-13.0.0.src.tar.xz
cd llvm-13.0.0.src
mkdir -p tools/clang
tar -xf ../clang-13.0.0.src.tar.xz -C tools/clang --strip-components=1
mkdir llvm-build; cd llvm-build
CC=gcc CXX=g++ CFLAGS="$CFLAGS -flarge-source-files" CXXFLAGS="$CXXFLAGS -flarge-source-files" cmake -DCMAKE_INSTALL_PREFIX=/usr -DLLVM_ENABLE_FFI=ON -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_TARGETS_TO_BUILD="host;AMDGPU" -DLLVM_BUILD_TESTS=ON -DLLVM_BINUTILS_INCDIR=/usr/include -Wno-dev -G Ninja ..
ninja -j$(nproc)
ninja install
install -t /usr/share/licenses/llvm -Dm644 ../LICENSE.TXT
ln -sf llvm /usr/share/licenses/clang
cd ../..
rm -rf llvm-13.0.0.src
# Rust.
tar -xf rust-1.54.0-x86_64-unknown-linux-gnu.tar.gz
cd rust-1.54.0-x86_64-unknown-linux-gnu
# We will uninstall Rust later.
./install.sh --prefix=/usr --sysconfdir=/etc --without=rust-docs
cd ..
rm -rf rust-1.54.0-x86_64-unknown-linux-gnu
# JS78.
tar -xf firefox-78.15.0esr.source.tar.xz
cd firefox-78.15.0
patch -Np1 -i ../patches/js78-78.15.0-python310.patch
mkdir obj; cd obj
if mountpoint -q /dev/shm; then
  beforemounted="true"
else
  mount -t tmpfs devshm /dev/shm
  beforemounted="false"
fi
SHELL=/bin/sh ../js/src/configure --prefix=/usr --with-intl-api --with-system-zlib --with-system-icu --disable-jemalloc --disable-debug-symbols --enable-readline
make
make install
rm /usr/lib/libjs_static.ajs
sed -i '/@NSPR_CFLAGS@/d' /usr/bin/js78-config
if [ "$beforemounted" = "false" ]; then
  umount /dev/shm
fi
unset beforemounted
install -t /usr/share/licenses/js78 -Dm644 ../../extra-package-files/js78-license.txt
cd ../..
rm -rf firefox-78.15.0
# Sudo.
tar -xf sudo-1.9.9.tar.gz
cd sudo-1.9.9
./configure --prefix=/usr --libexecdir=/usr/lib --with-secure-path --with-all-insults --with-env-editor --with-passprompt="[sudo] password for %p: "
make
make install
ln -sf libsudo_util.so.0.0.0 /usr/lib/sudo/libsudo_util.so.0
cat > /etc/sudoers.d/default << END
# Show astericks when typing the password.
Defaults pwfeedback
# Allow members of the 'wheel' group to execute 'sudo'.
%wheel ALL=(ALL) ALL
END
cat > /etc/pam.d/sudo << END
auth      include     system-auth
account   include     system-account
session   required    pam_env.so
session   include     system-session
END
install -t /usr/share/licenses/sudo -Dm644 LICENSE.md
cd ..
rm -rf sudo-1.9.9
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
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/json-glib -Dm644 ../COPYING
cd ../..
rm -rf json-glib-1.6.6
# efivar.
tar -xf efivar-37.tar.bz2
cd efivar-37
make CFLAGS="$CFLAGS"
make install LIBDIR=/usr/lib
install -t /usr/share/licenses/efivar -Dm644 COPYING
cd ..
rm -rf efivar-37
# efibootmgr.
tar -xf efibootmgr_17.orig.tar.gz
cd efibootmgr-17
sed -e '/extern int efi_set_verbose/d' -i src/efibootmgr.c
make EFIDIR=massos EFI_LOADER=grubx64.efi
make EFIDIR=massos install
install -t /usr/share/licenses/efibootmgr -Dm644 COPYING
cd ..
rm -rf efibootmgr-17
# libpng.
tar -xf libpng-1.6.37.tar.xz
cd libpng-1.6.37
patch -Np1 -i ../patches/libpng-1.6.37-apng.patch
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libpng -Dm644 LICENSE
cd ..
rm -rf libpng-1.6.37
# FreeType (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf freetype-2.11.1.tar.xz
cd freetype-2.11.1
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static
make
make install
install -t /usr/share/licenses/freetype -Dm644 LICENSE.TXT
cd ..
rm -rf freetype-2.11.1
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
tar -xf harfbuzz-3.2.0.tar.xz
cd harfbuzz-3.2.0
mkdir hb-build; cd hb-build
meson --prefix=/usr --buildtype=release -Dgraphite2=enabled ..
ninja
ninja install
install -t /usr/share/licenses/harfbuzz -Dm644 ../COPYING
cd ../..
rm -rf harfbuzz-3.2.0
# FreeType (rebuild to support HarfBuzz).
tar -xf freetype-2.11.1.tar.xz
cd freetype-2.11.1
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static
make
make install
cd ..
rm -rf freetype-2.11.1
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
tar -xf woff2_1.0.2.orig.tar.gz
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
pigz -cd unifont-13.0.06.pcf.gz > /usr/share/fonts/unifont/unifont.pcf
# GRUB.
tar -xf grub-2.06.tar.xz
cd grub-2.06
mkdir build-pc; cd build-pc
unset CFLAGS CXXFLAGS
../configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --enable-grub-mkfont --enable-grub-mount --with-platform=pc --disable-werror
make
cd ..
mkdir build-efi; cd build-efi
../configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --enable-grub-mkfont --enable-grub-mount --with-platform=efi --disable-werror
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
GRUB_BACKGROUND="/usr/share/backgrounds/xfce/MassOS-Contemporary.png"
#GRUB_THEME="/path/to/theme"

# Uncomment to get a beep at GRUB start
#GRUB_INIT_TUNE="480 440 1"

# Uncomment to make GRUB remember the last selection. This requires
# setting 'GRUB_DEFAULT=saved' above.
GRUB_SAVEDEFAULT="true"

# Uncomment to disable submenus in boot menu
#GRUB_DISABLE_SUBMENU="y"

# Uncomment to enable detection of other OSes when generating grub.cfg
GRUB_DISABLE_OS_PROBER="false"
END
install -t /usr/share/licenses/grub -Dm644 ../COPYING
cd ../..
rm -rf grub-2.06
CFLAGS="-w -Os -pipe"
CXXFLAGS="-w -Os -pipe"
export CFLAGS CXXFLAGS
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
tar -xf libyaml-0.2.5.tar.gz
cd libyaml-0.2.5
./bootstrap
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libyaml -Dm644 License
cd ..
rm -rf libyaml-0.2.5
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
tar -xf libbytesize-2.6.tar.gz
cd libbytesize-2.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libbytesize -Dm644 LICENSE
cd ..
rm -rf libbytesize-2.6
# libblockdev.
tar -xf libblockdev-2.26.tar.gz
cd libblockdev-2.26
./configure --prefix=/usr --sysconfdir=/etc --with-python3 --without-nvdimm --without-dm
make
make install
install -t /usr/share/licenses/libblockdev -Dm644 LICENSE
cd ..
rm -rf libblockdev-2.26
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
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libgudev -Dm644 ../COPYING
cd ../..
rm -rf libgudev-237
# libmbim.
tar -xf libmbim-1.26.2.tar.xz
cd libmbim-1.26.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libmbim -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libmbim-1.26.2
# libqmi.
tar -xf libqmi-1.30.2.tar.xz
cd libqmi-1.30.2
PYTHON=python3 ./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libqmi -Dm644 COPYING COPYING.LIB
cd ..
rm -rf libqmi-1.30.2
# libwacom.
tar -xf libwacom-2.0.0.tar.xz
cd libwacom-2.0.0
mkdir wacom-build; cd wacom-build
meson --prefix=/usr --buildtype=release -Dtests=disabled ..
ninja
ninja install
install -t /usr/share/licenses/libwacom -Dm644 ../COPYING
cd ../..
rm -rf libwacom-2.0.0
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
tar -xf wayland-1.20.0.tar.xz
cd wayland-1.20.0
mkdir wayland-build; cd wayland-build
meson --prefix=/usr --buildtype=release -Ddocumentation=false ..
ninja
ninja install
install -t /usr/share/licenses/wayland -Dm644 ../COPYING
cd ../..
rm -rf wayland-1.20.0
# Wayland-Protocols.
tar -xf wayland-protocols-1.25.tar.xz
cd wayland-protocols-1.25
mkdir wayland-protocols-build; cd wayland-protocols-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/wayland-protocols -Dm644 ../COPYING
cd ../..
rm -rf wayland-protocols-1.25
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
tar -xf enchant-2.3.2.tar.gz
cd enchant-2.3.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/enchant -Dm644 COPYING.LIB
cd ..
rm -rf enchant-2.3.2
# Fontconfig.
tar -xf fontconfig-2.13.1.tar.bz2
cd fontconfig-2.13.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-docs
make
make install
install -t /usr/share/licenses/fontconfig -Dm644 COPYING
cd ..
rm -rf fontconfig-2.13.1
# Fribidi.
tar -xf fribidi-1.0.11.tar.xz
cd fribidi-1.0.11
mkdir BIDIRECTIONAL-build; cd BIDIRECTIONAL-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/fribidi -Dm644 ../COPYING
cd ../..
rm -rf fribidi-1.0.11
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
install -Dt /usr/bin -m755 censor lolcat
install -dm755 /usr/share/licenses/lolcat
cat > /usr/share/licenses/lolcat/LICENSE << "END"
The license covering this software is equivalent to a public domain dedication,
however the license document contains profanity, therefore it has not been
included here. If you still wish to view the license document, it is can be
viewed online at https://github.com/jaseg/lolcat/blob/main/LICENSE.
END
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
tar -xf libjpeg-turbo_2.1.2.orig.tar.gz
cd libjpeg-turbo-2.1.2
mkdir jpeg-build; cd jpeg-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DENABLE_STATIC=FALSE -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libjpeg-turbo -Dm644 ../LICENSE.md ../README.ijg
cd ../..
rm -rf libjpeg-turbo-2.1.2
# libgphoto2
tar -xf libgphoto2-2.5.27.tar.xz
cd libgphoto2-2.5.27
./configure --prefix=/usr --disable-rpath
make
make install
install -t /usr/share/licenses/libgphoto2 -Dm644 COPYING
cd ..
rm -rf libgphoto2-2.5.27
# Pixman.
tar -xf pixman-0.40.0.tar.gz
cd pixman-0.40.0
mkdir pixman-build; cd pixman-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/pixman -Dm644 ../COPYING
cd ../..
rm -rf pixman-0.40.0
# Qpdf.
tar -xf qpdf-10.5.0.tar.gz
cd qpdf-10.5.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/qpdf -Dm644 Artistic-2.0 LICENSE.txt NOTICE.md
cd ..
rm -rf qpdf-10.5.0
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
tar -xf iso-codes_4.9.0.orig.tar.xz
cd iso-codes-4.9.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/iso-codes -Dm644 COPYING
cd ..
rm -rf iso-codes-4.9.0
# xdg-user-dirs.
tar -xf xdg-user-dirs-0.17.tar.gz
cd xdg-user-dirs-0.17
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xdg-user-dirs -Dm644 COPYING
cd ..
rm -rf xdg-user-dirs-0.17
# LSB-Tools.
tar -xf LSB-Tools-0.9.tar.gz
cd LSB-Tools-0.9
python setup.py build
python setup.py install --optimize=1
install -t /usr/share/licenses/lsb-tools -Dm644 LICENSE
cd ..
rm -rf LSB-Tools-0.9
# p7zip.
tar -xf p7zip-17.04-6-geb1bbb0.tar.xz
cd p7zip-17.04-6-geb1bbb0
sed '/^gzip/d' -i install.sh
sed -i '160a if(_buffer == nullptr || _size == _pos) return E_FAIL;' CPP/7zip/Common/StreamObjects.cpp
make OPTFLAGS="-s $CFLAGS" all3
make DEST_HOME=/usr DEST_MAN=/usr/share/man DEST_SHARE_DOC=/usr/share/doc/p7zip-17.04 install
install -t /usr/share/licenses/p7zip -Dm644 DOC/License.txt
cd ..
rm -rf p7zip-17.04-6-geb1bbb0
# Ruby.
tar -xf ruby-3.1.0.tar.xz
cd ruby-3.1.0
./configure --prefix=/usr --enable-shared
make
make install
install -t /usr/share/licenses/ruby -Dm644 COPYING
cd ..
rm -rf ruby-3.1.0
# slang.
tar -xf slang-pre2.3.3-64.tar.gz
cd slang-pre2.3.3-64
./configure --prefix=/usr --sysconfdir=/etc --with-readline=gnu
make -j1
make -j1 install_doc_dir=/usr/share/doc/slang SLSH_DOC_DIR=/usr/share/doc/slang/slsh install-all
chmod 755 /usr/lib/libslang.so.2.3.3 /usr/lib/slang/v2/modules/*.so
rm -f /usr/lib/libslang.a
install -t /usr/share/licenses/slang -Dm644 COPYING
cd ..
rm -rf slang-pre2.3.3-64
# BIND Utilities.
tar -xf bind-9.16.25.tar.xz
cd bind-9.16.25
./configure --prefix=/usr --with-json-c --with-libidn2 --with-libxml2 --with-lmdb --with-openssl --without-python
make -C lib/dns
make -C lib/isc
make -C lib/bind9
make -C lib/isccfg
make -C lib/irs
make -C bin/dig
make -C bin/dig install
install -t /usr/share/licenses/bind-utils -Dm644 COPYRIGHT LICENSE
cd ..
rm -rf bind-9.16.25
# dhclient.
tar -xf dhcp-4.4.2-P1.tar.gz
cd dhcp-4.4.2-P1
sed -i '/o.*dhcp_type/d' server/mdb.c
sed -r '/u.*(local|remote)_port/d' -i client/dhclient.c relay/dhcrelay.c
CFLAGS="$CFLAGS -fno-strict-aliasing -D_PATH_DHCLIENT_SCRIPT='\"/usr/sbin/dhclient-script\"' -D_PATH_DHCPD_CONF='\"/etc/dhcp/dhcpd.conf\"' -D_PATH_DHCLIENT_CONF='\"/etc/dhcp/dhclient.conf\"'" ./configure --prefix=/usr --sysconfdir=/etc/dhcp --localstatedir=/var --with-srv-lease-file=/var/lib/dhcpd/dhcpd.leases --with-srv6-lease-file=/var/lib/dhcpd/dhcpd6.leases --with-cli-lease-file=/var/lib/dhclient/dhclient.leases --with-cli6-lease-file=/var/lib/dhclient/dhclient6.leases
make -j1
make -C client install
install -m755 client/scripts/linux /usr/sbin/dhclient-script
install -dm755 /etc/dhcp
cat > /etc/dhcp/dhclient.conf << END
# Basic dhclient.conf(5)

#prepend domain-name-servers 127.0.0.1;
request subnet-mask, broadcast-address, time-offset, routers,
        domain-name, domain-name-servers, domain-search, host-name,
        netbios-name-servers, netbios-scope, interface-mtu,
        ntp-servers;
require subnet-mask, domain-name-servers;
#timeout 60;
#retry 60;
#reboot 10;
#select-timeout 5;
#initial-interval 2;
END
install -dm755 /var/lib/dhclient
install -t /usr/share/licenses/dhclient -Dm644 LICENSE
cd ..
rm -rf dhcp-4.4.2-P1
# xdg-utils.
tar -xf xdg-utils-1.1.3.tar.gz
cd xdg-utils-1.1.3
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
install -t /usr/share/licenses/xdg-utils -Dm644 LICENSE
cd ..
rm -rf xdg-utils-1.1.3
# libnl.
tar -xf libnl-3.5.0.tar.gz
cd libnl-3.5.0
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
install -t /usr/share/licenses/libnl -Dm644 COPYING
cd ..
rm -rf libnl-3.5.0
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
CONFIG_PEERKEY=y
CONFIG_PKCS12=y
CONFIG_READLINE=y
CONFIG_SMARTCARD=y
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
# libzip.
tar -xf libzip-1.8.0.tar.xz
cd libzip-1.8.0
mkdir libzip-build; cd libzip-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/libzip -Dm644 ../LICENSE
cd ../..
rm -rf libzip-1.8.0
# gz2xz.
tar -xf gz2xz-1.0.2.tar.gz
cd gz2xz-1.0.2
make INSTALL_DIR=/usr/bin install
install -t /usr/share/licenses/gz2xz -Dm644 LICENSE
gz2xz --install-symlinks
cd ..
rm -rf gz2xz-1.0.2
# dmg2img.
tar -xf dmg2img_1.6.7.orig.tar.gz
cd dmg2img-1.6.7
patch --ignore-whitespace -Np1 -i ../patches/dmg2img-1.6.7-openssl.patch
make PREFIX=/usr CFLAGS="$CFLAGS"
install -m755 dmg2img vfdecrypt /usr/bin
install -t /usr/share/licenses/dmg2img -Dm644 COPYING
cd ..
rm -rf dmg2img-1.6.7
# util-macros.
tar -xf util-macros-1.19.3.tar.bz2
cd util-macros-1.19.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
install -t /usr/share/licenses/util-macros -Dm644 COPYING
cd ..
rm -rf util-macros-1.19.3
# xorgproto.
tar -xf xorgproto-2021.5.tar.bz2
cd xorgproto-2021.5
mkdir xorgproto-build; cd xorgproto-build
meson --prefix=/usr -Dlegacy=true ..
ninja
ninja install
install -t /usr/share/licenses/xorgproto -Dm644 ../COPYING*
cd ../..
rm -rf xorgproto-2021.5
# libXau.
tar -xf libXau-1.0.9.tar.bz2
cd libXau-1.0.9
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libxau -Dm644 COPYING
cd ..
rm -rf libXau-1.0.9
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
tar -xf xcb-proto-1.14.1.tar.xz
cd xcb-proto-1.14.1
PYTHON=python3 ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
install -t /usr/share/licenses/xcb-proto -Dm644 COPYING
cd ..
rm -rf xcb-proto-1.14.1
# libxcb.
tar -xf libxcb-1.14.tar.xz
cd libxcb-1.14
CFLAGS="$CFLAGS -Wno-error=format-extra-args" PYTHON=python3 ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --without-doxygen
make
make install
install -t /usr/share/licenses/libxcb -Dm644 COPYING
cd ..
rm -rf libxcb-1.14
# Xorg Libraries.
for i in xtrans-1.4.0 libX11-1.7.3 libXext-1.3.4 libFS-1.0.8 libICE-1.0.10 libSM-1.2.3 libXScrnSaver-1.2.3 libXt-1.2.1 libXmu-1.1.3 libXpm-3.5.13 libXaw-1.0.14 libXfixes-6.0.0 libXcomposite-0.4.5 libXrender-0.9.10 libXcursor-1.2.0 libXdamage-1.1.5 libfontenc-1.1.4 libXfont2-2.0.5 libXft-2.3.4 libXi-1.8 libXinerama-1.1.4 libXrandr-1.5.2 libXres-1.2.1 libXtst-1.2.3 libXv-1.0.11 libXvMC-1.0.12 libXxf86dga-1.1.5 libXxf86vm-1.1.4 libdmx-1.1.4 libpciaccess-0.16 libxkbfile-1.1.0 libxshmfence-1.3; do
  tar -xf $i.tar.*
  cd $i
  case $i in
    libICE* ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static ICE_LIBS=-lpthread ;;
    libXfont2-[0-9]* ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-devel-docs ;;
    libXt-[0-9]* ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-appdefaultdir=/etc/X11/app-defaults ;;
    * ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  esac
  make
  make install
  install -t /usr/share/licenses/$(echo $i | cut -d- -f1 | tr '[:upper:]' '[:lower:]') -Dm644 COPYING
  cd ..
  rm -rf $i
  ldconfig
done
# xcb-util.
for i in xcb-util-0.4.0 xcb-util-image-0.4.0 xcb-util-keysyms-0.4.0 xcb-util-renderutil-0.3.9 xcb-util-wm-0.4.1 xcb-util-cursor-0.1.3; do
  tar -xf $i.tar.bz2
  cd $i
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  make
  make install
  test ! -f COPYING || install -t /usr/share/licenses/xcb-util -Dm644 COPYING
  cd ..
  rm -rf $i
  ldconfig
done
# libdrm.
tar -xf libdrm-2.4.109.tar.xz
cd libdrm-2.4.109
mkdir no-digital-restrictions-management; cd no-digital-restrictions-management
meson --prefix=/usr --buildtype=release -Dudev=true -Dvalgrind=false ..
ninja
ninja install
install -t /usr/share/licenses/libdrm -Dm644 ../../extra-package-files/libdrm-license.txt
cd ../..
rm -rf libdrm-2.4.109
# glslang (required for Vulkan support in Mesa).
tar -xf glslang-11.7.1.tar.xz
cd glslang-11.7.1
mkdir static-release; cd static-release
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
mkdir ../shared-release; cd ../shared-release
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/glslang -Dm644 ../LICENSE.txt
cd ../..
rm -rf glslang-11.7.1
# Vulkan-Headers.
tar -xf Vulkan-Headers-1.3.204.tar.gz
cd Vulkan-Headers-1.3.204
mkdir VH-build; cd VH-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/vulkan-headers -Dm644 ../LICENSE.txt
cd ../..
rm -rf Vulkan-Headers-1.3.204
# Vulkan-Loader.
tar -xf Vulkan-Loader-1.3.204.tar.gz
cd Vulkan-Loader-1.3.204
mkdir VL-build; cd VL-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DVULKAN_HEADERS_INSTALL_DIR=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_INSTALL_DATADIR=/share -DCMAKE_SKIP_RPATH=TRUE -DBUILD_TESTS=OFF -DBUILD_WSI_XCB_SUPPORT=ON -DBUILD_WSI_XLIB_SUPPORT=ON -DBUILD_WSI_WAYLAND_SUPPORT=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/vulkan-loader -Dm644 ../LICENSE.txt
cd ../..
rm -rf Vulkan-Loader-1.3.204
# libva (circular dependency; will be rebuilt later to support Mesa).
tar -xf libva-2.13.0.tar.bz2
cd libva-2.13.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/libva -Dm644 COPYING
cd ..
rm -rf libva-2.13.0
# libvdpau.
tar -xf libvdpau-1.4.tar.bz2
cd libvdpau-1.4
mkdir vdpau-build; cd vdpau-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libvdpau -Dm644 ../COPYING
cd ../..
rm -rf libvdpau-1.4
# Mesa.
tar -xf mesa-21.3.5.tar.xz
cd mesa-21.3.5
patch -Np1 -i ../patches/mesa-21.3.3-xdemos.patch
sed '1s/python/&3/' -i bin/symbols-check.py
mkdir mesa-build; cd mesa-build
meson --prefix=/usr --buildtype=release -Dgallium-drivers="i915,iris,nouveau,r600,radeonsi,svga,swrast,virgl" -Ddri-drivers="i965,nouveau" -Dvulkan-drivers="amd,intel,swrast" -Dvulkan-layers="device-select,intel-nullhw,overlay" -Dgallium-nine=false -Dglx=dri -Dvalgrind=disabled -Dlibunwind=disabled ..
ninja
ninja install
install -t /usr/share/licenses/mesa -Dm644 ../docs/license.rst
cd ../..
rm -rf mesa-21.3.5
# libva (rebuild to support Mesa).
tar -xf libva-2.13.0.tar.bz2
cd libva-2.13.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf libva-2.13.0
# xbitmaps.
tar -xf xbitmaps-1.1.2.tar.bz2
cd xbitmaps-1.1.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
install -t /usr/share/licenses/xbitmaps -Dm644 COPYING
cd ..
rm -rf xbitmaps-1.1.2
# Xorg Applications.
for i in iceauth-1.0.8 luit-1.1.1 mkfontscale-1.2.1 sessreg-1.1.2 setxkbmap-1.3.2 smproxy-1.0.6 x11perf-1.6.1 xauth-1.1.1 xbacklight-1.2.3 xcmsdb-1.0.5 xcursorgen-1.0.7 xdpyinfo-1.3.2 xdriinfo-1.0.6 xev-1.2.4 xgamma-1.0.6 xhost-1.0.8 xinput-1.6.3 xkbcomp-1.4.5 xkbevd-1.1.4 xkbutils-1.0.4 xkill-1.0.5 xlsatoms-1.1.3 xlsclients-1.1.4 xmessage-1.0.5 xmodmap-1.0.10 xpr-1.0.5 xprop-1.2.5 xrandr-1.5.1 xrdb-1.2.1 xrefresh-1.0.6 xset-1.2.4 xsetroot-1.1.2 xvinfo-1.1.4 xwd-1.0.8 xwininfo-1.1.5 xwud-1.0.5; do
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
# xcursor-themes.
tar -xf xcursor-themes-1.0.6.tar.bz2
cd xcursor-themes-1.0.6
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xcursor-themes -Dm644 COPYING
cd ..
rm -rf xcursor-themes-1.0.6
# Font Util.
tar -xf font-util-1.3.2.tar.bz2
cd font-util-1.3.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
install -t /usr/share/licenses/font-util -Dm644 COPYING
cd ..
rm -rf font-util-1.3.2
# Noto Fonts.
tar --no-same-owner -xf noto-fonts3.tar.xz -C / --strip-components=1
rm -f /LICENSE
sed -i 's|<string>sans-serif</string>|<string>Noto Sans</string>|' /etc/fonts/fonts.conf
sed -i 's|<string>monospace</string>|<string>Noto Sans Mono</string>|' /etc/fonts/fonts.conf
fc-cache
# XKeyboard-Config.
tar -xf xkeyboard-config-2.34.tar.bz2
cd xkeyboard-config-2.34
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-xkb-rules-symlink=xorg
make
make install
install -t /usr/share/licenses/xkeyboard-config -Dm644 COPYING
cd ..
rm -rf xkeyboard-config-2.34
# libxkbcommon.
tar -xf libxkbcommon-1.3.1.tar.xz
cd libxkbcommon-1.3.1
mkdir xkb-build; cd xkb-build
meson --prefix=/usr --buildtype=release -Denable-docs=false ..
ninja
ninja install
install -t /usr/share/licenses/libxkbcommon -Dm644 ../LICENSE
cd ../..
rm -rf libxkbcommon-1.3.1
# Systemd (rebuild to support more features).
tar -xf systemd-stable-250.3.tar.gz
cd systemd-stable-250.3
sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
mkdir systemd-better-than-the-rest-build; cd systemd-better-than-the-rest-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var --buildtype=release -Dmode=release -Dfallback-hostname=massos -Dversion-tag=250.3-massos -Dblkid=true -Ddefault-dnssec=no -Dfirstboot=false -Dinstall-tests=false -Dldconfig=false -Dsysusers=false -Db_lto=false -Drpmmacrosdir=no -Dhomed=true -Duserdb=true -Dgnu-efi=true -Dman=true -Dpamconfdir=/etc/pam.d ..
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
rm -rf systemd-stable-250.3
# D-Bus (rebuild for X support (dbus-launch)).
tar -xf dbus-1.12.20.tar.gz
cd dbus-1.12.20
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --enable-libaudit --enable-user-session --disable-doxygen-docs --with-console-auth-dir=/run/console --with-system-pid-file=/run/dbus/pid --with-system-socket=/run/dbus/system_bus_socket
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
rm -rf dbus-1.12.20
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
tar -xf alsa-lib-1.2.6.1.tar.bz2
cd alsa-lib-1.2.6.1
./configure
make
make install
install -t /usr/share/licenses/alsa-lib -Dm644 COPYING
cd ..
rm -rf alsa-lib-1.2.6.1
# libepoxy.
tar -xf libepoxy-1.5.9.tar.xz
cd libepoxy-1.5.9
mkdir epoxy-build; cd epoxy-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libepoxy -Dm644 ../COPYING
cd ../..
rm -rf libepoxy-1.5.9
# libxcvt (dependency of Xorg-Server since 21.1.1).
tar -xf libxcvt-0.1.1.tar.xz
cd libxcvt-0.1.1
mkdir xcvt-build; cd xcvt-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libxcvt -Dm644 ../COPYING
cd ../..
rm -rf libxcvt-0.1.1
# Xorg-Server.
tar -xf xorg-server-21.1.3.tar.xz
cd xorg-server-21.1.3
patch -Np1 -i ../patches/xorg-server-21.1.2-addxvfbrun.patch
mkdir XSRV-BUILD; cd XSRV-BUILD
meson --prefix=/usr -Dglamor=true -Dsuid_wrapper=true -Dxephyr=true -Dxvfb=true -Dxkb_output_dir=/var/lib/xkb ..
ninja
ninja install
install -m755 ../xvfb-run /usr/bin/xvfb-run
install -m644 ../xvfb-run.1 /usr/share/man/man1/xvfb-run.1
mkdir -p /etc/X11/xorg.conf.d
install -t /usr/share/licenses/xorg-server -Dm644 ../COPYING
cd ../..
rm -rf xorg-server-21.1.3
# Xwayland.
tar -xf xwayland-21.1.4.tar.xz
cd xwayland-21.1.4
mkdir XWLD-BUILD; cd XWLD-BUILD
meson --prefix=/usr -Dxvfb=false -Dxkb_output_dir=/var/lib/xkb ..
ninja
ninja install
install -t /usr/share/licenses/xwayland -Dm644 ../COPYING
cd ../..
rm -rf xwayland-21.1.4
# libevdev.
tar -xf libevdev-1.12.0.tar.xz
cd libevdev-1.12.0
mkdir EVDEV-build; cd EVDEV-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var -Ddocumentation=disabled ..
ninja
ninja install
install -t /usr/share/licenses/libevdev -Dm644 ../COPYING
cd ../..
rm -rf libevdev-1.12.0
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
tar -xf libinput-1.19.3.tar.xz
cd libinput-1.19.3
mkdir libinput-build; cd libinput-build
meson --prefix=/usr --buildtype=release -Ddebug-gui=false -Dtests=false -Ddocumentation=false ..
ninja
ninja install
install -t /usr/share/licenses/libinput -Dm644 ../COPYING
cd ../..
rm -rf libinput-1.19.3
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
tar -xf xf86-input-synaptics-1.9.1.tar.bz2
cd xf86-input-synaptics-1.9.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-synaptics -Dm644 COPYING
cd ..
rm -rf xf86-input-synaptics-1.9.1
# xf86-input-wacom.
tar -xf xf86-input-wacom-0.40.0.tar.bz2
cd xf86-input-wacom-0.40.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-wacom -Dm644 GPL
cd ..
rm -rf xf86-input-wacom-0.40.0
# xf86-video-amdgpu.
tar -xf xf86-video-amdgpu-21.0.0.tar.bz2
cd xf86-video-amdgpu-21.0.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-video-amdgpu -Dm644 COPYING
cd ..
rm -rf xf86-video-amdgpu-21.0.0
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
tar -xf xf86-video-intel-20211007.tar.xz
cd xf86-video-intel-20211007
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --enable-kms-only --enable-uxa --mandir=/usr/share/man
make
make install
mv /usr/share/man/man4/intel-virtual-output.4 /usr/share/man/man1/intel-virtual-output.1
sed -i '/\.TH/s/4/1/' /usr/share/man/man1/intel-virtual-output.1
install -t /usr/share/licenses/xf86-video-intel -Dm644 COPYING
cd ..
rm -rf xf86-video-intel-20211007
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
# xf86-video-vmware.
tar -xf xf86-video-vmware-13.3.0.tar.bz2
cd xf86-video-vmware-13.3.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/xf86-input-vmware -Dm644 COPYING
cd ..
rm -rf xf86-video-vmware-13.3.0
# intel-vaapi-driver.
tar -xf intel-vaapi-driver-2.4.1.tar.bz2
cd intel-vaapi-driver-2.4.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/intel-vaapi-driver -Dm644 COPYING
cd ..
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
# Polkit.
tar -xf polkit-0.120.tar.gz
cd polkit-0.120
patch -Np1 -i ../patches/polkit-0.120-CVE-2021-4034.patch
groupadd -fg 27 polkitd
useradd -c "PolicyKit Daemon Owner" -d /etc/polkit-1 -u 27 -g polkitd -s /bin/false polkitd
sed -i "s:/sys/fs/cgroup/systemd/:/sys:g" configure
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-os-type=massos --enable-gtk-doc
make
make install
cat > /etc/pam.d/polkit-1 << END
auth     include        system-auth
account  include        system-account
password include        system-password
session  include        system-session
END
install -t /usr/share/licenses/polkit -Dm644 COPYING
cd ..
rm -rf polkit-0.120
# OpenSSH.
tar -xf openssh-8.8p1.tar.gz
cd openssh-8.8p1
install -dm700 /var/lib/sshd
chown root:sys /var/lib/sshd
groupadd -g 50 sshd
useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-md5-passwords --with-pam --with-privsep-path=/var/lib/sshd --with-default-path=/usr/bin --with-superuser-path=/usr/sbin:/usr/bin --with-pid-dir=/run
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
rm -rf openssh-8.8p1
# sshfs.
tar -xf sshfs-3.7.2.tar.xz
cd sshfs-3.7.2
mkdir sshfs-build; cd sshfs-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/sshfs -Dm644 ../COPYING
cd ../..
rm -rf sshfs-3.7.2
# GLU.
tar -xf glu-9.0.2.tar.xz
cd glu-9.0.2
mkdir glu-build; cd glu-build
meson --prefix=/usr --buildtype=release -Dgl_provider=gl ..
ninja
ninja install
rm -f /usr/lib/libGLU.a
cd ../..
rm -rf glu-9.0.2
# Freeglut.
tar -xf freeglut-3.2.1.tar.gz
cd freeglut-3.2.1
patch -Np1 -i ../patches/freeglut-3.2.1-gcc10_fix-1.patch
mkdir fg-build; cd fg-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DFREEGLUT_BUILD_DEMOS=OFF -DFREEGLUT_BUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/freeglut -Dm644 ../COPYING
cd ../..
rm -rf freeglut-3.2.1
# libtiff.
tar -xf tiff-4.3.0.tar.gz
cd tiff-4.3.0
mkdir ltiff-build; cd ltiff-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
sed -i /Version/s/\$/$(cat ../VERSION)/ /usr/lib/pkgconfig/libtiff-4.pc
install -t /usr/share/licenses/libtiff -Dm644 ../COPYRIGHT
cd ../..
rm -rf tiff-4.3.0
# lcms2.
tar -xf lcms2-2.12.tar.gz
cd lcms2-2.12
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/lcms2 -Dm644 COPYING
cd ..
rm -rf lcms2-2.12
# JasPer.
tar -xf jasper-2.0.33.tar.gz
cd jasper-version-2.0.33
sed -i '/GLUT_glut_LIBRARY/s/^/#/' build/cmake/modules/JasOpenGL.cmake
mkdir jasper-build; cd jasper-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_INSTALL_RPATH=YES -DJAS_ENABLE_DOC=NO -DJAS_ENABLE_LIBJPEG=ON -DJAS_ENABLE_OPENGL=ON -DJAS_ENABLE_AUTOMATIC_DEPENDENCIES=OFF -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/jasper -Dm644 ../LICENSE
cd ../..
rm -rf jasper-version-2.0.33
# ATK.
tar -xf atk-2.36.0.tar.xz
cd atk-2.36.0
mkdir atk-build; cd atk-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/atk -Dm644 ../COPYING
cd ../..
rm -rf atk-2.36.0
# Atkmm.
tar -xf atkmm-2.28.2.tar.xz
cd atkmm-2.28.2
mkdir atkmm-build; cd atkmm-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/atkmm -Dm644 ../COPYING ../COPYING.tools
cd ../..
rm -rf atkmm-2.28.2
# GDK-Pixbuf.
tar -xf gdk-pixbuf-2.42.6.tar.xz
cd gdk-pixbuf-2.42.6
mkdir pixbuf-build; cd pixbuf-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
gdk-pixbuf-query-loaders --update-cache
install -t /usr/share/licenses/gdk-pixbuf -Dm644 ../COPYING
cd ../..
rm -rf gdk-pixbuf-2.42.6
# Cairo.
tar -xf cairo-1.17.4.tar.xz
cd cairo-1.17.4
./configure --prefix=/usr --disable-static --enable-tee
make
make install
install -t /usr/share/licenses/cairo -Dm644 COPYING COPYING-LGPL-2.1
cd ..
rm -rf cairo-1.17.4
# cairomm.
tar -xf cairomm-1.14.0.tar.xz
cd cairomm-1.14.0
mkdir cmm-build; cd cmm-build
meson --prefix=/usr --buildtype=release -Dbuild-tests=true -Dboost-shared=true ..
ninja
ninja install
install -t /usr/share/licenses/cairomm -Dm644 ../COPYING
cd ../..
rm -rf cairomm-1.14.0
# HarfBuzz (rebuild to support Cairo).
tar -xf harfbuzz-3.2.0.tar.xz
cd harfbuzz-3.2.0
mkdir hb-build; cd hb-build
meson --prefix=/usr --buildtype=release -Dgraphite2=enabled ..
ninja
ninja install
cd ../..
rm -rf harfbuzz-3.2.0
# Pango.
tar -xf pango-1.50.3.tar.xz
cd pango-1.50.3
mkdir pango-build; cd pango-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/pango -Dm644 ../COPYING
cd ../..
rm -rf pango-1.50.3
# Pangomm.
tar -xf pangomm-2.46.2.tar.xz
cd pangomm-2.46.2
mkdir pmm-build; cd pmm-build
meson --prefix=/usr --buildtype=release ..
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
# XML::Simple.
tar -xf XML-Simple-2.25.tar.gz
cd XML-Simple-2.25
perl Makefile.PL
make
make install
install -t /usr/share/licenses/xml-simple -Dm644 LICENSE
cd ..
rm -rf XML-Simple-2.25
# icon-naming-utils.
tar -xf icon-naming-utils_0.8.90.orig.tar.gz
cd icon-naming-utils-0.8.90
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/icon-naming-utils -Dm644 COPYING
cd ..
rm -rf icon-naming-utils-0.8.90
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
# SDL (initial build; will be rebuilt later to support PulseAudio).
tar -xf SDL-1.2.15.tar.gz
cd SDL-1.2.15
sed -e '/_XData32/s:register long:register _Xconst long:' -i src/video/x11/SDL_x11sym.h
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/sdl -Dm644 COPYING
cd ..
rm -rf SDL-1.2.15
# libwebp.
tar -xf libwebp-1.2.1.tar.gz
cd libwebp-1.2.1
./configure --prefix=/usr --enable-libwebpmux --enable-libwebpdemux --enable-libwebpdecoder --enable-libwebpextras --enable-swap-16bit-csp --disable-static
make
make install
install -t /usr/share/licenses/libwebp -Dm644 COPYING
cd ..
rm -rf libwebp-1.2.1
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
tar -xf graphviz-2.50.0.tar.gz
cd graphviz-2.50.0
sed -i '/LIBPOSTFIX="64"/s/64//' configure.ac
./autogen.sh
./configure --prefix=/usr --disable-php --with-webp PS2PDF=true
make
make install
install -t /usr/share/licenses/graphviz -Dm644 COPYING
cd ..
rm -rf graphviz-2.50.0
# Vala.
tar -xf vala-0.54.6.tar.xz
cd vala-0.54.6
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/vala -Dm644 COPYING
cd ..
rm -rf vala-0.54.6
# libgusb.
tar -xf libgusb-0.3.10.tar.xz
cd libgusb-0.3.10
mkdir GUSB-build; cd GUSB-build
meson --prefix=/usr --buildtype=release -Ddocs=false ..
ninja
ninja install
install -t /usr/share/licenses/libgusb -Dm644 ../COPYING
cd ../..
rm -rf libgusb-0.3.10
# librsvg.
tar -xf librsvg-2.52.5.tar.xz
cd librsvg-2.52.5
./configure --prefix=/usr --enable-vala --disable-static
make
make install
gdk-pixbuf-query-loaders --update-cache
install -t /usr/share/licenses/librsvg -Dm644 COPYING.LIB
cd ..
rm -rf librsvg-2.52.5
# adwaita-icon-theme.
tar -xf adwaita-icon-theme-41.0.tar.xz
cd adwaita-icon-theme-41.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/adwaita-icon-theme -Dm644 COPYING COPYING_CCBYSA3 COPYING_LGPL
cd ..
rm -rf adwaita-icon-theme-41.0
# at-spi2-core.
tar -xf at-spi2-core-2.42.0.tar.xz
cd at-spi2-core-2.42.0
mkdir spi2-build; cd spi2-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/at-spi2-core -Dm644 ../COPYING
cd ../..
rm -rf at-spi2-core-2.42.0
# at-spi2-atk.
tar -xf at-spi2-atk-2.38.0.tar.xz
cd at-spi2-atk-2.38.0
mkdir spi2-build; cd spi2-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/at-spi2-atk -Dm644 ../COPYING
cd ../..
rm -rf at-spi2-atk-2.38.0
# GTK3.
tar -xf gtk+-3.24.31.tar.xz
cd gtk+-3.24.31
./configure --prefix=/usr --sysconfdir=/etc --enable-broadway-backend --enable-x11-backend --enable-wayland-backend
make
make install
gtk-query-immodules-3.0 --update-cache
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/gtk3 -Dm644 COPYING
cd ..
rm -rf gtk+-3.24.31
# Gtkmm3.
tar -xf gtkmm-3.24.5.tar.xz
cd gtkmm-3.24.5
mkdir gmm-build; cd gmm-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/gtkmm3 -Dm644 ../COPYING ../COPYING.tools
cd ../..
rm -rf gtkmm-3.24.5
# Arc (GTK Theme).
tar --no-same-owner -xf arc-theme-20220102.tar.xz -C /usr/share --strip-components=1
gtk-update-icon-cache /usr/share/icons/Arc
mkdir -p /etc/gtk-2.0
cat > /etc/gtk-2.0/gtkrc << END
gtk-theme-name = "Arc-Dark"
gtk-icon-theme-name = "Arc"
gtk-cursor-theme-name = "Adwaita"
gtk-font-name = "Noto Sans 10"
END
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << END
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
# libhandy.
tar -xf libhandy-1.5.0.tar.xz
cd libhandy-1.5.0
mkdir handy-build; cd handy-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libhandy -Dm644 ../COPYING
cd ../..
rm -rf libhandy-1.5.0
# libdazzle.
tar -xf libdazzle-3.42.0.tar.xz
cd libdazzle-3.42.0
mkdir DAZZLE-build; cd DAZZLE-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libdazzle -Dm644 ../COPYING
cd ../..
rm -rf libdazzle-3.42.0
# Sysprof.
tar -xf sysprof-3.42.1.tar.xz
cd sysprof-3.42.1
mkdir SYSPROF-build; cd SYSPROF-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
sed -i 's/Development/System/' /usr/share/applications/org.gnome.Sysprof3.desktop
install -t /usr/share/licenses/sysprof -Dm644 ../COPYING ../COPYING.gpl-2
cd ../..
rm -rf sysprof-3.42.1
# libgee.
tar -xf libgee-0.20.4.tar.xz
cd libgee-0.20.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libgee -Dm644 COPYING
cd ..
rm -rf libgee-0.20.4
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
tar -xf pycairo-1.20.1.tar.gz
cd pycairo-1.20.1
python setup.py build
python setup.py install --optimize=1
python setup.py install_pycairo_header
python setup.py install_pkgconfig
install -t /usr/share/licenses/pycairo -Dm644 COPYING COPYING-LGPL-2.1
cd ..
rm -rf pycairo-1.20.1
# PyGObject.
tar -xf pygobject-3.42.0.tar.xz
cd pygobject-3.42.0
mv tests/test_gdbus.py{,.nouse}
mkdir pygo-build; cd pygo-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/pygobject -Dm644 ../COPYING
cd ../..
rm -rf pygobject-3.42.0
# gexiv2.
tar -xf gexiv2-0.14.0.tar.xz
cd gexiv2-0.14.0
mkdir gexiv2-build; cd gexiv2-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/gexiv2 -Dm644 ../COPYING
cd ../..
rm -rf gexiv2-0.14.0
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
tar -xf speex-1.2.0.tar.gz
cd speex-1.2.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/speex -Dm644 COPYING
cd ..
rm -rf speex-1.2.0
# SpeexDSP.
tar -xf speexdsp-1.2.0.tar.gz
cd speexdsp-1.2.0
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/speexdsp -Dm644 COPYING
cd ..
rm -rf speexdsp-1.2.0
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
tar -xf flac-1.3.3.tar.xz
cd flac-1.3.3
patch -Np1 -i ../patches/flac-1.3.3-security_fixes-1.patch
./configure --prefix=/usr --disable-thorough-tests
make
make install
install -t /usr/share/licenses/flac -Dm644 COPYING.FDL COPYING.GPL COPYING.LGPL COPYING.Xiph
cd ..
rm -rf flac-1.3.3
# libsndfile.
tar -xf libsndfile-1.0.31.tar.bz2
cd libsndfile-1.0.31
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libsndfile -Dm644 COPYING
cd ..
rm -rf libsndfile-1.0.31
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
tar -xf jack2-1.9.20.tar.gz
cd jack2-1.9.20
./waf configure --prefix=/usr --htmldir=/usr/share/doc/jack2 --autostart=none --classic --dbus --systemd-unit
./waf build -j$(nproc)
./waf install
install -t /usr/share/licenses/jack2 -Dm644 COPYING
cd ..
rm -rf jack2-1.9.20
# SBC.
tar -xf sbc-1.5.tar.xz
cd sbc-1.5
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/sbc -Dm644 COPYING COPYING.LIB
cd ..
rm -rf sbc-1.5
# libical.
tar -xf libical-3.0.13.tar.gz
cd libical-3.0.13
mkdir build-with-CMAKE; cd build-with-CMAKE
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSHARED_ONLY=yes -DICAL_BUILD_DOCS=false -DGOBJECT_INTROSPECTION=true -DICAL_GLIB_VAPI=true -Wno-dev ..
make -j1
make -j1 install
install -t /usr/share/licenses/libical -Dm644 ../COPYING ../LICENSE ../LICENSE.LGPL21.txt
cd ../..
rm -rf libical-3.0.13
# BlueZ.
tar -xf bluez-5.63.tar.xz
cd bluez-5.63
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-manpages --enable-library
make
make install
ln -sf ../libexec/bluetooth/bluetoothd /usr/sbin
install -dm755 /etc/bluetooth
install -m644 src/main.conf /etc/bluetooth/main.conf
systemctl enable bluetooth
systemctl enable --global obex
install -t /usr/share/licenses/bluez -Dm644 COPYING COPYING.LIB
cd ..
rm -rf bluez-5.63
# Avahi.
tar -xf avahi-0.8.tar.gz
cd avahi-0.8
groupadd -fg 84 avahi
useradd -c "Avahi Daemon Owner" -d /var/run/avahi-daemon -u 84 -g avahi -s /bin/false avahi
groupadd -fg 86 netdev
patch -Np1 -i ../patches/avahi-0.8-ipv6_race_condition_fix-1.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-libevent --disable-mono --disable-monodoc --disable-python --disable-qt3 --disable-qt4 --disable-qt5 --enable-core-docs --with-distro=none
make
make install
systemctl enable avahi-daemon
install -t /usr/share/licenses/avahi -Dm644 LICENSE
cd ..
rm -rf avahi-0.8
# PulseAudio.
tar -xf pulseaudio-15.0.tar.xz
cd pulseaudio-15.0
mkdir pulse-build; cd pulse-build
meson --prefix=/usr --buildtype=release -Ddatabase=gdbm -Ddoxygen=false ..
ninja
ninja install
rm -f /etc/dbus-1/system.d/pulseaudio-system.conf
install -t /usr/share/licenses/pulseaudio -Dm644 ../LICENSE ../GPL ../LGPL
cd ../..
rm -rf pulseaudio-15.0
# SDL (rebuild to support pulseaudio).
tar -xf SDL-1.2.15.tar.gz
cd SDL-1.2.15
sed -e '/_XData32/s:register long:register _Xconst long:' -i src/video/x11/SDL_x11sym.h
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf SDL-1.2.15
# SDL2.
tar -xf SDL2-2.0.20.tar.gz
cd SDL2-2.0.20
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libSDL2*.a
install -t /usr/share/licenses/sdl2 -Dm644 LICENSE.txt
cd ..
rm -rf SDL2-2.0.20
# dmidecode.
tar -xf dmidecode-3.3.tar.xz
cd dmidecode-3.3
make prefix=/usr CFLAGS="$CFLAGS"
make prefix=/usr install
install -t /usr/share/licenses/dmidecode -Dm644 LICENSE
cd ..
rm -rf dmidecode-3.3
# laptop-detect.
tar -xf laptop-detect_0.16.tar.xz
cd laptop-detect-0.16
sed -e "s/@VERSION@/0.16/g" < laptop-detect.in > laptop-detect
install -Dm755 laptop-detect /usr/bin/laptop-detect
install -Dm644 laptop-detect.1 /usr/share/man/man1/laptop-detect.1
install -t /usr/share/licenses/laptop-detect -Dm644 debian/copyright
cd ..
rm -rf laptop-detect-0.16
# rrdtool.
tar -xf rrdtool-1.7.2.tar.gz
cd rrdtool-1.7.2
sed -e 's/$(RUBY) ${abs_srcdir}\/ruby\/extconf.rb/& --vendor/' -i bindings/Makefile.am
autoreconf -fi
./configure --prefix=/usr --localstatedir=/var --disable-rpath --enable-perl --enable-perl-site-install --with-perl-options='INSTALLDIRS=vendor' --enable-ruby --enable-ruby-site-install --enable-python --enable-tcl --disable-libwrap
make
make install
rm -f /usr/lib/librrd.a
install -t /usr/share/licenses/dmidecode -Dm644 COPYRIGHT LICENSE
cd ..
rm -rf rrdtool-1.7.2
# lm-sensors.
tar -xf lm-sensors-3.6.0.tar.gz
cd lm-sensors-3-6-0
make PREFIX=/usr MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord CFLAGS="$CFLAGS"
make PREFIX=/usr MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord install
install -t /usr/share/licenses/lm-sensors -Dm644 COPYING COPYING.LGPL
cd ..
rm -rf lm-sensors-3-6-0
# ORC.
tar -xf orc-0.4.32.tar.gz
cd orc-0.4.32
mkdir orc-build; cd orc-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
rm -f /usr/lib/liborc-test-0.4.a
install -t /usr/share/licenses/orc -Dm644 ../COPYING
cd ../..
rm -rf orc-0.4.32
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
tar -xf net-snmp-5.9.1.tar.xz
cd net-snmp-5.9.1
./configure --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --enable-ucd-snmp-compatibility --enable-ipv6 --with-python-modules --with-default-snmp-version="3" --with-sys-contact="root@localhost" --with-sys-location="Unknown" --with-logfile="/var/log/snmpd.log" --with-mib-modules="host misc/ipfwacc ucd-snmp/diskio tunnel ucd-snmp/dlmod ucd-snmp/lmsensorsMib" --with-persistent-directory="/var/net-snmp"
make NETSNMP_DONT_CHECK_VERSION=1
make -j1 INSTALLDIRS=vendor install
install -m644 systemd-units/snmpd.service /usr/lib/systemd/system/snmpd.service
install -m644 systemd-units/snmptrapd.service /usr/lib/systemd/system/snmptrapd.service
for i in libnetsnmp libnetsnmpmibs libsnmp libnetsnmphelpers libnetsnmptrapd libnetsnmpagent; do
  rm -f /usr/lib/$i.a
done
install -t /usr/share/licenses/net-snmp -Dm644 COPYING
cd ..
rm -rf net-snmp-5.9.1
# ppp.
tar -xf ppp-2.4.9.tar.gz
cd ppp-2.4.9
sed -i "s:^#FILTER=y:FILTER=y:" pppd/Makefile.linux
sed -i "s:^#HAVE_INET6=y:HAVE_INET6=y:" pppd/Makefile.linux
sed -i "s:^#CBCP=y:CBCP=y:" pppd/Makefile.linux
CFLAGS="$CFLAGS -D_GNU_SOURCE" ./configure --prefix=/usr
make
make install
install -dm755 /etc/ppp
tar --no-same-owner -xf ../ppp-2.4.9-extra-files.tar.xz -C /etc/ppp --strip-components=1
install -m755 scripts/{pon,poff,plog} /usr/bin
install -m644 scripts/pon.1 /usr/share/man/man1/pon.1
install -m600 etc.ppp/pap-secrets /etc/ppp/pap-secrets
install -m600 etc.ppp/chap-secrets /etc/ppp/chap-secrets
install -dm755 /etc/ppp/peers
chmod 0755 /usr/lib/pppd/2.4.9/*.so
install -t /usr/share/licenses/ppp -Dm644 ../extra-package-files/ppp-license.txt
cd ..
rm -rf ppp-2.4.9
# Vim.
tar -xf vim-8.2.4250.tar.gz
cd vim-8.2.4250
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
echo '#define SYS_GVIMRC_FILE "/etc/gvimrc"' >> src/feature.h
./configure --prefix=/usr --with-features=huge --enable-gpm --enable-gui=gtk3 --with-tlib=ncursesw --enable-perlinterp --enable-python3interp --enable-rubyinterp --enable-tclinterp --with-tclsh=tclsh --with-compiledby="MassOS"
make
make install
cat > /etc/vimrc << END
source \$VIMRUNTIME/defaults.vim
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
rm -rf vim-8.2.4250
# libwpe.
tar -xf libwpe-1.12.0.tar.xz
cd libwpe-1.12.0
mkdir wpe-build; cd wpe-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libwpe -Dm644 ../COPYING
cd ../..
rm -rf libwpe-1.12.0
# OpenJPEG.
tar -xf openjpeg-2.4.0.tar.gz
cd openjpeg-2.4.0
mkdir ojpg-build; cd ojpg-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
cd ../doc
for man in man/man?/*; do install -v -D -m 644 $man /usr/share/$man; done
install -t /usr/share/licenses/openjpeg -Dm644 ../LICENSE
cd ../..
rm -rf openjpeg-2.4.0
# libsecret.
tar -xf libsecret-0.20.4.tar.xz
cd libsecret-0.20.4
mkdir secret-build; cd secret-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libsecret -Dm644 ../COPYING ../COPYING.TESTS
cd ../..
rm -rf libsecret-0.20.4
# Gcr.
tar -xf gcr-3.41.0.tar.xz
cd gcr-3.41.0
sed -i 's:"/desktop:"/org:' schema/*.xml
sed -e '208 s/@BASENAME@/gcr-viewer.desktop/' -e '231 s/@BASENAME@/gcr-prompter.desktop/' -i ui/meson.build
patch -Np1 -i ../patches/gcr-3.41.0-meson-0.61.0-fix.patch
mkdir gcr-build; cd gcr-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/gcr -Dm644 ../COPYING
cd ../..
rm -rf gcr-3.41.0
# pinentry.
tar -xf pinentry-1.2.0.tar.bz2
cd pinentry-1.2.0
./configure --prefix=/usr --enable-pinentry-tty
make
make install
install -t /usr/share/licenses/pinentry -Dm644 COPYING
cd ..
rm -rf pinentry-1.2.0
# AccountsService.
tar -xf accountsservice-0.6.55.tar.xz
cd accountsservice-0.6.55
patch -Np1 -i ../patches/accountsservice-0.6.55-mesonfix.patch
mkdir as-build; cd as-build
meson --prefix=/usr --buildtype=release -Dadmin_group=adm -Dsystemd=true ..
ninja
ninja install
install -t /usr/share/licenses/accountsservice -Dm644 ../COPYING
cd ../..
rm -rf accountsservice-0.6.55
# polkit-gnome.
tar -xf polkit-gnome-0.105.tar.xz
cd polkit-gnome-0.105
patch -Np1 -i ../patches/polkit-gnome-0.105-consolidated_fixes-1.patch
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
# Colord.
tar -xf colord-1.4.5.tar.xz
cd colord-1.4.5
groupadd -g 71 colord
useradd -c "Color Daemon Owner" -d /var/lib/colord -u 71 -g colord -s /bin/false colord
mv po/fur.po po/ur.po
sed -i 's/fur/ur/' po/LINGUAS
mkdir colord-build; cd colord-build
meson --prefix=/usr --buildtype=release -Ddaemon_user=colord -Dvapi=true -Dsystemd=true -Dlibcolordcompat=true -Dargyllcms_sensor=false -Dbash_completion=false -Ddocs=false -Dman=false ..
ninja
ninja install
install -t /usr/share/licenses/ppp -Dm644 ../COPYING
cd ../..
rm -rf colord-1.4.5
# CUPS.
tar -xf cups-2.4.1-source.tar.gz
cd cups-2.4.1
useradd -c "Print Service User" -d /var/spool/cups -g lp -s /bin/false -u 9 lp
groupadd -g 19 lpadmin
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
rm -f /usr/share/applications/cups.desktop
install -t /usr/share/licenses/cups -Dm644 LICENSE
cd ..
rm -rf cups-2.4.1
# Poppler.
tar -xf poppler-22.01.0.tar.xz
cd poppler-22.01.0
mkdir poppler-build; cd poppler-build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DTESTDATADIR=$PWD/testfiles -DENABLE_UNSTABLE_API_ABI_HEADERS=ON -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/poppler -Dm644 ../COPYING ../COPYING3
tar -xf ../../poppler-data-0.4.11.tar.gz
cd poppler-data-0.4.11
make prefix=/usr install
cd ../../..
rm -rf poppler-22.01.0
# Ghostscript.
tar -xf ghostscript-9.55.0.tar.xz
cd ghostscript-9.55.0
sed -i 's/gscms_transformm_color_const/gscms_transform_color_const/' base/gsicc_lcms2.c
rm -rf freetype lcms2mt jpeg libpng openjpeg zlib
./configure --prefix=/usr --disable-compile-inits --enable-dynamic --with-system-libtiff
make
useradd -s /bin/bash tempuser
chown -R tempuser:tempuser .
su tempuser -c "make so"
chown -R root:root .
userdel -rf tempuser
make install
make soinstall
install -m644 base/*.h /usr/include/ghostscript
ln -sfn ghostscript /usr/include/ps
cp -r examples/ /usr/share/ghostscript/9.55.0/
tar --no-same-owner -xf ../ghostscript-fonts-std-8.11.tar.gz -C /usr/share/ghostscript
tar --no-same-owner -xf ../gnu-gs-fonts-other-6.0.tar.gz -C /usr/share/ghostscript
fc-cache /usr/share/ghostscript/fonts
install -t /usr/share/licenses/ghostscript -Dm644 LICENSE
cd ..
rm -rf ghostscript-9.55.0
# MuPDF.
tar -xf mupdf-1.18.0-source.tar.gz
cd mupdf-1.18.0-source
sed -i '/MU.*_EXE. :/{
        s/\(.(MUPDF_LIB)\)\(.*\)$/\2 | \1/
        N
        s/$/ -lmupdf -L$(OUT)/
        }' Makefile
cat > user.make << END
USE_SYSTEM_FREETYPE := yes
USE_SYSTEM_HARFBUZZ := yes
USE_SYSTEM_JBIG2DEC := no
USE_SYSTEM_JPEGXR := no
USE_SYSTEM_LCMS2 := no
USE_SYSTEM_LIBJPEG := yes
USE_SYSTEM_MUJS := no
USE_SYSTEM_OPENJPEG := yes
USE_SYSTEM_ZLIB := yes
USE_SYSTEM_GLUT := no
USE_SYSTEM_CURL := yes
USE_SYSTEM_GUMBO := no
END
patch -Np1 -i ../patches/mupdf-1.18.0-security_fix-1.patch
XCFLAGS="-fPIC" make build=release shared=yes
make prefix=/usr shared=yes install
chmod 755 /usr/lib/libmupdf.so
ln -sf mupdf-x11 /usr/bin/mupdf
install -t /usr/share/licenses/mupdf -Dm644 COPYING
cd ..
rm -rf mupdf-1.18.0-source
# cups-filters.
tar -xf cups-filters-1.28.11.tar.xz
cd cups-filters-1.28.11
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --without-rcdir --disable-static --with-test-font-path=/usr/share/fonts/noto/NotoSans-Regular.ttf
make
make install
install -m644 utils/cups-browsed.service /usr/lib/systemd/system/cups-browsed.service
install -t /usr/share/licenses/cups-filters -Dm644 COPYING
systemctl enable cups-browsed
cd ..
rm -rf cups-filters-1.28.11
# Gutenprint.
tar -xf gutenprint-5.3.3.tar.xz
cd gutenprint-5.3.3
sed -i 's|$(PACKAGE)/doc|doc/$(PACKAGE)-$(VERSION)|' {,doc/,doc/developer/}Makefile.in
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/gutenprint -Dm644 COPYING
cd ..
rm -rf gutenprint-5.3.3
# SANE.
tar -xf backends-1.1.1.tar.gz
cd backends-1.1.1
[ -d /run/lock ] || mkdir -p /run/lock
groupadd -g 70 scanner
echo "1.1.1" > .tarball-version
echo "1.1.1" > .version
autoreconf -fi
mkdir inSANE-build; cd inSANE-build
sg scanner -c "../configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-group=scanner"
make
make install
install -m644 tools/udev/libsane.rules /usr/lib/udev/rules.d/65-scanner.rules
[ ! -e /var/lock/sane ] || chgrp scanner /var/lock/sane
install -t /usr/share/licenses/sane -Dm644 ../COPYING ../LICENSE ../README.djpeg
cd ../..
rm -rf backends-1.1.1
# HPLIP.
tar -xf hplip-3.21.12.tar.gz
cd hplip-3.21.12
patch -Np1 -i ../patches/hplip-3.21.12-fix_too_many_bugs.patch
AUTOMAKE="automake --foreign" autoreconf -fi
./configure --prefix=/usr --disable-qt4 --disable-qt5 --enable-hpcups-install --enable-cups-drv-install --disable-imageProcessor-build --enable-pp-build
make
make -j1 rulesdir=/usr/lib/udev/rules.d DESTDIR=$PWD/destination-tmp install
rm -rf destination-tmp/etc/{sane.d,xdg}
rm -rf destination-tmp/usr/share/hal
rm -rf destination-tmp/etc/init.d
rm -f destination-tmp/usr/share/applications/hp-uiscan.desktop
rm -f destination-tmp/usr/share/applications/hplip.desktop
rm -f destination-tmp/usr/bin/hp-uninstall
install -dm755 destination-tmp/etc/sane.d/dll.d
echo hpaio > destination-tmp/etc/sane.d/dll.d/hpaio
cp -a destination-tmp/* /
ldconfig
install -t /usr/share/licenses/hplip -Dm644 COPYING
cd ..
rm -rf hplip-3.21.12
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
tar -xf Python-3.10.2.tar.xz
cd Python-3.10.2
./configure --prefix=/usr --enable-shared --with-system-expat --with-system-ffi --with-ensurepip=yes --enable-optimizations
make
make install
pip --no-color install requests
pip --no-color install tldr
cd ..
rm -rf Python-3.10.2
# Cython.
tar -xf Cython-0.29.25.tar.gz
cd Cython-0.29.25
python setup.py build
python setup.py install --skip-build
install -t /usr/share/licenses/cython -Dm644 COPYING.txt LICENSE.txt
cd ..
rm -rf Cython-0.29.25
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
# mobile-broadband-provider-info.
tar -xf mobile-broadband-provider-info-20210805.tar.xz
cd mobile-broadband-provider-info-20210805
./autogen.sh --prefix=/usr
make
make install
install -t /usr/share/licenses/mobile-broadband-provider-info -Dm644 COPYING
cd ..
rm -rf mobile-broadband-provider-info-20210805
# ModemManager.
tar -xf ModemManager-1.18.4.tar.xz
cd ModemManager-1.18.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-systemd-journal --with-systemd-suspend-resume --disable-static
make
make install
install -t /usr/share/licenses/modemmanager -Dm644 COPYING COPYING.LIB
cd ..
rm -rf ModemManager-1.18.4
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
# D-Bus Python.
tar -xf dbus-python-1.2.18.tar.gz
cd dbus-python-1.2.18
PYTHON=/usr/bin/python3 ./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/dbus-python -Dm644 COPYING
cd ..
rm -rf dbus-python-1.2.18
# UPower.
tar -xf upower-UPOWER_0_99_13.tar.bz2
cd upower-UPOWER_0_99_13
./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-deprecated --disable-static --enable-gtk-doc
make
make install
install -t /usr/share/licenses/upower -Dm644 COPYING
systemctl enable upower
cd ..
rm -rf upower-UPOWER_0_99_13
# NetworkManager.
tar -xf NetworkManager-1.34.0.tar.xz
cd NetworkManager-1.34.0
grep -rl '^#!.*python$' | xargs sed -i '1s/python/&3/'
mkdir nm-build; cd nm-build
meson --prefix=/usr --buildtype=release -Dnmtui=true -Dovs=false -Dqt=false -Dselinux=false -Dsession_tracking=systemd ..
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
cat > /etc/NetworkManager/conf.d/dhcp.conf << END
[main]
dhcp=dhclient
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
rm -rf NetworkManager-1.34.0
# libnma.
tar -xf libnma-1.8.32.tar.xz
cd libnma-1.8.32
mkdir nma-build; cd nma-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libnma -Dm644 ../COPYING ../COPYING.LGPL
cd ../..
rm -rf libnma-1.8.32
# libnotify.
tar -xf libnotify-0.7.9.tar.xz
cd libnotify-0.7.9
mkdir notify-build; cd notify-build
meson --prefix=/usr --buildtype=release -Dman=false ..
ninja
ninja install
install -t /usr/share/licenses/libnotify -Dm644 ../COPYING
cd ../..
rm -rf libnotify-0.7.9
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
tar -xf libwnck-40.0.tar.xz
cd libwnck-40.0
mkdir wnck-build; cd wnck-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libwnck -Dm644 ../COPYING
cd ../..
rm -rf libwnck-40.0
# network-manager-applet.
tar -xf network-manager-applet-1.24.0.tar.xz
cd network-manager-applet-1.24.0
patch -Np1 -i ../patches/network-manager-applet-1.24.0-MesonBrokeYetAnotherPackage.patch
mkdir nma-build; cd nma-build
meson --prefix=/usr --buildtype=release -Dappindicator=no -Dselinux=false ..
ninja
ninja install
install -t /usr/share/licenses/network-manager-applet -Dm644 ../COPYING
cd ../..
rm -rf network-manager-applet-1.24.0
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
tar -xf gsettings-desktop-schemas-41.0.tar.xz
cd gsettings-desktop-schemas-41.0
sed -i -r 's:"(/system):"/org/gnome\1:g' schemas/*.in
mkdir gsds-build; cd gsds-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/gsettings-desktop-schemas -Dm644 ../COPYING
cd ../..
rm -rf gsettings-desktop-schemas-41.0
# glib-networking.
tar -xf glib-networking-2.70.1.tar.xz
cd glib-networking-2.70.1
mkdir glibnet-build; cd glibnet-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/glib-networking -Dm644 ../COPYING
cd ../..
rm -rf glib-networking-2.70.1
# libsoup.
tar -xf libsoup-2.74.2.tar.xz
cd libsoup-2.74.2
mkdir soup-build; cd soup-build
meson --prefix=/usr --buildtype=release -Dvapi=enabled ..
ninja
ninja install
install -t /usr/share/licenses/libsoup -Dm644 ../COPYING
cd ../..
rm -rf libsoup-2.74.2
# libostree.
tar -xf libostree-2022.1.tar.xz
cd libostree-2022.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-builtin-grub2-mkconfig --with-dracut --with-openssl --enable-experimental-api --disable-static
make
make install
install -t /usr/share/licenses/libostree -Dm644 COPYING
cd ..
rm -rf libostree-2022.1
# libxmlb.
tar -xf libxmlb-0.3.6.tar.gz
cd libxmlb-0.3.6
mkdir xmlb-build; cd xmlb-build
meson --prefix=/usr --buildtype=release -Dstemmer=true ..
ninja
ninja install
install -t /usr/share/licenses/libxmlb -Dm644 ../LICENSE
cd ../..
rm -rf libxmlb-0.3.6
# AppStream.
tar -xf AppStream-0.15.1.tar.xz
cd AppStream-0.15.1
mkdir appstream-build; cd appstream-build
meson --prefix=/usr --buildtype=release -Dvapi=true -Dcompose=true ..
ninja
ninja install
install -t /usr/share/licenses/appstream -Dm644 ../LICENSE.GPLv2 ../LICENSE.LGPLv2.1
cd ../..
rm -rf AppStream-0.15.1
# appstream-glib.
tar -xf appstream_glib_0_7_18.tar.gz
cd appstream-glib-appstream_glib_0_7_18
mkdir appstream-glib-build; cd appstream-glib-build
meson --prefix=/usr --buildtype=release -Drpm=false ..
ninja
ninja install
install -t /usr/share/licenses/appstream-glib -Dm644 ../COPYING
cd ../..
rm -rf appstream-glib-appstream_glib_0_7_18
# Bubblewrap.
tar -xf bubblewrap-0.5.0.tar.xz
cd bubblewrap-0.5.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/bubblewrap -Dm644 COPYING
cd ..
rm -rf bubblewrap-0.5.0
# xdg-dbus-proxy.
tar -xf xdg-dbus-proxy-0.1.2.tar.xz
cd xdg-dbus-proxy-0.1.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xdg-dbus-proxy -Dm644 COPYING
cd ..
rm -rf xdg-dbus-proxy-0.1.2
# Flatpak.
tar -xf flatpak-1.12.4.tar.xz
cd flatpak-1.12.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-system-bubblewrap --with-system-dbus-proxy --with-dbus-config-dir=/usr/share/dbus-1/system.d
make
make install
cat > /etc/profile.d/flatpak.sh << END
if [ -n "\$XDG_DATA_HOME" ] && [ -d "\$XDG_DATA_HOME/flatpak/exports/bin" ]; then
  pathappend "\$XDG_DATA_HOME/flatpak/exports/bin"
elif [ -n "\$HOME" ] && [ -d "\$HOME/.local/share/flatpak/exports/bin" ]; then
  pathappend "\$HOME/.local/share/flatpak/exports/bin"
fi
if [ -d /var/lib/flatpak/exports/bin ]; then
  pathappend /var/lib/flatpak/exports/bin
fi
pathprepend /var/lib/flatpak/exports/share XDG_DATA_DIRS
pathprepend "\$HOME/.local/share/flatpak/exports/share" XDG_DATA_DIRS
END
groupadd -g 69 flatpak
useradd -c "User for flatpak system helper" -d /var/lib/flatpak -u 69 -g flatpak -s /bin/false flatpak
flatpak remote-add flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y runtime/org.gtk.Gtk3theme.Arc-Dark/x86_64/3.22
install -t /usr/share/licenses/flatpak -Dm644 COPYING
cd ..
rm -rf flatpak-1.12.4
# libportal-gtk3.
tar -xf libportal-0.5.tar.xz
cd libportal-0.5
mkdir portal-build; cd portal-build
meson --prefix=/usr --buildtype=release -Dbackends=gtk3 -Ddocs=false ..
ninja
ninja install
install -t /usr/share/licenses/libportal-gtk3 -Dm644 ../COPYING
cd ../..
rm -rf libportal-0.5
# GeoClue.
tar -xf geoclue-2.5.7.tar.bz2
cd geoclue-2.5.7
mkdir geoclue-build; cd geoclue-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/geoclue -Dm644 ../COPYING ../COPYING.LIB
cd ../..
rm -rf geoclue-2.5.7
# xdg-desktop-portal.
tar -xf xdg-desktop-portal-1.12.1.tar.xz
cd xdg-desktop-portal-1.12.1
./configure --prefix=/usr --disable-pipewire
make
make install
install -t /usr/share/licenses/xdg-desktop-portal -Dm644 COPYING
cd ..
rm -rf xdg-desktop-portal-1.12.1
# xdg-desktop-portal-gtk.
tar -xf xdg-desktop-portal-gtk-1.12.0.tar.xz
cd xdg-desktop-portal-gtk-1.12.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xdg-desktop-portal-gtk -Dm644 COPYING
cd ..
rm -rf xdg-desktop-portal-gtk-1.12.0
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
tar -xf rest-0.8.1.tar.xz
cd rest-0.8.1
./configure --prefix=/usr --with-ca-certificates=/etc/pki/tls/certs/ca-bundle.crt
make
make install
install -t /usr/share/licenses/rest -Dm644 COPYING
cd ..
rm -rf rest-0.8.1
# wpebackend-fdo.
tar -xf wpebackend-fdo-1.12.0.tar.xz
cd wpebackend-fdo-1.12.0
mkdir fdo-build; cd fdo-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/wpebackend-fdo -Dm644 ../COPYING
cd ../..
rm -rf wpebackend-fdo-1.12.0
# libass.
tar -xf libass-0.15.2.tar.xz
cd libass-0.15.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libass -Dm644 COPYING
cd ..
rm -rf libass-0.15.2
# OpenH264.
tar -xf openh264-2.1.1.tar.gz
cd openh264-2.1.1
mkdir H264-build; cd H264-build
meson --prefix=/usr --buildtype=release -Dtests=disabled ..
ninja
ninja install
rm -f /usr/lib/libopenh264.a
install -t /usr/share/licenses/openh264 -Dm644 ../LICENSE
cd ../..
rm -rf openh264-2.1.1
# CDParanoia-III.
tar -xf cdparanoia-III-10.2.src.tgz
cd cdparanoia-III-10.2
patch -Np1 -i ../patches/cdparanoia-III-10.2-gcc_fixes-1.patch
./configure --prefix=/usr --mandir=/usr/share/man
make -j1
make -j1 install
chmod 755 /usr/lib/libcdda_*.so.0.10.2
install -t /usr/share/licenses/cdparanoia -Dm644 COPYING-GPL COPYING-LGPL
cd ..
rm -rf cdparanoia-III-10.2
# mpg123.
tar -xf mpg123-1.29.3.tar.bz2
cd mpg123-1.29.3
./configure --prefix=/usr --enable-int-quality=yes --with-audio="alsa jack oss pulse sdl"
make
make install
install -t /usr/share/licenses/mpg123 -Dm644 COPYING
cd ..
rm -rf mpg123-1.29.3
# libvpx.
tar -xf libvpx_1.11.0.orig.tar.gz
cd libvpx-1.11.0
sed -i 's/cp -p/cp/' build/make/Makefile
mkdir WEBMPROJECT-VPX-build; cd WEBMPROJECT-VPX-build
../configure --prefix=/usr --enable-shared --disable-static
make
make install
install -t /usr/share/licenses/libvpx -Dm644 ../LICENSE
cd ../..
rm -rf libvpx-1.11.0
# LAME.
tar -xf lame-3.100.tar.gz
cd lame-3.100
./configure --prefix=/usr --enable-mp3rtp --enable-nasm --disable-static
make
make pkghtmldir=/usr/share/doc/lame install
install -t /usr/share/licenses/lame -Dm644 COPYING LICENSE
cd ..
rm -rf lame-3.100
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
# libdvdread.
tar -xf libdvdread-6.1.2.tar.bz2
cd libdvdread-6.1.2
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libdvdread -Dm644 COPYING
cd ..
rm -rf libdvdread-6.1.2
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
patch -Np1 -i ../patches/libcanberra-0.30-wayland-1.patch
./configure --prefix=/usr --disable-oss
make
make install
install -t /usr/share/licenses/libcanberra -Dm644 LGPL
cd ..
rm -rf libcanberra-0.30
# x264.
tar -xf x264-0.164.3081.tar.xz
cd x264-0.164.3081
./configure --prefix=/usr --enable-shared
make
make install
ln -sf libx264.so.164 /usr/lib/libx264.so
install -t /usr/share/licenses/x264 -Dm644 COPYING
cd ..
rm -rf x264-0.164.3081
# x265.
tar -xf x265-3.5-19-g747a079f7.tar.xz
cd x265-3.5-19-g747a079f7
mkdir the-real-build-directory-for-x265; cd the-real-build-directory-for-x265
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ../source
ninja
ninja install
rm -f /usr/lib/libx265.a
ln -sf libx265.so.203 /usr/lib/libx265.so
ldconfig
install -t /usr/share/licenses/x265 -Dm644 ../COPYING
cd ../..
rm -rf x265-3.5-19-g747a079f7
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
tar -xf ffmpeg-5.0.tar.xz
cd ffmpeg-5.0
./configure --prefix=/usr --disable-debug --disable-static --enable-gnutls --enable-gpl --enable-libass --enable-libcdio --enable-libdrm --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libjack --enable-libmp3lame --enable-libopenh264 --enable-libopenjpeg --enable-libopus --enable-libpulse --enable-librsvg --enable-librtmp --enable-libspeex --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxcb --enable-libxcb-shape --enable-libxcb-shm --enable-libxcb-xfixes --enable-libxml2 --enable-opengl --enable-small --enable-shared --enable-version3 --enable-vulkan
make
gcc $CFLAGS tools/qt-faststart.c -o tools/qt-faststart
make install
install -m755 tools/qt-faststart /usr/bin
install -t /usr/share/licenses/ffmpeg -Dm644 COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md
cd ..
rm -rf ffmpeg-5.0
# OpenAL.
tar -xf openal-soft-1.21.1.tar.gz
cd openal-soft-1.21.1/build
sed -i "s/AVCodec \*codec/const AVCodec \*codec/" ../examples/alffplay.cpp
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/openal -Dm644 ../COPYING ../BSD-3Clause
cd ../..
rm -rf openal-soft-1.21.1
# GStreamer.
tar -xf gstreamer-1.18.5.tar.xz
cd gstreamer-1.18.5
mkdir gstreamer-build; cd gstreamer-build
meson --prefix=/usr --buildtype=release -Dgst_debug=false -Dpackage-origin="https://github.com/MassOS-Linux/MassOS" -Dpackage-name="GStreamer 1.18.5 (MassOS)" ..
ninja
ninja install
install -t /usr/share/licenses/gstreamer -Dm644 ../COPYING
cd ../..
rm -rf gstreamer-1.18.5
# gst-plugins-base.
tar -xf gst-plugins-base-1.18.5.tar.xz
cd gst-plugins-base-1.18.5
mkdir base-build; cd base-build
meson --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/MassOS-Linux/MassOS" -Dpackage-name="GStreamer 1.18.5 (MassOS)" ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-base -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-base-1.18.5
# gst-plugins-good.
tar -xf gst-plugins-good-1.18.5.tar.xz
cd gst-plugins-good-1.18.5
mkdir good-build; cd good-build
meson --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/MassOS-Linux/MassOS" -Dpackage-name="GStreamer 1.18.5 (MassOS)" ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-good -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-good-1.18.5
# gst-plugins-bad.
tar -xf gst-plugins-bad-1.18.5.tar.xz
cd gst-plugins-bad-1.18.5
mkdir bad-build; cd bad-build
meson --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/MassOS-Linux/MassOS" -Dpackage-name="GStreamer 1.18.5 (MassOS)" ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-bad -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-bad-1.18.5
# gst-plugins-ugly.
tar -xf gst-plugins-ugly-1.18.5.tar.xz
cd gst-plugins-ugly-1.18.5
mkdir ugly-build; cd ugly-build
meson --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/MassOS-Linux/MassOS" -Dpackage-name="GStreamer 1.18.5 (MassOS)" ..
ninja
ninja install
install -t /usr/share/licenses/gst-plugins-ugly -Dm644 ../COPYING
cd ../..
rm -rf gst-plugins-ugly-1.18.5
# gst-libav.
tar -xf gst-libav-1.18.5.tar.xz
cd gst-libav-1.18.5
patch -Np1 -i ../patches/gst-libav-1.18.5-ffmpeg5.patch
mkdir gstlibav-build; cd gstlibav-build
meson --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/MassOS-Linux/MassOS" -Dpackage-name="GStreamer 1.18.5 (MassOS)" ..
ninja
ninja install
install -t /usr/share/licenses/gst-libav -Dm644 ../COPYING
cd ../..
rm -rf gst-libav-1.18.5
# WebKitGTK.
tar -xf webkitgtk-2.34.4.tar.xz
cd webkitgtk-2.34.4
mkdir webkitgtk-build; cd webkitgtk-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_RPATH=ON -DPORT=GTK -DLIB_INSTALL_DIR=/usr/lib -DUSE_SOUP2=ON -DUSE_LIBHYPHEN=OFF -DENABLE_GAMEPAD=OFF -DENABLE_MINIBROWSER=ON -DUSE_WOFF2=ON -DUSE_WPE_RENDERER=ON -Wno-dev -G Ninja ..
ninja -j$(nproc)
ninja install
install -dm755 /usr/share/licenses/webkitgtk
find ../Source -name 'COPYING*' -or -name 'LICENSE*' -print0 | sort -z | while IFS= read -d $'\0' -r _f; do echo "### $_f ###"; cat "$_f"; echo; done > /usr/share/licenses/webkitgtk/LICENSE
cd ../..
rm -rf webkitgtk-2.34.4
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
# Clutter GTK.
tar -xf clutter-gtk-1.8.4.tar.xz
cd clutter-gtk-1.8.4
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/clutter-gtk -Dm644 COPYING
cd ..
rm -rf clutter-gtk-1.8.4
# libchamplain.
tar -xf libchamplain-0.12.20.tar.xz
cd libchamplain-0.12.20
mkdir champlain-build; cd champlain-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libchamplain -Dm644 ../COPYING
cd ../..
rm -rf libchamplain-0.12.20
# gspell.
tar -xf gspell-1.9.1.tar.xz
cd gspell-1.9.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/gspell -Dm644 COPYING
cd ..
rm -rf gspell-1.9.1
# gnome-online-accounts.
tar -xf gnome-online-accounts-3.40.1.tar.xz
cd gnome-online-accounts-3.40.1
mkdir GNOME-ONLINE-xbuild; cd GNOME-ONLINE-xbuild
../configure --prefix=/usr --disable-static --enable-kerberos
make
make install
install -t /usr/share/licenses/gnome-online-accounts -Dm644 ../COPYING
cd ../..
rm -rf gnome-online-accounts-3.40.1
# libgdata.
tar -xf libgdata-0.18.1.tar.xz
cd libgdata-0.18.1
mkdir gdata-build; cd gdata-build
meson --prefix=/usr --buildtype=release -Dalways_build_tests=false ..
ninja
ninja install
install -t /usr/share/licenses/libgdata -Dm644 ../COPYING
cd ../..
rm -rf libgdata-0.18.1
# Gvfs.
tar -xf gvfs-1.48.1.tar.xz
cd gvfs-1.48.1
patch -Np1 -i ../patches/gvfs-1.48.1-mesonfix.patch
mkdir gvfs-build; cd gvfs-build
meson --prefix=/usr --buildtype=release -Dbluray=false -Dsmb=false ..
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
install -t /usr/share/licenses/gvfs -Dm644 ../COPYING
cd ../..
rm -rf gvfs-1.48.1
# libxfce4util.
tar -xf libxfce4util-4.16.0.tar.bz2
cd libxfce4util-4.16.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/libxfce4util -Dm644 COPYING
cd ..
rm -rf libxfce4util-4.16.0
# xfconf.
tar -xf xfconf-4.16.0.tar.bz2
cd xfconf-4.16.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xfconf -Dm644 COPYING
cd ..
rm -rf xfconf-4.16.0
# libxfce4ui.
tar -xf libxfce4ui-4.16.1.tar.bz2
cd libxfce4ui-4.16.1
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/libxfce4ui -Dm644 COPYING
cd ..
rm -rf libxfce4ui-4.16.1
# Exo.
tar -xf exo-4.16.3.tar.bz2
cd exo-4.16.3
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/exo -Dm644 COPYING
cd ..
rm -rf exo-4.16.3
# Garcon.
tar -xf garcon-4.16.1.tar.bz2
cd garcon-4.16.1
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/garcon -Dm644 COPYING
cd ..
rm -rf garcon-4.16.1
# Thunar.
tar -xf thunar-4.16.10.tar.bz2
cd thunar-4.16.10
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/thunar -Dm644 COPYING
cd ..
rm -rf thunar-4.16.10
# thunar-volman.
tar -xf thunar-volman-4.16.0.tar.bz2
cd thunar-volman-4.16.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/thunar-volman -Dm644 COPYING
cd ..
rm -rf thunar-volman-4.16.0
# Tumbler.
tar -xf tumbler-4.16.0.tar.bz2
cd tumbler-4.16.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/tumbler -Dm644 COPYING
cd ..
rm -rf tumbler-4.16.0
# xfce4-appfinder.
tar -xf xfce4-appfinder-4.16.1.tar.bz2
cd xfce4-appfinder-4.16.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xfce4-appfinder -Dm644 COPYING
cd ..
rm -rf xfce4-appfinder-4.16.1
# xfce4-artwork.
tar -xf xfce4-artwork_0.1.1a~git+20110420.orig.tar.gz
cd xfce4-artwork-0.1.1a
./configure --prefix=/usr
make
make backdropsdir=/usr/share/backgrounds/xfce install
install -t /usr/share/licenses/xfce4-artwork -Dm644 COPYING
cd ..
rm -rf xfce4-artwork-0.1.1a
# xfce4-panel.
tar -xf xfce4-panel-4.16.3.tar.bz2
cd xfce4-panel-4.16.3
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xfce4-panel -Dm644 COPYING
cd ..
rm -rf xfce4-panel-4.16.3
# xfce4-power-manager.
tar -xf xfce4-power-manager-4.16.0.tar.bz2
cd xfce4-power-manager-4.16.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xfce4-power-manager -Dm644 COPYING
cd ..
rm -rf xfce4-power-manager-4.16.0
# libxklavier.
tar -xf libxklavier-5.4.tar.bz2
cd libxklavier-5.4
./configure --prefix=/usr --disable-static
make
make install
install -t /usr/share/licenses/libxklavier -Dm644 COPYING.LIB
cd ..
rm -rf libxklavier-5.4
# xfce4-settings.
tar -xf xfce4-settings-4.16.2.tar.bz2
cd xfce4-settings-4.16.2
./configure --prefix=/usr --sysconfdir=/etc --enable-sound-settings
make
make install
install -t /usr/share/licenses/xfce4-settings -Dm644 COPYING
cd ..
rm -rf xfce4-settings-4.16.2
# xfdesktop.
tar -xf xfdesktop-4.16.0.tar.bz2
cd xfdesktop-4.16.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xfdesktop -Dm644 COPYING
cd ..
rm -rf xfdesktop-4.16.0
# xfwm4.
tar -xf xfwm4-4.16.1.tar.bz2
cd xfwm4-4.16.1
./configure --prefix=/usr
make
make install
sed -i 's/Default/Arc-Dark/' /usr/share/xfwm4/defaults
install -t /usr/share/licenses/xfwm4 -Dm644 COPYING
cd ..
rm -rf xfwm4-4.16.1
# xfce4-session.
tar -xf xfce4-session-4.16.0.tar.bz2
cd xfce4-session-4.16.0
./configure --prefix=/usr --sysconfdir=/etc --disable-legacy-sm
make
make install
update-desktop-database
update-mime-database /usr/share/mime
install -t /usr/share/licenses/xfce4-session -Dm644 COPYING
cd ..
rm -rf xfce4-session-4.16.0
# Parole.
tar -xf parole-4.16.0.tar.bz2
cd parole-4.16.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/parole -Dm644 COPYING
cd ..
rm -rf parole-4.16.0
# VTE.
tar -xf vte-0.66.2.tar.gz
cd vte-0.66.2
mkdir vte-build; cd vte-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
rm -f /etc/profile.d/vte.*
install -t /usr/share/licenses/vte -Dm644 ../COPYING.CC-BY-4-0 ../COPYING.GPL3 ../COPYING.LGPL3 ../COPYING.XTERM
cd ../..
rm -rf vte-0.66.2
# xfce4-terminal.
tar -xf xfce4-terminal-0.8.10.tar.bz2
cd xfce4-terminal-0.8.10
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xfce4-terminal -Dm644 COPYING
cd ..
rm -rf xfce4-terminal-0.8.10
# Shotwell.
tar -xf shotwell-0.30.14.tar.xz
cd shotwell-0.30.14
mkdir SHOTWELL-build; cd SHOTWELL-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/shotwell -Dm644 ../COPYING
cd ../..
rm -rf shotwell-0.30.14
# xfce4-notifyd.
tar -xf xfce4-notifyd-0.6.2.tar.bz2
cd xfce4-notifyd-0.6.2
./configure --prefix=/usr --sysconfdir=/etc
make
make install
install -t /usr/share/licenses/xfce4-notifyd -Dm644 COPYING
cd ..
rm -rf xfce4-notifyd-0.6.2
# keybinder.
tar -xf keybinder-3.0-0.3.2.tar.gz
cd keybinder-3.0-0.3.2
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/keybinder -Dm644 COPYING
cd ..
rm -rf keybinder-3.0-0.3.2
# xfce4-pulseaudio-plugin.
tar -xf xfce4-pulseaudio-plugin-0.4.3.tar.bz2
cd xfce4-pulseaudio-plugin-0.4.3
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/xfce4-pulseaudio-plugin -Dm644 COPYING
cd ..
rm -rf xfce4-pulseaudio-plugin-0.4.3
# pavucontrol.
tar -xf pavucontrol-5.0.tar.xz
cd pavucontrol-5.0
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/pavucontrol -Dm644 LICENSE
cd ..
rm -rf pavucontrol-5.0
# Blueman.
tar -xf blueman-2.2.2.tar.xz
cd blueman-2.2.2
sed -i '/^dbusdir =/ s/sysconfdir/datadir/' data/configs/Makefile.{am,in}
./configure --prefix=/usr --sysconfdir=/etc --with-dhcp-config='/etc/dhcp/dhclient.conf'
make
make install
mv /etc/xdg/autostart/blueman.desktop /usr/share/blueman/autostart.desktop
cat > /sbin/blueman-autostart << "END"
#!/bin/bash

not_root() {
  echo "Error: $(basename $0) must be run as root." >&2
  exit 1
}

usage() {
  echo "Usage: $(basename $0) [enable|disable]" >&2
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
chmod 755 /sbin/blueman-autostart
install -t /usr/share/licenses/blueman -Dm644 COPYING
cd ..
rm -rf blueman-2.2.2
# xfce4-screenshooter.
tar -xf xfce4-screenshooter-1.9.9.tar.bz2
cd xfce4-screenshooter-1.9.9
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-screenshooter -Dm644 COPYING
cd ..
rm -rf xfce4-screenshooter-1.9.9
# xfce4-taskmanager.
tar -xf xfce4-taskmanager-1.5.2.tar.bz2
cd xfce4-taskmanager-1.5.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-taskmanager -Dm644 COPYING
cd ..
rm -rf xfce4-taskmanager-1.5.2
# xfce4-clipman-plugin.
tar -xf xfce4-clipman-plugin-1.6.2.tar.bz2
cd xfce4-clipman-plugin-1.6.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-clipman-plugin -Dm644 COPYING
cd ..
rm -rf xfce4-clipman-plugin-1.6.2
# xfce4-whiskermenu-plugin.
tar -xf xfce4-whiskermenu-plugin-2.6.1.tar.bz2
cd xfce4-whiskermenu-plugin-2.6.1
mkdir whisker-build; cd whisker-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -Wno-dev -G Ninja ..
ninja
ninja install
install -t /usr/share/licenses/xfce4-whiskermenu-plugin -Dm644 ../COPYING
cd ../..
rm -rf xfce4-whiskermenu-plugin-2.6.1
# xfce4-screensaver.
tar -xf xfce4-screensaver-4.16.0.tar.bz2
cd xfce4-screensaver-4.16.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-debug
make
make install
install -t /usr/share/licenses/xfce4-screensaver -Dm644 COPYING
cd ..
rm -rf xfce4-screensaver-4.16.0
# xarchiver.
tar -xf xarchiver-0.5.4.17.tar.gz
cd xarchiver-0.5.4.17
./configure  --prefix=/usr --libexecdir=/usr/lib/xfce4
make
make install
install -t /usr/share/licenses/xarchiver -Dm644 COPYING
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
update-desktop-database -q
cd ..
rm -rf xarchiver-0.5.4.17
# thunar-archive-plugin.
tar -xf thunar-archive-plugin-0.4.0.tar.bz2
cd thunar-archive-plugin-0.4.0
./configure --prefix=/usr --sysconfdir=/etc  --libexecdir=/usr/lib/xfce4 --localstatedir=/var --disable-static
make
make install
install -t /usr/share/licenses/thunar-archive-plugin -Dm644 COPYING
cd ..
rm -rf thunar-archive-plugin-0.4.0
# gtksourceview4.
tar -xf gtksourceview-4.8.2.tar.xz
cd gtksourceview-4.8.2
mkdir build; cd build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/gtksourceview4 -Dm644 ../COPYING
cd ../..
rm -rf gtksourceview-4.8.2
# Mousepad.
tar -xf mousepad-0.5.8.tar.bz2
cd mousepad-0.5.8
./configure --prefix=/usr --enable-keyfile-settings
make
make install
install -t /usr/share/licenses/mousepad -Dm644 COPYING
cd ..
rm -rf mousepad-0.5.8
# galculator.
tar -xf galculator_2.1.4.orig.tar.gz
cd galculator-2.1.4
sed -i 's/s_preferences/extern s_preferences/' src/main.c
autoreconf -fi
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/galculator -Dm644 COPYING
cd ..
rm -rf galculator-2.1.4
# Gparted.
tar -xf gparted-1.3.1.tar.gz
cd gparted-1.3.1
./configure --prefix=/usr --disable-doc --disable-static
make
make install
install -t /usr/share/licenses/gparted -Dm644 COPYING
cd ..
rm -rf gparted-1.3.1
# mtools.
tar -xf mtools-4.0.37.tar.gz
cd mtools-4.0.37
sed -e '/^SAMPLE FILE$/s:^:# :' -i mtools.conf
./configure --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -m644 mtools.conf /etc/mtools.conf
install -t /usr/share/licenses/mtools -Dm644 COPYING
cd ..
rm -rf mtools-4.0.37
# Baobab.
tar -xf baobab-41.0.tar.xz
cd baobab-41.0
mkdir baobab-build; cd baobab-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/baobab -Dm644 ../COPYING ../COPYING.docs
cd ../..
rm -rf baobab-41.0
# libglib-testing.
tar -xf libglib-testing-0.1.0.tar.xz
cd libglib-testing-0.1.0
mkdir GLIBTEST-build; cd GLIBTEST-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/libglib-testing -Dm644 ../COPYING
cd ../..
rm -rf libglib-testing-0.1.0
# malcontent (dependency of GNOME Software).
tar -xf malcontent-0.10.3.tar.xz
cd malcontent-0.10.3
patch -Np1 -i ../patches/malcontent-0.10.3-mesonfix.patch
mkdir malcontent-build; cd malcontent-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
install -t /usr/share/licenses/malcontent -Dm644 ../COPYING ../COPYING-DOCS
cd ../..
rm -rf malcontent-0.10.3
# GNOME Software.
tar -xf gnome-software-41.3.tar.xz
cd gnome-software-41.3
mkdir gnome-software-build; cd gnome-software-build
meson --prefix=/usr --buildtype=release -Dfwupd=false -Dpackagekit=false -Dvalgrind=false ..
ninja
ninja install
install -t /usr/share/licenses/gnome-software -Dm644 ../COPYING
cd ../..
rm -rf gnome-software-41.3
# MassOS Welcome (modified version of Gnome Tour).
tar -xf gnome-tour-41.rc-MassOS-2.tar.xz
cd gnome-tour-41.rc-MassOS-2
mkdir MassOS-Welcome-build; cd MassOS-Welcome-build
meson --prefix=/usr --buildtype=release ..
RUSTFLAGS="-C relocation-model=dynamic-no-pic" ninja
install -m755 target/release/gnome-tour /usr/bin/massos-welcome
cat > /usr/bin/firstlogin << "END"
#!/bin/sh
/usr/bin/massos-welcome
rm -f ~/.config/autostart/firstlogin.desktop
END
chmod 755 /usr/bin/firstlogin
install -dm755 /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/firstlogin.desktop << "END"
[Desktop Entry]
Type=Application
Name=First Login Welcome Program
Exec=/usr/bin/firstlogin
END
install -t /usr/share/licenses/massos-welcome -Dm644 ../LICENSE.md
cd ../..
rm -rf gnome-tour-41.rc-MassOS-2
# lightdm.
tar -xf lightdm-1.30.0.tar.xz
cd lightdm-1.30.0
groupadd -g 65 lightdm
useradd -c "Lightdm Daemon" -d /var/lib/lightdm -u 65 -g lightdm -s /bin/false lightdm
./configure --prefix=/usr --libexecdir=/usr/lib/lightdm --localstatedir=/var --sbindir=/usr/bin --sysconfdir=/etc --disable-static --disable-tests --with-greeter-user=lightdm --with-greeter-session=lightdm-gtk-greeter
make
make install
cp tests/src/lightdm-session /usr/bin
sed -i '1 s/sh/bash --login/' /usr/bin/lightdm-session
rm -rf /etc/init
install -dm755 -o lightdm -g lightdm /var/lib/lightdm
install -dm755 -o lightdm -g lightdm /var/lib/lightdm-data
install -dm755 -o lightdm -g lightdm /var/cache/lightdm
install -dm770 -o lightdm -g lightdm /var/log/lightdm
install -t /usr/share/licenses/lightdm -Dm644 COPYING.GPL3 COPYING.LGPL2 COPYING.LGPL3
cd ..
rm -rf lightdm-1.30.0
# lightdm-gtk-greeter.
tar -xf lightdm-gtk-greeter-2.0.8.tar.gz
cd lightdm-gtk-greeter-2.0.8
./configure --prefix=/usr --libexecdir=/usr/lib/lightdm --sbindir=/usr/bin --sysconfdir=/etc --with-libxklavier --enable-kill-on-sigterm --disable-libido --disable-libindicator --disable-static --disable-maintainer-mode
make
make install
sed -i 's/#background=/background = \/usr\/share\/backgrounds\/xfce\/MassOS-Contemporary.png/' /etc/lightdm/lightdm-gtk-greeter.conf
install -t /usr/share/licenses/lightdm-gtk-greeter -Dm644 COPYING
systemctl enable lightdm
cd ..
rm -rf lightdm-gtk-greeter-2.0.8
# Plymouth.
tar -xf plymouth-0.9.5.tar.gz
cd plymouth-0.9.5
LDFLAGS="$LDFLAGS -ludev" ./autogen.sh --prefix=/usr --exec-prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --enable-systemd-integration --enable-drm --enable-pango --with-release-file=/etc/os-release --with-logo=/usr/share/plymouth/massos-logo.png --with-background-color=0x000000 --with-background-start-color-stop=0x000000 --with-background-end-color-stop=0x4D4D4D --without-rhgb-compat-link --without-system-root-install --with-runtimedir=/run
make
make install
install -m644 ../massos-logo-small.png /usr/share/plymouth/massos-logo.png
cp /usr/share/plymouth/massos-logo.png /usr/share/plymouth/themes/spinner/watermark.png
sed -i 's/WatermarkVerticalAlignment=.96/WatermarkVerticalAlignment=.5/' /usr/share/plymouth/themes/spinner/spinner.plymouth
install -t /usr/share/licenses/plymouth -Dm644 COPYING
plymouth-set-default-theme spinner
cd ..
rm -rf plymouth-0.9.5
# evince
tar -xf evince-41.3.tar.xz
cd evince-41.3
find . -name meson.build | xargs sed -i '/merge_file/{n;d}'
mkdir build && cd build
meson --prefix=/usr --buildtype=release -Dgtk_doc=false -Dnautilus=false
ninja
ninja install
cd ..
rm -rf evince-41.3
# htop.
tar -xf htop-3.1.2.tar.gz
cd htop-3.1.2
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --enable-delayacct --enable-openvz --enable-unicode --enable-vserver
make
make install
ln -sf htop /usr/bin/top
ln -sf htop.1 /usr/share/man/man1/top.1
rm -f /usr/share/applications/htop.desktop
install -t /usr/share/licenses/htop -Dm644 COPYING
cd ..
rm -rf htop-3.1.2
# bsd-games.
tar -xf bsd-games-3.1.tar.gz
cd bsd-games-3.1
./configure --prefix=/usr
make
make install
install -t /usr/share/licenses/bsd-games -Dm644 LICENSE
cd ..
rm -rf bsd-games-3.1
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
tar -xf vitetris_0.59.1.orig.tar.gz
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
# Firefox.
tar --no-same-owner -xf firefox-96.0.3.tar.bz2 -C /usr/lib
mkdir -p /usr/lib/firefox/distribution
cat > /usr/lib/firefox/distribution/policies.json << END
{
  "policies": {
    "DisableAppUpdate": true
  }
}
END
ln -sr /usr/lib/firefox/firefox /usr/bin/firefox
mkdir -p /usr/share/{applications,pixmaps}
cat > /usr/share/applications/firefox.desktop << END
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
# Thunderbird.
tar --no-same-owner -xf thunderbird-91.5.1.tar.bz2 -C /usr/lib
mkdir -p /usr/lib/thunderbird/distribution
cat > /usr/lib/thunderbird/distribution/policies.json << END
{
  "policies": {
    "DisableAppUpdate": true
  }
}
END
ln -sr /usr/lib/thunderbird/thunderbird /usr/bin/thunderbird
cat > /usr/share/applications/thunderbird.desktop << END
[Desktop Entry]
Name=Thunderbird Mail
Comment=Send and receive mail with Thunderbird
GenericName=Mail Client
Exec=thunderbird %u
Terminal=false
Type=Application
Icon=thunderbird
Categories=Network;Email;
MimeType=application/xhtml+xml;text/xml;application/xhtml+xml;application/xml;application/rss+xml;x-scheme-handler/mailto;
StartupNotify=true
END
ln -sr /usr/lib/thunderbird/chrome/icons/default/default256.png /usr/share/pixmaps/thunderbird.png
install -dm755 /usr/share/licenses/thunderbird
cat > /usr/share/licenses/thunderbird/LICENSE << "END"
To view the license for Thunderbird, please open Thunderbird, go to the menu,
choose "About Thunderbird", and click "Licensing Information".
END
# Linux Kernel.
tar -xf linux-5.16.4.tar.xz
cd linux-5.16.4
cp ../kernel-config .config
make olddefconfig
make
make INSTALL_MOD_STRIP=1 modules_install
cp arch/x86/boot/bzImage /boot/vmlinuz-5.16.4-massos
cp arch/x86/boot/bzImage /usr/lib/modules/5.16.4-massos/vmlinuz
cp System.map /boot/System.map-5.16.4-massos
cp .config /boot/config-5.16.4-massos
rm /usr/lib/modules/5.16.4-massos/{source,build}
make -s kernelrelease > version
builddir=/usr/lib/modules/5.16.4-massos/build
install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map version vmlinux
install -Dt "$builddir/kernel" -m644 kernel/Makefile
install -Dt "$builddir/arch/x86" -m644 arch/x86/Makefile
cp -t "$builddir" -a scripts
install -Dt "$builddir/tools/objtool" tools/objtool/objtool
mkdir -p "$builddir"/{fs/xfs,mm}
cp -t "$builddir" -a include
cp -t "$builddir/arch/x86" -a arch/x86/include
install -Dt "$builddir/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s
install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h
install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h
install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h
install -Dt "$builddir/drivers/iio/common/hid-sensors" -m644 drivers/iio/common/hid-sensors/*.h
find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;
rm -rf "$builddir/Documentation"
find -L "$builddir" -type l -delete
find "$builddir" -type f -name '*.o' -delete
ln -sr "$builddir" "/usr/src/linux"
install -t /usr/share/licenses/linux -Dm644 COPYING LICENSES/exceptions/* LICENSES/preferred/*
cd ..
rm -rf linux-5.16.4
# MassOS release detection utility.
gcc $CFLAGS massos-release.c -o massos-release -s
install -m755 massos-release /usr/bin/massos-release
# MassOS Backgrounds.
install -Dm644 backgrounds/* /usr/share/backgrounds/xfce
mv /usr/share/backgrounds/xfce/xfce-verticals.png /usr/share/backgrounds/xfce/xfce-verticals1.png
ln -s MassOS-Contemporary.png /usr/share/backgrounds/xfce/xfce-verticals.png
# Additional MassOS files.
install -t /usr/share/massos -Dm644 LICENSE builtins massos-logo.png massos-logo-small.png massos-logo-notext.png
# Install Neofetch.
curl --fail-with-body -s https://raw.githubusercontent.com/TheSonicMaster/neofetch/bc2a8e60dbbd3674f4fa4dd167f904116eb07055/neofetch -o /usr/bin/neofetch
chmod 755 /usr/bin/neofetch
curl --fail-with-body -s https://raw.githubusercontent.com/TheSonicMaster/neofetch/bc2a8e60dbbd3674f4fa4dd167f904116eb07055/neofetch.1 -o /usr/share/man/man1/neofetch.1
# MassOS container tool.
curl --fail-with-body -s https://raw.githubusercontent.com/ClickNinYT/mct/c0ae1ac88dc6a7d9a97f4c2710b02591e398cead/mct -o /usr/sbin/mct
chmod 755 /usr/sbin/mct
# Uninstall Rust.
/usr/lib/rustlib/uninstall.sh
# Remove leftover junk in /root.
rm -rf /root/.cargo
rm -rf /root/.cmake
# Install symlinks to busybox for any programs not otherwise provided.
busybox --install -s
# Redundant since we use systemd.
rm -f /usr/bin/sv
rm -f /linuxrc
# Conflicts with /usr/sbin/lspci.
rm -f /usr/bin/lspci
# Unused package managers, potentially dangerous on MassOS.
rm -f /usr/bin/{dpkg,dpkg-deb,rpm}
# Remove Debian stuff.
rm -rf /etc/kernel
# Move any misplaced files.
cp -r /usr/etc /
rm -rf /usr/etc
cp -r /usr/man /usr/share
rm -rf /usr/man
# Remove documentation to free up space.
rm -rf /usr/share/doc/*
rm -rf /usr/doc
rm -rf /usr/docs
rm -f /usr/share/gtk-doc/html/appstream
rm -rf /usr/share/gtk-doc/html/*
# Remove temporary compiler from stage1.
find /usr -depth -name $(uname -m)-massos-linux-gnu\* | xargs rm -rf
# Remove libtool archives.
find /usr/lib /usr/libexec -name \*.la -delete
# Remove any temporary files.
rm -rf /tmp/*
# As a finishing touch, run ldconfig.
ldconfig
# For massos-upgrade.
cat > /tmp/preupgrade << "END"
# Nothing here yet...
END
cat > /tmp/postupgrade << "END"
for user in $(ls -A /home); do
  test -e /home/$user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml || (install -Dm644 /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml /home/$user/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml && chown -R $user:$user /home/$user/.config/xfce4/xfconf/xfce-perchannel-xml)
done
END
# Clean sources directory and self destruct.
cd ..
rm -rf /sources
