import std/[tables, strutils, sequtils]
import ../src/[test_utils]
import ../src/persistent/[vec]
# import ../src/persistent/[sumtree]

## 
## TODO
## 
## API
## [x] to_vec
## [x] concat
## [ ] del
## [ ] slice
## [ ] take
## [ ] drop
## [ ] set_len
## [ ] insert
## [ ] splice
## [ ] map
## [ ] filter
## [ ] reverse
## [ ] transient mutation
## 
## Impl
## [ ] get ImArray to use this
## [ ] add hash to pvec summary
## [ ] use `distinct` so that we can have monomorphic impls come after sumtree
##   - look at impl of https://github.com/Nycto/RBTreeNim/blob/master/src/rbtree.nim
## [ ] parameterize branch size and buffer size
##   - i'd like to benchmark different sizes
## [ ] top-level sumtree should not be a ref
## [ ] store cumulative size array on the sumtree node
## [ ] add validate fn for testing and debugging
## [ ] transients
## 
## Test
## [ ] all the APIs
## [ ] much larger sizes
## [ ] sparse arrays
## 

proc main* =
  suite "persistent vec":
    test "clone":
      var v1 = init_vec[int]()
      var v2 = v1.clone()
      check v1.valid
      check v2.valid
      check v1 == v2
    test "simple append":
      var
        v1 = init_vec[int]()
        v2 = v1.push(0)
      check v1.valid
      check v2.valid
      check v1 != v2
      check v1.len == 0
      check v2.len == 1
    test "push":
      proc push_test(sz: int) =
        var v = init_vec[int]()
        for i in 0..<sz:
          v = v.push(i)
        check v.valid
        check v.len == sz
        check toSeq(v.items) == toSeq(0..<sz)
      var sizes = [1, 10, 100, 1_000, 10_000, 100_000]
      for sz in sizes:
        push_test(sz)
    test "prepend":
      proc push_test(sz: int) =
        var v = init_vec[int]()
        for i in 0..<sz:
          v = v.prepend(i)
        check v.valid
        check v.len == sz
        check toSeq(v.items) == toSeq(countdown(sz - 1, 0))
      var sizes = [1, 10, 100, 1_000, 10_000, 100_000]
      for sz in sizes:
        push_test(sz)
    test "push and iterator pairs":
      var
        v1 = init_vec[int]().push(10).push(11).push(12).push(13).push(14).push(15)
        s = toSeq(v1.pairs)
      check v1.valid
      check s == @[(0, 10), (1, 11), (2, 12), (3, 13), (4, 14), (5, 15)]
    test "push and iterator items":
      var
        v1 = init_vec[int]().push(10).push(11).push(12).push(13).push(14).push(15)
        s = toSeq(v1.items)
      check v1.valid
      check s == @[10, 11, 12, 13, 14, 15]
    test "push_front and iterator pairs":
      var
        v1 = init_vec[int]().push_front(10).push_front(11).push_front(12).push_front(13)
        s = toSeq(v1.pairs)
      check v1.valid
      check s == @[(0, 13), (1, 12), (2, 11), (3, 10)]
    test "push_front and iterator items":
      var
        v1 = init_vec[int]().push_front(10).push_front(11).push_front(12).push_front(13)
        s = toSeq(v1.items)
      check v1.valid
      check s == @[13, 12, 11, 10]
    test "to_vec":
      proc to_vec_test(size: int) =
        var
          s = toSeq(0..<size)
          v = to_vec(s)
        check v.valid
        check toSeq(v) == s
      to_vec_test(0)
      to_vec_test(1)
      to_vec_test(10)
      to_vec_test(100)
      to_vec_test(1000)
      to_vec_test(10000)
      to_vec_test(100000)
      to_vec_test(1000000)
      # to_vec_test(10000000)
    test "to_vec internals":
      check [0].to_vec.depth_safe == 0
      check [1, 2, 3, 4, 5, 6].to_vec.depth_safe == 0
      check [0].to_vec.kind == kLeaf
      check [1, 2, 3, 4, 5, 6].to_vec.kind == kLeaf
      check toSeq(0..<100).to_vec.valid
    test "get":
      proc get_test(sz: int) =
        var
          offset = 5
          v = to_vec(toSeq(offset..<(sz + offset)))
        check v.valid
        for i in 0..<sz:
          var res = v.get(i) == i + offset
          check res
      var sizes = [1, 10, 100, 1_000, 10_000, 100_000]
      for sz in sizes:
        get_test(sz)
    test "set":
      proc set_test(sz: int) =
        var
          offset = 5
          offset_seq = toSeq(offset..<(sz + offset))
          v = to_vec(toSeq(0..<sz))
        check v.valid
        for i in 0..<sz:
          v = v.set(i, i + offset)
        check toSeq(v.items) == offset_seq
      var sizes = [1, 10, 100, 1_000, 10_000, 100_000]
      for sz in sizes:
        set_test(sz)
    test "simple equality":
      var
        v1 = init_vec[int]()
        v2 = v1.push(1)
        v3 = v1.push(1)
      check v1.valid
      check v2.valid
      check v3.valid
      check v2 == v3
    test "concat":
      proc concat_test(sz1, sz2: int) =
        var
          s1 = toSeq(0..<sz1)
          s2 = toSeq(0..<sz2)
          v1 = to_vec(s1)
          v2 = to_vec(s2)
        check v1.valid
        check v2.valid
        check toSeq(v1 & v2) == s1 & s2
      var sizes = @[0, 1, 10, 100, 1_000, 10_000]
      for sz1 in sizes:
        for sz2 in sizes:
          concat_test(sz1, sz2)
    test "vec hashes":
      var
        v1 = [1, 2, 3, 4, 5, 6].to_vec
        v2 = [1, 2, 3, 4, 5, 6].to_vec
        v3 = [6, 5, 4, 3, 2, 1].to_vec
      check v1.valid
      check v2.valid
      check v3.valid
      check v1 == v2
      check v1 != v3
    test "pop":
      var
        v1 = [1, 2, 3, 4, 5, 6].to_vec
        (v2, six) = v1.pop()
      check v2.size == 5
      check six == 6
  
  echo "done"
