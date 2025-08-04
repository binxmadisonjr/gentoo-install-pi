#!/bin/bash
set -e

source "../config.env"

# Check for requred packages before starting install
for cmd in $REQUIRED_CMDS; do
    if ! command -v $cmd &>/dev/null; then
        echo "Missing required command: $cmd"
        MISSING=1
    fi
done

if [[ $MISSING -eq 1 ]]; then
    echo "Please install all required packages before running this script."
    echo "Common package names:"
    echo "  Debian/Ubuntu: sudo apt update && sudo apt install wget git parted dosfstools btrfs-progs tar gawk coreutils"
    echo "  Fedora:        sudo dnf install wget git parted dosfstools btrfs-progs tar gawk coreutils"
    echo "  Arch:          sudo pacman -S wget git parted dosfstools btrfs-progs tar gawk coreutils"
    exit 1
fi
