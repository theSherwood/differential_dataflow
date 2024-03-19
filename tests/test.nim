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

  suite "string":
    test "simple":
      var
        s1 = init_string("some string")
        s2 = init_string(" and more")
      check s1.size == 11
      check s2.size == 9
      check s1 != s2
      var s3 = s1.concat(s2)
      check s3.size == 20
      check s3 == init_string("some string and more")
      check s3[0] == init_string("s").as_v
      check s3[0] != init_string("n").as_v
    test "concat":
      var
        s1 = init_string("foobar")
        s2 = init_string("foo")
      check s1 != s2
      var s3 = s2.concat(init_string("bar"))
      check s3 != s2
      check s3 == s1

  suite "array":
    test "get":
      var a1 = init_array(@[1.0.as_v, 3.0.as_v, 9.7.as_v])
      check a1.size == 3
      check a1[0] == 1.0.as_v
      check a1[100] == Nil.as_v
    test "set":
      var
        a1 = init_array(@[1.0.as_v, 3.0.as_v, 9.7.as_v])
        a2 = a1.set(1, 11.5.as_v)
        a3 = a2.set(1, 3.0.as_v)
      check a1 != a2
      check a2 != a3
      check a1 == a3
      check a1[0] == a2[0]
      check a1[2] == a2[2]
      check a1.size == 3
      check a2.size == 3
      check a1[1] == 3.0.as_v
      check a2[1] == 11.5.as_v

main()
