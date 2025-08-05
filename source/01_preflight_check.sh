#!/bin/bash
set -e

# --- Load config ---
source "config.env"

# --- Check for root ---
echo "Checking for root privileges..."

if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

echo "Root check complete!"

# Check for requred packages before starting install
echo "Checking for required packages..."

MISSING=0
for cmd in $REQUIRED_CMDS; do
    if ! command -v $cmd &>/dev/null; then
        echo "Missing required command: $cmd"
        MISSING=1
    fi
done

if [[ $MISSING -eq 1 ]]; then
    echo "Please install all required packages before running this script."
    exit 1
fi

echo "Required packages found!"
