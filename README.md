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
wach scripts/test.sh
```

## Start the server

```sh
dev start
```

# Run the code natively

```sh
nim r --os: macosx --threads: off --cc: gcc --stackTrace: on --d: debug TODO.nim
```
