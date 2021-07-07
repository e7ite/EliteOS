#!/bin/bash

# Script that runs the QEMU emulator and kills when it triple faults. I use
# QEMU version 1.3.0 to ensure compatibility with GDB.

# Launch QEMU with bootloader and monitor interrupts and CPU resets
/opt/qemudbg/bin/qemu-system-x86_64 -hda build/boot.bin --daemonize -d int,cpu_reset -D error.txt

# Monitor the file error.txt and wait for it to triple fault to be written to it
while inotifywait -e modify error.txt 2>/dev/null 1>/dev/null
do
	if [[ $(grep -c 'Triple fault' error.txt) -ne 0 ]]
	then
		kill -9 $(pgrep qemu-system)
		echo 'Received triple fault. Killing QEMU'
		exit 0
	fi
done
