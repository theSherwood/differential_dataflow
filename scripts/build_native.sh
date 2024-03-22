#!/bin/bash

set -e

# The following variables are needed:
#
# - NIMBASE
# - NIM
# - CC
#

export PATH_TO_C_ASSETS="./nimcache/dist_native"
export C_ENTRY_FILE="${PATH_TO_C_ASSETS}/@mdida.nim.c"

export OPTIMIZE="-Os"
export LDFLAGS="${OPTIMIZE}"
export CFLAGS="${OPTIMIZE}"
export CXXFLAGS="${OPTIMIZE}"

echo "============================================="
echo "Compiling nim to c"
echo "============================================="

(
  # Clean previous compilation results
  rm -Rf ${PATH_TO_C_ASSETS}

  # Compile Nim to C
  ${NIM} \
  -c \
  --os:any \
  --cpu:wasm32 \
  --threads:off \
  --app:lib \
  --cc:${CC} \
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
  c src/dida.nim

  # Link nimbase.h
  ln -sfw ${NIMBASE} ${PATH_TO_C_ASSETS}/nimbase.h
)

echo "============================================="
echo "Compiling done"
echo "============================================="