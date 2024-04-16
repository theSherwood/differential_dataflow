#!/bin/bash

__help_string="
Usage:
  $(basename $0) -tru native node browser  # runs tests natively, in node (wasm), in browser (wasm)
  $(basename $0) -t native                 # builds tests for native
  $(basename $0) -bru                      # runs benchmarks natively and in node (wasm), against js

Options:
  -? -h --help         Print this usage information.
  -r --run             Run the compiled output.
  -u --user_settings   Use user_settings.sh to setup variables.
  -t --test            Test.
  -b --bench           Benchmark (accepts no positional arguments).
"

RUN=0
TEST=0
BENCHMARK=0
USER_SETTINGS=0

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "h?rtbu" opt; do
  case "$opt" in
    h|\?)
      echo "$__help_string"
      exit 0
      ;;
    r) RUN=1 ;;
    t) TEST=1 ;;
    b) BENCHMARK=1 ;;
    u) USER_SETTINGS=1 ;;
    -)
      case "${OPTARG}" in
        help)
          echo "$__help_string"
          exit 0
          ;;
        run           ) RUN=1 ;;
        test          ) TEST=1 ;;
        bench         ) BENCHMARK=1 ;;
        user_settings ) USER_SETTINGS=1 ;;
        *)
          echo "Invalid option: --$OPTARG"
          exit 1
          ;;
      esac
      ;;
  esac
done

shift $((OPTIND-1))

if [ $TEST -eq 1 ] && [ $BENCHMARK -eq 1 ]; then
  echo "Invalid: We currently do not support running -b and -t together."
  exit 1
fi

FILE=""
NAME=""
if [ $TEST -eq 1 ]; then
  export FILE="tests/test.nim"
  export NAME="test"
elif [ $BENCHMARK -eq 1 ]; then
  export FILE="benchmark/benchmark.nim"
  export NAME="benchmark"
fi

native_built=0
wasm_built=0

build_native() {
  if [ $TEST -eq 1 ]; then
    native_built=1
    opt_str="-"
    if [ $USER_SETTINGS -eq 1 ]; then opt_str+="u"; fi
    if [ $OPTIMIZE -eq 1 ]; then opt_str+="o"; fi
    if [[ opt_str = "-" ]]; then opt_str=""; fi
    (./scripts/build.sh -f "${FILE}" -n "${NAME}" "${opt_str}")
  elif [ $BENCHMARK -eq 1 ]; then
    native_built=1
    opt_str="-o"
    if [ $USER_SETTINGS -eq 1 ]; then opt_str+="u"; fi
    (./scripts/build.sh -f "${FILE}" -n "${NAME}" "${opt_str}")
  else
    echo "TODO"
  fi
}

build_wasm() {
  if [ $TEST -eq 1 ] || [ $BENCHMARK -eq 1 ]; then
    wasm_built=1
    opt_str="-wo"
    if [ $USER_SETTINGS -eq 1 ]; then opt_str+="u"; fi
    (./scripts/build.sh -f "${FILE}" -n "${NAME}" "${opt_str}")
  else
    echo "TODO"
  fi
}

positional_args=("$@")

if [ $BENCHMARK -eq 1 ]; then
  if [ ${#positional_args[@]} -gt 0 ]; then
      echo "Invalid: When -b is passed, no positional arguments are accepted."
      exit 1
  fi
  build_native
  build_wasm
  if [ $RUN -eq 1 ]; then
    # run native
    ("./dist/${NAME}")
    # run wasm in node
    (node --experimental-default-type=module benchmark/node_glue.js "./dist/${NAME}.wasm")
    # run js
    (node --experimental-default-type=module benchmark/benchmark.js)
    # Create a report from the individual results
    (node --experimental-default-type=module benchmark/report.js)
    exit 0
  fi

else

  for arg in "$positional_args"
  do
    case "$arg" in
      native)
        if [ $native_built -eq 0 ]; then build_native; fi
        if [ $RUN -eq 1 ] && [ $native_built -eq 1 ]; then
          echo "============================================="
          echo "Running native"
          echo "============================================="
          ("./dist/${NAME}")
        fi
        ;;
      node)
        if [ $wasm_built -eq 0 ]; then build_wasm; fi
        if [ $RUN -eq 1 ] && [ $wasm_built -eq 1 ]; then
          echo "============================================="
          echo "Running wasm in node"
          echo "============================================="
          (node --experimental-default-type=module src/node_glue.js "./dist/${NAME}.wasm")
        fi
        ;;
      browser)
        if [ $wasm_built -eq 0 ]; then build_wasm; fi
        if [ $RUN -eq 1 ] && [ $wasm_built -eq 1 ]; then
          echo "============================================="
          echo "Running wasm in browser"
          echo "============================================="
          # pass the wasm path to the webpage
          export VITE_WASM_PATH="./dist/${NAME}.wasm"
          (npm run start)
        fi
        ;;
      *)
        echo "Unrecognized arg: ${arg}"
        exit 1
        ;;
    esac
  done

fi