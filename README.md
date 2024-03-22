# differential_dataflow

## Compile

### Build Wasm

```sh
./run.sh -wu
```

OR

```sh
wach -o "src/**" "./run.sh -wu"
```

## Test

### Test Native

```sh
./run.sh -tu
```

OR

```sh
wach ./run.sh -tu
```

OR (to compile the test in wasm)

### Test Wasm

```sh
wach -o "src/**" "./run.sh -utw"
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