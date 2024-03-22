#!/bin/bash

__help_string="
Usage: $(basename $0) [OPTIONS]

Example:

  $(basename $0)      # builds native without user variables
  $(basename $0) -utw # runs wasm tests with user variables

Options:
  -h|-?     Print this usage information
  -u        Use user_settings.sh to setup variables
  -t        Run tests
  -w        Target wasm (native is default)
"

TEST=0
WASM=0
USER_SETTINGS=0

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
verbose=0

while getopts "h?twu" opt; do
  case "$opt" in
    h|\?)
      echo "$__help_string"
      exit 0
      ;;
    t) TEST=1
      ;;
    w) WASM=1
      ;;
    u) USER_SETTINGS=1
      ;;
  esac
done

shift $((OPTIND-1))

# default to building native 
TARGET="native"
ACTION="build"

if [ $TEST -eq 1 ]; then
  ACTION="test"
fi
if [ $WASM -eq 1 ]; then
  TARGET="wasm"
fi

# The user settings exports some variables with paths to be configured per user.
#
# - EMSCRIPTEN
# - NIMBASE
# - NIM
# - CC
#
# At some point, move to a dockerized or otherwise reproducible build system.
if [ $USER_SETTINGS -eq 1 ]; then
  source "scripts/user_settings.sh"
fi

echo "Running scripts/${ACTION}_${TARGET}.sh"

# Run the target script
source "scripts/${ACTION}_${TARGET}.sh"
