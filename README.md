# EliteOS
An OS from ground up. Right now it is only a legacy BIOS compatible bootloader.

## Build Instructions
1. Get the repository.
2. Tell CMake where to create the Makefile. I'd recommend `mkdir build && cmake -S . -B build`
3. Run `make`
4. Done! `boot.bin` is the bootloader which you can load on QEMU or a x86_64 processor with legacy BIOS firmware.

## Dependencies
CMake: Build system

## Testing
I have tested this on a Lenovo Thinkpad 11E with Intel Celero N3160.

## Credits:
Name|Reason
----|------
[Daniel McCarthy](https://dragonzap.com/course/developing-a-multithreaded-kernel-from-scratch) | Course on developing a multithreaded kernel from scratch
