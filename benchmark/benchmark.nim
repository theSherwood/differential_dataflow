
when defined(wasm):
  proc get_time(): int {.importc.}
  proc random_f64(): float64 {.importc.}
else:
  discard