#!/bin/bash

set -e


# The following variables are needed:
#
# - NIMBASE
# - NIM
# - CC
#

export PATH_TO_C_ASSETS="./nimcache/tests_native"

(
  # Clean previous compilation results
  rm -Rf ${PATH_TO_C_ASSETS}
  # --os: macosx \

  ${NIM} \
  r \
  --threads: off \
  --cc: ${CC} \
  --stackTrace: on \
  --d: release \
  --multimethods: on \
  --nimcache:${PATH_TO_C_ASSETS} \
  tests/test.nim
)

