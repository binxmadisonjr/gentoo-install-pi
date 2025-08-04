#!/bin/bash
set -e

source "config.env"

# Check for requred packages before starting install
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
