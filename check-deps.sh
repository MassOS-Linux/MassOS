#!/bin/bash

# This script will check to ensure you have the necessary dependencies for
# building MassOS installed on your system. Only needed if you are building on
# a non-MassOS distro, as MassOS has all the necessary dependencies built-in.

find_prog() {
  printf "\e[1;33mLooking for $1...\e[0m "
  found="$(which "$1" 2>/dev/null)"
  if [ ! -z "$found" ]; then
    echo -e "\e[1;32m$found\e[0m"
  else
    echo -e "\e[1;31mNOT FOUND\e[0m"
  fi
}

find_prog awk
find_prog bash
find_prog bison
find_prog diff
find_prog find
find_prog g++
find_prog gcc
find_prog grep
find_prog gzip
find_prog info
find_prog install
find_prog ld.bfd
find_prog m4
find_prog make
find_prog patch
find_prog perl
find_prog python3
find_prog sed
find_prog sh
find_prog tar
find_prog xz
find_prog yacc

if [ ! -e /etc/massos-release ]; then
  echo "Please note that these results are not a guarantee that your build" >&2
  echo "will succeed or fail. For the best results, we always recommend" >&2
  echo "building from an existing installation of MassOS." >&2
fi
