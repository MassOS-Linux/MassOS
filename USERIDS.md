# System User and Group IDs in MassOS

Due to the nature of filesystem permissions being based on numerical user and group IDs, rather than names, the MassOS developers have made the decision to hardcode the UIDs and GIDs of most system accounts managed by the `systemd-sysusers` configuration database. This is in an effort to avoid unexpected permission errors when performing a system upgrade from an older MassOS release which did not contain a particular system account, to a newer release which does, if the otherwise automatic ID assignment would result in a value corresponding to a different account on the existing OS.

All areas of the MassOS build system must ensure system accounts are set with IDs that match the values listed in the below tables. Any deviations should be reported as [issues](https://github.com/MassOS-Linux/MassOS/issues) on the MassOS repository. When new packages added to the build system install `systemd-sysusers` configuration files, care _must_ be taken to ensure the UID/GID of any system accounts contained therein are hardcoded to a unique ID.

As a general rule, the ID allocations should be based on the following ranges:

| Range | Description |
|-|-|
| 961 - 999 | ID allocations retained from older builds of MassOS for backwards compatibility purposes. |
| 500 - 960 | Reserved for system administrators who are installing packages at runtime which require system accounts. |
| 100 - 499 | Standard range for hardcoded IDs for system users and groups of generic packages in the MassOS build system. If in doubt, use this range. Consult the tables below to find an ID number that is not already being used by something else. |
| 1 - 99 | Special range for low-level system users and groups. This range should only be used in exceptional circumstances. The **100 - 499** range should be preferred in almost all cases. |

ID **0** is the root account (superuser). IDs **1000** and greater are for human users only (i.e. created at runtime with the `useradd` utility).

**NOTE 1:** All rows in both of the below tables are in _descending_ order of ID numbers.

**NOTE 2:** All system users implicitly have an identically named group with a GID matching the UID. In such instances (where the group only serves as the internal group of the user), the group will _not_ be displayed in the **Group IDs** table.

# Group IDs

| Group ID | Name | Package | Active? |
|-|-|-|-|
| 999 | adm | systemd | Yes |
| 998 | wheel | systemd | Yes |
| 997 | empower | systemd | Yes |
| 996 | utmp | systemd | Yes |
| 995 | audio | systemd | Yes |
| 994 | cdrom | systemd | Yes |
| 993 | clock | systemd | Yes |
| 992 | dialout | systemd | Yes |
| 991 | disk | systemd | Yes |
| 990 | input | systemd | Yes |
| 989 | kmem | systemd | Yes |
| 988 | kvm | systemd | Yes |
| 987 | lp | systemd | Yes |
| 986 | render | systemd | Yes |
| 985 | sgx | systemd | Yes |
| 984 | tape | systemd | Yes |
| 983 | video | systemd | Yes |
| 982 | users | systemd | Yes |
| 981 | systemd-journal | systemd | Yes |
| 12 | autologin | systemd | Yes |
| 11 | netdev | systemd | Yes |
| 10 | scanner | systemd | Yes |
| 9 | lpadmin | systemd | Yes |
| 8 | mail | systemd | Yes |
| 7 | floppy | systemd | Yes |
| 5 | tty | systemd | Yes |

# User IDs

| User ID | Name | Package | Active? |
|-|-|-|-|
| 980 | systemd-coredump | systemd | Yes |
| 979 | systemd-network | systemd | Yes |
| 978 | systemd-oom | systemd | Yes |
| 977 | systemd-resolve | systemd | Yes |
| 976 | systemd-timesync | systemd | Yes |
| 975 | messagebus | dbus | Yes |
| 974 | uuidd | util-linux | Yes |
| 973 | tss | tpm2-tss | Yes |
| 972 | openvpn | openvpn | Yes |
| 971 | fcron | fcron | Yes |
| 970 | dhcpcd | dhcpcd | Yes |
| 969 | systemd-imds | systemd | Yes |
| 968 | polkitd | polkit | Yes |
| 967 | sshd | openssh | Yes |
| 966 | colord | colord | Yes |
| 965 | avahi | avahi | Yes |
| 964 | nm-openvpn | networkmanager-openvpn | Yes |
| 963 | flatpak | flatpak | Yes |
| 962 | passim | passim | Yes |
| 961 | fwupd | fwupd | Yes |
| 430 | lightdm | lightdm | Yes (xfce variant only) |
| 420 | cups | cups | Yes |
| 6 | daemon | systemd | Yes |
| 2 | sys | systemd | Yes |
| 1 | bin | systemd   | Yes |
| 0 | root | systemd | Yes |
