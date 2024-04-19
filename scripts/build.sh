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
  -o --opt             Use compiler optimizations (-Os).
  -f FILE              Entry file (.nim).
  -n NAME              Name to use for outputs and C cache files.
"

echo "Command: $0 $@"

RUN=0
TARGET=""
USER_SETTINGS=0
OPTIMIZE=""
unset -v FILE
unset -v NAME

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
verbose=0

while getopts "h?rou-t:f:n:" opt; do
  case "$opt" in
    \?|h|help)
      echo "$__help_string"
      exit 0
      ;;
    r|run           ) RUN=1 ;;
    o|opt           ) OPTIMIZE="-Os" ;;
    t|target        ) TARGET=${OPTARG} ;;
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

if [ -z "$FILE" ] || [ -z "$NAME" ] || [ -z "$TARGET" ]; then
  echo 'Missing -f or -n or -t' >&2
  exit 1
fi

WASM32=0
WASM64=0
NATIVE=0

# normalize TARGET
if [ "$TARGET" == "w" ]; then TARGET="wasm32"; fi   # default to wasm32
if [ "$TARGET" == "w32" ]; then TARGET="wasm32"; fi
if [ "$TARGET" == "w64" ]; then TARGET="wasm64"; fi
if [ "$TARGET" == "n" ]; then TARGET="native"; fi
# validate TARGET
if [ "$TARGET" == "native" ]; then
  NATIVE=1
elif [ "$TARGET" == "wasm32" ]; then
  WASM32=1
elif [ "$TARGET" == "wasm64" ]; then
  WASM64=1
else
  echo "Invalid option argument for -t"
  echo "Valid arguments are 'native', 'wasm32', 'wasm64'"
  exit 1
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

echo "Path: $PATH_TO_C_ASSETS"

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

if [ $WASM32 -eq 1 ]; then

  echo "== Compiling Nim \"${FILE}\" to C to Wasm32 ="

  # Clean previous compilation results
  rm -Rf ${PATH_TO_C_ASSETS}
  rm -Rf "./dist/${NAME}_wasm32.wasm"

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
    --d: wasm32 \
    --d: release \
    --d: useMalloc \
    --d: noSignalHandler \
    --nimcache: ${PATH_TO_C_ASSETS} \
    c ${FILE}
  )

  # Link nimbase.h
  ln -sf ${NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h

  echo "== Compiling C to Wasm32 with Emscripten ===="

  (
    # -s MALLOC=emmalloc-verbose \
    # -g \
    # -s EXPORT_ES6=0 \
    # -s MODULARIZE=0 \

    # Compile C to Wasm32
    ${EMSCRIPTEN} \
    ${OPTIMIZE} \
    -s PURE_WASI=1 \
    -s IMPORTED_MEMORY=1 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s MEMORY64=0 \
    -s STRICT=0 \
    -s ASSERTIONS=0 \
    -s MAIN_MODULE=0 \
    -s RELOCATABLE=0 \
    -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
    --no-entry \
    -o "dist/${NAME}_wasm32.wasm" \
    $(c_files)
  )

  # Create output folder
  mkdir -p dist
  # Move artifacts
  # mv my-module.{js,wasm} dist

  echo "== Compiling to Wasm32 done ================="

elif [ $WASM64 -eq 1 ]; then

  echo "== Compiling Nim \"${FILE}\" to C to Wasm64 ="

  # Clean previous compilation results
  rm -Rf ${PATH_TO_C_ASSETS}
  rm -Rf "./dist/${NAME}_wasm64.wasm"

  (
    # Compile Nim to C
    ${NIM} \
    -c \
    --cc: ${CC} \
    --os: linux \
    --gc: arc \
    --app: lib \
    --opt: speed \
    --noMain: on \
    --threads: off \
    --stackTrace: off \
    --exceptions: goto \
    --d: wasm \
    --d: wasm64 \
    --d: release \
    --d: useMalloc \
    --d: noSignalHandler \
    --nimcache: ${PATH_TO_C_ASSETS} \
    c ${FILE}
  )

  # Link nimbase.h
  ln -sf ${NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h

  echo "== Compiling C to Wasm64 with Emscripten ===="

  (
    # -s MALLOC=emmalloc-verbose \
    # -g \
    # -s EXPORT_ES6=0 \
    # -s MODULARIZE=0 \

    # Compile C to Wasm64
    ${EMSCRIPTEN} \
    ${OPTIMIZE} \
    -s PURE_WASI=1 \
    -s IMPORTED_MEMORY=1 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s MEMORY64=2 \
    -s STRICT=0 \
    -s ASSERTIONS=0 \
    -s MAIN_MODULE=0 \
    -s RELOCATABLE=0 \
    -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
    --no-entry \
    -o "dist/${NAME}_wasm64.wasm" \
    $(c_files)
  )

  # Create output folder
  mkdir -p dist
  # Move artifacts
  # mv my-module.{js,wasm} dist

  echo "== Compiling to Wasm64 done ================="

elif [ $NATIVE -eq 1 ]; then

  echo "== Compiling Nim \"${FILE}\" to C ==========="

  # Clean previous compilation results
  rm -Rf ${PATH_TO_C_ASSETS}
  rm -Rf "./dist/${NAME}_native"

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
  )

  # Link nimbase.h
  ln -sf ${NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h

  echo "== Compiling C =============================="

  (
    # Compile C
    ${CC} \
    ${OPTIMIZE} \
    -o "dist/${NAME}_native" \
    $(c_files)

    # Create output folder
    mkdir -p dist
    # Move artifacts
    # mv my-module.{js,wasm} dist
  )

  echo "== Compiling C done ========================="

fi