from ../src/test_utils import failures
from dida_from_python import nil

# Run tests
dida_from_python.main()

when defined(wasm):
  if failures > 0: raise newException(AssertionDefect, "Something failed.")
