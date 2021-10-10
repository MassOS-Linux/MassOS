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
sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.34/core_perl -Darchlib=/usr/lib/perl5/5.34/core_perl -Dsitelib=/usr/lib/perl5/5.34/site_perl -Dsitearch=/usr/lib/perl5/5.34/site_perl -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl
make
make install
cd ..
rm -rf perl-5.34.0
# Python.
tar -xf Python-3.9.7.tar.xz
cd Python-3.9.7
./configure --prefix=/usr --enable-shared --without-ensurepip
make
make install
cd ..
rm -rf Python-3.9.7
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
tar -xf util-linux-2.37.2.tar.xz
cd util-linux-2.37.2
mkdir -p /var/lib/hwclock
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --without-python runstatedir=/run
make
make install
cd ..
rm -rf util-linux-2.37.2
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
tar -xf iana-etc-20210924.tar.gz
cd iana-etc-20210924
cp services protocols /etc
cd ..
rm -rf iana-etc-20210924
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
tar -xf ../../tzdata2021c.tar.gz
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
rm -f /usr/lib/libz.a
cd ..
rm -rf zlib-1.2.11
# bzip2.
tar -xf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install
cp -a libbz2.so.* /usr/lib
ln -s libbz2.so.1.0.8 /usr/lib/libbz2.so
cp bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sf bzip2 $i
done
rm -f /usr/lib/libbz2.a
cd ..
rm -rf bzip2-1.0.8
# XZ.
tar -xf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf xz-5.2.5
# LZ4.
tar -xf lz4-1.9.3.tar.xz
cd lz4-1.9.3
make PREFIX=/usr -C lib
make PREFIX=/usr -C programs lz4 lz4c
make PREFIX=/usr install
rm -f /usr/lib/liblz4.a
cd ..
rm -rf lz4-1.9.3
# ZSTD.
tar -xf zstd-1.5.0.tar.gz
cd zstd-1.5.0
make
make prefix=/usr install
rm -f /usr/lib/libzstd.a
cd ..
rm -rf zstd-1.5.0
# pigz.
tar -xf pigz-2.6.tar.gz
cd pigz-2.6
sed -i 's/O3/Os/' Makefile
sed -i 's/LDFLAGS=/LDFLAGS=-s/' Makefile
make
install -m755 pigz /usr/bin/pigz
install -m755 unpigz /usr/bin/unpigz
install -m644 pigz.1 /usr/share/man/man1/pigz.1
cd ..
rm -rf pigz-2.6
# Readline.
tar -xf readline-8.1.tar.gz
cd readline-8.1
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr --disable-static --with-curses
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
cd ..
rm -rf readline-8.1
# m4.
tar -xf m4-1.4.19.tar.xz
cd m4-1.4.19
./configure --prefix=/usr
make
make install
cd ..
rm -rf m4-1.4.19
# bc.
tar -xf bc-5.0.2.tar.xz
cd bc-5.0.2
CC=gcc ./configure --prefix=/usr -G -Os
make
make install
cd ..
rm -rf bc-5.0.2
# Flex.
tar -xf flex-2.6.4.tar.gz
cd flex-2.6.4
./configure --prefix=/usr --disable-static
make
make install
ln -s flex /usr/bin/lex
cd ..
rm -rf flex-2.6.4
# Tcl.
tar -xf tcl8.6.11-src.tar.gz
cd tcl8.6.11
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr --mandir=/usr/share/man --enable-64bit
make
sed -e "s|$SRCDIR/unix|/usr/lib|" -e "s|$SRCDIR|/usr/include|" -i tclConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.2|/usr/lib/tdbc1.1.2|" -e "s|$SRCDIR/pkgs/tdbc1.1.2/generic|/usr/include|" -e "s|$SRCDIR/pkgs/tdbc1.1.2/library|/usr/lib/tcl8.6|" -e "s|$SRCDIR/pkgs/tdbc1.1.2|/usr/include|" -i pkgs/tdbc1.1.2/tdbcConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.1|/usr/lib/itcl4.2.1|" -e "s|$SRCDIR/pkgs/itcl4.2.1/generic|/usr/include|" -e "s|$SRCDIR/pkgs/itcl4.2.1|/usr/include|" -i pkgs/itcl4.2.1/itclConfig.sh
unset SRCDIR
make install
chmod u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sf tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
cd ../..
rm -rf tcl8.6.11
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
cd ..
rm -rf mpc-1.2.1
# Attr.
tar -xf attr-2.5.1.tar.gz
cd attr-2.5.1
./configure --prefix=/usr --disable-static --sysconfdir=/etc
make
make install
cd ..
rm -rf attr-2.5.1
# Acl.
tar -xf acl-2.3.1.tar.xz
cd acl-2.3.1
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf acl-2.3.1
# Libcap.
tar -xf libcap-2.59.tar.xz
cd libcap-2.59
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib
make prefix=/usr lib=lib install
chmod 755 /usr/lib/lib{cap,psx}.so.2.59
cd ..
rm -rf libcap-2.59
# CrackLib.
tar -xf cracklib-2.9.7.tar.bz2
cd cracklib-2.9.7
PYTHON=python3 CPPFLAGS=-I/usr/include/python3.9 ./configure --prefix=/usr --disable-static --with-default-dict=/usr/lib/cracklib/pw_dict
make
make install
install -Dm644 ../cracklib-words-2.9.7.bz2 /usr/share/dict/cracklib-words.bz2
bunzip2 /usr/share/dict/cracklib-words.bz2
ln -sf cracklib-words /usr/share/dict/words
echo "massos" >> /usr/share/dict/cracklib-extra-words
install -dm755 /usr/lib/cracklib
create-cracklib-dict /usr/share/dict/cracklib-words /usr/share/dict/cracklib-extra-words
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
cd ..
rm -rf libpwquality-1.4.4
# Libcap (with Linux-PAM).
tar -xf libcap-2.59.tar.xz
cd libcap-2.59
make -C pam_cap
install -m755 pam_cap/pam_cap.so /usr/lib/security
install -m644 pam_cap/capability.conf /etc/security
cat > /etc/pam.d/system-auth << END
auth      optional    pam_cap.so
auth      required    pam_unix.so
END
cd ..
rm -rf libcap-2.59
# Shadow.
tar -xf shadow-4.8.1.tar.xz
cd shadow-4.8.1
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;
sed -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' -e 's@/var/spool/mail@/var/mail@' -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' -i etc/login.defs
sed -i 's/1000/999/' etc/useradd
touch /usr/bin/passwd
./configure --sysconfdir=/etc --with-group-name-max-length=32
make
make exec_prefix=/usr install
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
cd ..
rm -rf shadow-4.8.1
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
../configure --prefix=/usr --enable-languages=c,c++ --disable-multilib --disable-bootstrap --with-system-zlib
make
make install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/11.2.0/include-fixed/bits/
ln -sr /usr/bin/cpp /usr/lib
ln -sf ../../libexec/gcc/$(gcc -dumpmachine)/11.2.0/liblto_plugin.so /usr/lib/bfd-plugins/
mkdir -p /usr/share/gdb/auto-load/usr/lib
mv /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
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
cd ..
rm -rf pkg-config-0.29.2
# Ncurses.
tar -xf ncurses-6.2.tar.gz
cd ncurses-6.2
./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug --without-normal --enable-pc-files --enable-widec
make
make install
for lib in ncurses form panel menu; do
    rm -f /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sf ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
done
rm -f /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sf libncurses.so /usr/lib/libcurses.so
rm -f /usr/lib/libncurses++w.a
cd ..
rm -rf ncurses-6.2
# libsigsegv.
tar -xf libsigsegv-2.13.tar.gz
cd libsigsegv-2.13
./configure --prefix=/usr --enable-shared --disable-static
make
make install
cd ..
rm -rf libsigsegv-2.13
# Sed.
tar -xf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr
make
make install
cd ..
rm -rf sed-4.8
# Psmisc.
tar -xf psmisc-23.4.tar.xz
cd psmisc-23.4
./configure --prefix=/usr
make
make install
cd ..
rm -rf psmisc-23.4
# Gettext.
tar -xf gettext-0.21.tar.xz
cd gettext-0.21
./configure --prefix=/usr --disable-static
make
make install
chmod 0755 /usr/lib/preloadable_libintl.so
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
# Grep.
tar -xf grep-3.7.tar.xz
cd grep-3.7
./configure --prefix=/usr
make
make install
cd ..
rm -rf grep-3.7
# Bash.
tar -xf bash-5.1.8.tar.gz
cd bash-5.1.8
./configure --prefix=/usr --without-bash-malloc --with-installed-readline
make
make install
cd ..
rm -rf bash-5.1.8
# libtool.
tar -xf libtool-2.4.6.tar.xz
cd libtool-2.4.6
./configure --prefix=/usr
make
make install
rm -f /usr/lib/libltdl.a
cd ..
rm -rf libtool-2.4.6
# GDBM.
tar -xf gdbm-1.21.tar.gz
cd gdbm-1.21
./configure --prefix=/usr --disable-static --enable-libgdbm-compat
make
make install
cd ..
rm -rf gdbm-1.21
# gperf.
tar -xf gperf-3.1.tar.gz
cd gperf-3.1
./configure --prefix=/usr
make
make install
cd ..
rm -rf gperf-3.1
# Expat.
tar -xf expat-2.4.1.tar.xz
cd expat-2.4.1
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf expat-2.4.1
# Inetutils.
tar -xf inetutils-2.2.tar.xz
cd inetutils-2.2
./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var --disable-logger --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh --disable-servers
make
make install
mv /usr/{,s}bin/ifconfig
cd ..
rm -rf inetutils-2.2
# Netcat.
tar -xf netcat-0.7.1.tar.xz
cd netcat-0.7.1
./configure --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
cd ..
rm -rf netcat-0.7.1
# Less.
tar -xf less-590.tar.gz
cd less-590
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf less-590
# Perl.
tar -xf perl-5.34.0.tar.xz
cd perl-5.34.0
patch -Np1 -i ../patches/perl-5.34.0-upstream_fixes-1.patch
export BUILD_ZLIB=False BUILD_BZIP2=0
sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr -Dprivlib=/usr/lib/perl5/5.34/core_perl -Darchlib=/usr/lib/perl5/5.34/core_perl -Dsitelib=/usr/lib/perl5/5.34/site_perl -Dsitearch=/usr/lib/perl5/5.34/site_perl -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 -Dpager="/usr/bin/less -isR" -Duseshrplib -Dusethreads
make
make install
unset BUILD_ZLIB BUILD_BZIP2
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
cd ..
rm -rf intltool-0.51.0
# Autoconf.
tar -xf autoconf-2.71.tar.xz
cd autoconf-2.71
./configure --prefix=/usr
make
make install
cd ..
rm -rf autoconf-2.71
# Automake.
tar -xf automake-1.16.4.tar.xz
cd automake-1.16.4
./configure --prefix=/usr
make
make install
cd ..
rm -rf automake-1.16.4
# elfutils.
tar -xf elfutils-0.185.tar.bz2
cd elfutils-0.185
./configure --prefix=/usr --program-prefix="eu-" --disable-debuginfod --enable-libdebuginfod=dummy
make
make install
rm -f /usr/lib/lib{asm,dw,elf}.a
cd ..
rm -rf elfutils-0.185
# libffi.
tar -xf libffi-3.4.2.tar.gz
cd libffi-3.4.2
./configure --prefix=/usr --disable-static --disable-exec-static-tramp
make
make install
cd ..
rm -rf libffi-3.4.2
# OpenSSL.
tar -xf openssl-1.1.1l.tar.gz
cd openssl-1.1.1l
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
cd ..
rm -rf openssl-1.1.1l
# kmod.
tar -xf kmod-29.tar.xz
cd kmod-29
./configure --prefix=/usr --sysconfdir=/etc --with-xz --with-zstd --with-zlib --with-openssl
make
make install
for target in depmod insmod modinfo modprobe rmmod; do ln -sf ../bin/kmod /usr/sbin/$target; done
ln -sf kmod /usr/bin/lsmod
cd ..
rm -rf kmod-29
# Python (initial build; will be rebuilt later to support SQLite and Tk).
tar -xf Python-3.9.7.tar.xz
cd Python-3.9.7
./configure --prefix=/usr --enable-shared --with-system-expat --with-system-ffi --with-ensurepip=yes --enable-optimizations
make
make install
ln -sf python3 /usr/bin/python
ln -sf pydoc3 /usr/bin/pydoc
ln -sf idle3 /usr/bin/idle
ln -sf python3-config /usr/bin/python-config
ln -sf pip3 /usr/bin/pip
pip --no-color install --upgrade pip
pip --no-color install --upgrade setuptools
pip --no-color install pyparsing
cd ..
rm -rf Python-3.9.7
# Ninja.
tar -xf ninja-1.10.2.tar.gz
cd ninja-1.10.2
python configure.py --bootstrap
install -m755 ninja /usr/bin
install -Dm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
cd ..
rm -rf ninja-1.10.2
# Meson.
tar -xf meson-0.59.2.tar.gz
cd meson-0.59.2
python setup.py build
python setup.py install --root=meson-destination-directory
cp -r meson-destination-directory/* /
install -Dm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
cd ..
rm -rf meson-0.59.2
# libseccomp.
tar -xf libseccomp-2.5.2.tar.gz
cd libseccomp-2.5.2
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libseccomp-2.5.2
# File.
tar -xf file-5.40.tar.gz
cd file-5.40
./configure --prefix=/usr --enable-libseccomp
make
make install
cd ..
rm -rf file-5.40
# Coreutils.
tar -xf coreutils-9.0.tar.xz
cd coreutils-9.0
patch -Np1 -i ../patches/coreutils-9.0-bugfix-1.patch
./configure --prefix=/usr --enable-no-install-program=kill,uptime
make
make install
mv /usr/bin/chroot /usr/sbin
mv /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
cd ..
rm -rf coreutils-9.0
# Check.
tar -xf check-0.15.2.tar.gz
cd check-0.15.2
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf check-0.15.2
# Diffutils.
tar -xf diffutils-3.8.tar.xz
cd diffutils-3.8
./configure --prefix=/usr
make
make install
cd ..
rm -rf diffutils-3.8
# Gawk.
tar -xf gawk-5.1.0.tar.xz
cd gawk-5.1.0
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
make install
cd ..
rm -rf gawk-5.1.0
# Findutils.
tar -xf findutils-4.8.0.tar.xz
cd findutils-4.8.0
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make install
cd ..
rm -rf findutils-4.8.0
# Groff.
tar -xf groff-1.22.4.tar.gz
cd groff-1.22.4
./configure --prefix=/usr
make -j1
make install
cd ..
rm -rf groff-1.22.4
# Gzip.
tar -xf gzip-1.11.tar.xz
cd gzip-1.11
./configure --prefix=/usr
make
make install
cd ..
rm -rf gzip-1.11
# Texinfo.
tar -xf texinfo-6.8.tar.xz
cd texinfo-6.8
./configure --prefix=/usr
sed -e 's/__attribute_nonnull__/__nonnull/' -i gnulib/lib/malloc/dynarray-skeleton.c
make
make install
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
cd ../..
rm -rf db-5.3.28
# LMDB.
tar -xf LMDB_0.9.29.tar.gz
cd lmdb-LMDB_0.9.29/libraries/liblmdb
make
sed -i 's| liblmdb.a||' Makefile
make prefix=/usr install
cd ../../..
rm -rf lmdb-LMDB_0.9.29
# Cyrus SASL (will be rebuilt later to support krb5 and OpenLDAP).
tar -xf cyrus-sasl-2.1.27.tar.gz
cd cyrus-sasl-2.1.27
./configure --prefix=/usr --sysconfdir=/etc --enable-auth-sasldb --with-dbpath=/var/lib/sasl/sasldb2 --with-sphinx-build=no --with-saslauthd=/var/run/saslauthd
make -j1
make -j1 install
cd ..
rm -rf cyrus-sasl-2.1.27
# iptables.
tar -xf iptables-1.8.7.tar.bz2
cd iptables-1.8.7
./configure --prefix=/usr --disable-nftables --enable-libipq
make
make install
cd ..
rm -rf iptables-1.8.7
# IPRoute2.
tar -xf iproute2-5.14.0.tar.xz
cd iproute2-5.14.0
make
make SBINDIR=/usr/sbin install
cd ..
rm -rf iproute2-5.14.0
# Kbd.
tar -xf kbd-2.4.0.tar.xz
cd kbd-2.4.0
patch -Np1 -i ../patches/kbd-2.4.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr
make
make install
cd ..
rm -rf kbd-2.4.0
# libpipeline.
tar -xf libpipeline-1.5.3.tar.gz
cd libpipeline-1.5.3
./configure --prefix=/usr
make
make install
cd ..
rm -rf libpipeline-1.5.3
# Make.
tar -xf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr
make
make install
cd ..
rm -rf make-4.3
# Ed.
tar -xf ed-1.17.tar.xz
cd ed-1.17
./configure --prefix=/usr
make
make install
cd ..
rm -rf ed-1.17
# Patch.
tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr
make
make install
cd ..
rm -rf patch-2.7.6
# Tar.
tar -xf tar-1.34.tar.xz
cd tar-1.34
./configure --prefix=/usr --program-prefix=g
make
make install
cd ..
rm -rf tar-1.34
# Nano (Vim will be installed later, after Xorg, to support a GUI).
tar -xf nano-5.9.tar.xz
cd nano-5.9
./configure --prefix=/usr --sysconfdir=/etc --enable-utf8
make
make install
cp doc/sample.nanorc /etc/nanorc
sed -i '0,/# include/{s/# include/include/}' /etc/nanorc
cd ..
rm -rf nano-5.9
# MarkupSafe.
tar -xf MarkupSafe-2.0.1.tar.gz
cd MarkupSafe-2.0.1
python setup.py build
python setup.py install --optimize=1
cd ..
rm -rf MarkupSafe-2.0.1
# Jinja2.
tar -xf Jinja2-3.0.1.tar.gz
cd Jinja2-3.0.1
python setup.py install --optimize=1
cd ..
rm -rf Jinja2-3.0.1
# Mako.
tar -xf Mako-1.1.5.tar.gz
cd Mako-1.1.5
python setup.py install --optimize=1
cd ..
rm -rf Mako-1.1.5
# Pygments.
tar -xf Pygments-2.10.0.tar.gz
cd Pygments-2.10.0
python setup.py install --optimize=1
cd ..
rm -rf Pygments-2.10.0
# acpi.
tar -xf acpi-1.7.tar.gz
cd acpi-1.7
./configure --prefix=/usr
make
make install
cd ..
rm -rf acpi-1.7
# rpcsvc-proto.
tar -xf rpcsvc-proto-1.4.2.tar.xz
cd rpcsvc-proto-1.4.2
./configure --sysconfdir=/etc
make
make install
cd ..
rm -rf rpcsvc-proto-1.4.2
# Which.
tar -xf which-2.21.tar.gz
cd which-2.21
./configure --prefix=/usr
make
make install
cd ..
rm -rf which-2.21
# ICU.
tar -xf icu4c-69_1-src.tgz
cd icu/source
./configure --prefix=/usr
make
make install
cd ../..
rm -rf icu
# Boost.
tar -xf boost_1_77_0.tar.bz2
cd boost_1_77_0
./bootstrap.sh --prefix=/usr --with-python=python3
./b2 stage -j$(nproc) threading=multi link=shared
./b2 install threading=multi link=shared
cd ..
rm -rf boost_1_77_0
# libgpg-error.
tar -xf libgpg-error-1.42.tar.bz2
cd libgpg-error-1.42
./configure --prefix=/usr
make
make install
cd ..
rm -rf libgpg-error-1.42
# libgcrypt.
tar -xf libgcrypt-1.9.4.tar.bz2
cd libgcrypt-1.9.4
./configure --prefix=/usr
make
make install
cd ..
rm -rf libgcrypt-1.9.4
# Unzip.
tar -xf unzip60.tar.gz
cd unzip60
patch -Np1 -i ../patches/unzip-6.0-consolidated_fixes-1.patch
make -f unix/Makefile generic
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
cd ..
rm -rf unzip60
# Zip.
tar -xf zip30.tar.gz
cd zip30
make -f unix/Makefile generic_gcc
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
cd ..
rm -rf zip30
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
tar -xf libxml2-2.9.12.tar.gz
cd libxml2-2.9.12
./configure --prefix=/usr --disable-static --with-history --with-python=/usr/bin/python3
make
make install
cd ..
rm -rf libxml2-2.9.12
# libarchive.
tar -xf libarchive-3.5.2.tar.xz
cd libarchive-3.5.2
./configure --prefix=/usr --disable-static
make
make install
ln -sf bsdtar /usr/bin/tar
ln -sf bsdcpio /usr/bin/cpio
ln -sf bsdtar.1 /usr/share/man/man1/tar.1
ln -sf bsdcpio.1 /usr/share/man/man1/cpio.1
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
cd ..
rm -rf docbook-xsl-nons-1.79.2
# libxslt.
tar -xf libxslt-1.1.34.tar.gz
cd libxslt-1.1.34
sed -i s/3000/5000/ libxslt/transform.c doc/xsltproc.{1,xml}
./configure --prefix=/usr --disable-static --without-python
make
make install
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
cd ..
rm -rf lynx2.8.9rel.1
# xmlto.
tar -xf xmlto-0.0.28.tar.bz2
cd xmlto-0.0.28
./configure --prefix=/usr
make
make install
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
tar -xf lxml-4.6.3.tar.gz
cd lxml-4.6.3
python setup.py build
python setup.py install --optimize=1
cd ..
rm -rf lxml-4.6.3
# itstool.
tar -xf itstool-2.0.7.tar.bz2
cd itstool-2.0.7
PYTHON=/usr/bin/python3 ./configure --prefix=/usr
make
make install
cd ..
rm -rf itstool-2.0.7
# Asciidoc.
tar -xf asciidoc-9.1.1.tar.gz
cd asciidoc-9.1.1
sed -i 's:doc/testasciidoc.1::' Makefile.in
rm doc/testasciidoc.1.txt
./configure --prefix=/usr --sysconfdir=/etc
make
make install
make docs
cd ..
rm -rf asciidoc-9.1.1
# GNU-EFI.
tar -xf gnu-efi-3.0.13.tar.bz2
cd gnu-efi-3.0.13
make
make -C lib
make -C gnuefi
make -C inc
make -C apps
make PREFIX=/usr install
install -Dm 644 apps/*.efi -t /usr/share/gnu-efi/apps/x86_64
cd ..
rm -rf gnu-efi-3.0.13
# Systemd (initial build; will be rebuilt later to support more features).
tar -xf systemd-249.tar.gz
cd systemd-249
patch -Np1 -i ../patches/systemd-249-upstream_fixes-1.patch
sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
mkdir sysd-build; cd sysd-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var --buildtype=release -Dmode=release -Dfallback-hostname=massos -Dversion-tag=249-massos -Dblkid=true -Ddefault-dnssec=no -Dfirstboot=false -Dinstall-tests=false -Dldconfig=false -Dsysusers=false -Db_lto=false -Drpmmacrosdir=no -Dhomed=false -Duserdb=false -Dgnu-efi=true -Dman=true -Dpamconfdir=/etc/pam.d ..
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
cd ../..
cp systemd-units/* /usr/lib/systemd/system
rm -rf systemd-249
# D-Bus (initial build; will be rebuilt later for X support (dbus-launch)).
tar -xf dbus-1.12.20.tar.gz
cd dbus-1.12.20
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-doxygen-docs --with-console-auth-dir=/run/console --with-system-pid-file=/run/dbus/pid --with-system-socket=/run/dbus/system_bus_socket
make
make install
ln -sf /etc/machine-id /var/lib/dbus
cd ..
rm -rf dbus-1.12.20
# Man-DB.
tar -xf man-db-2.9.4.tar.xz
cd man-db-2.9.4
./configure --prefix=/usr --sysconfdir=/etc --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap
make
make install
cd ..
rm -rf man-db-2.9.4
# Procps-NG.
tar -xf procps-ng-3.3.17.tar.xz
cd procps-3.3.17
./configure --prefix=/usr --disable-static --disable-kill --with-systemd
make
make install
cd ..
rm -rf procps-3.3.17
# util-linux.
tar -xf util-linux-2.37.2.tar.xz
cd util-linux-2.37.2
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --without-python runstatedir=/run
make
make install
cd ..
rm -rf util-linux-2.37.2
# Busybox.
tar -xf busybox-1.34.0.tar.bz2
cd busybox-1.34.0
cp ../busybox-config .config
make
install -m755 busybox /usr/bin/busybox
cd ..
rm -rf busybox-1.34.0
# e2fsprogs.
tar -xf e2fsprogs-1.46.4.tar.gz
cd e2fsprogs-1.46.4
mkdir e2-build; cd e2-build
../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck
make
make install
rm -f /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
cd ../..
rm -rf e2fsprogs-1.46.4
# dosfstools.
tar -xf dosfstools-4.2.tar.gz
cd dosfstools-4.2
./configure --prefix=/usr --enable-compat-symlinks --mandir=/usr/share/man
make
make install
cd ..
rm -rf dosfstools-4.2
# fuse2.
tar -xf fuse-2.9.9.tar.gz
cd fuse-2.9.9
sed -i '58iAC_CHECK_FUNCS([closefrom])' configure.ac
sed -i '25i#ifdef HAVE_CONFIG_H' util/ulockmgr_server.c
sed -i '26i  #include "config.h"' util/ulockmgr_server.c
sed -i '27i#endif' util/ulockmgr_server.c
sed -i '130i#if !defined(HAVE_CLOSEFROM)' util/ulockmgr_server.c
sed -i '148i#endif' util/ulockmgr_server.c
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
cd ../..
rm -rf fuse-3.10.5
# dracut.
tar -xf dracut-055.tar.gz
cd dracut-055
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --systemdsystemunitdir=/usr/lib/systemd/system --bashcompletiondir=/usr/share/bash-completion/completions
make
make install
echo 'compress="xz"' >> /etc/dracut.conf
cd ..
rm -rf dracut-055
# LZO.
tar -xf lzo-2.10.tar.gz
cd lzo-2.10
./configure --prefix=/usr --enable-shared --disable-static
make
make install
cd ..
rm -rf lzo-2.10
# squashfs-tools.
tar -xf squashfs-tools-4.5.tar.xz
cd squashfs-tools-4.5
make GZIP_SUPPORT=1 XZ_SUPPORT=1 LZO_SUPPORT=1 LZMA_XZ_SUPPORT=1 LZ4_SUPPORT=1 ZSTD_SUPPORT=1 XATTR_SUPPORT=1
make INSTALL_DIR=/usr/bin install
cd ..
rm -rf squashfs-tools-4.5
# squashfuse.
tar -xf squashfuse-0.1.104.tar.gz
cd squashfuse-0.1.104
./configure --prefix=/usr
sed -e 's/ -shared / -Wl,-O1,--as-needed\0/g' -i libtool
make
make install
install -Dm644 *.h /usr/include/squashfuse
cd ..
rm -rf squashfuse-0.1.104
# libaio.
tar -xf libaio_0.3.112.orig.tar.xz
cd libaio-0.3.112
sed -i '/install.*libaio.a/s/^/#/' src/Makefile
make
make install
cd ..
rm -rf libaio-0.3.112
# mdadm.
tar -xf mdadm-4.1.tar.xz
cd mdadm-4.1
sed 's@-Werror@@' -i Makefile
make
make BINDIR=/usr/sbin install
cd ..
rm -rf mdadm-4.1
# thin-provisioning-tools.
tar -xf thin-provisioning-tools-0.9.0.tar.gz
cd thin-provisioning-tools-0.9.0
autoconf
./configure --prefix=/usr
make
make install
cd ..
rm -rf thin-provisioning-tools-0.9.0
# LVM2.
tar -xf LVM2.2.03.13.tgz
cd LVM2.2.03.13
./configure --prefix=/usr --enable-cmdlib --enable-dmeventd --enable-pkgconfig --enable-udev_sync
make
make install
make install_systemd_units
cd ..
rm -rf LVM2.2.03.13
# btrfs-progs.
tar -xf btrfs-progs-v5.14.2.tar.xz
cd btrfs-progs-v5.14.2
./configure --prefix=/usr
make
make install
cd ..
rm -rf btrfs-progs-v5.14.2
# ntfs-3g.
tar -xf ntfs-3g_ntfsprogs-2021.8.22.tgz
cd ntfs-3g_ntfsprogs-2021.8.22
./configure --prefix=/usr --disable-static --with-fuse=external
make
make install
ln -s ../bin/ntfs-3g /usr/sbin/mount.ntfs
ln -s ntfs-3g.8 /usr/share/man/man8/mount.ntfs.8
cd ..
rm -rf ntfs-3g_ntfsprogs-2021.8.22
# exfatprogs.
tar -xf exfatprogs-1.1.2.tar.gz
cd exfatprogs-1.1.2
autoreconf -fi
./configure --prefix=/usr
make
make install
cd ..
rm -rf exfatprogs-1.1.2
# Parted.
tar -xf parted-3.4.tar.xz
cd parted-3.4
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf parted-3.4
# Popt.
tar -xf popt-1.18.tar.gz
cd popt-1.18
./configure --prefix=/usr --disable-static
make
make install
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
cd ..
rm -rf gptfdisk-1.0.8
# rsync.
tar -xf rsync-3.2.3.tar.gz
cd rsync-3.2.3
./configure --prefix=/usr --disable-lz4 --disable-xxhash --without-included-zlib
make
make install
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
cd ..
rm -rf brotli-1.0.9
# CMake.
tar --no-same-owner -xf cmake-3.21.3-linux-x86_64.tar.gz
cd cmake-3.21.3-linux-x86_64
rm -rf doc
mv man share
cp -R * /usr
rm /usr/bin/cmake-gui
rm /usr/share/applications/cmake-gui.desktop
rm /usr/share/icons/hicolor/32x32/apps/CMakeSetup.png
rm /usr/share/icons/hicolor/128x128/apps/CMakeSetup.png
cd ..
rm -rf cmake-3.21.3-linux-x86_64
# c-ares.
tar -xf c-ares-1.17.2.tar.gz
cd c-ares-1.17.2
mkdir c-ares-build; cd c-ares-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf c-ares-1.17.2
# JSON-C.
tar -xf json-c-0.15.tar.gz
cd json-c-0.15
mkdir json-c-build; cd json-c-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf json-c-0.15
# cryptsetup.
tar -xf cryptsetup-2.4.1.tar.xz
cd cryptsetup-2.4.1
./configure --prefix=/usr --disable-ssh-token
make
make install
cd ..
rm -rf cryptsetup-2.4.1
# libusb.
tar -xf libusb-1.0.24.tar.bz2
cd libusb-1.0.24
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libusb-1.0.24
# libmtp.
tar -xf libmtp-1.1.19.tar.gz
cd libmtp-1.1.19
./configure --prefix=/usr --with-udev=/usr/lib/udev
make
make install
rm -f /usr/lib/libmtp.a
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
cd ..
rm -rf libnfs-libnfs-4.0.0
# libieee1284.
tar -xf libieee1284-0.2.11.tar.xz
cd libieee1284-0.2.11
./configure --prefix=/usr --mandir=/usr/share/man --with-python
make
make install
rm -f /usr/lib/libieee1284.a
cd ..
rm -rf libieee1284-0.2.11
# PCRE.
tar -xf pcre-8.45.tar.bz2
cd pcre-8.45
./configure --prefix=/usr --enable-unicode-properties --enable-jit --enable-pcre16 --enable-pcre32 --enable-pcregrep-libz --enable-pcregrep-libbz2 --enable-pcretest-libreadline --disable-static
make
make install
cd ..
rm -rf pcre-8.45
# PCRE2.
tar -xf pcre2-10.37.tar.bz2
cd pcre2-10.37
./configure --prefix=/usr --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline --disable-static
make
make install
cd ..
rm -rf pcre2-10.37
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
tar -xf libunistring-0.9.10.tar.xz
cd libunistring-0.9.10
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libunistring-0.9.10
# libidn2.
tar -xf libidn2-2.3.2.tar.gz
cd libidn2-2.3.2
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libidn2-2.3.2
# whois.
tar -xf whois-5.4.3.tar.gz
cd whois-5.4.3
make
make prefix=/usr install-whois
make prefix=/usr install-mkpasswd
make prefix=/usr install-pos
cd ..
rm -rf whois-5.4.3
# libpsl.
tar -xf libpsl-0.21.1.tar.gz
cd libpsl-0.21.1
sed -i 's/env python/&3/' src/psl-make-dafsa
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libpsl-0.21.1
# Wget.
tar -xf wget-1.21.2.tar.gz
cd wget-1.21.2
./configure --prefix=/usr --sysconfdir=/etc --with-ssl=openssl --with-cares
make
make install
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
cd ..
rm -rf pciutils-3.7.0
# libtasn1.
tar -xf libtasn1-4.17.0.tar.gz
cd libtasn1-4.17.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libtasn1-4.17.0
# p11-kit.
tar -xf p11-kit-0.24.0.tar.xz
cd p11-kit-0.24.0
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
cd ../..
rm -rf p11-kit-0.24.0
# make-ca.
tar -xf make-ca-1.9.tar.xz
cd make-ca-1.9
make install
install -dm755 /etc/ssl/local
make-ca -g
systemctl enable update-pki.timer
wget http://www.linux-usb.org/usb.ids -O /usr/share/hwdata/usb.ids
update-pciids
cd ..
rm -rf make-ca-1.9
# libssh2.
tar -xf libssh2-1.10.0.tar.gz
cd libssh2-1.10.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libssh2-1.10.0
# Jansson.
tar -xf jansson-2.13.1.tar.gz
cd jansson-2.13.1
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf jansson-2.13.1
# nghttp2.
tar -xf nghttp2-1.45.1.tar.xz
cd nghttp2-1.45.1
./configure --prefix=/usr --disable-static --enable-lib-only
make
make install
cd ..
rm -rf nghttp2-1.45.1
# curl (will be rebuilt later to support krb5 and OpenLDAP).
tar -xf curl-7.79.1.tar.xz
cd curl-7.79.1
./configure --prefix=/usr --disable-static --with-openssl --with-libssh2 --enable-ares --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
cd ..
rm -rf curl-7.79.1
# libassuan.
tar -xf libassuan-2.5.5.tar.bz2
cd libassuan-2.5.5
./configure --prefix=/usr
make
make install
cd ..
rm -rf libassuan-2.5.5
# Nettle.
tar -xf nettle-3.7.3.tar.gz
cd nettle-3.7.3
./configure --prefix=/usr --disable-static
make
make install
chmod 755 /usr/lib/lib{hogweed,nettle}.so
cd ..
rm -rf nettle-3.7.3
# GNUTLS.
tar -xf gnutls-3.7.2.tar.xz
cd gnutls-3.7.2
./configure --prefix=/usr --disable-guile --disable-rpath --with-default-trust-store-pkcs11="pkcs11:"
make
make install
cd ..
rm -rf gnutls-3.7.2
# OpenLDAP.
tar -xf openldap-2.5.7.tgz
cd openldap-2.5.7
patch -Np1 -i ../patches/openldap-2.5.7-consolidated-1.patch
autoconf
./configure --prefix=/usr --sysconfdir=/etc --disable-static --enable-dynamic --enable-versioning --disable-debug --disable-slapd
make depend
make
make install
cd ..
rm -rf openldap-2.5.7
# npth.
tar -xf npth-1.6.tar.bz2
cd npth-1.6
./configure --prefix=/usr
make
make install
cd ..
rm -rf npth-1.6
# libksba.
tar -xf libksba-1.6.0.tar.bz2
cd libksba-1.6.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf libksba-1.6.0
# GNUPG.
tar -xf gnupg-2.2.29.tar.bz2
cd gnupg-2.2.29
sed -e '/noinst_SCRIPTS = gpg-zip/c sbin_SCRIPTS += gpg-zip' -i tools/Makefile.in
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install
cd ..
rm -rf gnupg-2.2.29
# krb5.
tar -xf krb5-1.19.2.tar.gz
cd krb5-1.19.2/src
sed -i -e 's@\^u}@^u cols 300}@' tests/dejagnu/config/default.exp
sed -i -e '/eq 0/{N;s/12 //}' plugins/kdb/db2/libdb2/test/run.test
sed -i '/t_iprop.py/d' tests/Makefile.in
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var/lib --runstatedir=/run --with-system-et --with-system-ss --with-system-verto=no --enable-dns-for-realm
make
make install
cd ../..
rm -rf krb5-1.19.2
# gsasl.
tar -xf gsasl-1.10.0.tar.gz
cd gsasl-1.10.0
./configure --prefix=/usr --disable-static --with-gssapi-impl=mit
make
make install
cd ..
rm -rf gsasl-1.10.0
# curl (rebuild to support gsasl, krb5 and OpenLDAP).
tar -xf curl-7.79.1.tar.xz
cd curl-7.79.1
./configure --prefix=/usr --disable-static --with-openssl --with-libssh2 --with-gssapi --enable-ares --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make
make install
cd ..
rm -rf curl-7.79.1
# SWIG.
tar -xf swig-4.0.2.tar.gz
cd swig-4.0.2
./configure --prefix=/usr --without-maximum-compile-warnings
make
make install
cd ..
rm -rf swig-4.0.2
# GPGME.
tar -xf gpgme-1.16.0.tar.bz2
cd gpgme-1.16.0
sed 's/defined(__sun.*$/1/' -i src/posix-io.c
./configure --prefix=/usr
make
make install
cd ..
rm -rf gpgme-1.16.0
# SQLite.
tar -xf sqlite-autoconf-3360000.tar.gz
cd sqlite-autoconf-3360000
./configure --prefix=/usr --disable-static --enable-fts5 CPPFLAGS="-DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS4=1 -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 -DSQLITE_ENABLE_DBSTAT_VTAB=1 -DSQLITE_SECURE_DELETE=1 -DSQLITE_ENABLE_FTS3_TOKENIZER=1"
make
make install
cd ..
rm -rf sqlite-autoconf-3360000
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
cd ..
rm -rf libtirpc-1.3.2
# libnsl.
tar -xf libnsl-2.0.0.tar.xz
cd libnsl-2.0.0
./configure --sysconfdir=/etc --disable-static
make
make install
cd ..
rm -rf libnsl-2.0.0
# Audit.
tar -xf audit-3.0.5.tar.gz
cd audit-3.0.5
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
cd ..
rm -rf audit-3.0.5
# AppArmor.
tar -xf apparmor_3.0.3.orig.tar.gz
cd apparmor-3.0.3/libraries/libapparmor
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
tar -xf shadow-4.8.1.tar.xz
cd shadow-4.8.1
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;
sed -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' -e 's@/var/spool/mail@/var/mail@' -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' -i etc/login.defs
sed -i 's/1000/999/' etc/useradd
./configure --sysconfdir=/etc --with-group-name-max-length=32 --with-audit
make
make exec_prefix=/usr install
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
rm -rf shadow-4.8.1
# NSPR.
tar -xf nspr-4.32.tar.gz
cd nspr-4.32/nspr
sed -ri '/^RELEASE/s/^/#/' pr/src/misc/Makefile.in
sed -i 's#$(LIBRARY) ##' config/rules.mk
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit
make
make install
cd ../..
rm -rf nspr-4.32
# NSS.
tar -xf nss-3.71.tar.gz
cd nss-3.71
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
cd ../..
rm -rf nss-3.71
# Git.
tar -xf git-2.33.0.tar.xz
cd git-2.33.0
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --with-python=python3 --with-libpcre2
make
make man
make perllibdir=/usr/lib/perl5/5.34/site_perl install
make install-man
cd ..
rm -rf git-2.33.0
# libstemmer.
tar -xf libstemmer-2.1.0.tar.xz
cd libstemmer-2.1.0
make
install -m755 libstemmer.so.0.0.0 /usr/lib/libstemmer.so.0.0.0
ln -s libstemmer.so.0.0.0 /usr/lib/libstemmer.so.0
ln -s libstemmer.so.0 /usr/lib/libstemmer.so
install -m644 include/libstemmer.h /usr/include/libstemmer.h
ldconfig
cd ..
rm -rf libstemmer-2.1.0
# Pahole.
tar -xf pahole-1.22-5-ge38e89e.tar.xz
cd pahole-1.22-5-ge38e89e
mkdir pahole-build; cd pahole-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -D__LIB=lib -Wno-dev -G Ninja ..
ninja
ninja install
mv /usr/share/dwarves/runtime/python/ostra.py /usr/lib/python3.9/ostra.py
rm -rf /usr/share/dwarves/runtime/python
cd ../..
rm -rf pahole-1.22-5-ge38e89e
# DKMS.
tar -xf dkms-2.8.7.tar.gz
make -C dkms-2.8.7 BASHDIR=/usr/share/bash-completion/completions install
rm -rf dkms-2.8.7
# GLib.
tar -xf glib-2.70.0.tar.xz
cd glib-2.70.0
patch -Np1 -i ../patches/glib-2.68.4-skip_warnings-1.patch
mkdir glib-build; cd glib-build
meson --prefix=/usr --buildtype=release -Dman=true ..
ninja
ninja install
cd ../..
rm -rf glib-2.70.0
# GTK-Doc.
tar -xf gtk-doc-1.33.2.tar.xz
cd gtk-doc-1.33.2
autoreconf -fi
./configure --prefix=/usr
make
make install
cd ..
rm -rf gtk-doc-1.33.2
# libsigc++
tar -xf libsigc++-2.10.7.tar.xz
cd libsigc++-2.10.7
mkdir sigc++-build; cd sigc++-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libsigc++-2.10.7
# GLibmm
tar -xf glibmm-2.66.2.tar.xz
cd glibmm-2.66.2
mkdir glibmm-build; cd glibmm-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf glibmm-2.66.2
# gobject-introspection.
tar -xf gobject-introspection-1.70.0.tar.xz
cd gobject-introspection-1.70.0
mkdir gobj-build; cd gobj-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf gobject-introspection-1.70.0
# shared-mime-info.
tar -xf shared-mime-info-2.1.tar.gz
cd shared-mime-info-2.1
mkdir smi-build; cd smi-build
meson --prefix=/usr --buildtype=release -Dupdate-mimedb=true ..
ninja
ninja install
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
cd ../..
rm -rf desktop-file-utils-0.26
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
cd ..
rm -rf autoconf-2.13
# LLVM.
tar -xf llvm-13.0.0.src.tar.xz
cd llvm-13.0.0.src
mkdir -p tools/clang
tar -xf ../clang-13.0.0.src.tar.xz -C tools/clang --strip-components=1
mkdir llvm-build; cd llvm-build
CC=gcc CXX=g++ CFLAGS="$CFLAGS -flarge-source-files" CXXFLAGS="$CXXFLAGS -flarge-source-files" cmake -DCMAKE_INSTALL_PREFIX=/usr -DLLVM_ENABLE_FFI=ON -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_TARGETS_TO_BUILD="host;AMDGPU" -DLLVM_BUILD_TESTS=ON -DLLVM_BINUTILS_INCDIR=/usr/include -Wno-dev -G Ninja ..
ninja
ninja install
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
cd ../..
rm -rf firefox-78.15.0
# Sudo.
tar -xf sudo-1.9.8p2.tar.gz
cd sudo-1.9.8p2
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
cd ..
rm -rf sudo-1.9.8p2
# volume_key.
tar -xf volume_key-0.3.12.tar.gz
cd volume_key-volume_key-0.3.12
autoreconf -fi
./configure --prefix=/usr --without-python
make
make install
cd ..
rm -rf volume_key-volume_key-0.3.12
# JSON-GLib.
tar -xf json-glib-1.6.6.tar.xz
cd json-glib-1.6.6
mkdir json-build; cd json-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf json-glib-1.6.6
# efivar.
tar -xf efivar-37.tar.bz2
cd efivar-37
patch -Np1 -i ../patches/efivar-37-gcc_9-1.patch
make CFLAGS="$CFLAGS"
make install LIBDIR=/usr/lib
cd ..
rm -rf efivar-37
# efibootmgr.
tar -xf efibootmgr-17.tar.gz
cd efibootmgr-17
sed -e '/extern int efi_set_verbose/d' -i src/efibootmgr.c
make EFIDIR=massos EFI_LOADER=grubx64.efi
make EFIDIR=massos install
cd ..
rm -rf efibootmgr-17
# libpng.
tar -xf libpng-1.6.37.tar.xz
cd libpng-1.6.37
patch -Np1 -i ../patches/libpng-1.6.37-apng.patch
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libpng-1.6.37
# FreeType (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf freetype-2.11.0.tar.xz
cd freetype-2.11.0
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static
make
make install
cd ..
rm -rf freetype-2.11.0
# Graphite2 (circular dependency; will be rebuilt later to support HarfBuzz).
tar -xf graphite2-1.3.14.tgz
cd graphite2-1.3.14
sed -i '/cmptest/d' tests/CMakeLists.txt
mkdir graphite2-build; cd graphite2-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf graphite2-1.3.14
# HarfBuzz.
tar -xf harfbuzz-3.0.0.tar.xz
cd harfbuzz-3.0.0
mkdir hb-build; cd hb-build
meson --prefix=/usr --buildtype=release -Dgraphite=enabled ..
ninja
ninja install
cd ../..
rm -rf harfbuzz-3.0.0
# FreeType (rebuild to support HarfBuzz).
tar -xf freetype-2.11.0.tar.xz
cd freetype-2.11.0
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static
make
make install
cd ..
rm -rf freetype-2.11.0
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
# Unifont.
mkdir -p /usr/share/fonts/unifont
curl -s https://unifoundry.com/pub/unifont/unifont-13.0.06/font-builds/unifont-13.0.06.pcf.gz | gunzip - > /usr/share/fonts/unifont/unifont.pcf
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
cat > /etc/default/grub << END
# Configuration file for GRUB bootloader

GRUB_DEFAULT="0"
GRUB_TIMEOUT="5"
GRUB_DISTRIBUTOR="MassOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
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
sed -i 's/${GRUB_DISTRIBUTOR} GNU\/Linux/${GRUB_DISTRIBUTOR}/' /etc/grub.d/10_linux
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
make newns
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
cd ..
rm -rf os-prober
# libyaml.
tar -xf libyaml-0.2.5.tar.gz
cd libyaml-0.2.5
./bootstrap
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libyaml-0.2.5
# libatasmart.
tar -xf libatasmart-0.19.tar.xz
cd libatasmart-0.19
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libatasmart-0.19
# libbytesize.
tar -xf libbytesize-2.6.tar.gz
cd libbytesize-2.6
./configure --prefix=/usr
make
make install
cd ..
rm -rf libbytesize-2.6
# libblockdev.
tar -xf libblockdev-2.26.tar.gz
cd libblockdev-2.26
./configure --prefix=/usr --sysconfdir=/etc --with-python3 --without-nvdimm --without-dm
make
make install
cd ..
rm -rf libblockdev-2.26
# libdaemon.
tar -xf libdaemon-0.14.tar.gz
cd libdaemon-0.14
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libdaemon-0.14
# libgudev.
tar -xf libgudev-237.tar.xz
cd libgudev-237
mkdir libgudev-build; cd libgudev-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libgudev-237
# libmbim.
tar -xf libmbim-1.26.0.tar.xz
cd libmbim-1.26.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libmbim-1.26.0
# libqmi.
tar -xf libqmi-1.30.2.tar.xz
cd libqmi-1.30.2
PYTHON=python3 ./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libqmi-1.30.2
# libuv.
tar -xf libuv-v1.42.0.tar.gz
cd libuv-v1.42.0
sh autogen.sh
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libuv-v1.42.0
# libwacom.
tar -xf libwacom-1.12.tar.bz2
cd libwacom-1.12
mkdir wacom-build; cd wacom-build
meson --prefix=/usr --buildtype=release -Dtests=disabled ..
ninja
ninja install
cd ../..
rm -rf libwacom-1.12
# mtdev.
tar -xf mtdev-1.1.6.tar.bz2
cd mtdev-1.1.6
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf mtdev-1.1.6
# Wayland.
tar -xf wayland-1.19.0.tar.xz
cd wayland-1.19.0
mkdir wayland-build; cd wayland-build
meson --prefix=/usr --buildtype=release -Ddocumentation=false ..
ninja
ninja install
cd ../..
rm -rf wayland-1.19.0
# Wayland-Protocols.
tar -xf wayland-protocols-1.23.tar.xz
cd wayland-protocols-1.23
mkdir wayland-protocols-build; cd wayland-protocols-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf wayland-protocols-1.23
# Aspell.
tar -xf aspell-0.60.8.tar.gz
cd aspell-0.60.8
./configure --prefix=/usr
make
make install
ln -sfn aspell-0.60 /usr/lib/aspell
install -m755 scripts/ispell /usr/bin/
install -m755 scripts/spell /usr/bin/
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
tar -xf enchant-2.3.0.tar.gz
cd enchant-2.3.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf enchant-2.3.0
# Fontconfig.
tar -xf fontconfig-2.13.1.tar.bz2
cd fontconfig-2.13.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-docs
make
make install
cd ..
rm -rf fontconfig-2.13.1
# Fribidi.
tar -xf fribidi-1.0.11.tar.xz
cd fribidi-1.0.11
mkdir BIDIRECTIONAL-build; cd BIDIRECTIONAL-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf fribidi-1.0.11
# giflib.
tar -xf giflib-5.2.1.tar.gz
cd giflib-5.2.1
make
make PREFIX=/usr install
rm -f /usr/lib/libgif.a
cd ..
rm -rf giflib-5.2.1
# libexif.
tar -xf libexif-0.6.23.tar.xz
cd libexif-0.6.23
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libexif-0.6.23
# NASM.
tar -xf nasm-2.15.05.tar.xz
cd nasm-2.15.05
./configure --prefix=/usr
make
make install
cd ..
rm -rf nasm-2.15.05
# libjpeg-turbo.
tar -xf libjpeg-turbo-2.1.1.tar.gz
cd libjpeg-turbo-2.1.1
mkdir jpeg-build; cd jpeg-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DENABLE_STATIC=FALSE -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf libjpeg-turbo-2.1.1
# libgphoto2
tar -xf libgphoto2-2.5.27.tar.xz
cd libgphoto2-2.5.27
./configure --prefix=/usr --disable-rpath
make
make install
cd ..
rm -rf libgphoto2-2.5.27
# Pixman.
tar -xf pixman-0.40.0.tar.gz
cd pixman-0.40.0
mkdir pixman-build; cd pixman-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf pixman-0.40.0
# Qpdf.
tar -xf qpdf-10.3.2.tar.gz
cd qpdf-10.3.2
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf qpdf-10.3.2
# qrencode.
tar -xf qrencode-4.1.1.tar.bz2
cd qrencode-4.1.1
./configure --prefix=/usr
make
make install
cd ..
rm -rf qrencode-4.1.1
# libsass.
tar -xf libsass-3.6.5.tar.gz
cd libsass-3.6.5
autoreconf -fi
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libsass-3.6.5
# sassc.
tar -xf sassc-3.6.2.tar.gz
cd sassc-3.6.2
autoreconf -fi
./configure --prefix=/usr
make
make install
cd ..
rm -rf sassc-3.6.2
# ISO-Codes.
tar -xf iso-codes_4.7.0.orig.tar.xz
cd iso-codes-4.7.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf iso-codes-4.7.0
# XDG-user-dirs.
tar -xf xdg-user-dirs-0.17.tar.gz
cd xdg-user-dirs-0.17
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf xdg-user-dirs-0.17
# LSB-Tools.
tar -xf LSB-Tools-0.9.tar.gz
cd LSB-Tools-0.9
python setup.py build
python setup.py install --optimize=1
cd ..
rm -rf LSB-Tools-0.9
# p7zip.
tar -xf p7zip-17.04.tar.gz
cd p7zip-17.04
sed '/^gzip/d' -i install.sh
sed -i '160a if(_buffer == nullptr || _size == _pos) return E_FAIL;' CPP/7zip/Common/StreamObjects.cpp
make all3
make DEST_HOME=/usr DEST_MAN=/usr/share/man DEST_SHARE_DOC=/usr/share/doc/p7zip-17.04 install
cd ..
rm -rf p7zip-17.04
# UnRAR.
tar -xf unrarsrc-6.0.7.tar.gz
cd unrar
make -f makefile
install -m755 unrar /usr/bin
cd ..
rm -rf unrar
# Ruby.
tar -xf ruby-3.0.2.tar.xz
cd ruby-3.0.2
./configure --prefix=/usr --enable-shared
make
make install
gem install lolcat
cd ..
rm -rf ruby-3.0.2
# slang.
tar -xf slang-2.3.2.tar.bz2
cd slang-2.3.2
./configure --prefix=/usr --sysconfdir=/etc --with-readline=gnu
make -j1
make -j1 install_doc_dir=/usr/share/doc/slang-2.3.2 SLSH_DOC_DIR=/usr/share/doc/slang-2.3.2/slsh install-all
chmod 755 /usr/lib/libslang.so.2.3.2 /usr/lib/slang/v2/modules/*.so
rm -f /usr/lib/libslang.a
cd ..
rm -rf slang-2.3.2
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
cd ..
rm -rf dhcp-4.4.2-P1
# xdg-utils.
tar -xf xdg-utils-1.1.3.tar.gz
cd xdg-utils-1.1.3
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
cd ..
rm -rf xdg-utils-1.1.3
# libnl.
tar -xf libnl-3.5.0.tar.gz
cd libnl-3.5.0
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
cd ..
rm -rf libnl-3.5.0
# wpa_supplicant.
tar -xf wpa_supplicant-2.9.tar.gz
cd wpa_supplicant-2.9/wpa_supplicant
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
cd ../..
rm -rf wpa_supplicant-2.9
# libzip.
tar -xf libzip-1.8.0.tar.xz
cd libzip-1.8.0
mkdir libzip-build; cd libzip-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf libzip-1.8.0
# gz2xz.
tar -xf gz2xz-1.0.2.tar.gz
cd gz2xz-1.0.2
make INSTALL_DIR=/usr/bin install
gz2xz --install-symlinks
cd ..
rm -rf gz2xz-1.0.2
# util-macros.
tar -xf util-macros-1.19.3.tar.bz2
cd util-macros-1.19.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
cd ..
rm -rf util-macros-1.19.3
# xorgproto.
tar -xf xorgproto-2021.5.tar.bz2
cd xorgproto-2021.5
mkdir xorgproto-build; cd xorgproto-build
meson --prefix=/usr -Dlegacy=true ..
ninja
ninja install
cd ../..
rm -rf xorgproto-2021.5
# libXau.
tar -xf libXau-1.0.9.tar.bz2
cd libXau-1.0.9
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf libXau-1.0.9
# libXdmcp.
tar -xf libXdmcp-1.1.3.tar.bz2
cd libXdmcp-1.1.3
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf libXdmcp-1.1.3
# xcb-proto.
tar -xf xcb-proto-1.14.1.tar.xz
cd xcb-proto-1.14.1
PYTHON=python3 ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
cd ..
rm -rf xcb-proto-1.14.1
# libxcb.
tar -xf libxcb-1.14.tar.xz
cd libxcb-1.14
CFLAGS="$CFLAGS -Wno-error=format-extra-args" PYTHON=python3 ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --without-doxygen
make
make install
cd ..
rm -rf libxcb-1.14
# Xorg Libraries.
for i in xtrans-1.4.0 libX11-1.7.2 libXext-1.3.4 libFS-1.0.8 libICE-1.0.10 libSM-1.2.3 libXScrnSaver-1.2.3 libXt-1.2.1 libXmu-1.1.3 libXpm-3.5.13 libXaw-1.0.14 libXfixes-6.0.0 libXcomposite-0.4.5 libXrender-0.9.10 libXcursor-1.2.0 libXdamage-1.1.5 libfontenc-1.1.4 libXfont2-2.0.5 libXft-2.3.4 libXi-1.8 libXinerama-1.1.4 libXrandr-1.5.2 libXres-1.2.1 libXtst-1.2.3 libXv-1.0.11 libXvMC-1.0.12 libXxf86dga-1.1.5 libXxf86vm-1.1.4 libdmx-1.1.4 libpciaccess-0.16 libxkbfile-1.1.0 libxshmfence-1.3; do
  tar -xf $i.tar.bz2
  cd $i
  case $i in
    libICE* ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static ICE_LIBS=-lpthread ;;
    libXfont2-[0-9]* ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-devel-docs ;;
    libXt-[0-9]* ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-appdefaultdir=/etc/X11/app-defaults ;;
    * ) ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  esac
  make
  make install
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
  cd ..
  rm -rf $i
  ldconfig
done
# libdrm.
tar -xf libdrm-2.4.107.tar.xz
cd libdrm-2.4.107
mkdir libdrm-build; cd libdrm-build
meson --prefix=/usr --buildtype=release -Dudev=true -Dvalgrind=false ..
ninja
ninja install
cd ../..
rm -rf libdrm-2.4.107
# libva (circular dependency; will be rebuilt later to support Mesa).
tar -xf libva-2.13.0.tar.bz2
cd libva-2.13.0
./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf libva-2.13.0
# libvdpau.
tar -xf libvdpau-1.4.tar.bz2
cd libvdpau-1.4
mkdir vdpau-build; cd vdpau-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libvdpau-1.4
# Mesa.
tar -xf mesa-21.2.3.tar.xz
cd mesa-21.2.3
patch -Np1 -i ../patches/mesa-21.2.1-add_xdemos-1.patch
sed '1s/python/&3/' -i bin/symbols-check.py
mkdir mesa-build; cd mesa-build
meson --prefix=/usr --buildtype=release -Dgallium-drivers="i915,iris,nouveau,r600,radeonsi,svga,swrast,virgl" -Ddri-drivers="i965,nouveau" -Dgallium-nine=false -Dglx=dri -Dvalgrind=disabled -Dlibunwind=disabled ..
ninja
ninja install
cd ../..
rm -rf mesa-21.2.3
# libva (rebuild to support Mesa).
tar -xf libva-2.13.0.tar.bz2
cd libva-2.13.0
./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf libva-2.13.0
# xbitmaps.
tar -xf xbitmaps-1.1.2.tar.bz2
cd xbitmaps-1.1.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make install
cd ..
rm -rf xbitmaps-1.1.2
# Xorg Applications.
for i in iceauth-1.0.8 luit-1.1.1 mkfontscale-1.2.1 sessreg-1.1.2 setxkbmap-1.3.2 smproxy-1.0.6 x11perf-1.6.1 xauth-1.1 xbacklight-1.2.3 xcmsdb-1.0.5 xcursorgen-1.0.7 xdpyinfo-1.3.2 xdriinfo-1.0.6 xev-1.2.4 xgamma-1.0.6 xhost-1.0.8 xinput-1.6.3 xkbcomp-1.4.5 xkbevd-1.1.4 xkbutils-1.0.4 xkill-1.0.5 xlsatoms-1.1.3 xlsclients-1.1.4 xmessage-1.0.5 xmodmap-1.0.10 xpr-1.0.5 xprop-1.2.5 xrandr-1.5.1 xrdb-1.2.1 xrefresh-1.0.6 xset-1.2.4 xsetroot-1.1.2 xvinfo-1.1.4 xwd-1.0.8 xwininfo-1.1.5 xwud-1.0.5; do
  tar -xf $i.tar.*
  cd $i
  case $i in
    luit-[0-9]* ) sed -i -e "/D_XOPEN/s/5/6/" configure ;;
  esac
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  make
  make install
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
cd ..
rm -rf xcursor-themes-1.0.6
# Xorg Fonts.
for i in font-util-1.3.2 encodings-1.0.5 font-alias-1.0.4 font-adobe-utopia-type1-1.0.4 font-bh-ttf-1.0.3 font-bh-type1-1.0.3 font-ibm-type1-1.0.3 font-misc-ethiopic-1.0.4 font-xfree86-type1-1.0.4; do
  tar -xf $i.tar.bz2
  cd $i
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
  make
  make install
  cd ..
  rm -rf $i
done
install -dm755 /usr/share/fonts
ln -sfn /usr/share/fonts/X11/OTF /usr/share/fonts/X11-OTF
ln -sfn /usr/share/fonts/X11/TTF /usr/share/fonts/X11-TTF
# Noto Fonts.
tar --no-same-owner -xf noto-fonts.tar.xz -C /usr --strip-components=2
fc-cache
# XKeyboard-Config.
tar -xf xkeyboard-config-2.34.tar.bz2
cd xkeyboard-config-2.34
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-xkb-rules-symlink=xorg
make
make install
cd ..
rm -rf xkeyboard-config-2.34
# libxkbcommon.
tar -xf libxkbcommon-1.3.1.tar.xz
cd libxkbcommon-1.3.1
mkdir xkb-build; cd xkb-build
meson --prefix=/usr --buildtype=release -Denable-docs=false ..
ninja
ninja install
cd ../..
rm -rf libxkbcommon-1.3.1
# Systemd (rebuild to support more features).
tar -xf systemd-249.tar.gz
cd systemd-249
patch -Np1 -i ../patches/systemd-249-upstream_fixes-1.patch
sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
mkdir sysd-build; cd sysd-build
meson --prefix=/usr --sysconfdir=/etc --localstatedir=/var --buildtype=release -Dmode=release -Dfallback-hostname=massos -Dversion-tag=249-massos -Dblkid=true -Ddefault-dnssec=no -Dfirstboot=false -Dinstall-tests=false -Dldconfig=false -Dsysusers=false -Db_lto=false -Drpmmacrosdir=no -Dhomed=true -Duserdb=true -Dgnu-efi=true -Dman=true -Dpamconfdir=/etc/pam.d ..
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
rm -rf systemd-249
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
cd ..
rm -rf dbus-glib-0.112
# alsa-lib.
tar -xf alsa-lib-1.2.5.1.tar.bz2
cd alsa-lib-1.2.5.1
./configure
make
make install
cd ..
rm -rf alsa-lib-1.2.5.1
# libepoxy.
tar -xf libepoxy-1.5.9.tar.xz
cd libepoxy-1.5.9
mkdir epoxy-build; cd epoxy-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libepoxy-1.5.9
# Xorg-Server.
tar -xf xorg-server-1.20.13.tar.xz
cd xorg-server-1.20.13
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --enable-glamor --enable-suid-wrapper --enable-kdrive --with-xkb-output=/var/lib/xkb
make
make install
mkdir -p /etc/X11/xorg.conf.d
cd ..
rm -rf xorg-server-1.20.13
# libevdev.
tar -xf libevdev-1.11.0.tar.xz
cd libevdev-1.11.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf libevdev-1.11.0
# xf86-input-evdev.
tar -xf xf86-input-evdev-2.10.6.tar.bz2
cd xf86-input-evdev-2.10.6
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-input-evdev-2.10.6
# libinput.
tar -xf libinput-1.19.1.tar.xz
cd libinput-1.19.1
mkdir libinput-build; cd libinput-build
meson --prefix=/usr --buildtype=release -Ddebug-gui=false -Dtests=false -Ddocumentation=false ..
ninja
ninja install
cd ../..
rm -rf libinput-1.19.1
# xf86-input-libinput.
tar -xf xf86-input-libinput-1.2.0.tar.bz2
cd xf86-input-libinput-1.2.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-input-libinput-1.2.0
# xf86-input-synaptics.
tar -xf xf86-input-synaptics-1.9.1.tar.bz2
cd xf86-input-synaptics-1.9.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-input-synaptics-1.9.1
# xf86-input-wacom.
tar -xf xf86-input-wacom-0.40.0.tar.bz2
cd xf86-input-wacom-0.40.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-input-wacom-0.40.0
# xf86-video-amdgpu.
tar -xf xf86-video-amdgpu-21.0.0.tar.bz2
cd xf86-video-amdgpu-21.0.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-video-amdgpu-21.0.0
# xf86-video-ati.
tar -xf xf86-video-ati-19.1.0.tar.bz2
cd xf86-video-ati-19.1.0
patch -Np1 -i ../patches/xf86-video-ati-19.1.0-upstream_fixes-1.patch
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-video-ati-19.1.0
# xf86-video-fbdev.
tar -xf xf86-video-fbdev-0.5.0.tar.bz2
cd xf86-video-fbdev-0.5.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-video-fbdev-0.5.0
# xf86-video-intel.
tar -xf xf86-video-intel-20211007.tar.xz
cd xf86-video-intel-20211007
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --enable-kms-only --enable-uxa --mandir=/usr/share/man
make
make install
mv -v /usr/share/man/man4/intel-virtual-output.4 /usr/share/man/man1/intel-virtual-output.1
sed -i '/\.TH/s/4/1/' /usr/share/man/man1/intel-virtual-output.1
cd ..
rm -rf xf86-video-intel-20211007
# xf86-video-nouveau.
tar -xf xf86-video-nouveau-1.0.17.tar.bz2
cd xf86-video-nouveau-1.0.17
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-video-nouveau-1.0.17
# xf86-video-vmware.
tar -xf xf86-video-vmware-13.3.0.tar.bz2
cd xf86-video-vmware-13.3.0
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf xf86-video-vmware-13.3.0
# intel-vaapi-driver.
tar -xf intel-vaapi-driver-2.4.1.tar.bz2
cd intel-vaapi-driver-2.4.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf intel-vaapi-driver-2.4.1
# xinit.
tar -xf xinit-1.4.1.tar.bz2
cd xinit-1.4.1
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --with-xinitdir=/etc/X11/app-defaults
make
make install
ldconfig
cd ..
rm -rf xinit-1.4.1
# Prefer libinput for handling input devices.
ln -sr /usr/share/X11/xorg.conf.d/40-libinput.conf /etc/X11/xorg.conf.d/40-libinput.conf
# Polkit.
tar -xf polkit-0.120.tar.gz
cd polkit-0.120
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
cd ..
rm -rf openssh-8.8p1
# sshfs.
tar -xf sshfs-3.7.2.tar.xz
cd sshfs-3.7.2
mkdir sshfs-build; cd sshfs-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf sshfs-3.7.2
# GLU.
tar -xf glu-9.0.2.tar.xz
cd glu-9.0.2
mkdir glu-build; cd glu-build
meson --prefix=/usr -Dgl_provider=gl --buildtype=release ..
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
cd ../..
rm -rf tiff-4.3.0
# lcms2.
tar -xf lcms2-2.12.tar.gz
cd lcms2-2.12
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf lcms2-2.12
# ATK.
tar -xf atk-2.36.0.tar.xz
cd atk-2.36.0
mkdir atk-build; cd atk-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf atk-2.36.0
# Atkmm.
tar -xf atkmm-2.28.2.tar.xz
cd atkmm-2.28.2
mkdir atkmm-build; cd atkmm-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
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
cd ../..
rm -rf gdk-pixbuf-2.42.6
# Cairo.
tar -xf cairo-1.17.4.tar.xz
cd cairo-1.17.4
./configure --prefix=/usr --disable-static --enable-tee
make
make install
cd ..
rm -rf cairo-1.17.4
# cairomm.
tar -xf cairomm-1.14.0.tar.xz
cd cairomm-1.14.0
mkdir cmm-build; cd cmm-build
meson --prefix=/usr --buildtype=release -Dbuild-tests=true -Dboost-shared=true ..
ninja
ninja install
cd ../..
rm -rf cairomm-1.14.0
# Pango.
tar -xf pango-1.48.10.tar.xz
cd pango-1.48.10
mkdir pango-build; cd pango-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf pango-1.48.10
# Pangomm.
tar -xf pangomm-2.46.1.tar.xz
cd pangomm-2.46.1
mkdir pmm-build; cd pmm-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf pangomm-2.46.1
# hicolor-icon-theme.
tar -xf hicolor-icon-theme-0.17.tar.xz
cd hicolor-icon-theme-0.17
./configure --prefix=/usr
make install
cd ..
rm -rf hicolor-icon-theme-0.17
# XML::Simple.
tar -xf XML-Simple-2.25.tar.gz
cd XML-Simple-2.25
perl Makefile.PL
make
make install
cd ..
rm -rf XML-Simple-2.25
# icon-naming-utils.
tar -xf icon-naming-utils-0.8.90.tar.bz2
cd icon-naming-utils-0.8.90
./configure --prefix=/usr
make
make install
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
cd ..
rm -rf gtk+-2.24.33
# SDL (initial build; will be rebuilt later to support PulseAudio).
tar -xf SDL-1.2.15.tar.gz
cd SDL-1.2.15
sed -e '/_XData32/s:register long:register _Xconst long:' -i src/video/x11/SDL_x11sym.h
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf SDL-1.2.15
# libwebp.
tar -xf libwebp-1.2.1.tar.gz
cd libwebp-1.2.1
./configure --prefix=/usr --enable-libwebpmux --enable-libwebpdemux --enable-libwebpdecoder --enable-libwebpextras --enable-swap-16bit-csp --disable-static
make
make install
cd ..
rm -rf libwebp-1.2.1
# libglade.
tar -xf libglade-2.6.4.tar.bz2
cd libglade-2.6.4
sed -i '/DG_DISABLE_DEPRECATED/d' glade/Makefile.in
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libglade-2.6.4
# Graphviz.
tar -xf graphviz-2.49.1.tar.gz
cd graphviz-2.49.1
sed -i '/LIBPOSTFIX="64"/s/64//' configure.ac
./autogen.sh
./configure --prefix=/usr --disable-php --with-webp PS2PDF=true
make
make install
cd ..
rm -rf graphviz-2.49.1
# Vala.
tar -xf vala-0.54.2.tar.xz
cd vala-0.54.2
./configure --prefix=/usr
make
make install
cd ..
rm -rf vala-0.54.2
# libgusb.
tar -xf libgusb-0.3.7.tar.gz
cd libgusb-0.3.7
mkdir libgusb-build; cd libgusb-build
meson --prefix=/usr --buildtype=release -Ddocs=false ..
ninja
ninja install
cd ../..
rm -rf libgusb-0.3.7
# librsvg.
tar -xf librsvg-2.52.0.tar.xz
cd librsvg-2.52.0
./configure --prefix=/usr --enable-vala --disable-static
make
make install
gdk-pixbuf-query-loaders --update-cache
cd ..
rm -rf librsvg-2.52.0
# adwaita-icon-theme.
tar -xf adwaita-icon-theme-41.0.tar.xz
cd adwaita-icon-theme-41.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf adwaita-icon-theme-41.0
# at-spi2-core.
tar -xf at-spi2-core-2.42.0.tar.xz
cd at-spi2-core-2.42.0
mkdir spi2-build; cd spi2-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
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
cd ../..
rm -rf at-spi2-atk-2.38.0
# GTK3.
tar -xf gtk+-3.24.30.tar.xz
cd gtk+-3.24.30
./configure --prefix=/usr --sysconfdir=/etc --enable-broadway-backend --enable-x11-backend --enable-wayland-backend
make
make install
gtk-query-immodules-3.0 --update-cache
glib-compile-schemas /usr/share/glib-2.0/schemas
cd ..
rm -rf gtk+-3.24.30
# Gtkmm.
tar -xf gtkmm-3.24.5.tar.xz
cd gtkmm-3.24.5
mkdir gmm-build; cd gmm-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf gtkmm-3.24.5
# Arc (GTK Theme).
tar --no-same-owner -xf arc-theme-20210412.tar.xz -C /usr/share --strip-components=1
gtk-update-icon-cache /usr/share/icons/Arc
mkdir -p /etc/gtk-2.0
cat > /etc/gtk-2.0/gtkrc << END
gtk-theme-name = "Arc-Dark"
gtk-icon-theme-name = "Arc"
gtk-cursor-theme-name = "Adwaita"
END
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << END
[Settings]
gtk-theme-name = Arc-Dark
gtk-icon-theme-name = Arc
gtk-font-name = Sans 10
gtk-cursor-theme-size = 0
gtk-toolbar-style = GTK_TOOLBAR_ICONS
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintnone
gtk-xft-rgba = rgb
gtk-cursor-theme-name = Adwaita
END
# libhandy.
tar -xf libhandy-1.4.0.tar.xz
cd libhandy-1.4.0
mkdir handy-build; cd handy-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libhandy-1.4.0
# libogg.
tar -xf libogg-1.3.5.tar.xz
cd libogg-1.3.5
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libogg-1.3.5
# libvorbis.
tar -xf libvorbis-1.3.7.tar.xz
cd libvorbis-1.3.7
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libvorbis-1.3.7
# libtheora.
tar -xf libtheora-1.1.1.tar.xz
cd libtheora-1.1.1
sed -i 's/png_\(sizeof\)/\1/g' examples/png2theora.c
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libtheora-1.1.1
# Speex.
tar -xf speex-1.2.0.tar.gz
cd speex-1.2.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf speex-1.2.0
# SpeexDSP.
tar -xf speexdsp-1.2.0.tar.gz
cd speexdsp-1.2.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf speexdsp-1.2.0
# Opus.
tar -xf opus-1.3.1.tar.gz
cd opus-1.3.1
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf opus-1.3.1
# FLAC.
tar -xf flac-1.3.3.tar.xz
cd flac-1.3.3
patch -Np1 -i ../patches/flac-1.3.3-security_fixes-1.patch
./configure --prefix=/usr --disable-thorough-tests
make
make install
cd ..
rm -rf flac-1.3.3
# libsndfile.
tar -xf libsndfile-1.0.31.tar.bz2
cd libsndfile-1.0.31
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libsndfile-1.0.31
# SBC.
tar -xf sbc-1.5.tar.xz
cd sbc-1.5
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf sbc-1.5
# libical.
tar -xf libical-3.0.11.tar.gz
cd libical-3.0.11
mkdir build-with-CMAKE; cd build-with-CMAKE
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DSHARED_ONLY=yes -DICAL_BUILD_DOCS=false -DGOBJECT_INTROSPECTION=true -DICAL_GLIB_VAPI=true -Wno-dev ..
make -j1
make -j1 install
cd ../..
rm -rf libical-3.0.11
# BlueZ.
tar -xf bluez-5.61.tar.xz
cd bluez-5.61
sed 's/pause(/bluez_&/' -i profiles/audio/media.c
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-manpages --enable-library
make
make install
ln -sf ../libexec/bluetooth/bluetoothd /usr/sbin
install -dm755 /etc/bluetooth
install -m644 src/main.conf /etc/bluetooth/main.conf
systemctl enable bluetooth
systemctl enable --global obex
cd ..
rm -rf bluez-5.61
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
# dmidecode.
tar -xf dmidecode-3.3.tar.xz
cd dmidecode-3.3
make prefix=/usr CFLAGS="$CFLAGS"
make prefix=/usr install
cd ..
rm -rf dmidecode-3.3
# laptop-detect.
tar -xf laptop-detect_0.16.tar.xz
cd laptop-detect-0.16
sed -e "s/@VERSION@/0.16/g" < laptop-detect.in > laptop-detect
install -Dm755 laptop-detect /usr/bin/laptop-detect
install -Dm644 laptop-detect.1 /usr/share/man/man1/laptop-detect.1
cd ..
rm -rf laptop-detect-0.16
# rrdtool.
tar -xf rrdtool-1.7.2.tar.gz
cd rrdtool-1.7.2
sed -e 's/$(RUBY) ${abs_srcdir}\/ruby\/extconf.rb/& --vendor/' -i bindings/Makefile.am
aclocal
automake
./configure --prefix=/usr --localstatedir=/var --disable-rpath --enable-perl --enable-perl-site-install --with-perl-options='INSTALLDIRS=vendor' --enable-ruby --enable-ruby-site-install --enable-python --enable-tcl --disable-libwrap
make
make install
rm -f /usr/lib/librrd.a
cd ..
rm -rf rrdtool-1.7.2
# lm-sensors.
tar -xf lm-sensors-3-6-0.tar.gz
cd lm-sensors-3-6-0
make PREFIX=/usr MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord
make PREFIX=/usr MANDIR=/usr/share/man BUILD_STATIC_LIB=0 PROG_EXTRA=sensord install
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
cd ..
rm -rf libpcap-1.10.1
# Net-SNMP.
tar -xf net-snmp-5.9.1.tar.xz
cd net-snmp-5.9.1
./configure --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --enable-ucd-snmp-compatibility --enable-ipv6 --with-python-modules --with-default-snmp-version="3" --with-sys-contact="root@localhost" --with-sys-location="Unknown" --with-logfile="/var/log/snmpd.log" --with-mib-modules="host misc/ipfwacc ucd-snmp/diskio tunnel ucd-snmp/dlmod ucd-snmp/lmsensorsMib" --with-persistent-directory="/var/net-snmp"
make NETSNMP_DONT_CHECK_VERSION=1
make INSTALLDIRS=vendor install
install -m644 systemd-units/snmpd.service /usr/lib/systemd/system/snmpd.service
install -m644 systemd-units/snmptrapd.service /usr/lib/systemd/system/snmptrapd.service
for i in libnetsnmp libnetsnmpmibs libsnmp libnetsnmphelpers libnetsnmptrapd libnetsnmpagent; do
  rm -f /usr/lib/$i.a
done
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
cd ..
rm -rf ppp-2.4.9
# Vim.
tar -xf vim-8.2.3458.tar.xz
cd vim-8.2.3458
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
echo '#define SYS_GVIMRC_FILE "/etc/gvimrc"' >> src/feature.h
./configure --prefix=/usr --with-features=huge --enable-gui=gtk3 --with-tlib=ncursesw
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
cd ..
rm -rf vim-8.2.3458
# libwpe.
tar -xf libwpe-1.10.1.tar.xz
cd libwpe-1.10.1
mkdir wpe-build; cd wpe-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libwpe-1.10.1
# OpenJPEG.
tar -xf openjpeg-2.4.0.tar.gz
cd openjpeg-2.4.0
mkdir ojpg-build; cd ojpg-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC_LIBS=OFF -Wno-dev -G Ninja ..
ninja
ninja install
cd ../doc
for man in man/man?/*; do install -v -D -m 644 $man /usr/share/$man; done
cd ../..
rm -rf openjpeg-2.4.0
# libsecret.
tar -xf libsecret-0.20.4.tar.xz
cd libsecret-0.20.4
mkdir secret-build; cd secret-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libsecret-0.20.4
# Gcr.
tar -xf gcr-3.41.0.tar.xz
cd gcr-3.41.0
sed -i 's:"/desktop:"/org:' schema/*.xml
sed -e '208 s/@BASENAME@/gcr-viewer.desktop/' -e '231 s/@BASENAME@/gcr-prompter.desktop/' -i ui/meson.build
mkdir gcr-build; cd gcr-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf gcr-3.41.0
# pinentry.
tar -xf pinentry-1.2.0.tar.bz2
cd pinentry-1.2.0
./configure --prefix=/usr --enable-pinentry-tty
make
make install
cd ..
rm -rf pinentry-1.2.0
# AccountsService.
tar -xf accountsservice-0.6.55.tar.xz
cd accountsservice-0.6.55
mkdir as-build; cd as-build
meson --prefix=/usr --buildtype=release -Dadmin_group=adm -Dsystemd=true ..
ninja
ninja install
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
cd ../..
rm -rf colord-1.4.5
# CUPS.
tar -xf cups-2.3.3op2-source.tar.gz
cd cups-2.3.3op2
useradd -c "Print Service User" -d /var/spool/cups -g lp -s /bin/false -u 9 lp
groupadd -g 19 lpadmin
sed -e "s/-Wno-format-truncation//" -i configure -i config-scripts/cups-compiler.m4
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
cd ..
rm -rf cups-2.3.3op2
# Poppler.
tar -xf poppler-21.10.0.tar.xz
cd poppler-21.10.0
mkdir poppler-build; cd poppler-build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DTESTDATADIR=$PWD/testfiles -DENABLE_UNSTABLE_API_ABI_HEADERS=ON -Wno-dev -G Ninja ..
ninja
ninja install
tar -xf ../../poppler-data-0.4.11.tar.gz
cd poppler-data-0.4.11
make prefix=/usr install
cd ../../..
rm -rf poppler-21.10.0
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
fc-cache /usr/share/ghostscript/fonts/
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
cd ..
rm -rf mupdf-1.18.0-source
# CUPS Filters.
tar -xf cups-filters-1.28.10.tar.xz
cd cups-filters-1.28.10
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --without-rcdir --disable-static --with-test-font-path=/usr/share/fonts/noto/NotoSans-Regular.ttf
make
make install
install -m644 utils/cups-browsed.service /usr/lib/systemd/system/cups-browsed.service
systemctl enable cups-browsed
cd ..
rm -rf cups-filters-1.28.10
# Gutenprint.
tar -xf gutenprint-5.3.3.tar.xz
cd gutenprint-5.3.3
sed -i 's|$(PACKAGE)/doc|doc/$(PACKAGE)-$(VERSION)|' {,doc/,doc/developer/}Makefile.in
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf gutenprint-5.3.3
# SANE.
tar -xf sane-backends-1.0.32.tar.gz
cd sane-backends-1.0.32
[ -d /run/lock ] || mkdir -p /run/lock
groupadd -g 70 scanner
mkdir inSANE-build; cd inSANE-build
sg scanner -c "../configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-group=scanner"
make
make install
install -m644 tools/udev/libsane.rules /usr/lib/udev/rules.d/65-scanner.rules
[ ! -e /var/lock/sane ] || chgrp scanner /var/lock/sane
cd ../..
rm -rf sane-backends-1.0.32
# hplip.
tar -xf hplip-3.21.8.tar.xz
cd hplip-3.21.8
./configure --prefix=/usr --disable-qt4 --disable-qt5 --enable-hpcups-install --enable-cups-drv-install --disable-imageProcessor-build --enable-pp-build
make
make -j1 rulesdir=/usr/lib/udev/rules.d DESTDIR=$PWD/destination-tmp install
rm -rf destination-tmp/etc/{sane.d,xdg}
rm -rf destination-tmp/usr/share/hal
rm -rf destination-tmp/etc/init.d
rm -f destination-tmp/usr/share/applications/hp-uiscan.desktop
rm -f destination-tmp/usr/share/applications/hplip.desktop
install -dm755 destination-tmp/etc/sane.d/dll.d
echo hpaio > destination-tmp/etc/sane.d/dll.d/hpaio
cp -a destination-tmp/* /
ldconfig
cd ..
rm -rf hplip-3.21.8
# Tk.
tar -xf tk8.6.11.1-src.tar.gz
cd tk8.6.11/unix
./configure --prefix=/usr --mandir=/usr/share/man --enable-64bit
make
sed -e "s@^\(TK_SRC_DIR='\).*@\1/usr/include'@" -e "/TK_B/s@='\(-L\)\?.*unix@='\1/usr/lib@" -i tkConfig.sh
make install
make install-private-headers
ln -sf wish8.6 /usr/bin/wish
chmod 755 /usr/lib/libtk8.6.so
cd ../..
rm -rf tk8.6.11
# Python (rebuild to support SQLite and Tk).
tar -xf Python-3.9.7.tar.xz
cd Python-3.9.7
./configure --prefix=/usr --enable-shared --with-system-expat --with-system-ffi --with-ensurepip=yes --enable-optimizations
make
make install
pip install cython
pip install requests
pip install tldr
cd ..
rm -rf Python-3.9.7
# libplist.
tar -xf libplist-2.2.0.tar.bz2
cd libplist-2.2.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libplist-2.2.0
# libusbmuxd.
tar -xf libusbmuxd-2.0.2.tar.bz2
cd libusbmuxd-2.0.2
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libusbmuxd-2.0.2
# libimobiledevice.
tar -xf libimobiledevice-1.3.0.tar.bz2
cd libimobiledevice-1.3.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libimobiledevice-1.3.0
# mobile-broadband-provider-info.
tar -xf mobile-broadband-provider-info-20210805.tar.xz
cd mobile-broadband-provider-info-20210805
./autogen.sh --prefix=/usr
make
make install
cd ..
rm -rf mobile-broadband-provider-info-20210805
# ModemManager.
tar -xf ModemManager-1.18.2.tar.xz
cd ModemManager-1.18.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-systemd-journal --with-systemd-suspend-resume --disable-static
make
make install
cd ..
rm -rf ModemManager-1.18.2
# libndp.
tar -xf libndp-1.8.tar.gz
cd libndp-1.8
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
cd ..
rm -rf libndp-1.8
# newt.
tar -xf newt-0.52.21.tar.gz
cd newt-0.52.21
sed -e 's/^LIBNEWT =/#&/' -e '/install -m 644 $(LIBNEWT)/ s/^/#/' -e 's/$(LIBNEWT)/$(LIBNEWTSONAME)/g' -i Makefile.in
./configure --prefix=/usr --with-gpm-support --with-python=python3.9
make
make install
cd ..
rm -rf newt-0.52.21
# PyCairo.
tar -xf pycairo-1.20.1.tar.gz
cd pycairo-1.20.1
python setup.py build
python setup.py install --optimize=1
python setup.py install_pycairo_header
python setup.py install_pkgconfig
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
cd ../..
rm -rf pygobject-3.42.0
# D-Bus Python.
tar -xf dbus-python-1.2.18.tar.gz
cd dbus-python-1.2.18
PYTHON=/usr/bin/python3 ./configure --prefix=/usr
make
make install
cd ..
rm -rf dbus-python-1.2.18
# UPower.
tar -xf upower-UPOWER_0_99_13.tar.bz2
cd upower-UPOWER_0_99_13
./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-deprecated --disable-static --enable-gtk-doc
make
make install
systemctl enable upower
cd ..
rm -rf upower-UPOWER_0_99_13
# NetworkManager.
tar -xf NetworkManager-1.32.12.tar.xz
cd NetworkManager-1.32.12
grep -rl '^#!.*python$' | xargs sed -i '1s/python/&3/'
mkdir nm-build; cd nm-build
meson --prefix=/usr --buildtype=release -Dnmtui=true -Dovs=false -Dselinux=false -Dqt=false -Dsession_tracking=systemd ..
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
systemctl enable NetworkManager
cd ../..
rm -rf NetworkManager-1.32.12
# libnma.
tar -xf libnma-1.8.32.tar.xz
cd libnma-1.8.32
mkdir nma-build; cd nma-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libnma-1.8.32
# libnotify.
tar -xf libnotify-0.7.9.tar.xz
cd libnotify-0.7.9
mkdir notify-build; cd notify-build
meson --prefix=/usr --buildtype=release -Dman=false ..
ninja
ninja install
cd ../..
rm -rf libnotify-0.7.9
# startup-notification.
tar -xf startup-notification-0.12.tar.gz
cd startup-notification-0.12
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf startup-notification-0.12
# libwnck.
tar -xf libwnck-40.0.tar.xz
cd libwnck-40.0
mkdir wnck-build; cd wnck-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf libwnck-40.0
# network-manager-applet.
tar -xf network-manager-applet-1.24.0.tar.xz
cd network-manager-applet-1.24.0
mkdir nma-build; cd nma-build
meson --prefix=/usr --buildtype=release -Dappindicator=no -Dselinux=false ..
ninja
ninja install
cd ../..
rm -rf network-manager-applet-1.24.0
# UDisks.
tar -xf udisks-2.9.4.tar.bz2
cd udisks-2.9.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static
make
make install
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
cd ../..
rm -rf gsettings-desktop-schemas-41.0
# glib-networking.
tar -xf glib-networking-2.70.0.tar.xz
cd glib-networking-2.70.0
mkdir glibnet-build; cd glibnet-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf glib-networking-2.70.0
# libsoup.
tar -xf libsoup-2.74.0.tar.xz
cd libsoup-2.74.0
mkdir soup-build; cd soup-build
meson --prefix=/usr --buildtype=release -Dvapi=enabled ..
ninja
ninja install
cd ../..
rm -rf libsoup-2.74.0
# libostree.
tar -xf libostree-2021.4.tar.xz
cd libostree-2021.4
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-builtin-grub2-mkconfig --with-dracut --with-openssl --enable-experimental-api --disable-static
make
make install
cd ..
rm -rf libostree-2021.4
# AppStream.
tar -xf AppStream-0.14.6.tar.xz
cd AppStream-0.14.6
mkdir appstream-build; cd appstream-build
meson --prefix=/usr --buildtype=release -Dvapi=true -Dcompose=true ..
ninja
ninja install
cd ../..
rm -rf AppStream-0.14.6
# appstream-glib.
tar -xf appstream_glib_0_7_18.tar.gz
cd appstream-glib-appstream_glib_0_7_18
mkdir appstream-glib-build; cd appstream-glib-build
meson --prefix=/usr --buildtype=release -Drpm=false ..
ninja
ninja install
cd ../..
rm -rf appstream-glib-appstream_glib_0_7_18
# Bubblewrap.
tar -xf bubblewrap-0.5.0.tar.xz
cd bubblewrap-0.5.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf bubblewrap-0.5.0
# xdg-dbus-proxy.
tar -xf xdg-dbus-proxy-0.1.2.tar.xz
cd xdg-dbus-proxy-0.1.2
./configure --prefix=/usr
make
make install
cd ..
rm -rf xdg-dbus-proxy-0.1.2
# Flatpak.
tar -xf flatpak-1.12.1.tar.xz
cd flatpak-1.12.1
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
flatpak remote-add flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y runtime/org.gtk.Gtk3theme.Arc-Dark/x86_64/3.22
cd ..
rm -rf flatpak-1.12.1
# libcdio.
tar -xf libcdio-2.1.0.tar.bz2
cd libcdio-2.1.0
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libcdio-2.1.0
# libcdio-paranoia.
tar -xf libcdio-paranoia-10.2+2.0.1.tar.bz2
cd libcdio-paranoia-10.2+2.0.1
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libcdio-paranoia-10.2+2.0.1
# rest.
tar -xf rest-0.8.1.tar.xz
cd rest-0.8.1
./configure --prefix=/usr --with-ca-certificates=/etc/pki/tls/certs/ca-bundle.crt
make
make install
cd ..
rm -rf rest-0.8.1
# wpebackend-fdo.
tar -xf wpebackend-fdo-1.10.0.tar.xz
cd wpebackend-fdo-1.10.0
mkdir fdo-build; cd fdo-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf wpebackend-fdo-1.10.0
# GeoClue.
tar -xf geoclue-2.5.7.tar.bz2
cd geoclue-2.5.7
mkdir geoclue-build; cd geoclue-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf geoclue-2.5.7
# gstreamer.
tar -xf gstreamer-1.18.5.tar.xz
cd gstreamer-1.18.5
mkdir gstreamer-build; cd gstreamer-build
meson --prefix=/usr --buildtype=release -Dgst_debug=false -Dpackage-origin="https://github.com/TheSonicMaster/MassOS" -Dpackage-name="GStreamer 1.18.5 MassOS" ..
ninja
ninja install
cd ../..
rm -rf gstreamer-1.18.5
# CDParanoia-III.
tar -xf cdparanoia-III-10.2.src.tgz
cd cdparanoia-III-10.2
patch -Np1 -i ../patches/cdparanoia-III-10.2-gcc_fixes-1.patch
./configure --prefix=/usr --mandir=/usr/share/man
make -j1
make -j1 install
chmod 755 /usr/lib/libcdda_*.so.0.10.2
cd ..
rm -rf cdparanoia-III-10.2
# gst-plugins-base.
tar -xf gst-plugins-base-1.18.5.tar.xz
cd gst-plugins-base-1.18.5
mkdir gstbase-build; cd gstbase-build
meson  --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/TheSonicMaster/MassOS" -Dpackage-name="GStreamer 1.18.5 MassOS" ..
ninja
ninja install
cd ../..
rm -rf gst-plugins-base-1.18.5
# mpg123.
tar -xf mpg123-1.29.0.tar.bz2
cd mpg123-1.29.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf mpg123-1.29.0
# libvpx.
tar -xf libvpx-1.10.0.tar.gz
cd libvpx-1.10.0
sed -i 's/cp -p/cp/' build/make/Makefile
mkdir libvpx-build; cd libvpx-build
../configure --prefix=/usr --enable-shared --disable-static
make
make install
cd ../..
rm -rf libvpx-1.10.0
# LAME.
tar -xf lame-3.100.tar.gz
cd lame-3.100
./configure --prefix=/usr --enable-mp3rtp --enable-nasm --disable-static
make
make pkghtmldir=/usr/share/doc/lame-3.100 install
cd ..
rm -rf lame-3.100
# Taglib.
tar -xf taglib-1.12.tar.gz
cd taglib-1.12
mkdir taglib-build; cd taglib-build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=ON -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf taglib-1.12
# gst-plugins-good.
tar -xf gst-plugins-good-1.18.5.tar.xz
cd gst-plugins-good-1.18.5
mkdir gstgood-build; cd gstgood-build
meson  --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/TheSonicMaster/MassOS" -Dpackage-name="GStreamer 1.18.5 MassOS" ..
ninja
ninja install
cd ../..
rm -rf gst-plugins-good-1.18.5
# SoundTouch.
tar -xf soundtouch-2.3.0.tar.bz2
cd soundtouch-2.3.0
./bootstrap
./configure --prefix=/usr
make
make install
cd ..
rm -rf soundtouch-2.3.0
# libdvdread.
tar -xf libdvdread-6.1.2.tar.bz2
cd libdvdread-6.1.2
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libdvdread-6.1.2
# libdvdnav.
tar -xf libdvdnav-6.1.1.tar.bz2
cd libdvdnav-6.1.1
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libdvdnav-6.1.1
# gst-plugins-bad.
tar -xf gst-plugins-bad-1.18.5.tar.xz
cd gst-plugins-bad-1.18.5
mkdir gstbad-build; cd gstbad-build
meson  --prefix=/usr --buildtype=release -Dpackage-origin="https://github.com/TheSonicMaster/MassOS" -Dpackage-name="GStreamer 1.18.5 MassOS" ..
ninja
ninja install
cd ../..
rm -rf gst-plugins-bad-1.18.5
# libcanberra.
tar -xf libcanberra-0.30.tar.xz
cd libcanberra-0.30
patch -Np1 -i ../patches/libcanberra-0.30-wayland-1.patch
./configure --prefix=/usr --disable-oss
make
make install
cd ..
rm -rf libcanberra-0.30
# WebKitGTK.
tar -xf webkitgtk-2.34.0.tar.xz
cd webkitgtk-2.34.0
mkdir webkitgtk-build; cd webkitgtk-build
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_RPATH=ON -DPORT=GTK -DLIB_INSTALL_DIR=/usr/lib -DUSE_SOUP2=ON -DUSE_LIBHYPHEN=OFF -DENABLE_GAMEPAD=OFF -DENABLE_MINIBROWSER=ON -DUSE_WOFF2=OFF -DUSE_WPE_RENDERER=ON -Wno-dev -G Ninja ..
ninja
ninja install
cd ../..
rm -rf webkitgtk-2.34.0
# gspell.
tar -xf gspell-1.9.1.tar.xz
cd gspell-1.9.1
./configure --prefix=/usr --enable-gtk-doc
make
make install
cd ..
rm -rf gspell-1.9.1
# gnome-online-accounts.
tar -xf gnome-online-accounts-3.40.0.tar.xz
cd gnome-online-accounts-3.40.0
mkdir goa-build; cd goa-build
../configure --prefix=/usr --disable-static
make
make install
cd ../..
rm -rf gnome-online-accounts-3.40.0
# libgdata.
tar -xf libgdata-0.18.1.tar.xz
cd libgdata-0.18.1
mkdir gdata-build; cd gdata-build
meson --prefix=/usr --buildtype=release -Dalways_build_tests=false ..
ninja
ninja install
cd ../..
rm -rf libgdata-0.18.1
# Gvfs.
tar -xf gvfs-1.48.1.tar.xz
cd gvfs-1.48.1
mkdir gvfs-build; cd gvfs-build
meson --prefix=/usr --buildtype=release -Dbluray=false -Dsmb=false ..
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
cd ../..
rm -rf gvfs-1.48.1
# libxfce4util.
tar -xf libxfce4util-4.16.0.tar.bz2
cd libxfce4util-4.16.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf libxfce4util-4.16.0
# xfconf.
tar -xf xfconf-4.16.0.tar.bz2
cd xfconf-4.16.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf xfconf-4.16.0
# libxfce4ui.
tar -xf libxfce4ui-4.16.1.tar.bz2
cd libxfce4ui-4.16.1
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf libxfce4ui-4.16.1
# Exo.
tar -xf exo-4.16.2.tar.bz2
cd exo-4.16.2
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf exo-4.16.2
# Garcon.
tar -xf garcon-4.16.1.tar.bz2
cd garcon-4.16.1
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf garcon-4.16.1
# Thunar.
tar -xf thunar-4.16.10.tar.bz2
cd thunar-4.16.10
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf thunar-4.16.10
# thunar-volman.
tar -xf thunar-volman-4.16.0.tar.bz2
cd thunar-volman-4.16.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf thunar-volman-4.16.0
# Tumbler.
tar -xf tumbler-4.16.0.tar.bz2
cd tumbler-4.16.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf tumbler-4.16.0
# xfce4-appfinder.
tar -xf xfce4-appfinder-4.16.1.tar.bz2
cd xfce4-appfinder-4.16.1
./configure --prefix=/usr
make
make install
cd ..
rm -rf xfce4-appfinder-4.16.1
# xfce4-panel.
tar -xf xfce4-panel-4.16.3.tar.bz2
cd xfce4-panel-4.16.3
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf xfce4-panel-4.16.3
# xfce4-power-manager.
tar -xf xfce4-power-manager-4.16.0.tar.bz2
cd xfce4-power-manager-4.16.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf xfce4-power-manager-4.16.0
# libxklavier.
tar -xf libxklavier-5.4.tar.bz2
cd libxklavier-5.4
./configure --prefix=/usr --disable-static
make
make install
cd ..
rm -rf libxklavier-5.4
# xfce4-settings.
tar -xf xfce4-settings-4.16.2.tar.bz2
cd xfce4-settings-4.16.2
./configure --prefix=/usr --sysconfdir=/etc --enable-sound-settings
make
make install
cd ..
rm -rf xfce4-settings-4.16.2
# xfdesktop.
tar -xf xfdesktop-4.16.0.tar.bz2
cd xfdesktop-4.16.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf xfdesktop-4.16.0
# xfwm4.
tar -xf xfwm4-4.16.1.tar.bz2
cd xfwm4-4.16.1
./configure --prefix=/usr
make
make install
sed -i 's/Default/Arc-Dark/' /usr/share/xfwm4/defaults
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
cd ..
rm -rf xfce4-session-4.16.0
# Parole.
tar -xf parole-4.16.0.tar.bz2
cd parole-4.16.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf parole-4.16.0
# VTE.
tar -xf vte-0.66.0.tar.gz
cd vte-0.66.0
mkdir vte-build; cd vte-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
rm -f /etc/profile.d/vte.*
cd ../..
rm -rf vte-0.66.0
# xfce4-terminal.
tar -xf xfce4-terminal-0.8.10.tar.bz2
cd xfce4-terminal-0.8.10
./configure --prefix=/usr
make
make install
cd ..
rm -rf xfce4-terminal-0.8.10
# Ristretto.
tar -xf ristretto-0.11.0.tar.bz2
cd ristretto-0.11.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf ristretto-0.11.0
# xfce4-notifyd.
tar -xf xfce4-notifyd-0.6.2.tar.bz2
cd xfce4-notifyd-0.6.2
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf xfce4-notifyd-0.6.2
# keybinder.
tar -xf keybinder-3.0-0.3.2.tar.gz
cd keybinder-3.0-0.3.2
./configure --prefix=/usr
make
make install
cd ..
rm -rf keybinder-3.0-0.3.2
# xfce4-pulseaudio-plugin.
tar -xf xfce4-pulseaudio-plugin-0.4.3.tar.bz2
cd xfce4-pulseaudio-plugin-0.4.3
./configure --prefix=/usr
make
make install
cd ..
rm -rf xfce4-pulseaudio-plugin-0.4.3
# pavucontrol.
tar -xf pavucontrol-5.0.tar.xz
cd pavucontrol-5.0
./configure --prefix=/usr
make
make install
cd ..
rm -rf pavucontrol-5.0
# Blueman.
tar -xf blueman-2.2.2.tar.xz
cd blueman-2.2.2
sed -i '/^dbusdir =/ s/sysconfdir/datadir/' data/configs/Makefile.{am,in}
./configure --prefix=/usr --sysconfdir=/etc --with-dhcp-config='/etc/dhcp/dhclient.conf'
make
make install
mv /etc/xdg/autostart/blueman.desktop /usr/share/blueman/autostart.destkop
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
cd ..
rm -rf blueman-2.2.2
# xfce4-screenshooter.
tar -xf xfce4-screenshooter-1.9.9.tar.bz2
cd xfce4-screenshooter-1.9.9
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-debug
make
make install
cd ..
rm -rf xfce4-screenshooter-1.9.9
# xfce4-taskmanager.
tar -xf xfce4-taskmanager-1.5.2.tar.bz2
cd xfce4-taskmanager-1.5.2
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-debug
make
make install
cd ..
rm -rf xfce4-taskmanager-1.5.2
# xarchiver.
tar -xf xarchiver-0.5.4.17.tar.gz
cd xarchiver-0.5.4.17
./configure  --prefix=/usr --libexecdir=/usr/lib/xfce4
make
make install
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
cd ..
rm -rf thunar-archive-plugin-0.4.0
# gtksourceview.
tar -xf gtksourceview-4.8.2.tar.xz
cd gtksourceview-4.8.2
mkdir build; cd build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf gtksourceview-4.8.2
# Mousepad.
tar -xf mousepad-0.5.7.tar.bz2
cd mousepad-0.5.7
./configure --prefix=/usr --enable-keyfile-settings
make
make install
cd ..
rm -rf mousepad-0.5.7
# galculator.
tar -xf galculator-2.1.4.tar.gz
cd galculator-2.1.4
sed -i 's/s_preferences/extern s_preferences/' src/main.c
./configure --prefix=/usr
make
make install
cd ..
rm -rf galculator-2.1.4
# Gparted.
tar -xf gparted-1.3.1.tar.gz
cd gparted-1.3.1
./configure --prefix=/usr --disable-doc --disable-static
make
make install
cd ..
rm -rf gparted-1.3.1
# mtools.
tar -xf mtools-4.0.35.tar.gz
cd mtools-4.0.35
sed -e '/^SAMPLE FILE$/s:^:# :' -i mtools.conf
./configure --prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
install -m644 mtools.conf /etc/mtools.conf
cd ..
rm -rf mtools-4.0.35
# Baobab.
tar -xf baobab-41.0.tar.xz
cd baobab-41.0
mkdir baobab-build; cd baobab-build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install
cd ../..
rm -rf baobab-41.0
# libxmlb.
tar -xf libxmlb-0.3.3.tar.gz
cd libxmlb-0.3.3
mkdir xmlb-build; cd xmlb-build
meson --prefix=/usr --buildtype=release -Dstemmer=true ..
ninja
ninja install
cd ../..
rm -rf libxmlb-0.3.3
# Gnome Software.
tar -xf gnome-software-41.0.tar.xz
cd gnome-software-41.0
mkdir gnome-software-build; cd gnome-software-build
meson --prefix=/usr --buildtype=release -Dfwupd=false -Dpackagekit=false -Dvalgrind=false ..
ninja
ninja install
cd ../..
rm -rf gnome-software-41.0
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
cd ..
rm -rf lightdm-1.30.0
# lightdm-gtk-greeter.
tar -xf lightdm-gtk-greeter-2.0.8.tar.gz
cd lightdm-gtk-greeter-2.0.8
./configure --prefix=/usr --libexecdir=/usr/lib/lightdm --sbindir=/usr/bin --sysconfdir=/etc --with-libxklavier --enable-kill-on-sigterm --disable-libido --disable-libindicator --disable-static --disable-maintainer-mode
make
make install
sed -i 's/#background=/background = \/usr\/share\/backgrounds\/xfce\/MassOS-Contemporary.png/' /etc/lightdm/lightdm-gtk-greeter.conf
systemctl enable lightdm
cd ..
rm -rf lightdm-gtk-greeter-2.0.8
# htop.
tar -xf htop-3.1.0.tar.gz
cd htop-3.1.0
autoreconf -fi
./configure --prefix=/usr --sysconfdir=/etc --enable-delayacct --enable-openvz --enable-unicode --enable-vserver
make
make install
rm -f /usr/share/applications/htop.desktop
cd ..
rm -rf htop-3.1.0
# sl.
tar -xf sl-5.02.tar.gz
cd sl-5.02
gcc -Os sl.c -o sl -s -lcurses
install -m755 sl /usr/bin/sl
install -m644 sl.1 /usr/share/man/man1/sl.1
cd ..
rm -rf sl-5.02
# cowsay.
tar -xf cowsay-3.04.tar.gz
cd rank-amateur-cowsay-cowsay-3.04
patch -Np1 -i ../patches/cowsay-3.04-prefix.patch
sed -i 's|/man/|/share/man/|' install.sh
echo "/usr" | ./install.sh
rm /usr/share/cows/mech-and-cow
cd ..
rm -rf rank-amateur-cowsay-cowsay-3.04
# figlet.
tar -xf figlet-2.2.5.tar.gz
cd figlet-2.2.5
make BINDIR=/usr/bin MANDIR=/usr/share/man DEFAULTFONTDIR=/usr/share/figlet/fonts all
make BINDIR=/usr/bin MANDIR=/usr/share/man DEFAULTFONTDIR=/usr/share/figlet/fonts install
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
cd ..
rm -rf cmatrix
# Firefox.
tar --no-same-owner -xf firefox-93.0.tar.bz2 -C /usr/lib
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
# Thunderbird.
tar --no-same-owner -xf thunderbird-91.2.0.tar.bz2 -C /usr/lib
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
# Linux Kernel.
tar -xf linux-5.14.11.tar.xz
cd linux-5.14.11
cp ../kernel-config .config
make olddefconfig
make
make INSTALL_MOD_STRIP=1 modules_install
cp arch/x86/boot/bzImage /boot/vmlinuz-5.14.11-massos
cp arch/x86/boot/bzImage /usr/lib/modules/5.14.11-massos/vmlinuz
cp System.map /boot/System.map-5.14.11-massos
cp .config /boot/config-5.14.11-massos
rm /usr/lib/modules/5.14.11-massos/{source,build}
make -s kernelrelease > version
builddir=/usr/lib/modules/5.14.11-massos/build
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
cd ..
rm -rf linux-5.14.11
# MassOS release detection utility.
gcc -Os -s massos-release.c -o massos-release
install -m755 massos-release /usr/bin/massos-release
# MassOS Backgrounds.
install -Dm644 backgrounds/* /usr/share/backgrounds/xfce
mv /usr/share/backgrounds/xfce/xfce-verticals.png /usr/share/backgrounds/xfce/xfce-verticals1.png
ln -s MassOS-Contemporary.png /usr/share/backgrounds/xfce/xfce-verticals.png
# Install Neofetch.
curl -s https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch -o /usr/bin/neofetch
chmod 755 /usr/bin/neofetch
# Uninstall Rust.
/usr/lib/rustlib/uninstall.sh
rm -rf /root/.cargo
# Move any misplaced files.
cp -r /usr/etc /
rm -rf /usr/etc
cp -r /usr/man /usr/share
rm -rf /usr/man
# Remove documentation.
rm -rf /usr/share/doc/*
rm -rf /usr/doc
# Remove temporary compiler from stage1.
find /usr -depth -name $(uname -m)-massos-linux-gnu\* | xargs rm -rf
# Remove libtool archives.
find /usr/lib /usr/libexec -name \*.la -delete
# Remove any temporary files.
rm -rf /tmp/*
# As a finishing touch, run ldconfig.
ldconfig
# Clean sources directory and self destruct.
cd ..
rm -rf /sources
