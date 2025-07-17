#!/usr/bin/env bash

# Exit on error.
set -e

# Create the directory if it does not exist.
mkdir -p keys/secureboot

# Change to the directory.
cd keys/secureboot

# Do not run if keys already exist.
if test -e db.key && test -e db.crt && test -e db.der && test -e db.esl && test -e db.auth; then
  echo "A complete secure boot key set was found in 'keys/secureboot/'." >&2
  echo "If you are happy to use this key set, you don't need this script!" >&2
  echo "If you want to (re)generate new keys, remove the old key's files." >&2
  exit 1
elif test -e db.key || test -e db.crt || test -e db.der || test -e db.esl || test -e db.auth; then
  echo "An incomplete secure boot key set was found in 'keys/secureboot/'." >&2
  echo "This incomplete set cannot be used as-is, you should regenerate." >&2
  echo "If you want to (re)generate new keys, remove the old key's files." >&2
  exit 1
fi

# Require some programs.
if ! command -v openssl >/dev/null; then
  echo "This program needs OpenSSL installed in order to run." >&2
  echo "Alternatively, you can drop a pregenerated key pair into 'keys/'." >&2
  exit 1
fi
if ! command -v cert-to-efi-sig-list >/dev/null || ! command -v sign-efi-sig-list >/dev/null; then
  echo "This program needs efitools installed in order to run." >&2
  echo "Note that only MassOS experimental-20250611 and newer include it." >&2
  echo "Alternatively, you can drop a pregenerated key pair into 'keys/'." >&2
  exit 1
fi

# Initial message.
echo "This script will generate a secure boot signing key pair for MassOS." >&2
echo "You must provide a common name (CN) for your key." >&2
echo "The CN should be unique for your own builds, and descriptive." >&2
echo "For example, \"John Smith Secure Boot Signing Key\"." >&2

# Ask the user to enter the name associated with the key.
while true; do
  read -rp "Enter the common name (CN) to be used for the signing key: " name
  # Do not permit using the same name as the official MassOS key.
  if test "$name" = "Official MassOS Secure Boot Key (Daniel Massey)" || test "$name" = "MassOS Project Official SB Signing 2025"; then
    echo "Sorry, please choose a different name for your CN." >&2
    continue
  fi
  # Only break out of the loop if the name is not empty.
  if test ! -z "$name"; then
    break
  fi
done

# Generate the key pair using OpenSSL.
openssl req -new -x509 -newkey rsa:2048 -nodes -keyout db.key -out db.crt -days 3650 -subj "/CN=$name/"

# Convert public key to DER (x509) format.
openssl x509 -in db.crt -outform DER -out db.der

# Create .esl and .auth files.
cert-to-efi-sig-list -g "$(uuidgen)" db.crt db.esl
sign-efi-sig-list -k db.key -c db.crt db db.esl db.auth

echo "" >&2
echo "The new secure boot key set was placed in 'keys/secureboot/'." >&2
echo "It will be valid for 10 years from now (see 'keys/README.md')." >&2
echo "DO NOT, UNDER ANY CIRCUMSTANCE, SHARE THE 'db.key' FILE WITH ANYONE!" >&2
echo "OTHERWISE IMPERSONATION CAN OCCUR AND THE DBX MAY REVOKE YOUR KEY!" >&2
echo "It is, however, safe to share all the other 'db.*' files." >&2
echo "The MassOS wiki has info on how to import the new key into firmware." >&2
