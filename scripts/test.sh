#!/bin/bash

set -e

# The user settings exports some variables with paths to be configured per user.
#
# - PATH_TO_NIM
#
# At some point, move to a dockerized or otherwise reproducible build system.
source "scripts/build_user_settings.sh"

(
  ${PATH_TO_NIM} \
  r \
  --os: macosx \
  --threads: off \
  --cc: gcc \
  --stackTrace: on \
  --d: release \
  --multimethods: on \
  tests/test.nim
)

