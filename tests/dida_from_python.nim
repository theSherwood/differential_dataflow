import ../src/[test_utils, dida_from_python]

proc main* =
  suite "foo":
    check 1 == 2
