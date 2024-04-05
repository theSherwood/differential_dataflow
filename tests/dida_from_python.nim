import ../src/[test_utils, dida_from_python, values]

template STR*(): ImValue = init_string().v
template STR*(s: string): ImValue = init_string(s).v
template ARR*(): ImValue = init_array().v
template ARR*(vs: openArray[ImValue]): ImValue = init_array(vs).v
template SET*(): ImValue = init_set().v
template SET*(vs: openArray[ImValue]): ImValue = init_set(vs).v
template MAP*(): ImValue = init_map().v
template MAP*(vs: openArray[(ImValue, ImValue)]): ImValue = init_map(vs).v

template COL*(rows: openArray[Row]): Collection = init_collection(rows)
template VER*(timestamps: openArray[int]): Version = init_version(timestamps)
template FTR*(versions: openArray[Version]): Frontier = init_frontier(versions)

proc main* =
  suite "collection":
    test "simple":
      var
        a = COL([])
        b = COL([])
        c = COL([((0.0.v, 1.0.v), 1)])
      check a == b
      check a != c

    test "various":
      var
        a = COL([
          ((STR"apple", STR"$5"), 2),
          ((STR"banana", STR"$2"), 1)
        ])
        b = COL([
          ((STR"apple", STR"$3"), 1),
          ((STR"apple", ARR([STR"granny smith", STR"$2"])), 1),
          ((STR"kiwi", STR"$2"), 1)
        ])
        c = COL([
          ((STR"apple", STR"$5"), 2),
          ((STR"banana", STR"$2"), 1),
          ((STR"apple", STR"$2"), 20),
        ])
        d = COL([
          ((STR"apple", 11.0.v), 1),
          ((STR"apple", 3.0.v), 2),
          ((STR"banana", 2.0.v), 3),
          ((STR"coconut", 3.0.v), 1),
        ])
        # some results
        a_concat_b_result = COL([
          ((STR"apple", STR"$5"), 2),
          ((STR"banana", STR"$2"), 1),
          ((STR"apple", STR"$3"), 1),
          ((STR"apple", ARR([STR"granny smith", STR"$2"])), 1),
          ((STR"kiwi", STR"$2"), 1)
        ])
        a_join_b_result = COL([
          ((STR"apple", ARR([STR"$5", STR"$3"])), 2),
          ((STR"apple", ARR([STR"$5", ARR([STR"granny smith", STR"$2"])])), 2),
        ])
        b_join_a_result = COL([
          ((STR"apple", ARR([STR"$3", STR"$5"])), 2),
          ((STR"apple", ARR([ARR([STR"granny smith", STR"$2"]), STR"$5"])), 2),
        ])
      check a.concat(b) == a_concat_b_result
      check b.concat(a) == a_concat_b_result
      check a.join(b) == a_join_b_result
      check b.join(a) == b_join_a_result
      check a.filter(proc (e: Entry): bool = e.key == STR"apple") == COL([
        ((STR"apple", STR"$5"), 2)
      ])
      check a.map(proc (e: Entry): Entry = (e.value, e.key)) == COL([
        ((STR"$5", STR"apple"), 2),
        ((STR"$2", STR"banana"), 1)
      ])
      check a.concat(b).count() == COL([
        ((STR"apple", 4.0.v), 1),
        ((STR"banana", 1.0.v), 1),
        ((STR"kiwi", 1.0.v), 1)
      ])
      check a.concat(b).distinct() == COL([
        ((STR"apple", STR"$5"), 1),
        ((STR"banana", STR"$2"), 1),
        ((STR"apple", STR"$3"), 1),
        ((STR"apple", ARR([STR"granny smith", STR"$2"])), 1),
        ((STR"kiwi", STR"$2"), 1)
      ])
      check d.min() == COL([
        ((STR"apple", 3.0.v), 1),
        ((STR"banana", 2.0.v), 1),
        ((STR"coconut", 3.0.v), 1),
      ])
      check d.max() == COL([
        ((STR"apple", 11.0.v), 1),
        ((STR"banana", 2.0.v), 1),
        ((STR"coconut", 3.0.v), 1),
      ])
      check d.sum() == COL([
        ((STR"apple", 17.0.v), 1),
        ((STR"banana", 6.0.v), 1),
        ((STR"coconut", 3.0.v), 1),
      ])
      check c.min() == COL([
        ((STR"apple", STR"$2"), 1),
        ((STR"banana", STR"$2"), 1),
      ])
      check c.max() == COL([
        ((STR"apple", STR"$5"), 1),
        ((STR"banana", STR"$2"), 1),
      ])
    
    test "negate":
      var a = COL([
        ((STR"foo", Nil.v), 3),
        ((STR"foo", Nil.v), 1),
        ((STR"bar", Nil.v), 2),
      ])
      check a.negate == COL([
        ((STR"foo", Nil.v), -3),
        ((STR"foo", Nil.v), -1),
        ((STR"bar", Nil.v), -2),
      ])

    test "consolidate":
      var a = COL([
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
      check a.consolidate == COL([
        ((STR"foo", Nil.v), 14),
        ((STR"bar", Nil.v), -41),
      ])
      check a.concat(a.negate).consolidate == COL([])

    test "iterate":
      var a = COL([((1.0.v, Nil.v), 1)])
      proc add_one(c: Collection): Collection =
        return c.map(proc (e: Entry): Entry = ((e.key.as_f64 + 1.0).v, e.value))
          .concat(c)
          .filter(proc (e: Entry): bool = e.key < 5.0.v)
          .distinct
          .consolidate
      check a.iterate(add_one) == COL([
        ((1.0.v, Nil.v), 1),
        ((2.0.v, Nil.v), 1),
        ((3.0.v, Nil.v), 1),
        ((4.0.v, Nil.v), 1),
      ])

  suite "version":
    test "simple":
      var
        v0_0 = [0, 0].VER
        v1_0 = [1, 0].VER
        v0_1 = [0, 1].VER
        v1_1 = [1, 1].VER
        v2_0 = [2, 0].VER

      check v0_0.lt(v1_0)
      check v0_0.lt(v0_1)
      check v0_0.lt(v1_1)
      check v0_0.le(v1_0)
      check v0_0.le(v0_1)
      check v0_0.le(v1_1)

      check not(v1_0.lt(v1_0))
      check v1_0.le(v1_0)
      check not(v1_0.le(v0_1))
      check not(v0_1.le(v1_0))
      check v0_1.le(v1_1)
      check v1_0.le(v1_1)
      check v0_0.le(v1_1)
  
  suite "frontier":
    test "simple":
      var
        v0_0 = [0, 0].VER
        v1_0 = [1, 0].VER
        v0_1 = [0, 1].VER
        v1_1 = [1, 1].VER
        v2_0 = [2, 0].VER
      
      check FTR([v0_0]).le(FTR([v0_0]))
      check FTR([v0_0]).le(FTR([v1_0]))
      check FTR([v0_0]).lt(FTR([v1_0]))
      check FTR([v2_0, v1_1]).lt(FTR([v2_0]))
      check FTR([v0_0]) != (FTR([v1_0]))
      check FTR([v2_0, v1_1]) == (FTR([v1_1, v2_0]))

  suite "dida":
    test "simple":
      check 1 == 1
      var
        b = init_builder()
          .print("initial")
          .negate()
          .print("post negate")
        n = b.node
        g = b.graph
      
        

  

