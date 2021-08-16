#!/bin/bash
#
# This script downloads the sources necessary for building a MassOS system.
#
# Exit on error.
set -e
# Create directory where the sources will be saved.
mkdir -p sources && cd sources
# Download sources using source-urls as a wget input file.
wget --continue --input-file=../source-urls
