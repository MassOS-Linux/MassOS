#!/bin/bash
#
# Prepare the environment for building the full MassOS system.
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
  echo "Error: You must run stage1.sh first!" >&2
  exit 1
fi
# Ensure the MassOS environment is owned by root.
chown -R root:root "$MASSOS"
# Create pseudo-filesystem mount directories.
mkdir -p "$MASSOS"/{dev,proc,sys,run}
# Initialise /dev/console and /dev/null.
mknod -m 600 "$MASSOS"/dev/console c 5 1
mknod -m 666 "$MASSOS"/dev/null c 1 3
# Chroot into the MassOS environment and continue the build.
utils/programs/mass-chroot "$MASSOS" /sources/build-system.sh
# Strip executables and libraries to free up space.
printf "Stripping binaries... "
find "$MASSOS"/usr/{bin,libexec,sbin} -type f -exec strip --strip-all {} ';' &> /dev/null || true
echo "Done!"
printf "Stripping libraries... "
find "$MASSOS"/usr/lib -type f -name \*.a -exec strip --strip-debug {} ';' &> /dev/null || true
find "$MASSOS"/usr/lib -type f -name \*.so\* -exec strip --strip-unneeded {} ';' &> /dev/null || true
echo "Done!"
# Finish the MassOS system.
outfile="massos-$(cat utils/massos-release)-rootfs-x86_64.tar"
printf "Creating $outfile... "
cd "$MASSOS"
tar -cpf ../"$outfile" *
cd ..
echo "Done!"
echo "Compressing $outfile with XZ (using $(nproc) threads)..."
xz -v --threads=$(nproc) "$outfile"
echo "Successfully created $outfile.xz."
printf "SHA256 checksum: "
sha256sum $outfile.xz | sed "s/  $outfile.xz//"
# Clean up.
rm -rf $MASSOS
