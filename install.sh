#!/bin/bash
set -e 

# --- Load config ---
cp config.env source/config.env
source "source/config.env"

# --- Run install ---
# --- --- 01 --- ---
echo "Running checks..."
"source/01_preflight_check.sh"
echo "Check is complete!"
# --- --- 02 --- ---
echo "Starting downloads now..."
"source/02_downloads.sh"
echo "Downloads complete!"
# --- --- 03 --- ---
echo "Setting up your device for chroot..."
"source/03_setup.sh"
echo "Setup complete!"
# --- --- 04 --- ---
echo "Finalizing the installation..."
"source/04_finalize.sh"
echo "Installation finalized! All done."
