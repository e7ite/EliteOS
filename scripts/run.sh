#!/bin/bash

# Script that runs the QEMU emulator. I use QEMU version 1.3.0 to ensure
# compatibility with GDB.

qemu-system-x86_64 -hda build/boot.bin
