# MassOS
This is the main source repository for the [MassOS](https://massos.org) operating system.

If you are an end-user, the following links may help you find what you're looking for:

- [MassOS Website](https://massos.org): The main MassOS website.
- [Download MassOS](https://massos.org/download.html): Contains direct download links for the latest version of MassOS.
- [About MassOS](https://github.com/MassOS-Linux/MassOS/wiki/About-MassOS): Provides information about the MassOS project.
- [Installing MassOS](https://github.com/MassOS-Linux/MassOS/wiki/Installing-MassOS): Information on how to install MassOS on your computer.
- [Post Installation](https://github.com/MassOS-Linux/MassOS/wiki/Post-Installation): Tips on how to make the most out of your MassOS installation, like installing software and using additional package managers.
- [Upgrading MassOS](https://github.com/MassOS-Linux/MassOS/wiki/Upgrading-MassOS): Information about upgrading your system to a newer version of MassOS.
- [MassOS Wiki](https://github.com/MassOS-Linux/MassOS/wiki): All MassOS documentation lives here.
- [Issues](https://github.com/MassOS-Linux/MassOS/issues): From here you can report bugs with MassOS and search for ones which have already been reported.

If you are a developer, the information below, as well as the following links may be helpful:

- [Contributing](https://github.com/MassOS-Linux/MassOS/wiki/Contributing): Information about contributing to MassOS.
- [Building MassOS](https://github.com/MassOS-Linux/MassOS/wiki/Building-MassOS): Information about building MassOS from source.

# Information for developers
A detailed description of how the MassOS build system works can be found at [Building MassOS](https://github.com/MassOS-Linux/MassOS/wiki/Building-MassOS).

This repository contains the source and build system for the core MassOS system (stage 1 and stage 2), as well as Xfce (stage 3). The GNOME port is submoduled at `stage3/gnome`, and any further desktop environments which become supported in the future will also be submoduled. The GNOME port is maintained at the [MassOS-GNOME](https://github.com/MassOS-Linux/MassOS-GNOME) repository.

This repo also does not contain the MassOS Installation Program found in the live CD, or the scripts used to build live ISO images for MassOS. Those can be found in the [livecd-installer](https://github.com/MassOS-Linux/livecd-installer) repository.

All repositories for the MassOS project can be found [here](https://github.com/orgs/MassOS-Linux/repositories).
