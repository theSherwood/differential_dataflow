from ../src/test_utils import failures
from vec import nil
from sumtree import nil
from values import nil
from dida_from_python import nil

# Run tests
vec.main()
# sumtree.main()
# values.main()
# dida_from_python.main()

when defined(wasm):
  if failures > 0: raise newException(AssertionDefect, "Something failed.")