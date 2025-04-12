#!/bin/bash
#
# This script verifies the sources downloaded by 'retrieve-sources.sh'.
# MassOS now uses Blake-2 (b2) checksums, so the 'b2sum' program is required.
#
# Cannot verify anything if the sources directory is missing.
if [ ! -d sources ]; then
  echo "Error: You must run 'retrieve-sources.sh' first." >&2
  exit 1
fi
# Change into the sources directory.
cd sources
# Run b2sum on all downloaded files.
b2sum -c ../source-urls.b2
STATUS=$?
# Ensure everything verified successfully.
if [ $STATUS -ne 0 ]; then
  echo -e "\nOne or file(s) failed to verify successfully." >&2
  echo "Check the above output to determine which one. Then, modify its" >&2
  echo "URL in 'source-urls', AND/OR its checksum in 'source-urls.b2'." >&2
  exit $STATUS
else
  echo -e "\nGood, it looks like everything verified successfully!"
  echo "You can now begin the build of MassOS by running './stage1.sh'."
fi
