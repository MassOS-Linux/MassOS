# The directory of 'keys/' in MassOS
This directory should contain signing keys (both public and private) and the like, for a custom MassOS build to properly support trust-based features such as secure boot.

The `generate-sb-keys.sh` script in the top-level of the MassOS source repository will generate a secure boot key set for you, and automatically place its output into the 'secureboot/' subdirectory. The key will be valid for 10 years after generation (setting it any longer than that may be possible, but isn't advisable, since some firmwares may reject keys with expiry dates too far into the future).

The files in this directory that the MassOS build system expects to use will be added to `.gitignore` in the top-level of the MassOS source repository, since it would be a pretty bad move if you accidentally published your private key to the world wide web. **ANY OTHER FILES HERE WON'T**, so be aware of this.

# Information about secure boot key/cert files
Here is an explanation of the five `db.*` files that will be placed in the `secureboot/` subdirectory after running the aforementioned key set generation script:

- `db.key`: The private signing key. **DO NOT, UNDER ANY CIRCUMSTANCE, EVER SHARE THIS WITH ANYONE!**
- `db.crt`: The public certificate for the key in the PEM format. Safe to share, but not very useful (apart from maybe verifying a valid signature inside a binary with `sbverify`).
- `db.der`: The public certificate for the key in the DER (x509) binary format. Used again by certain parts of the process. However, if you were importing the key into shim using MokManager, instead of importing into the UEFI firmware directly, it would expect this format.
- `db.esl`: The raw EFI signature list. Only used to generate the `db.auth` file, has no other purpose.
- `db.auth`: The signed EFI signature list, suitable for importing into a secure-boot-enabled UEFI firmware, so as to allow it to be able to boot `.efi` binaries which are signed with the key set.

# More information
Detailed information about secure boot, including how to import secure boot certificates into the firmware, can be found at [UEFI Secure Boot](https://github.com/MassOS-Linux/MassOS/wiki/UEFI-Secure-Boot) on the MassOS wiki.
