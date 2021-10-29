#!/bin/bash
#
# Build the environment which will be used to build the full OS later.
set -e
# Disabling hashing is useful so the newly built tools are detected.
set +h
# Ensure retrieve-sources.sh has been run first.
if [ ! -d sources ]; then
  echo "Error: You must run retrieve-sources.sh first!" >&2
  exit 1
fi
# Setup the environment.
MASSOS=$PWD/massos-rootfs
MASSOS_TGT=x86_64-massos-linux-gnu
PATH=$MASSOS/tools/bin:$PATH
SRC=$MASSOS/sources
CONFIG_SITE=$MASSOS/usr/share/config.site
export MASSOS MASSOS_TGT PATH SRC CONFIG_SITE
# Build in parallel using all available CPU cores.
export MAKEFLAGS="-j$(nproc)"
# Setup the basic filesystem structure.
mkdir -p $MASSOS/{etc,var}
mkdir -p $MASSOS/usr/{bin,lib,sbin}
for i in bin lib sbin; do
  ln -s usr/$i $MASSOS/$i
done
mkdir $MASSOS/lib64
ln -s lib $MASSOS/usr/lib64
# Directory where source tarballs will be placed while building.
# Temporary toolchain directory.
mkdir $MASSOS/tools
# Move sources into the temporary environment.
mv sources $SRC
# Copy patches into the temporary environment.
mkdir -p $SRC/patches
cp patches/* $SRC/patches
# Copy systemd units into the temporary environment.
cp -r utils/systemd-units $SRC
# Binutils (Pass 1).
cd $SRC
tar -xf binutils-2.37.tar.xz
cd binutils-2.37
mkdir build; cd build
../configure --prefix=$MASSOS/tools --with-sysroot=$MASSOS --target=$MASSOS_TGT --disable-nls --disable-werror
make
make -j1 install
cd ../..
rm -rf binutils-2.37
# GCC (Pass 1).
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
tar -xf ../gmp-6.2.1.tar.xz
mv gmp-6.2.1 gmp
tar -xf ../mpfr-4.1.0.tar.xz
mv mpfr-4.1.0 mpfr
tar -xf ../mpc-1.2.1.tar.gz
mv mpc-1.2.1 mpc
mkdir build; cd build
../configure --target=$MASSOS_TGT --prefix=$MASSOS/tools --with-glibc-version=2.11 --with-sysroot=$MASSOS --with-newlib --without-headers --enable-initfini-array --disable-nls --disable-shared --disable-multilib --disable-decimal-float --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
make
make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($MASSOS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
cd ..
rm -rf gcc-11.2.0
# Linux API Headers.
tar -xf linux-5.14.15.tar.xz
cd linux-5.14.15
make headers
find usr/include -name '.*' -delete
rm usr/include/Makefile
cp -r usr/include $MASSOS/usr
cd ..
rm -rf linux-5.14.15
# Glibc
tar -xf glibc-2.34.tar.xz
cd glibc-2.34
ln -sf ../lib/ld-linux-x86-64.so.2 $MASSOS/lib64
ln -sf ../lib/ld-linux-x86-64.so.2 $MASSOS/lib64/ld-lsb-x86-64.so.3
patch -Np1 -i ../patches/glibc-2.34-fhs-1.patch
mkdir build; cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host=$MASSOS_TGT --build=$(../scripts/config.guess) --enable-kernel=3.2 --with-headers=$MASSOS/usr/include libc_cv_slibdir=/usr/lib
make
make DESTDIR=$MASSOS install
sed '/RTLDLIST=/s@/usr@@g' -i $MASSOS/usr/bin/ldd
$MASSOS/tools/libexec/gcc/$MASSOS_TGT/*/install-tools/mkheaders
cd ../..
rm -rf glibc-2.34
# libstdc++ from GCC (Pass 1).
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
mkdir build; cd build
../libstdc++-v3/configure --host=$MASSOS_TGT --build=$(../config.guess) --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch --with-gxx-include-dir=/tools/$MASSOS_TGT/include/c++/$($MASSOS_TGT-gcc --version | head -n1 | cut -d')' -f2 | sed 's/ //')
make
make DESTDIR=$MASSOS install
cd ../..
rm -rf gcc-11.2.0
# Compiler flags for MassOS. We prefer to optimise for size.
CFLAGS="-w -Os -pipe"
CXXFLAGS="-w -Os -pipe"
export CFLAGS CXXFLAGS
# m4.
tar -xf m4-1.4.19.tar.xz
cd m4-1.4.19
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$MASSOS install
cd ..
rm -rf m4-1.4.19
# Ncurses.
tar -xf ncurses-6.2.tar.gz
cd ncurses-6.2
sed -i s/mawk// configure
mkdir build; cd build
../configure
make -C include
make -C progs tic
cd ..
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(./config.guess) --mandir=/usr/share/man --with-manpage-format=normal --with-shared --without-debug --without-ada --without-normal --enable-widec
make
make DESTDIR=$MASSOS TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > $MASSOS/usr/lib/libncurses.so
cd ..
rm -rf ncurses-6.2
# Bash.
tar -xf bash-5.1.8.tar.gz
cd bash-5.1.8
./configure --prefix=/usr --build=$(support/config.guess) --host=$MASSOS_TGT --without-bash-malloc
make
make DESTDIR=$MASSOS install
ln -s bash $MASSOS/bin/sh
cd ..
rm -rf bash-5.1.8
# Coreutils.
tar -xf coreutils-9.0.tar.xz
cd coreutils-9.0
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(build-aux/config.guess) --enable-install-program=hostname --enable-no-install-program=kill,uptime
make
make DESTDIR=$MASSOS install
mv $MASSOS/usr/bin/chroot $MASSOS/usr/sbin
mkdir -p $MASSOS/usr/share/man/man8
mv $MASSOS/usr/share/man/man1/chroot.1 $MASSOS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' $MASSOS/usr/share/man/man8/chroot.8
cd ..
rm -rf coreutils-9.0
# Diffutils.
tar -xf diffutils-3.8.tar.xz
cd diffutils-3.8
./configure --prefix=/usr --host=$MASSOS_TGT
make
make DESTDIR=$MASSOS install
cd ..
rm -rf diffutils-3.8
# File
tar -xf file-5.41.tar.gz
cd file-5.41
mkdir build; cd build
../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
make
cd ..
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$MASSOS install
cd ..
rm -rf file-5.41
# Findutils.
tar -xf findutils-4.8.0.tar.xz
cd findutils-4.8.0
./configure --prefix=/usr --localstatedir=/var/lib/locate --host=$MASSOS_TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$MASSOS install
cd ..
rm -rf findutils-4.8.0
# Gawk.
tar -xf gawk-5.1.1.tar.xz
cd gawk-5.1.1
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(./config.guess)
make
make DESTDIR=$MASSOS install
cd ..
rm -rf gawk-5.1.1
# Grep.
tar -xf grep-3.7.tar.xz
cd grep-3.7
./configure --prefix=/usr --host=$MASSOS_TGT
make
make DESTDIR=$MASSOS install
cd ..
rm -rf grep-3.7
# Gzip.
tar -xf gzip-1.11.tar.xz
cd gzip-1.11
./configure --prefix=/usr --host=$MASSOS_TGT
make
make DESTDIR=$MASSOS install
cd ..
rm -rf gzip-1.11
# Make.
tar -xf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr --without-guile --host=$MASSOS_TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$MASSOS install
cd ..
rm -rf make-4.3
# Patch.
tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$MASSOS install
cd ..
rm -rf patch-2.7.6
# Sed.
tar -xf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr --host=$MASSOS_TGT
make
make DESTDIR=$MASSOS install
cd ..
rm -rf sed-4.8
# Tar.
tar -xf tar-1.34.tar.xz
cd tar-1.34
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(build-aux/config.guess) --program-prefix=g
make
make DESTDIR=$MASSOS install
ln -sf gtar $MASSOS/usr/bin/tar
cd ..
rm -rf tar-1.34
# XZ.
tar -xf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr --host=$MASSOS_TGT --build=$(build-aux/config.guess) --disable-static --docdir=/usr/share/doc/xz-5.2.5
make
make DESTDIR=$MASSOS install
cd ..
rm -rf xz-5.2.5
# Unset compiler flags for building criticial toolchain tools.
unset CFLAGS CXXFLAGS
# Binutils (Pass 2).
tar -xf binutils-2.37.tar.xz
cd binutils-2.37
mkdir build; cd build
../configure --prefix=/usr --build=$(../config.guess) --host=$MASSOS_TGT --disable-nls --enable-shared --disable-werror --enable-64-bit-bfd
make
make -j1 DESTDIR=$MASSOS install
install -m755 libctf/.libs/libctf.so.0.0.0 $MASSOS/usr/lib
cd ../..
rm -rf binutils-2.37
# GCC (Pass 2).
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
tar -xf ../gmp-6.2.1.tar.xz
mv gmp-6.2.1 gmp
tar -xf ../mpfr-4.1.0.tar.xz
mv mpfr-4.1.0 mpfr
tar -xf ../mpc-1.2.1.tar.gz
mv mpc-1.2.1 mpc
mkdir build; cd build
mkdir -p $MASSOS_TGT/libgcc
ln -s ../../../libgcc/gthr-posix.h $MASSOS_TGT/libgcc/gthr-default.h
../configure --build=$(../config.guess) --host=$MASSOS_TGT --prefix=/usr CC_FOR_TARGET=$MASSOS_TGT-gcc --with-build-sysroot=$MASSOS --enable-initfini-array --disable-nls --disable-multilib --disable-decimal-float --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
make
make DESTDIR=$MASSOS install
ln -s gcc $MASSOS/usr/bin/cc
cd ../..
rm -rf gcc-11.2.0
cd ../..
# Copy extra utilities and configuration files into the environment.
cp utils/{adduser,mass-chroot,mkinitramfs,mklocales} $MASSOS/usr/sbin
cp utils/{bashrc,dircolors,fstab,group,hostname,hosts,inputrc,locale.conf,locales,lsb-release,massos-release,os-release,passwd,profile,resolv.conf,shells,vconsole.conf} $MASSOS/etc
cp utils/{busybox,kernel}-config $SRC
cp utils/massos-release.c $SRC
cp utils/plymouth.png $SRC
cp -r utils/skel $MASSOS/etc
mkdir -p $MASSOS/etc/profile.d
cp utils/*.sh $MASSOS/etc/profile.d
cp -r backgrounds $SRC
cp build-system.sh $SRC
echo -e "\nThe bootstrap system was built successfully."
echo "To build the full MassOS system, now run './stage2.sh' AS ROOT."
