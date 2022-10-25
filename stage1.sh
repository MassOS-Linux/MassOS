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
# Starting message.
echo "Starting Stage 1 Build..."
# Setup the environment.
MASSOS="$PWD"/massos-rootfs
PATH="$MASSOS"/tools/bin:$PATH
SRC="$MASSOS"/sources
export MASSOS MASSOS_TARGET PATH SRC
# Build in parallel using all available CPU cores.
export MAKEFLAGS="-j$(nproc)"
# Compiler flags for MassOS. We prefer to optimise for size.
CFLAGS="-Os -pipe"
CXXFLAGS="-Os -pipe"
CPPFLAGS=""
LDFLAGS=""
export CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
# Setup the basic filesystem structure.
mkdir -p "$MASSOS"/{etc,var}
mkdir -p "$MASSOS"/usr/{bin,lib,sbin}
# Ensure the filesystem structure is unified.
ln -sf usr/bin "$MASSOS"/bin
ln -sf usr/lib "$MASSOS"/lib
ln -sf usr/sbin "$MASSOS"/sbin
ln -sf lib "$MASSOS"/usr/lib64
ln -sf usr/lib "$MASSOS"/lib64
# Directory where source tarballs will be placed while building.
# Temporary toolchain directory.
mkdir "$MASSOS"/tools
# Move sources into the temporary environment.
mv sources "$SRC"
# Copy patches into the temporary environment.
mkdir -p "$SRC"/patches
cp patches/* "$SRC"/patches
# Copy systemd units into the temporary environment.
cp -r utils/systemd-units "$SRC"
# Change to the sources directory.
cd "$SRC"
# Binutils (Initial build for bootstrapping).
tar -xf binutils-2.39.tar.xz
cd binutils-2.39
mkdir build; cd build
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix="$MASSOS"/tools --with-sysroot="$MASSOS" --target=x86_64-stage1-linux-gnu --with-pkgversion="MassOS Binutils 2.39" --enable-relro --disable-gprofng --disable-nls --disable-werror
make
make -j1 install
cd ../..
rm -rf binutils-2.39
# GCC (Initial build for bootstrapping).
tar -xf gcc-12.2.0.tar.xz
cd gcc-12.2.0
mkdir -p gmp mpfr mpc isl
tar -xf ../gmp-6.2.1.tar.xz -C gmp --strip-components=1
tar -xf ../mpfr-4.1.0.tar.xz -C mpfr --strip-components=1
tar -xf ../mpc-1.2.1.tar.gz -C mpc --strip-components=1
tar -xf ../isl-0.25.tar.xz -C isl --strip-components=1
sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64
mkdir build; cd build
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix="$MASSOS"/tools --target=x86_64-stage1-linux-gnu --enable-languages=c,c++ --with-pkgversion="MassOS GCC 12.2.0" --with-glibc-version=2.36 --with-sysroot="$MASSOS" --with-newlib --without-headers --enable-default-ssp --enable-linker-build-id --disable-decimal-float --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libstdcxx --disable-libvtv --disable-multilib --disable-nls --disable-shared --disable-threads
make
make install
cat ../gcc/{limitx,glimits,limity}.h > "$MASSOS"/tools/lib/gcc/x86_64-stage1-linux-gnu/12.2.0/install-tools/include/limits.h
cd ../..
rm -rf gcc-12.2.0
# Linux API Headers.
tar -xf linux-6.0.3.tar.xz
cd linux-6.0.3
make headers
find usr/include -name '.*' -delete
rm -f usr/include/Makefile
cp -r usr/include "$MASSOS"/usr
cd ..
rm -rf linux-6.0.3
# Glibc
tar -xf glibc-2.36.tar.xz
cd glibc-2.36
patch -Np1 -i ../patches/glibc-2.36-multiplefixes.patch
mkdir build; cd build
echo "rootsbindir=/usr/sbin" > configparms
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../scripts/config.guess) --enable-kernel=3.2 --disable-default-pie --with-headers="$MASSOS"/usr/include libc_cv_slibdir=/usr/lib
make
make DESTDIR="$MASSOS" install
ln -sf ld-linux-x86-64.so.2 "$MASSOS"/usr/lib/ld-lsb-x86-64.so.3
sed '/RTLDLIST=/s@/usr@@g' -i "$MASSOS"/usr/bin/ldd
"$MASSOS"/tools/libexec/gcc/x86_64-stage1-linux-gnu/$(x86_64-stage1-linux-gnu-gcc -dumpversion)/install-tools/mkheaders
cd ../..
rm -rf glibc-2.36
# libstdc++ from GCC (Could not be built with bootstrap GCC).
tar -xf gcc-12.2.0.tar.xz
cd gcc-12.2.0
mkdir build; cd build
CFLAGS="-O2" CXXFLAGS="-O2" ../libstdc++-v3/configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../config.guess) --disable-multilib --disable-nls --disable-libstdcxx-pch --with-gxx-include-dir=/tools/x86_64-stage1-linux-gnu/include/c++/$(x86_64-stage1-linux-gnu-gcc -dumpversion)
make
make DESTDIR="$MASSOS" install
cd ../..
rm -rf gcc-12.2.0
# Ncurses.
tar -xf ncurses-6.3.tar.gz
cd ncurses-6.3
sed -i 's/mawk//' configure
mkdir build; cd build
../configure
make -C include
make -C progs tic
cd ..
./configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(./config.guess) --mandir=/usr/share/man --with-cxx-shared --with-manpage-format=normal --with-shared --without-ada --without-debug --without-normal --enable-widec --disable-stripping
make
make DESTDIR="$MASSOS" TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > "$MASSOS"/usr/lib/libncurses.so
cd ..
rm -rf ncurses-6.3
# Bash.
tar -xf bash-5.2.tar.gz
cd bash-5.2
patch -Np0 -i ../patches/bash-5.2-upstreamfix.patch
./configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(support/config.guess) --without-bash-malloc
make
make DESTDIR="$MASSOS" install
ln -sf bash "$MASSOS"/bin/sh
cd ..
rm -rf bash-5.2
# Binutils (For stage 2, built using our new bootstrap toolchain).
tar -xf binutils-2.39.tar.xz
cd binutils-2.39
sed -i '6009s/$add_dir//' ltmain.sh
mkdir build; cd build
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../config.guess) --with-pkgversion="MassOS Binutils 2.39" --enable-relro --enable-shared --disable-gprofng --disable-nls --disable-werror
make
make -j1 DESTDIR="$MASSOS" install
cd ../..
rm -rf binutils-2.39
# GCC (For stage 2, built using our new bootstrap toolchain).
tar -xf gcc-12.2.0.tar.xz
cd gcc-12.2.0
mkdir -p gmp mpfr mpc isl
tar -xf ../gmp-6.2.1.tar.xz -C gmp --strip-components=1
tar -xf ../mpfr-4.1.0.tar.xz -C mpfr --strip-components=1
tar -xf ../mpc-1.2.1.tar.gz -C mpc --strip-components=1
tar -xf ../isl-0.25.tar.xz -C isl --strip-components=1
sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64
sed -i '/thread_header =/s/@.*@/gthr-posix.h/' libgcc/Makefile.in libstdc++-v3/include/Makefile.in
mkdir build; cd build
CFLAGS="-O2" CXXFLAGS="-O2" ../configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../config.guess) --target=x86_64-stage1-linux-gnu LDFLAGS_FOR_TARGET=-L"$PWD/x86_64-stage1-linux-gnu/libgcc" --with-build-sysroot="$MASSOS" --enable-languages=c,c++ --with-pkgversion="MassOS GCC 12.2.0" --enable-default-ssp --enable-initfini-array --enable-linker-build-id --disable-nls --disable-multilib --disable-decimal-float --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv
make
make DESTDIR="$MASSOS" install
ln -sf gcc "$MASSOS"/usr/bin/cc
cd ../..
rm -rf gcc-12.2.0
# Install upgrade-toolset to provide basic utilities for the start of stage 2.
mv "${MASSOS}"/usr/bin/bash{,.save}
tar -xf upgrade-toolset-20221015-x86_64.tar.xz -C "$MASSOS"/usr/bin --strip-components=1
mv "${MASSOS}"/usr/bin/bash{.save,}
rm -f "$MASSOS"/usr/bin/LICENSE*
cd ../..
# Remove bootstrap toolchain directory.
rm -rf "$MASSOS"/tools
# Remove temporary system documentation.
rm -rf "$MASSOS"/usr/share/{info,man,doc}/*
# Copy extra utilities and configuration files into the environment.
cp -r utils/etc/* "$MASSOS"/etc
cp utils/massos-release "$MASSOS"/etc
cp utils/programs/{adduser,mass-chroot,mkinitramfs,mklocales,set-default-tar} "$MASSOS"/usr/sbin
cp utils/programs/{un,}zman "$MASSOS"/usr/bin
cp utils/programs/massos-release.c "$SRC"
cp -r utils/build-configs/* "$SRC"
cp -r logo/* "$SRC"
cp utils/builtins "$SRC"
cp -r utils/extra-package-licenses "$SRC"
cp -r backgrounds "$SRC"
cp -r utils/man "$SRC"
cp LICENSE "$SRC"
cp build-system.sh build.env "$SRC"
echo -e "\nThe Stage 1 bootstrap system was built successfully."
echo "To build the full MassOS system, now run './stage2.sh' AS ROOT."
