cmake_minimum_required(VERSION 3.18.4)
project(EliteOS ASM_NASM)

# Set the output file and the source files variables
set(binfile boot.bin)
set(SOURCE_FILES boot.asm)

# What I had to do to get CMake to build the file in binary mode
set(CMAKE_ASM_NASM_COMPILE_OBJECT "<CMAKE_ASM_NASM_COMPILER> -f bin -o ${binfile} <SOURCE>")

# Create it as a library so it doesn't attempt to link it for now
add_library(${binfile} OBJECT ${SOURCE_FILES})

