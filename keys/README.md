# The directory of 'keys/' in MassOS
This directory should contain signing keys (both public and private) and the like, for a custom MassOS build to properly support trust-based features such as secure boot.

The `generate-sb-keys.sh` script in the top-level of the MassOS source repository will generate a secure boot key set for you, and automatically place its output into the 'secureboot/' subdirectory. The key will be valid for 10 years after generation (setting it any longer than that may be possible, but isn't advisable, since some firmwares may reject keys with expiry dates too far into the future).

The files in this directory that the MassOS build system expects to use will be added to `.gitignore` in the top-level of the MassOS source repository, since it would be a pretty bad move if you accidentally published your private key to the world wide web. **ANY OTHER FILES HERE WON'T**, so be aware of this.

# Information about secure boot key/cert files
Here is a brief explanation of the five `db.*` files that will be placed in the `secureboot/` subdirectory after running the aforementioned key set generation script:

- `db.key`: The private signing key. **DO NOT, UNDER ANY CIRCUMSTANCE, EVER SHARE THIS WITH ANYONE!**
- `db.crt`: The public certificate for the key in the PEM format. Can be used for direct verification of binaries (e.g., `sbverify`), or combined with other certificates to form a combined EFI signature list file.
- `db.der`: The public certificate for the key in the DER (x509) binary format. Can be converted to/from PEM using `openssl` utility. Known to be the format expected by shim's MokManager utility (for importing into shim's database, not importing into UEFI firmware directly).
- `db.esl`: The raw, unsigned EFI signature list. Used to generate the `db.auth` file. Multiple individual `.esl` files can optionally be concatenated into one single combined `.esl` file. If you intend to import the certificate onto a secure boot configuration [controlled by you](https://github.com/DanielMYT/secureboot-scripts), then you can sign the `.esl` file using your KEK key, to produce a `db.auth` file that can be imported using `efi-updatevar` or `KeyTool.efi`.
- `db.auth`: The authorized EFI signature list which has been self-signed, suitable for importing into a secure-boot-enabled UEFI firmware whose interface provides the ability to perform manual key management. This cannot be imported using `efi-updatevar` or `KeyTool.efi`, as they require db entries to be signed by the KEK (this `.auth` file is self-signed).

# More information
Detailed information about secure boot, including how to import secure boot certificates into the firmware, can be found at [UEFI Secure Boot](https://github.com/MassOS-Linux/MassOS/wiki/UEFI-Secure-Boot) on the MassOS wiki.
