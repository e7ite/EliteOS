#!/bin/bash

# Script that writes to my USB. If anyone besides me I don't know if this will
# work for you lol

# Get USB name from command line
usbModelName=$1
if [[ -z "$usbModelName" ]]
then
    echo "USAGE: $0 <USBNAME>"
    exit 1
fi

# Use fdisk to get the name of the disk and the directory it's stored in
diskInfo=$(sudo fdisk -l | grep -B1 $usbModelName)
diskModel=$(echo $diskInfo | awk '{printf $11}')
diskToWrite=$(echo $diskInfo | awk '{print $2}' | sed -E 's/://')

# Make sure it was successful in finding the names of the USB
if [[ -z "$diskModel" || -z "$diskToWrite" ]]
then
	echo "Can't find your USB. Did you remember to plug it in?"
	exit 1
fi

# Find the bootloader by the name "boot.bin"
bootDir=$(find . -name boot.bin)
if [[ -z "$usbModelName" ]]
then
    echo "Couldn't find boot.bin"
    exit 1
fi

# Confirm we want to write to the disk and write to it
echo "Are you sure you want to write $bootDir to $diskModel:$diskToWrite?"
echo "Enter anything to continue. Ctrl+C to exit."
read var
sudo dd if=$bootDir of=$diskToWrite
if [[ $? -ne 0 ]]
then
    echo "Failed to write the bootloader to disk"
    exit 1
fi
