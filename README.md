# differential_dataflow

## Compile

```sh
scripts/build_wasm.sh
```

OR

```sh
wach -o "src/**" "scripts/build_wasm.sh"
```

## Test

```sh
scripts/test.sh
```

OR

```sh
wach scripts/test_native.sh
```

OR (to compile the test in wasm)

```sh
wach -o "src/**" scripts/test_wasm.sh
```

## Start the server

```sh
dev start
```

## Run the code natively

```sh
nim r --os: macosx --threads: off --cc: gcc --stackTrace: on --d: debug TODO.nim
```

## Run the compiled wasm

### Node

```sh
node --experimental-default-type=module src/run_wasm.js
```

### Browser

```sh
dev start
```

Then go to http://localhost:3000/