# differential_dataflow

## Compile

```sh
./build_wasm.sh
```

OR

```sh
wach -o "src/**" "./build_wasm.sh"
```

## Start the server

```sh
dev start
```

# Run the code natively

```sh
nim r --os: macosx --threads: off --cc: gcc --stackTrace: on --d: debug TODO.nim
```