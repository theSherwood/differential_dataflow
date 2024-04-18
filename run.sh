#!/bin/bash

__help_string="
Usage:
  $(basename $0) -tru native node browser  # runs tests natively, in node (wasm), in browser (wasm)
  $(basename $0) -t native                 # builds tests for native
  $(basename $0) -bru                      # runs benchmarks native, wasm, and js
  $(basename $0) -bru native js            # runs benchmarks native and js
  $(basename $0) -bru native wasm          # runs benchmarks native and wasm

Options:
  -? -h --help         Print this usage information.
  -r --run             Run the compiled output.
  -u --user_settings   Use user_settings.sh to setup variables.
  -t --test            Test. Accepts positional args [native node browser].
  -b --bench           Benchmark Accepts positional args [native wasm js].
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
  
  run_native=0
  run_wasm=0
  run_js=0

  if [ $RUN -eq 1 ]; then
    # delete previous partial reports
    node --experimental-default-type=module benchmark/cleanup.js
  fi

  # default to benchmarking native, wasm, and js
  if [ ${#positional_args[@]} -eq 0 ]; then
    positional_args=("native" "wasm" "js")
  fi

  # Build in parallel
  for arg in "${positional_args[@]}"
  do
    case "$arg" in
      native)
        if [ $native_built -eq 0 ]; then
          build_native &
        fi
        run_native=1
        ;;
      wasm)
        if [ $wasm_built -eq 0 ]; then 
          build_wasm &
        fi
        run_wasm=1
        ;;
      js)
        run_js=1
        ;;
      *)
        echo "Unrecognized arg: ${arg}"
        exit 1
        ;;
    esac
  done

  # Wait for the builds to complete
  wait

  if [ $RUN -eq 1 ]; then
    # Run the benchmarks in parallel
    if [ $run_native -eq 1 ]; then
      "./dist/${NAME}" &
    fi
    if [ $run_wasm -eq 1 ]; then
      node --experimental-default-type=module benchmark/node_glue.js "./dist/${NAME}.wasm" &
    fi
    if [ $run_js -eq 1 ]; then
      node --experimental-default-type=module benchmark/benchmark.js &
    fi
    # Wait for the benchmarks to run
    wait
    # Create a report from the individual results
    node --experimental-default-type=module benchmark/report.js
    exit 0
  fi

else

  run_native=0
  run_node=0
  run_browser=0

  default to benchmarking native, wasm, and js
  if [ ${#positional_args[@]} -eq 0 ]; then
    positional_args=("native" "node")
  fi

  # Build in parallel
  for arg in "${positional_args[@]}"
  do
    case "$arg" in
      native)
        if [ $native_built -eq 0 ]; then
          build_native &
        fi
        run_native=1
        ;;
      node)
        if [ $wasm_built -eq 0 ]; then
          build_wasm &
        fi
        run_node=1
        ;;
      browser)
        if [ $wasm_built -eq 0 ]; then
          build_wasm &
        fi
        run_browser=1
        ;;
      *)
        echo "Unrecognized arg: ${arg}"
        exit 1
        ;;
    esac
  done

  # Wait for the builds to complete
  wait

  if [ $RUN -eq 1 ]; then
    if [ $run_native -eq 1 ]; then
      echo "== Running native ==========================="
      "./dist/${NAME}"
    fi
    if [ $run_node -eq 1 ]; then
      echo "== Running wasm in node ====================="
      node --experimental-default-type=module src/node_glue.js "./dist/${NAME}.wasm"
    fi
    if [ $run_browser -eq 1 ]; then
      echo "== Running wasm in browser =================="
      # pass the wasm path to the webpage
      export VITE_WASM_PATH="./dist/${NAME}.wasm"
      npm run start
    fi
    exit 0
  fi


fi