#!/bin/bash

set -e

# The following variables are needed:
#
# - EMSCRIPTEN
# - NIMBASE
# - NIM
#

export PATH_TO_C_ASSETS="./nimcache/tests_wasm"
export C_ENTRY_FILE="@mtest.nim.c"
export C_ENTRY_FILE_PATH="${PATH_TO_C_ASSETS}/${C_ENTRY_FILE}"

export OPTIMIZE="-Os"
export LDFLAGS="${OPTIMIZE}"
export CFLAGS="${OPTIMIZE}"
export CXXFLAGS="${OPTIMIZE}"

echo "============================================="
echo "Compiling nim"
echo "============================================="

(
  # Clean previous compilation results
  rm -Rf ${PATH_TO_C_ASSETS}

  # Compile Nim to C
  ${NIM} \
  -c \
  --os:linux \
  --cpu:wasm32 \
  --threads:off \
  --app:lib \
  --cc:${CC} \
  --gc:arc \
  --noMain:on \
  --stackTrace:off \
  --exceptions:goto \
  --opt:speed \
  --d:cpu32 \
  --d:wasm \
  --d:release \
  --d:useMalloc \
  --d:noSignalHandler \
  --nimcache:${PATH_TO_C_ASSETS} \
  c tests/test.nim

  # Link nimbase.h
  ln -sfw ${NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h
)

echo "============================================="
echo "Compiling wasm with Emscripten"
echo "============================================="

# Get all the c files other than the entry file in a list
c_libs=()
for file in ${PATH_TO_C_ASSETS}/*.c
do
  ! [[ -e "$file" ]] || [[ "$file" = ${C_ENTRY_FILE_PATH} ]] || c_libs+=("$file")
done
# echo "${c_libs[@]}"

(
  # -s MALLOC=emmalloc-verbose \
  # -g \

  # Compile C to Wasm
  ${EMSCRIPTEN} \
  ${OPTIMIZE} \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s IMPORTED_MEMORY=1 \
  -s STRICT=0 \
  -s PURE_WASI=1 \
  -s MODULARIZE=0 \
  -s EXPORT_ES6=0 \
  -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
  -s ASSERTIONS=0 \
  -s MAIN_MODULE=0 \
  -s RELOCATABLE=0 \
  --no-entry \
  -o out.wasm \
  "${c_libs[@]}" \
  ${C_ENTRY_FILE_PATH}

  # Create output folder
  # mkdir -p dist
  # Move artifacts
  # mv my-module.{js,wasm} dist
)

echo "============================================="
echo "Compiling wasm done"
echo "============================================="