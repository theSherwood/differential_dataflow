import std/[unittest, bitops]
import dida

proc main =
  suite "foo":
    test "bar":
      check 1 == get_one()
      check @[1, 2, 3] == @[1, 2, 3]
      check bitand(0b010, 0b011) == 0b010
      # check 2 == get_one()

main()
