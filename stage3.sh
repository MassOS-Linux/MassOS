#!/bin/bash
#
# Prepare the environment for building a desktop environment.
set -e
# Ensure we're running as root.
if [ $EUID -ne 0 ]; then
  echo "Error: Must be run as root." >&2
  exit 1
fi
# Setup the environment.
export MASSOS="$PWD"/massos-rootfs
# Ensure stage1 has been run first.
if [ ! -d "$MASSOS" ]; then
  echo "Error: You must run stage1.sh and stage2.sh first!" >&2
  exit 1
fi
# Ensure the specified desktop environment is valid.
if [ -z "$1" ]; then
  echo "Error: Specify the desktop environment ('stage3/README' for info)." >&2
  exit 1
fi
if [ ! -d "stage3/$1" ]; then
  echo "Error: '$1' is not a valid or supported desktop environment." >&2
  echo "The desktop environment must have a directory in 'stage3/'." >&2
  echo "Alternatively, pass 'nodesktop' if you want a core only build." >&2
  echo "See 'stage3/README' for more information." >&2
  exit 1
fi
if [ ! -e "stage3/$1/stage3-$1.sh" ]; then
  echo "Stage 3 directory for '$1' was found, but there is no Stage 3" >&2
  echo "build script inside it." >&2
  exit 1
fi
if [ ! -e "stage3/$1/source-urls" ]; then
  echo "Stage 3 directory and built script for '$1' was found, but there" >&2
  echo "is no source-urls file." >&2
  exit 1
fi
if [ "$1" != "nodesktop" ] && [ ! -e "stage3/$1/builtins" ]; then
  echo "Stage 3 directory and build script for '$1' was found, but there" >&2
  echo "is no builtins file." >&2
  exit 1
fi
# Download source URls for Stage 3.
echo "Downloading sources for '$1' (Stage 3)..."
mkdir -p stage3/sources; cd stage3/sources
set +e
wget -nc --continue --input-file=../"$1"/source-urls
STATUS=$?
# Ensure everything downloaded successfully.
if [ $STATUS -ne 0 ]; then
  echo -e "\nOne or more Stage 3 source download(s) failed." >&2
  echo "Consider checking the above output and try re-running '$0 $1'." >&2
  exit $STATUS
fi
set -e
cd ../..

# Put Stage 3 files into the system.
echo "Starting Stage 3 build for '$1'..."
## Build script, sources and patches.
mv stage3/sources "$MASSOS"/
cp stage3/"$1"/stage3-"$1".sh "$MASSOS"/sources/build-stage3.sh
if [ -d stage3/"$1"/patches ]; then
  cp -r stage3/"$1"/patches "$MASSOS"/sources/patches
fi
## Builtins.
if [ -e stage3/"$1"/builtins ]; then
  install -Dm644 stage3/"$1"/builtins "$MASSOS"/usr/share/massos/builtins.d/"$1"
fi
## /etc/skel, if present.
if [ -d stage3/"$1"/skel ]; then
  cp -r stage3/"$1"/skel/. "$MASSOS"/etc/skel/.
  chown -R root:root "$MASSOS"/etc/skel
fi
## systemd units.
if [ -d stage3/"$1"/systemd-units ]; then
  cp -r stage3/"$1"/systemd-units/* "$MASSOS"/usr/lib/systemd/system
  chown -R root:root "$MASSOS"/usr/lib/systemd/system
fi
# Re-enter the chroot and continue the build.
utils/programs/mass-chroot "$MASSOS" /sources/build-stage3.sh
# Put in finalize.sh and finish the build.
echo "Finalizing the build..."
cp finalize.sh "$MASSOS"/sources
utils/programs/mass-chroot "$MASSOS" /sources/finalize.sh
# Install preupgrade and postupgrade.
cp utils/{pre,post}upgrade "$MASSOS"/tmp
# Strip executables and libraries to free up space.
printf "Stripping binaries... "
find "$MASSOS"/usr/{bin,libexec,sbin} -type f -exec strip --strip-all {} ';' &> /dev/null || true
echo "Done!"
printf "Stripping libraries... "
find "$MASSOS"/usr/lib -type f -name \*.a -or -name \*.o -exec strip --strip-debug {} ';' &> /dev/null || true
find "$MASSOS"/usr/lib -type f -name \*.so\* -exec strip --strip-unneeded {} ';' &> /dev/null || true
echo "Done!"
# Finish the MassOS system.
outfile="massos-$(cat utils/massos-release)-rootfs-x86_64-$1.tar"
printf "Creating $outfile... "
cd "$MASSOS"
tar -cpf ../"$outfile" *
cd ..
echo "Done!"
echo "Compressing $outfile with XZ (using $(nproc) threads)..."
xz -v --threads=$(nproc) "$outfile"
echo "Successfully created $outfile.xz."
printf "SHA256 checksum for this build: "
sha256sum $outfile.xz | sed "s/  $outfile.xz//"
# Clean up.
rm -rf "$MASSOS"
# Finishing message.
echo
echo "We know it took time, but the build has finally finished successfully!"
echo "If you want to create a Live ISO file for your build, check out the"
echo "scripts at <https://github.com/MassOS-Linux/livecd-installer>."
