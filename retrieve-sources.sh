#!/bin/bash
#
# This script downloads the sources necessary for building a MassOS system.
#
# Create directory where the sources will be saved, and change to it.
mkdir -p sources
pushd sources >/dev/null || true
# Download sources using source-urls as a wget input file.
# We should NOT need to use a custom user agent, but we now do thanks to Anubis
# (on nearly EVERY SINGLE PROJECT's website/server) INCORRECTLY treating wget
# as an AI scraper, and trying to serve it a challenge which it can't complete
# because OBVIOUSLY command line downloaders do NOT have JavaScript support.
# This causes downloads to "appear" to succeed, but in fact downloads an HTML
# document (the Anubis challenge page) masqueraded as if it were a tarball. If
# it wants to gaslight us, we will, WITHOUT HESITATION, gaslight it back.
wget -nc --continue --no-check-certificate --user-agent="Git/2.55.0" --input-file=../source-urls
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
