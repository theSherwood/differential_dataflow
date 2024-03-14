import std/[unittest, bitops]
import values

proc main =
  suite "float":
    test "simple":
      var
        f1 = init_float()
        f2 = init_float()
      check f1 == f2
      check f1 == 0.float64
      check 0.float64 == f2
      var
        f3 = init_float(3.45)
        f4 = init_float(-99.156)
      check f3 != f4
      check f3.to_f64 == 3.45
      check -99.156 == f4.to_f64
      check to_imsv(3.45).ImFloat == f3
      check to_imsv(-99.156).ImFloat == f4
      check to_imsv(3.45) == f3.ImStackValue
      check to_imsv(-99.156) == f4.ImStackValue
  suite "map":
    test "simple":
      var
        m1 = init_map()
        m2 = init_map()
      check m1 == m2
      var
        m3 = m1.set(to_v(1.0), (3.0).to_v)
  suite "foo":
    test "bar":
      check 1 == get_one()
      check @[1, 2, 3] == @[1, 2, 3]
      check bitand(0b010, 0b011) == 0b010
      # check 2 == get_one()

main()
