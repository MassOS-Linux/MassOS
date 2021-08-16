#!/bin/bash
#
# Finish the MassOS system and create an output tarball.
set -e
# Ensure we're running as root.
if [ $EUID -ne 0 ]; then
  echo "Error: Must be run as root." >&2
  exit 1
fi
# 
