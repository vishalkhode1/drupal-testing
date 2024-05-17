#!/bin/bash

source ./.config.sh

# Function to check if a path is relative
is_relative() {
    case "$1" in
        /*) return 1 ;; # absolute path
        *) return 0 ;;  # relative path
    esac
}

# Function to convert a relative path to absolute path
to_absolute() {
    if is_relative "$1"; then
        echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    else
        echo "$1"
    fi
}
