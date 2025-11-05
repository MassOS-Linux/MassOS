#!/usr/bin/env bash

# This script validates the host system to ensure it is new enough to build
# MassOS, and that it contains all the needed software for building the system.

# Function to report that the system is inadequate.
bad() {
  echo -e "\e[1;31mYour system is INADEQUATE for building MassOS.\e[0m" >&2
  echo -e "\e[1;31mThis is because $*\e[0m" >&2
  exit 1
}

# MassOS must be compiled from a GNU/Linux system.
if test "$(uname -o)" != "GNU/Linux"; then
  bad "it is not a GNU/Linux system."
fi

# The running Linux kernel must be, AT BARE MINIMUM, 5.10. Older versions of
# the Linux kernel are ENTIRELY UNSUPPORTED and will be physically incapable of
# building MassOS. This is because MassOS configures its build of Glibc to only
# support 5.10 and newer kernels. Supporting older kernels is unnecessary for
# MassOS, because the very first version of MassOS used kernel 5.13, and by
# excluding support for older kernels which have never and will never be
# supported, the resulting system's binaries will be smaller and more optimised
# because the C library won't need to worry about including obsolete code.
KERNEL_FULL="$(uname -r)"
KERNEL_MAJOR="$(echo "$KERNEL_FULL" | cut -d. -f1)"
KERNEL_MINOR="$(echo "$KERNEL_FULL" | cut -d. -f2)"
if test -z "$KERNEL_MAJOR" || test -z "$KERNEL_MINOR" || test "$KERNEL_MAJOR" -lt 5 || { test "$KERNEL_MAJOR" -eq 5 && test "$KERNEL_MINOR" -lt 10; }; then
  bad "the kernel is too old (MUST BE 5.10 OR NEWER)."
fi

# GCC must be present, and must NOT be older than 12.x. We may increase this
# in the future, but to no more recent than 2 versions below the version
# currently in use by the MassOS build system.
GCC_MAJOR="$(gcc -dumpversion 2>/dev/null | cut -d. -f1)"
if test -z "$GCC_MAJOR"; then
  bad "GCC is not present on the system."
fi
if test "$GCC_MAJOR" -lt 12; then
  bad "the installed GCC is too old (MUST BE 12.x OR NEWER)"
fi

# GCC and G++ must be able to compile executables and support -Os optimization.
rm -f /tmp/mbstestcompile{.,app-}{,c{,pp}}
echo "int main(){}" > /tmp/mbstestcompile.c
echo "int main(){}" > /tmp/mbstestcompile.cpp
gcc -Os /tmp/mbstestcompile.c -o /tmp/mbstestcompileapp-c
g++ -Os /tmp/mbstestcompile.cpp -o /tmp/mbstestcompileapp-cpp
if ! /tmp/mbstestcompileapp-c || ! /tmp/mbstestcompileapp-cpp; then
  bad "the installed GCC cannot compile C/C++ executables."
fi
rm -f /tmp/mbstestcompile{.,app-}{,c{,pp}}

# Ensure required programs are present.
# TODO: See if upgrade-toolset can provide them?
if ! gawk --version &>/dev/null; then
  bad "gawk is not present on the system."
fi
if ! bison --version &>/dev/null || ! yacc --version &>/dev/null; then
  bad "bison/yacc is not present on the system."
fi

# TODO: Add more checks in the near future. This shall suffice for now.

# System appears to be acceptable.
echo -e "\e[1;32mYour environment appears suitable for building MassOS.\e[0m"
echo -e "\e[1;32mBe sure to also check the minimum hardware requirements:\e[0m"
echo -e "\e[1;32m<https://github.com/MassOS-Linux/MassOS/wiki/Building-MassOS>\e[0m"
