#!/bin/bash

# Function to check if a path is relative
is_relative() {
  case "$1" in
    /*) return 1;; # absolute path
    *) return 0;;  # relative path
  esac
}

# Function to convert a relative path to absolute path
to_absolute() {
  if is_relative "$1"; then
    echo "$(cd "$(dirname "${CURRENT_DIR}/$1")" && pwd)/$(basename "$1")"
  else
    echo "$1"
  fi
}

# Function to execute given command.
executeCommand() {
  printCommand "$1"
  eval "$1"
}

# Function to print given command.
printCommand() {
  echo -e " ${YELLOW}> $1${NOCOLOR}"
}

# Function to print Heading block.
printHeading() {
  heading="$1:"
  char_count=$(echo -e "${heading}" | wc -m)
  char_count=$((char_count - 1))
  echo -e "\n ${GREEN}${heading}${NOCOLOR}"
  s=$(printf "%-${char_count}s" "-")
  echo " ${s// /-}"
}

# Function to print Comments.
printComment() {
  echo -e "\n ${YELLOW}// $1${NOCOLOR}\n"
}