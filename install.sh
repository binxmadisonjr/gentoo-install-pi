#!/bin/bash
set -e 

# Load config
source "config.env"

# Run install
"source/01_package_check.sh"
echo "Package check is complete!"
echo "Starting downloads now!"
"source/02_downloads.sh"
echo "Downloads complete!"
echo "Setting up your device for chroot!"
"source/03_setup.sh"
echo "Setup complete!"
