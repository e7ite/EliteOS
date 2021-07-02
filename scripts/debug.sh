#!/bin/bash

# Used to start a gdb session with QEMU v1.3.0. Some newer versions of QEMU
# have problems communicating with GDB.

echo -e "target remote | qemu-system-x86_64 -hda build/boot.bin -S -gdb stdio\nset architecture i8086" > .gdbinit
gdb
