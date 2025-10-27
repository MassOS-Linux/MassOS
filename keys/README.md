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

# MassOS developer's guide to GRUB signed images
GRUB, in its vanilla state, would generate the EFI image at runtime, when the user runs the command `grub-install`. Unfortunately, this is not functionally usable with UEFI secure boot - because the distro developer/builder needs to sign the image for secure boot ahead of time, which cannot be done when the image is generated at runtime.

Furthermore, the vanilla `grub-install` generated image only contains the core GRUB image itself. All modules that GRUB needs to load at runtime are instead stored on-disk. This again causes issues for secure boot, because GRUB's lockdown policies forbid loading of modules from disk when secure boot is enabled.

To workaround both of these problems, we need to (a) pre-generate GRUB images for the distribution, which we can then sign for secure boot, (b) ensure those images contain all of GRUB's modules built-in, so no modules need to be loaded from the disk at runtime, and (c) patch `grub-install` so that it installs those pre-generated images instead of following its normal process of building a core GRUB image at runtime.

For (c), you can find the patch that MassOS applies to GRUB in the `patches/` directory of the MassOS source tree. For (a) and (b), the `grub-mkstandalone` utility does this job for us. It will generate a fully standalone GRUB image, containing all modules, and containing an embedded stub configuration file. As part of the GRUB package in the MassOS build system, we generate 3 different standalone images, each with a specific purpose:

- `grubx64.efi` - The default image for when `grub-install` is run.
- `gcdx64.efi` - The image for when `grub-install` is run with the `--removable` parameter (to install the EFI bootloader to the fallback location).
- `glcdx64.efi` - The image specifically designed for use on the MassOS Live CD.

The stub configuration file embedded in each individual image vary subtly, but they all do the following:

- Load some basic modules which are not configured to be pre-loaded out of the box (but are still built-in to the standalone GRUB image).
- Load the default GRUB font and set up the graphical interface for the GRUB menu.
- Switch to a second-stage configuration file stored on the disk. Either by using `$cmdpath` to find the second-stage file alongside the installed GRUB image, or alternatively falling back to a hardcoded location on firmwares where `$cmdpath` is unsupported.

For `grubx64.efi` and `gcdx64.efi`, the second-stage configuration file, which is written at runtime by `grub-install`, simply stores the UUID of the filesystem containing the main GRUB configuration file - either the root filesystem, or the boot partition (if `/boot` is on a separate partition to `/`). It then loads the full GRUB configuration file from that filesystem (which is generated when the user runs `grub-mkconfig -o /boot/grub/grub.cfg`), to continue the boot as normal. If the full configuration file is stored on a LUKS-encrypted partition, then the second-stage configuration file calls `cryptomount` first, to be able to unlock and access the encrypted volume.

For `glcdx64.efi` (the image used for the MassOS Live CD), the second-stage config is searched for on the filesystem which contains the Live CD files - and this second-stage config file alone populates the GRUB menu entries for the MassOS Live CD. For Legacy BIOS booting, the MassOS Live CD does not use GRUB anyway (it uses ISOLINUX instead), so this process does not apply.

Although the GRUB standalone images bundle every GRUB module within themselves, this is only done for the purpose of secure boot support (since, as previously mentioned, GRUB won't allow loading modules from the disk in secure boot mode). Not all of them are used by the bootup process itself. Some common disk and filesystem modules are configured (via use of the `--modules=` argument to `grub-mkstandalone`) to be automatically pre-loaded by the GRUB image on bootup. Other modules are loaded by the embedded stub configuration file.
