#!/bin/bash
#
# This script downloads the sources necessary for building a MassOS system.
#
# Create directory where the sources will be saved.
mkdir -p sources && cd sources
# Download sources using source-urls as a wget input file.
wget -nc --continue --input-file=../source-urls
STATUS=$?
# Ensure everything downloaded successfully.
if [ $STATUS -ne 0 ]; then
  echo -e "\nOne or more download(s) failed." >&2
  echo "Consider checking the above output, or try to re-run this command." >&2
  exit $STATUS
else
  echo -e "\nGood, it looks like everything downloaded successfully!"
  echo "Now you can begin the build of MassOS by running './stage1.sh'."
fi
