# The directory of 'keys/' in MassOS
This directory should contain signing keys (both public and private) and the like, for a custom MassOS build to properly support trust-based features such as secure boot.

The `generate-sb-keys.sh` script in the top-level of the MassOS source repository will generate a secure boot key set for you, and automatically place its output into the 'secureboot/' subdirectory.

The files in this directory that the MassOS build system expects to use will be added to `.gitignore` in the top-level of the MassOS source repository, since it would be a pretty bad move if you accidentally published your private key to the world wide web. ANY OTHER FILES HERE WON'T, so be aware of this.

# Information about secure boot
Here is an explanation of the five `db.*` files that will be placed in the `secureboot/` subdirectory after running the aforementioned key set generation script:

- `db.key`: The private signing key. **DO NOT EVER SHARE THIS WITH ANYONE!**
- `db.crt`: The public certificate for the key. Safe to share, but not very useful (used by certain parts of the signing/verification process).
- `db.der`: The public certificate for the key in the DER (x509) binary format. Used again by certain parts of the process. It is also technically possible to import this file into a UEFI firmware, but it is discouraged; instead you should import the `db.auth` file as explained below.
- `db.esl`: The raw EFI signature list. Only used to generate the `db.auth` file, has no other purpose.
- `db.auth`: The signed EFI signature list, suitable for importing into a secure-boot-enabled UEFI firmware, so as to allow it to be able to boot `.efi` binaries which are signed with the key set.

## What about Shim?
Shim is a companion bootloader that allows self-signed EFI binaries to run using user-managed **Machine Owner Keys (MOKs)**, without needing to import secure boot signing keys directly into the firmware (they will instead be stored in Shim's local database).

Shim is only useful when it is signed by Microsoft (such as the Shim builds used by Ubuntu and Fedora). For distros that aren't (and can't be) signed by Microsoft (including MassOS), for obvious reasons, and instead fully rely on custom keys, Shim is useless. Since the user would still need to import our keys into their firmware to run Shim anyway - thus defeating the whole purpose of Shim! So instead, we completely skip use of Shim, and just sign our bootloaders/kernels/kernel modules ourselves.

## Does any of this affect secure-boot-disabled systems?
Not at all! If secure boot is disabled in your firmware (as recommended by the MassOS documentation), then none of this matters. The bootloader and kernel you use in MassOS will still be signed, but the firmware won't check the signatures, so the signing won't have any impact, and the system will boot up and function exactly like it would if they weren't signed.

The reason we have made the decision to support secure boot, is because in some rare contexts, it cannot be disabled. Two possible known reasons for this (although there are likely more), are the following:

- You are dual-booting with Windows and some Windows program requires secure boot to be enabled.
  - For example, the **Vanguard** anti-cheat system, which is used by various online video games including **Valorant**, will refuse to run if secure boot is not enabled.
    - Obviously you could just make the decision to not play a proprietary video game which uses a borderline-malware kernel-level anti-cheat system, and this would be the easiest course of action, but who are we to try and dictate what you can or can't play on an operating system completely unrelated to MassOS?
- A few systems have UEFI firmwares which secure boot cannot be disabled on. This is extremely uncommon these days, but some older models of laptop from the **Microsoft Surface** and **Lenovo Thinkpad** lineups (for example), were known to be this way.
  - Modders often found ways to bypass this, e.g., by developing and flashing custom firmwares (such as **Coreboot**) onto the locked-down machine. But this obviously comes with the risk of bricking the machine, especially if the only possible method of flashing is by manually using a programmer device connected to the physical BIOS chip on the mainboard itself.
