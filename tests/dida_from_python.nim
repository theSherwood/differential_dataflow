import ../src/[test_utils, dida_from_python, values]

template MSET*(rows: openArray[Row]): Multiset = init_multiset(rows)

template STR*(): ImValue = init_string().v
template STR*(s: string): ImValue = init_string(s).v
template ARR*(): ImValue = init_array().v
template ARR*(vs: openArray[ImValue]): ImValue = init_array(vs).v
template SET*(): ImValue = init_set().v
template SET*(vs: openArray[ImValue]): ImValue = init_set(vs).v
template MAP*(): ImValue = init_map().v
template MAP*(vs: openArray[(ImValue, ImValue)]): ImValue = init_map(vs).v

proc main* =
  suite "multiset":
    test "simple":
      var
        a = MSET([])
        b = MSET([])
        c = MSET([((0.0.v, 1.0.v), 1)])
      check a == b
      check a != c

    test "various":
      var
        a = MSET([
          ((STR"apple", STR"$5"), 2),
          ((STR"banana", STR"$2"), 1)
        ])
        b = MSET([
          ((STR"apple", STR"$3"), 1),
          ((STR"apple", ARR([STR"granny smith", STR"$2"])), 1),
          ((STR"kiwi", STR"$2"), 1)
        ])
        c = MSET([
          ((STR"apple", STR"$5"), 2),
          ((STR"banana", STR"$2"), 1),
          ((STR"apple", STR"$2"), 20),
        ])
        d = MSET([
          ((STR"apple", 11.0.v), 1),
          ((STR"apple", 3.0.v), 2),
          ((STR"banana", 2.0.v), 3),
          ((STR"coconut", 3.0.v), 1),
        ])
        # some results
        a_concat_b_result = MSET([
          ((STR"apple", STR"$5"), 2),
          ((STR"banana", STR"$2"), 1),
          ((STR"apple", STR"$3"), 1),
          ((STR"apple", ARR([STR"granny smith", STR"$2"])), 1),
          ((STR"kiwi", STR"$2"), 1)
        ])
        a_join_b_result = MSET([
          ((STR"apple", ARR([STR"$5", STR"$3"])), 2),
          ((STR"apple", ARR([STR"$5", ARR([STR"granny smith", STR"$2"])])), 2),
        ])
        b_join_a_result = MSET([
          ((STR"apple", ARR([STR"$3", STR"$5"])), 2),
          ((STR"apple", ARR([ARR([STR"granny smith", STR"$2"]), STR"$5"])), 2),
        ])
      check a.concat(b) == a_concat_b_result
      check b.concat(a) == a_concat_b_result
      check a.join(b) == a_join_b_result
      check b.join(a) == b_join_a_result
      check a.filter(proc (e: Entry): bool = e.key == STR"apple") == MSET([
        ((STR"apple", STR"$5"), 2)
      ])
      check a.map(proc (e: Entry): Entry = (e.value, e.key)) == MSET([
        ((STR"$5", STR"apple"), 2),
        ((STR"$2", STR"banana"), 1)
      ])
      check a.concat(b).count() == MSET([
        ((STR"apple", 4.0.v), 1),
        ((STR"banana", 1.0.v), 1),
        ((STR"kiwi", 1.0.v), 1)
      ])
      check a.concat(b).distinct() == MSET([
        ((STR"apple", STR"$5"), 1),
        ((STR"banana", STR"$2"), 1),
        ((STR"apple", STR"$3"), 1),
        ((STR"apple", ARR([STR"granny smith", STR"$2"])), 1),
        ((STR"kiwi", STR"$2"), 1)
      ])
      check d.min() == MSET([
        ((STR"apple", 3.0.v), 1),
        ((STR"banana", 2.0.v), 1),
        ((STR"coconut", 3.0.v), 1),
      ])
      check d.max() == MSET([
        ((STR"apple", 11.0.v), 1),
        ((STR"banana", 2.0.v), 1),
        ((STR"coconut", 3.0.v), 1),
      ])
      check d.sum() == MSET([
        ((STR"apple", 17.0.v), 1),
        ((STR"banana", 6.0.v), 1),
        ((STR"coconut", 3.0.v), 1),
      ])
      check c.min() == MSET([
        ((STR"apple", STR"$2"), 1),
        ((STR"banana", STR"$2"), 1),
      ])
      check c.max() == MSET([
        ((STR"apple", STR"$5"), 1),
        ((STR"banana", STR"$2"), 1),
      ])

    test "consolidate":
      var a = MSET([
        ((STR"foo", Nil.v), 1),
        ((STR"foo", Nil.v), 3),
        ((STR"bar", Nil.v), 3),
        ((STR"foo", Nil.v), 9),
        ((STR"bar", Nil.v), 3),
        ((STR"was", Nil.v), 3),
        ((STR"foo", Nil.v), 1),
        ((STR"bar", Nil.v), -47),
        ((STR"was", Nil.v), -3),
      ])
      check a.consolidate == MSET([
        ((STR"foo", Nil.v), 14),
        ((STR"bar", Nil.v), -41),
      ])

    test "iterate":
      var a = MSET([((1.0.v, Nil.v), 1)])
      proc add_one(c: Multiset): Multiset =
        return c.map(proc (e: Entry): Entry = ((e.key.as_f64 + 1.0).v, e.value))
          .concat(c)
          .filter(proc (e: Entry): bool = e.key < 5.0.v)
          .distinct
          .consolidate
      check a.iterate(add_one) == MSET([
        ((1.0.v, Nil.v), 1),
        ((2.0.v, Nil.v), 1),
        ((3.0.v, Nil.v), 1),
        ((4.0.v, Nil.v), 1),
      ])
      
