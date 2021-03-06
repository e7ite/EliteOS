# EliteOS
An OS for the x86_64 architecture from the ground up, strictly made for learning purposes. Right now it is only a bootloader compatible with legacy BIOS. This is obviously not elite compared to other operating systems. I just like the word elite. I am a complete beginner with operating system development, and I am fueled with curiosity and excitement to get as far as possible on this. Expect beginner mistakes.

## Build Instructions
1. Get this repository 
2. Build the bootloader. If you want to use my script, make `scripts/build.sh` executable using `chmod +x scripts/build.sh`, and run it using `scripts/build.sh`. If the script doesn't work for you or you don't want to use my script, configure CMake using something like `mkdir build && cmake -S . -B build` and `cd build && make`. 
3. Done! `boot.bin` is the bootloader which you can load on QEMU or on a PC with an x86_64 processor with legacy BIOS firmware.

## Dependencies
CMake: Build system

## Testing
I test this on physical hardware using a Lenovo Thinkpad 11E with a Intel Celero N3160 processor via USB emulation. I also test this on a virtual x86_64 machine with QEMU v1.3.0.

## Credits:
Name|Reason
----|------
[Daniel McCarthy](https://dragonzap.com/course/developing-a-multithreaded-kernel-from-scratch) | Course on developing a multithreaded kernel from scratch
[Intel](https://software.intel.com/content/www/us/en/develop/articles/intel-sdm.html) | Documentation on x86_64 ISA and Intel x86_64 processors
[AMD](https://developer.amd.com/resources/developer-guides-manuals/) | Documentation on x86_64 ISA and AMD x86_64 processors
[OSDev Wiki](https://wiki.osdev.org/Main_Page) | The holy grail on OS development

