import std/[unittest]
import dida

proc main =
  suite "foo":
    test "bar":
      check 1 == get_one()
      check 2 == get_one()

main()
