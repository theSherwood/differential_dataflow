#!/bin/bash

__help_string="
Usage:
  $(basename $0) -h | --help
  $(basename $0) -f "tests/test.nim" -n test -u     # Compile tests for native
  $(basename $0) -f "tests/test.nim" -n test -uw    # Compile tests for wasm
  $(basename $0) -f "tests/test.nim" -n test -ruwo  # Compile and run tests for wasm with optimizations
  $(basename $0) -f "tests/test.nim" -n test -ruo   # Compile and run tests for native with optimizations
  $(basename $0) -f "src/dida.nim"   -n dida -uw    # Compile dida lib for wasm

Options:
  -? -h --help         Print this usage information.
  -r --run             Run the compiled output.
  -u --user_settings   Use user_settings.sh to setup variables.
  -w --wasm            Target wasm (native is default).
  -o --opt             Use compiler optimizations (-Os).
  -f FILE              Entry file (.nim).
  -n NAME              Name to use for outputs and C cache files.
"

echo "Command: $0 $@"

RUN=0
WASM=0
USER_SETTINGS=0
OPTIMIZE=""
unset -v FILE
unset -v NAME

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
verbose=0

while getopts "h?rowu-f:n:" opt; do
  case "$opt" in
    \?|h|help)
      echo "$__help_string"
      exit 0
      ;;
    r|run           ) RUN=1 ;;
    o|opt           ) OPTIMIZE="-Os" ;;
    w|wasm          ) WASM=1 ;;
    f|file          ) FILE=${OPTARG} ;;
    n|name          ) NAME=${OPTARG} ;;
    u|user_settings ) USER_SETTINGS=1 ;;
    -)
      case "${OPTARG}" in
        help)
          echo "$__help_string"
          exit 0
          ;;
        run           ) RUN=1 ;;
        opt           ) OPTIMIZE="-0s" ;;
        wasm          ) WASM=1 ;;
        user_settings ) USER_SETTINGS=1 ;;
        *)
          echo "Invalid option: --$OPTARG"
          exit 1
          ;;
      esac
      ;;
  esac
done

shift "$((OPTIND-1))"

if [ -z "$FILE" ] || [ -z "$NAME" ]; then
  echo 'Missing -f or -n' >&2
  exit 1
fi

# default to building native 
TARGET="native"
if [ $WASM -eq 1 ]; then
  TARGET="wasm"
fi

# The user settings exports some variables with paths to be configured per user.
#
# - CC         - path to C compiler
# - EMSCRIPTEN - path to emscripten
# - NIMBASE    - path to nimbase.h
# - NIM        - path to the Nim compiler
#
# At some point, move to a dockerized or otherwise reproducible build system.
if [ $USER_SETTINGS -eq 1 ]; then
  source "scripts/user_settings.sh"
fi

PATH_TO_C_ASSETS="./nimcache/${NAME}_${TARGET}"
C_ENTRY_FILE="@m${NAME}.nim.c"
C_ENTRY_FILE_PATH="${PATH_TO_C_ASSETS}/${C_ENTRY_FILE}"

export LDFLAGS="${OPTIMIZE}"
export CFLAGS="${OPTIMIZE}"
export CXXFLAGS="${OPTIMIZE}"

c_files() {
  # Get all the c files other than the entry file in a list
  c_libs=()
  for file in ${PATH_TO_C_ASSETS}/*.c
  do
    ! [[ -e "$file" ]] || [[ "$file" = ${C_ENTRY_FILE_PATH} ]] || c_libs+=("$file")
  done
  # append the entry file
  c_libs+=("$C_ENTRY_FILE_PATH")
  # return the list as a string
  echo "${c_libs[@]}"
}

# if WASM
if [ $WASM -eq 1 ]; then

  echo "============================================="
  echo "Compiling ${FILE} to C"
  echo "============================================="

  # Clean previous compilation results
  (rm -Rf ${PATH_TO_C_ASSETS})
  (rm -Rf "./dist/${NAME}.wasm")

  (
    # Compile Nim to C
    ${NIM} \
    -c \
    --cc: ${CC} \
    --os: linux \
    --gc: arc \
    --cpu: wasm32 \
    --app: lib \
    --opt: speed \
    --noMain: on \
    --threads: off \
    --stackTrace: off \
    --exceptions: goto \
    --d: cpu32 \
    --d: wasm \
    --d: release \
    --d: useMalloc \
    --d: noSignalHandler \
    --nimcache: ${PATH_TO_C_ASSETS} \
    c ${FILE}

    # Link nimbase.h
    ln -sf ${NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h
  )

  echo "============================================="
  echo "Compiling C with Emscripten"
  echo "============================================="

  (
    # -s MALLOC=emmalloc-verbose \
    # -g \

    # Compile C to Wasm
    ${EMSCRIPTEN} \
    ${OPTIMIZE} \
    -s PURE_WASI=1 \
    -s IMPORTED_MEMORY=1 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s STRICT=0 \
    -s MODULARIZE=0 \
    -s EXPORT_ES6=0 \
    -s ASSERTIONS=0 \
    -s MAIN_MODULE=0 \
    -s RELOCATABLE=0 \
    -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
    --no-entry \
    -o "dist/${NAME}.wasm" \
    $(c_files)

    # Create output folder
    mkdir -p dist
    # Move artifacts
    # mv my-module.{js,wasm} dist
  )

  echo "============================================="
  echo "Compiling done"
  echo "============================================="

else # NATIVE (not WASM)

  echo "============================================="
  echo "Compiling ${FILE} to C"
  echo "============================================="

  # Clean previous compilation results
  (rm -Rf ${PATH_TO_C_ASSETS})
  (rm -Rf "./dist/${NAME}")

  (
    # --os: any \
    # --app: lib \
    # --noMain: on \
    # --stackTrace: off \
    # --exceptions: goto \

    # Compile Nim to C
    ${NIM} \
    -c \
    --cc: ${CC} \
    --gc: arc \
    --opt: speed \
    --threads: off \
    --d: release \
    --nimcache: ${PATH_TO_C_ASSETS} \
    c ${FILE}

    # Link nimbase.h
    ln -sfw ${NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h
  )

  echo "============================================="
  echo "Compiling C"
  echo "============================================="

  (
    # Compile C
    ${CC} \
    ${OPTIMIZE} \
    -o "dist/${NAME}" \
    $(c_files)

    # Create output folder
    mkdir -p dist
    # Move artifacts
    # mv my-module.{js,wasm} dist
  )

  echo "============================================="
  echo "Compiling done"
  echo "============================================="

fi