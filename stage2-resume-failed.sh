#!/bin/bash
#
# Try to resume a failed stage2 build.
set -e
# Ensure we're running as root.
if [ $EUID -ne 0 ]; then
  echo "Error: Must be run as root." >&2
  exit 1
fi
# Important verification message.
if [ "$1" != "CONFIRM_STAGE2_RESUME=YES" ]; then
  echo "Please edit 'massos-rootfs/sources/build-system.sh' as root and" >&2
  echo "remove lines 39 up to where your build failed. Otherwise, it will" >&2
  echo "try to rebuild the whole system from the start, which WILL cause" >&2
  echo "issues if the system is already part-built." >&2
  echo -e "\nOnce you've done that, re-run this script like this:" >&2
  echo -e "\n$0 CONFIRM_STAGE2_RESUME=YES" >&2
  exit 1
fi
# Setup the environment.
export MASSOS="$PWD"/massos-rootfs
# Ensure stage1 has been run first.
if [ ! -d "$MASSOS" ]; then
  echo "Error: You must run stage1.sh first!" >&2
  exit 1
fi
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
