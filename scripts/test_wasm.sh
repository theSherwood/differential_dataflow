#!/bin/bash

set -e

# The user settings exports some variables with paths to be configured per user.
#
# - PATH_TO_EMSCRIPTEN
# - PATH_TO_NIMBASE
# - PATH_TO_NIM
#
# At some point, move to a dockerized or otherwise reproducible build system.
source "scripts/build_user_settings.sh"

export PATH_TO_C_ASSETS="./nimcache/wasm"
export C_ENTRY_FILE="${PATH_TO_C_ASSETS}/@mdida.nim.c"

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
  ${PATH_TO_NIM} \
  -c \
  --os:any \
  --cpu:wasm32 \
  --threads:off \
  --app:lib \
  --cc:clang \
  --gc:arc \
  --noMain:on \
  --stackTrace:off \
  --exceptions:goto \
  --opt:speed \
  --d:wasm \
  --d:release \
  --d:useMalloc \
  --d:noSignalHandler \
  --nimcache:${PATH_TO_C_ASSETS} \
  c tests/test.nim

  # Link nimbase.h
  ln -sfw ${PATH_TO_NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h
)

echo "============================================="
echo "Compiling wasm with Emscripten"
echo "============================================="

(
  # -s MALLOC=emmalloc-verbose \
  # -g \

  # Compile C to Wasm
  ${PATH_TO_EMSCRIPTEN} \
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
  ${PATH_TO_C_ASSETS}/[!@]*.c \
  ${C_ENTRY_FILE}

  # Create output folder
  # mkdir -p dist
  # Move artifacts
  # mv my-module.{js,wasm} dist
)

echo "============================================="
echo "Compiling wasm done"
echo "============================================="