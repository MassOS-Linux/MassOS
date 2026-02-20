#!/bin/bash
#
# This script downloads the sources necessary for building a MassOS system.
#
# Create directory where the sources will be saved, and change to it.
mkdir -p sources
pushd sources >/dev/null || true
# Download sources using source-urls as a wget input file.
wget -nc --continue --no-check-certificate --input-file=../source-urls
STATUS=$?
# Return out of the sources directory.
popd >/dev/null || true
# Ensure everything downloaded successfully.
if [ $STATUS -ne 0 ]; then
  echo -e "\nOne or more download(s) failed." >&2
  echo "Consider checking the above output, or try to re-run this command." >&2
  exit $STATUS
else
  echo -e "\nGood, it looks like everything downloaded successfully!"
  echo "You can verify the downloads by running './verify-sources.sh'."
  echo "Then you can begin the build of MassOS by running './stage1.sh'."
fi
