import std/[bitops]
import test_utils
import values

proc main =
  suite "number":
    test "simple":
      var
        n1 = init_number()
        n2 = init_number()
      check n1 == n2
      check n1 == 0.float64
      check 0.float64 == n2
      var
        n3 = init_number(3.45)
        n4 = init_number(-99.156)
      check n3 != n4
      check n3.as_f64 == 3.45
      check -99.156 == n4.as_f64
      check (3.45).as_v == n3.as_v
      check (-99.156).as_v == n4.as_v

  suite "map":
    test "immutable updates":
      var
        m1 = init_map()
        m2 = init_map()
      check m1 == m2
      check m1.size == 0
      check m2.size == 0
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

  if false:
    suite "string":
      test "simple":
        var
          s1 = init_string("some string")
          s2 = init_string(" and more")
        echo "here11"
        check s1.size == 11
        check s2.size == 9
        check s1 != s2
        echo "here12"
        var s3 = s1.concat(s2)
        check s3.size == 20
        check s3 == init_string("some string and more")
        echo "here13"
        check s3[0] == init_string("s").as_v
        # FIX - on 64-bit systems the ref of the payload (tail) is trampling everything
        check s3[0] != init_string("n").as_v
        echo "here14"

main()
