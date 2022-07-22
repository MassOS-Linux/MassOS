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
# Finishing message.
echo
echo "Stage 2 build completed successfully."
echo "You must now run stage3.sh and pass a supported desktop environment as"
echo "an argument. See 'stage3/README' for more information."
