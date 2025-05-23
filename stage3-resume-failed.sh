#!/bin/bash
#
# shellcheck disable=SC2035,SC2046,SC2086
#
# Resume from a failure in the stage 3 (desktop environment) build process.
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
# Important verification message.
if [ "$2" != "CONFIRM_STAGE3_RESUME=YES" ]; then
  echo "Please edit 'massos-rootfs/sources/build-stage3.sh' as root and" >&2
  echo "remove lines 13 up to where your build failed. Otherwise, it will" >&2
  echo "try to rebuild the whole system from the start, which WILL cause" >&2
  echo "issues and inconsistencies if the system is already part-built." >&2
  echo -e "\nOnce you've done that, re-run this script like this:" >&2
  echo -e "\n$(basename $0) $1 CONFIRM_STAGE3_RESUME=YES" >&2
  exit 1
fi
# Put Stage 3 files into the system.
echo "Trying to resume Stage 3 build for '$1'..."
# Re-enter the chroot and continue the build.
utils/programs/mass-chroot "$MASSOS" /root/mbs/build-stage3.sh
# Put in finalize.sh and finish the build.
echo "Finalizing the build..."
cp finalize.sh "$MASSOS"/root/mbs
utils/programs/mass-chroot "$MASSOS" /root/mbs/finalize.sh
# Install preupgrade and postupgrade.
cp utils/{pre,post}upgrade "$MASSOS"/tmp
# Install Live CD cleanup script for osinstallgui.
install -t "$MASSOS"/tmp -m755 utils/livecd-cleanup.sh
# Strip executables and libraries to free up space.
printf "Stripping binaries and libraries... "
find "$MASSOS"/usr/{bin,lib,libexec,sbin} -type f ! -name \*.a ! -name \*.o ! -name \*.mod ! -name \*.module -exec strip --strip-unneeded {} ';' &>/dev/null || true
find "$MASSOS"/usr/lib -type f \( -name \*.a -o -name \*.o -o -name \*.mod -o -name \*.module \) -exec strip --strip-debug {} ';' &>/dev/null || true
echo "Done!"
# Finish the MassOS system.
outfile="massos-$(cat "$MASSOS"/etc/massos-release)-rootfs-x86_64-$1.tar"
printf "Creating %s..." "$outfile"
cd "$MASSOS"
tar -cpf ../"$outfile" *
cd ..
echo "Done!"
echo "Compressing $outfile with ZSTD (using $(nproc) threads)..."
zstd --ultra -22 -T$(nproc) --rm "$outfile"
echo "Successfully created $outfile.zst."
b2sum "$outfile.zst" > "$outfile.zst.b2"
echo "Wrote Blake-2 checksum to $outfile.zst.b2."
# Clean up.
rm -rf "$MASSOS"
# Finishing message.
echo
echo "We know it took time, but the build has finally finished successfully!"
echo "If you want to create a Live ISO file for your build, use the script"
echo "'./create-livecd.sh'."
# Send a notification to the system if supported.
if notify-send --version &>/dev/null; then
  notify-send -i "$PWD"/logo/massos-logo.png "MassOS Build System" "The Stage 3 build has finished successfully." &>/dev/null || true
fi
