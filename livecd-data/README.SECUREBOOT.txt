=== SECURE BOOT SUPPORTED BUILD ===

This Live CD, and the MassOS build contained therein, are both configured to
support being booted on a UEFI system which has secure boot enabled. The Linux
kernel, kernel modules, and bootloader(s) have all been signed, and the
certificates that correspond to the keys used for signing can be found under
the 'secureboot/' directory of this Live CD.

For official builds of MassOS published by the MassOS developers, this will be
the official MassOS signing key, named one of the following:

  MassOS Project Secure Boot Signing 2026
  MassOS Project Official SB Signing 2025

For unofficial builds made and published by others, the key will be their own
custom signing key, which will have a different name to the official MassOS key
shown above. The process of importing the certificate into your firmware will
be identical regardless of whether the key is official or unofficial (see the
licensing note below for more information and clarification about this).

You will need to import the certificate used to sign this build into your UEFI
firmware if you want to be able to boot on a secure boot enabled system.
Although multiple files are included in the 'secureboot/' directory, most are
only there for redundancy purposes. Importing a secure boot certificate into a
UEFI firmware is almost always done using the `db.auth` file, which is a signed
list of trusted signatures. Alternatively, you can use the file `db.der` (also
named as `ENROLLME.cer`) to enroll into MokManager for use with shim. The
latter is now the default method recommended for MassOS. See the following page
on the MassOS wiki for more information, as well as detailed instructions on
how to do this:

  https://github.com/MassOS-Linux/MassOS/wiki/UEFI-Secure-Boot

If you are at all unsure about this process, and/or you do not have a reason to
enable secure boot anyway (e.g., an anti-cheat engine on Windows requires it),
then it's easier to just disable secure boot altogether, from your firmware
settings. This makes the process much simpler, and improves compatibility when
it comes to certain features like third party out-of-tree kernel modules, which
won't be signed for secure boot like the in-tree kernel modules. But the secure
boot support is, again, primary designed for people who can't (or don't want
to) disable secure boot, because they need it enabled for some specific reason.

Please be aware that certain hardening (or "lockdown") mechanisms are enabled
under UEFI secure boot. This includes the limitation that GRUB cannot load
themes that aren't built into the GRUB image itself (i.e., any custom theme),
as well as the requirement for all out-of-tree Linux kernel modules to be
signed with a MOK (Machine Owner Key) that is enrolled into shim's database.
The MassOS documentation contains detailed information about this:

  https://github.com/MassOS-Linux/MassOS/wiki/UEFI-Secure-Boot

=== NOTE ON LICENSING ===

The GRUB bootloader, which has been signed by the key(s) described above, is
GPL3-licensed. The MassOS developers have made every effort to comply with the
terms of this license. Although they keep their signing keys private, the
MassOS build system has been designed to support any signing key, and provides
a script in the MassOS source repository, named 'generate-sb-keys.sh', which
will generate a secure boot key set for you.

This results in the only difference between an official build and an unofficial
build being that they are signed by different keys, and therefore a user who
wants to boot MassOS on a secure boot enabled system, will have to import the
specific certificate which corresponds to the build they want to boot - whether
that be an official build (therefore importing the official MassOS certificate)
or an unofficial build (therefore importing the certificate specific to that
build). There are otherwise NO functional differences arising from this
situation; an unofficial build will behave identically to an official build, as
long as the correct certificate is imported into the user's UEFI firmware.

The GPL3 license of GRUB, does, however, mean that Microsoft is unable to sign
a GRUB bootloader using their official keys - since this would provide feature
inferiority (Microsoft keys are included in all firmwares by default, MassOS
keys (whether official or custom), or any other custom keys, are not). And this
would violate the TiVoization clause of the GPL3, which prevents running free
software on hardware that would essentially render it non-free in practise.

Please see the following URL for more in-depth information:

  https://github.com/MassOS-Linux/MassOS/wiki/UEFI-Secure-Boot
