import std/[tables, strutils, sequtils]
import ../src/[test_utils]
import ../src/persistent/[sumtree]

proc main* =
  suite "sumtree":
    test "clone":
      var v1 = init_vec[int]()
      var v2 = v1.clone()
      check v1 == v2
    test "simple append":
      var
        v1 = init_vec[int]()
        v2 = v1.push(0)
      check v1 != v2
      check v1.len == 0
      check v2.len == 1
    test "push and iterator pairs":
      var
        v1 = init_vec[int]().push(10).push(11).push(12).push(13).push(14).push(15)
        s = toSeq(v1.pairs)
      check s == @[(0, 10), (1, 11), (2, 12), (3, 13), (4, 14), (5, 15)]
    test "push and iterator items":
      var
        v1 = init_vec[int]().push(10).push(11).push(12).push(13).push(14).push(15)
        s = toSeq(v1.items)
      check s == @[10, 11, 12, 13, 14, 15]
    test "push_front and iterator pairs":
      var
        v1 = init_vec[int]().push_front(10).push_front(11).push_front(12).push_front(13)
        s = toSeq(v1.pairs)
      check s == @[(0, 13), (1, 12), (2, 11), (3, 10)]
    test "push_front and iterator items":
      var
        v1 = init_vec[int]().push_front(10).push_front(11).push_front(12).push_front(13)
        s = toSeq(v1.items)
      check s == @[13, 12, 11, 10]
    test "simple equality":
      var
        v1 = init_vec[int]()
        v2 = v1.push(1)
        v3 = v1.push(1)
      check v2 == v3

