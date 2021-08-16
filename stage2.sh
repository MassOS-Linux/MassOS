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
export MASSOS=$PWD/massos-rootfs
# Ensure the MassOS environment is owned by root.
chown -R root:root $MASSOS
# Create pseudo-filesystem mount directories.
mkdir -p $MASSOS/{dev,proc,sys,run}
# Initialise /dev/console and /dev/null.
mknod -m 600 $MASSOS/dev/console c 5 1
mknod -m 666 $MASSOS/dev/null c 1 3
# Chroot into the MassOS environment and continue the build.
utils/mass-chroot massos-rootfs /sources/build-system.sh
# Finish the MassOS system.
outfile="massos-$(cat utils/massos-release)-rootfs-x86_64.tar.xz"
echo "Creating $outfile..."
cd $MASSOS
tar -cJpf ../$outfile *
cd ..
echo "$outfile created successfully."
# Clean up.
rm -rf $MASSOS
