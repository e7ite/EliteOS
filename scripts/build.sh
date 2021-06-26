#!/bin/bash

# Script that creates the build folder and compiles the bootloader. Will 
# definitely be expanded upon as I progress through this course

# Create the directory if it doesn't exist already
mkdir build 2>/dev/null && cmake -S . -B build 

# Build the binary
cd build && make