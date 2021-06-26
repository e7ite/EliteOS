# EliteOS
An OS from ground up. Right now it is only a legacy BIOS compatible bootloader.

## Build Instructions
1. Get this repository 
2. Build the bootloader. If you want to use my script, make `scripts/build.sh` executable using `chmod +x scripts/build.sh`, and run it using `scripts/build.sh`. If the script doesn't work for you or you don't want to use my script, configure CMake using something like `mkdir build && cmake -S . -B build` and `cd build && make`. 
3. Done! `boot.bin` is the bootloader which you can load on QEMU or on a PC with an x86_64 processor with legacy BIOS firmware.

## Dependencies
CMake: Build system

## Testing
I have tested this on a Lenovo Thinkpad 11E with Intel Celero N3160.

## Credits:
Name|Reason
----|------
[Daniel McCarthy](https://dragonzap.com/course/developing-a-multithreaded-kernel-from-scratch) | Course on developing a multithreaded kernel from scratch
