#!/bin/bash

# Script that writes a new sector with whatever is inside the file "message.txt"
# to the bootloader boot.bin

# Finds the file called message.txt
msgFile=$(find . -name message.txt)
if [[ -z "$msgFile" ]]
then
    echo "Couldn't find message.txt"
    exit 1
fi

# Find the bootloader by the name "boot.bin"
bootBin=$(find . -name boot.bin)
if [[ -z "$bootBin" ]]
then
    echo "Couldn't find boot.bin"
    exit 1
fi

# Concatenate the file to the binary, and pad the rest of sector with zeroes
dd if=$msgFile >> $bootBin
if [[ $? -ne 0 ]]
then
    echo "Failed to append the message to the bootloader"
    exit 1
fi

dd if=/dev/zero bs=$((512-$(cat $msgFile | wc -c))) count=1 >> $bootBin
if [[ $? -ne 0 ]]
then
    echo "Failed to pad the bootloader with zeroes"
    exit 1
fi