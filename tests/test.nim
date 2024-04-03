from ../src/test_utils import failures
from values import nil
from dida_from_python import nil

# Run tests
values.main()
dida_from_python.main()

when defined(wasm):
  if failures > 0: raise newException(AssertionDefect, "Something failed.")