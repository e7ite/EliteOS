#!/bin/bash

# Used to start a gdb session with QEMU v1.3.0. Some newer versions of QEMU
# have problems communicating with GDB.

/opt/qemudbg/bin/qemu-system-x86_64 -hda build/boot.bin -S -s --daemonize --no-reboot
echo -e "target remote localhost:1234\n"\
	"set architecture i8086\n"\
        "layout asm\n"\
        "focus cmd\n"\
        "b *0x7C00" > .gdbinit
gdb
