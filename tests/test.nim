from ../src/test_utils import failures
from differential_dataflow import nil

# Run tests
differential_dataflow.main()

when defined(wasm):
  if failures > 0: raise newException(AssertionDefect, "Something failed.")
