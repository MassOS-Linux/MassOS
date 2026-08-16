#!/usr/bin/env bash

# Script location.
HERE="$(readlink -f "$(dirname "$0")")"

# Find 'version.env' file to source, or fail.
if test -r "$PWD"/version.env; then
  . "$PWD"/version.env
elif test -r "$HERE"/version.env; then
  . "$HERE"/version.env
else
  echo "ERROR: 'version.env' not found, cannot generate version." >&2
  exit 1
fi

# Ensure the mandatory values are defined.
if test -z "$VERSION_BASE" || test -z "$VERSION_DEV" || test -z "$VERSION_HOTFIX"; then
  echo "ERROR: 'version.env' is missing values, cannot generate version." >&2
  exit 1
fi

# Set up base version.
base="$VERSION_BASE"

# Apply dev or hotfix appendage as necessary.
if test "$VERSION_DEV" != "0"; then
  base+=".dev$VERSION_DEV"
elif test "$VERSION_HOTFIX" != "0" && test "$VERSION_HOTFIX" != "1"; then
  base+=".$VERSION_HOTFIX"
fi

# Echo final version.
echo "$base"
