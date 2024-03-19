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
      check n3 == 3.45
      check -99.156 == n4

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
        m3 = m2.set(1.0, Nil.v)
        m4 = m1.del(1.0)
      check m2.size == 1
      check m3.size == 0
      check m3 == m1
      check m3 == m4
      check m3.get(1.0) == Nil.v
      check m4.get(1.0) == Nil.v

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
      check s3[0] == init_string("s").v
      check s3[0] != init_string("n").v
    test "concat":
      var
        s1 = init_string("foobar")
        s2 = init_string("foo")
      check s1 != s2
      var s3 = s2.concat(init_string("bar"))
      var s4 = s2 & init_string("bar")
      check s3 != s2
      check s3 == s1
      check s4 == s3

  suite "array":
    test "get":
      var a1 = init_array(@[1.0.v, 3.0.v, 9.7.v])
      check a1.size == 3
      check a1[0] == 1.0.v
      check a1[100] == Nil.v
    test "set":
      var
        a1 = init_array(@[1.0.v, 3.0.v, 9.7.v])
        a2 = a1.set(1, 11.5.v)
        a3 = a2.set(1, 3.0.v)
      check a1 != a2
      check a2 != a3
      check a1 == a3
      check a1[0] == a2[0]
      check a1[2] == a2[2]
      check a1.size == 3
      check a2.size == 3
      check a1[1] == 3.0.v
      check a2[1] == 11.5.v
    test "concat":
      var
        a1 = init_array(@[1.0.v, 2.0.v, 3.0.v])
        a3 = a1.concat(a1)
        a4 = a1 & a1
      check a3 == a4
      check a3.size == 6

  suite "set":
    test "simple":
      var
        s1 = init_set()
        s2 = init_set()
      check s1 == s2
      check s1.has(1.0) == False
    test "add and del":
      var
        s1 = init_set()
        s2 = s1.add(3.0.v)
        s3 = s1.add(3.0.v)
      check s1 != s2
      check s2 == s3
      check s1.size == 0
      check s2.size == 1
      check s3.size == 1
      var
        s4 = s1.del(3.0.v)
        s5 = s2.del(3.0.v)
        s6 = s3.del(3.0.v)
      check s4 == s1
      check s5 == s1
      check s6 == s1
      check s5 != s2
      check s6 != s3
      check s5.size == 0
      check s6.size == 0


main()
