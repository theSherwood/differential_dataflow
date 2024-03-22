#!/bin/bash

__help_string="
Usage: $(basename $0) [OPTIONS]

Options:
  -h, --help                       Print this usage information
  -u, --user_settings              Use the user_settings.sh script to setup variables
  -t, --target <native | wasm>     Specify the target
  -a, --action <build | test>      Specify the action
"

# default to testing native 
TARGET="native"
ACTION="test"
USER_SETTINGS=0

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--target)
      TARGET="$2"
      shift # past argument
      shift # past value
      ;;
    -a|--action)
      ACTION="$2"
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      echo "$__help_string"
      exit 0
      ;;
    -u|--user_settings)
      USER_SETTINGS=1
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      echo "Unknown parameter $1"
      exit 1
      ;;
  esac
done

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

# Run the target script
source "scripts/${ACTION}_${TARGET}.sh"
