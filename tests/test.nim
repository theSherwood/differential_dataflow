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
      check f3.as_f64 == 3.45
      check -99.156 == f4.as_f64
      check (3.45).as_v == f3.as_v
      check (-99.156).as_v == f4.as_v
  suite "map":
    test "immutable updates":
      var
        m1 = init_map()
        m2 = init_map()
      check m1 == m2
      var m3 = m1.set(1.0, 3.0)
      check m3 != m1
      check m3 != m2
      check m1 == m2
      check m3.size == 1
      check m3.get(1.0) == 3.0
      var m4 = m3.del(1.0)
      check m4 != m3
      check m3 != m1
      check m4 == m1
    test "nil":
      var
        m1 = init_map()
        m2 = m1.set(1.0, 3.0)
        m3 = m2.set(1.0, Nil.as_v)
        m4 = m1.del(1.0)
      check m2.size == 1
      check m3.size == 0
      check m3 == m1
      check m3 == m4
      check m3.get(1.0) == Nil.as_v
      check m4.get(1.0) == Nil.as_v
  suite "foo":
    test "bar":
      check 1 == get_one()
      check @[1, 2, 3] == @[1, 2, 3]
      check bitand(0b010, 0b011) == 0b010
      # check 2 == get_one()

main()
