import std/[sugar, sequtils]
import ../src/[test_utils, dida_from_python, values]

template STR*(): ImValue = init_string().v
template STR*(s: string): ImValue = init_string(s).v
template ARR*(): ImValue = init_array().v
template ARR*(vs: openArray[ImValue]): ImValue = init_array(vs).v
template ARR*(vs: openArray[float64]): ImValue = init_array(toSeq(vs).map(f => f.v)).v
template ARR*(vs: openArray[int]): ImValue = init_array(toSeq(vs).map(i => i.float64.v)).v
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
        c = COL([([0, 1].ARR, 1)])
      check a == b
      check a != c

    test "various":
      var
        a = COL([
          ([STR"apple", STR"$5"].ARR, 2),
          ([STR"banana", STR"$2"].ARR, 1)
        ])
        b = COL([
          ([STR"apple", STR"$3"].ARR, 1),
          ([STR"apple", ARR([STR"granny smith", STR"$2"])].ARR, 1),
          ([STR"kiwi", STR"$2"].ARR, 1)
        ])
        c = COL([
          ([STR"apple", STR"$5"].ARR, 2),
          ([STR"banana", STR"$2"].ARR, 1),
          ([STR"apple", STR"$2"].ARR, 20),
        ])
        d = COL([
          ([STR"apple", 11.0.v].ARR, 1),
          ([STR"apple", 3.0.v].ARR, 2),
          ([STR"banana", 2.0.v].ARR, 3),
          ([STR"coconut", 3.0.v].ARR, 1),
        ])
        # some results
        a_concat_b_result = COL([
          ([STR"apple", STR"$5"].ARR, 2),
          ([STR"banana", STR"$2"].ARR, 1),
          ([STR"apple", STR"$3"].ARR, 1),
          ([STR"apple", ARR([STR"granny smith", STR"$2"])].ARR, 1),
          ([STR"kiwi", STR"$2"].ARR, 1)
        ])
        a_join_b_result = COL([
          ([STR"apple", ARR([STR"$5", STR"$3"])].ARR, 2),
          ([STR"apple", ARR([STR"$5", ARR([STR"granny smith", STR"$2"])])].ARR, 2),
        ])
        b_join_a_result = COL([
          ([STR"apple", ARR([STR"$3", STR"$5"])].ARR, 2),
          ([STR"apple", ARR([ARR([STR"granny smith", STR"$2"]), STR"$5"])].ARR, 2),
        ])
      check a.concat(b) == a_concat_b_result
      check b.concat(a) == a_concat_b_result
      check a.join(b) == a_join_b_result
      check b.join(a) == b_join_a_result
      check a.filter(proc (e: Entry): bool = e.key == STR"apple") == COL([
        ([STR"apple", STR"$5"].ARR, 2)
      ])
      check a.map((e) => [e.value, e.key].ARR) == COL([
        ([STR"$5", STR"apple"].ARR, 2),
        ([STR"$2", STR"banana"].ARR, 1)
      ])
      check a.concat(b).count() == COL([
        ([STR"apple", 4.0.v].ARR, 1),
        ([STR"banana", 1.0.v].ARR, 1),
        ([STR"kiwi", 1.0.v].ARR, 1)
      ])
      check a.concat(b).distinct() == COL([
        ([STR"apple", STR"$5"].ARR, 1),
        ([STR"banana", STR"$2"].ARR, 1),
        ([STR"apple", STR"$3"].ARR, 1),
        ([STR"apple", ARR([STR"granny smith", STR"$2"])].ARR, 1),
        ([STR"kiwi", STR"$2"].ARR, 1)
      ])
      check d.min() == COL([
        ([STR"apple", 3.0.v].ARR, 1),
        ([STR"banana", 2.0.v].ARR, 1),
        ([STR"coconut", 3.0.v].ARR, 1),
      ])
      check d.max() == COL([
        ([STR"apple", 11.0.v].ARR, 1),
        ([STR"banana", 2.0.v].ARR, 1),
        ([STR"coconut", 3.0.v].ARR, 1),
      ])
      check d.sum() == COL([
        ([STR"apple", 17.0.v].ARR, 1),
        ([STR"banana", 6.0.v].ARR, 1),
        ([STR"coconut", 3.0.v].ARR, 1),
      ])
      check c.min() == COL([
        ([STR"apple", STR"$2"].ARR, 1),
        ([STR"banana", STR"$2"].ARR, 1),
      ])
      check c.max() == COL([
        ([STR"apple", STR"$5"].ARR, 1),
        ([STR"banana", STR"$2"].ARR, 1),
      ])
    
    test "negate":
      var a = COL([
        ([STR"foo", Nil.v].ARR, 3),
        ([STR"foo", Nil.v].ARR, 1),
        ([STR"bar", Nil.v].ARR, 2),
      ])
      check a.negate == COL([
        ([STR"foo", Nil.v].ARR, -3),
        ([STR"foo", Nil.v].ARR, -1),
        ([STR"bar", Nil.v].ARR, -2),
      ])

    test "consolidate":
      var a = COL([
        ([STR"foo", Nil.v].ARR, 1),
        ([STR"foo", Nil.v].ARR, 3),
        ([STR"bar", Nil.v].ARR, 3),
        ([STR"foo", Nil.v].ARR, 9),
        ([STR"bar", Nil.v].ARR, 3),
        ([STR"was", Nil.v].ARR, 3),
        ([STR"foo", Nil.v].ARR, 1),
        ([STR"bar", Nil.v].ARR, -47),
        ([STR"was", Nil.v].ARR, -3),
      ])
      check a.consolidate == COL([
        ([STR"foo", Nil.v].ARR, 14),
        ([STR"bar", Nil.v].ARR, -41),
      ])
      check a.concat(a.negate).consolidate == COL([])

    test "iterate":
      var a = COL([([1.0.v, Nil.v].ARR, 1)])
      proc add_one(c: Collection): Collection =
        return c.map((e) => [(e.key.as_f64 + 1.0).v, e.value].ARR)
          .concat(c)
          .filter(proc (e: Entry): bool = e.key < 5.0.v)
          .distinct
          .consolidate
      check a.iterate(add_one) == COL([
        ([1.0.v, Nil.v].ARR, 1),
        ([2.0.v, Nil.v].ARR, 1),
        ([3.0.v, Nil.v].ARR, 1),
        ([4.0.v, Nil.v].ARR, 1),
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
    test "simple on_row and on_collection":
      var
        initial_data: seq[(Version, Collection)] = @[
          ([0].VER, [([0, 1].ARR, 1)].COL),
          ([0].VER, [([2, 3].ARR, 1)].COL),
        ]
        result_rows: seq[Row] = @[]
        result_data: seq[(Version, Collection)] = @[]
        correct_rows: seq[Row] = @[([0, 1].ARR, -1), ([2, 3].ARR, -1)]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [([0, 1].ARR, -1)].COL),
          ([0].VER, [([2, 3].ARR, -1)].COL),
        ]
        b = init_builder()
          .negate()
          .on_row(proc (r: Row) = result_rows.add(r))
          .on_collection(proc (v: Version, c: Collection) = result_data.add((v, c)))
        g = b.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check result_rows == correct_rows
      check result_data == correct_data
    
    test "simple accumulate_results":
      var
        initial_data: seq[(Version, Collection)] = @[
          ([0].VER, [([0, 1].ARR, 1)].COL),
          ([0].VER, [([2, 3].ARR, 1)].COL),
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [([0, 1].ARR, -1)].COL),
          ([0].VER, [([2, 3].ARR, -1)].COL),
        ]
        b = init_builder()
          .negate
          .accumulate_results
        g = b.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check b.node.results == correct_data

    test "simple map":
      var
        initial_data: seq[(Version, Collection)] = @[
          ([0].VER, [([0, 1].ARR, 1), ([8, 9].ARR, 5)].COL),
          ([0].VER, [([2, 3].ARR, 1)].COL),
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [([1, 0].ARR, 1), ([9, 8].ARR, 5)].COL),
          ([0].VER, [([3, 2].ARR, 1)].COL),
        ]
        b = init_builder()
          .map((e) => [e[1], e[0]].ARR)
          .accumulate_results
        g = b.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check b.node.results == correct_data

    test "simple filter":
      var
        initial_data: seq[(Version, Collection)] = @[
          ([0].VER, [([0, 1].ARR, 1)].COL),
          ([0].VER, [([0, 1].ARR, 1), ([8, 9].ARR, 5)].COL),
          ([0].VER, [([2, 3].ARR, 1)].COL),
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [([8, 9].ARR, 5)].COL),
        ]
        b = init_builder()
          .filter((e) => e[0] > 5.0.v)
          .accumulate_results
        g = b.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check b.node.results == correct_data

