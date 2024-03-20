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
      check not(1.0 in m3)
      check not(1.0 in m4)
      check 1.0 in m2
    test "init":
      var m1 = init_map([(1.0.v, 3.0.v), (4.5.v, 13.5.v)])
      check m1.size == 2
      check m1[4.5.v] == 13.5.v
    test "init with duplicates":
      var
        m1 = init_map([(1.0.v, 3.0.v), (4.5.v, 13.5.v), (4.5.v, 15.5.v)])
        m2 = init_map([(1.0.v, 3.0.v), (4.5.v, 15.5.v)])
      check m1.size == 2
      check m1[4.5.v] == 15.5.v
      check m1 == m2
    test "init with Nil values":
      var
        m1 = init_map([(1.0.v, Nil.v), (4.5.v, 13.5.v), (4.5.v, Nil.v)])
        m2 = init_map()
      check m1 == m2
    test "merge":
      var
        m1 = init_map([(1.0.v, 3.0.v), (4.5.v, 13.5.v)])
        m2 = init_map([(1.0.v, 5.0.v), (5.5.v, 13.5.v)])
        m3 = m1 & m2
        m4 = m2 & m1
        m5 = m1 & m1
      check m3.size == 3
      check m4.size == 3
      check m3 != m4
      check m3[1.0.v] == 5.0.v
      check m4[1.0.v] == 3.0.v
      check m5 == m1
    test "nested":
      var
        m1 = init_map()
        m2 = init_map([(1.0.v, 5.0.v), (5.5.v, 13.5.v)])
        m3 = init_map([(init_string("foo").v, init_string("bar").v)])
        m4 = init_map([(m1.v, m2.v), (Nil.v, m3.v)])
      check m4[m1.v] == m2.v
      check m4[Nil.v] == m3.v
      check m4[m2.v] == Nil.v
      var m5 = m4.set(m4.v, m2.v)
      check m5.size == m4.size + 1
      check m5.get(m4.v) == m2.v
      check m5[m4.v].as_map[1.0.v] == 5.0.v

  suite "array":
    test "init":
      var
        a1 = init_array(@[])
        a2 = init_array([])
        a3 = init_array()
      check a1 == a2
      check a3 == a2
    test "get":
      var a1 = init_array(@[1.0.v, 3.0.v, 9.7.v])
      check a1.size == 3
      check a1[0] == 1.0.v
      check a1[100] == Nil.v
      check a1[1.0] == 3.0
      check a1[2.0] == 9.7
      check a1[3.0] == Nil.v
    test "set":
      var
        a1 = init_array([1.0.v, 3.0.v, 9.7.v])
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
    test "nested":
      var
        a1 = init_array([1.0.v, 2.0.v])
        a2 = init_array([a1.v, a1.v, 3.0.v])
        a3 = a2.set(0, a2.v)
      check a3[0].v == a2.v
      check a2[0] == a2[1]
      check a2[0].as_arr[0] == 1.0.v

  suite "set":
    test "simple":
      var
        s1 = init_set()
        s2 = init_set([])
      check s1 == s2
      check s1.has(1.0) == False
    test "init":
      var
        s1 = init_set([1.0.v, 2.0.v, 3.0.v, 3.0.v, 2.0.v, 1.0.v])
        s2 = init_set([1.0.v, 2.0.v, 3.0.v])
      check s1.size == 3
      check s1 == s2
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
    test "nested":
      var
        s1 = init_set()
        s2 = init_set([3.0.v, s1.v, s1.v])
        s3 = init_set([s1.v, s2.v, 4.0.v])
        s4 = s3.add(s3.v)
        s5 = s4.del(s2.v)
      check s2.size == 2
      check s1.v in s2
      check s1.v in s3
      check s2.v in s3
      check s3.v in s4
      check not(s2.v in s5)

  suite "mixed nesting":
    test "simple":
      var
        m1 = init_map([(1.0.v, 2.0.v)])
        a1 = init_array([m1.v, m1.v])
        s1 = init_set([m1.v, a1.v])
        m2 = init_map([(m1.v, s1.v), (a1.v, m1.v), (s1.v, a1.v)])
        a2 = init_array([m1.v, a1.v, s1.v, m2.v])
        s2 = init_set([m1.v, a1.v, s1.v, m2.v, a2.v])
      check get_in(s2.v, [s2.v, m2.v]) == Nil.v
      check get_in(s2.v, [a2.v]) == a2.v
      check get_in(s2.v, [a2.v, 3.0.v]) == m2.v
      check get_in(s2.v, [a2.v, 3.0.v, s1.v]) == a1.v 
      check get_in(s2.v, [a2.v, 3.0.v, s1.v, 1.0.v]) == m1.v
      check get_in(s2.v, [a2.v, 3.0.v, s1.v, 1.0.v, 1.0.v]) == 2.0.v

main()
