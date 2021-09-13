# MassOS post-installation tips
This document contains some useful tips and information for things like installing software, customisation, and other useful tips to make the most out of your MassOS installation.
# Installing software
MassOS has the Flatpak package manager built in. Flatpak provides a nice way of distributing and installing graphical software across many GNU/Linux distributions.

There are two ways you can install Flatpak apps on MassOS. You can either do so from the GUI software center, or from the terminal.
## Installing Flatpak software from the GUI software center
The software center on MassOS is called "Software". You can launch it from the apps menu or search for it with the Xfce appfinder:
![](software1.png)
Once opened, the front page of the store contains some recommended apps. You can browse through the categories, or click the search button at the top left hand corner:
![](software2.png)
For example: To install VLC Media Player, we will search for "vlc":
![](software3.png)
Then click "Install" and wait patiently.
![](software4.png)
When the app is installed, it will be available from your apps list. You can also launch it by clicking the "Launch" button in the software center.
![](software5.png)
## Installing Flatpak software from the command-line
Press Control+Alt+T to open the terminal, or find the terminal in your apps list.

You can type the following command to install Flatpak software:
```
flatpak install <name of package>
```
For example, to install VLC Media Player:
```
flatpak install org.videolan.VLC
```
To search for software, replace `install` with `search`:
```
flatpak search <search term>
```
To list installed software:
```
flatpak list
```
## Suggested software
MassOS comes preinstalled with the Firefox Web Browser and Thunderbird Mail Client. If you'd prefer to use something else, it's easy to install a different one using the steps below. There are also some other common apps you may want, such as media players and text editors. Here are some recommended open-source programs. Do not forget that this list barely scratches the surface of what is available with Flatpak:
### Alternative web browsers
- LibreWolf
- Chromium
- Midori
- GNOME Web (Epiphany)
### Alternative mail clients
- Evolution
- Geary
- Claws Mail
### Media players
- VLC Media Player
- Celluloid
- Clapper
- mpv
### Advanced text editors
- Atom
- Visual Studio Code
- Brackets
# Tips.
- While Flatpak is the default and prefered package manager, many software packages can also be run on MassOS via the use of AppImages.
- Most development tools and headers are preserved in the MassOS system, allowing the user to easily compile any missing command-line software they might need. Autotools, Meson, and CMake build systems are supported.
- Many programs store customisable configuration files in `/etc`. If you know what you're doing, feel free to customise the configuration files here.
- MassOS has an SSH server built in. To enable the SSH server, run `sudo systemctl enable --now sshd`. This will allow remote connections to your MassOS machine over SSH.
- While GRUB is the default and recommended bootloader, it also supports systemd-boot. If you know what you're doing, you can use this extremely minimal boot manager instead of the full GRUB bootloader.
