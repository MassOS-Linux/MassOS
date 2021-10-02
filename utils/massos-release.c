/*

MassOS version detection utility.
Copyright (C) 2021 The Sonic Master.

*/

#include <stdio.h>

int main() {
  int c;
  FILE *file;
  file = fopen("/etc/massos-release","r");
  if (file) {
    while ((c = getc(file)) != EOF) {
      putchar(c);
    }
    fclose(file);
    return 0;
  } else {
    fprintf(stderr,"Error: Could not determine MassOS Release.\n");
    return 1;
  }
}
