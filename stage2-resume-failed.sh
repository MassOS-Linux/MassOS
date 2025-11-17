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
  echo "remove lines 26 up to where your build failed. Otherwise, it will" >&2
  echo "try to rebuild the whole system from the start, which WILL cause" >&2
  echo "issues and inconsistencies if the system is already part-built." >&2
  echo -e "\nOnce you've done that, re-run this script like this:" >&2
  echo -e "\n$(basename $0) CONFIRM_STAGE2_RESUME=YES" >&2
  exit 1
fi
# Setup the environment.
export MASSOS="$PWD"/massos-rootfs
# Ensure stage1 has been run first.
if [ ! -e "$MASSOS"/root/mbs/build-system.sh ]; then
  echo "Error: You must run stage1.sh first!" >&2
  exit 1
fi
# Chroot into the MassOS environment and continue the build.
utils/programs/mass-chroot "$MASSOS" /root/mbs/build-system.sh
# Sync here for redundancy purposes.
sync
# Finishing message.
echo
echo "Stage 2 build completed successfully."
echo "You must now run stage3.sh and pass a supported desktop environment as"
echo "an argument. See 'stage3/README' for more information."
# Send a notification to the system if supported.
if notify-send --version &>/dev/null; then
  notify-send -i "$PWD"/logo/massos-logo-circlecropped.png "MassOS Build System" "The Stage 2 build has finished successfully." &>/dev/null || true
fi
