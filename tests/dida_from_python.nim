import std/[sugar, sequtils]
import ../src/[test_utils, dida_from_python, values]

template COL*(rows: openArray[Row]): Collection = init_collection(rows)
template VER*(timestamps: openArray[int]): Version = init_version(timestamps)
template FTR*(versions: openArray[Version]): Frontier = init_frontier(versions)

proc main* =
  suite "collection":
    test "simple":
      var
        a = COL([])
        b = COL([])
        c = COL([(V [0, 1], 1)])
      check a == b
      check a != c

    test "various":
      var
        a = COL([
          (V ["apple", "$5"], 2),
          (V ["banana", "$2"], 1),
        ])
        b = COL([
          (V ["apple", "$3"], 1),
          (V ["apple", ["granny smith", "$2"]], 1),
          (V ["kiwi", "$2"], 1),
        ])
        c = COL([
          (V ["apple", "$5"], 2),
          (V ["banana", "$2"], 1),
          (V ["apple", "$2"], 20),
        ])
        d = COL([
          (V ["apple", 11], 1),
          (V ["apple", 3], 2),
          (V ["banana", 2], 3),
          (V ["coconut", 3], 1),
        ])
        # some results
        a_concat_b_result = COL([
          (V ["apple", "$5"], 2),
          (V ["banana", "$2"], 1),
          (V ["apple", "$3"], 1),
          (V ["apple", ["granny smith", "$2"]], 1),
          (V ["kiwi", "$2"], 1),
        ])
        a_join_b_result = COL([
          (V ["apple", ["$5", "$3"]], 2),
          (V ["apple", ["$5", ["granny smith", "$2"]]], 2),
        ])
        b_join_a_result = COL([
          (V ["apple", ["$3", "$5"]], 2),
          (V ["apple", [["granny smith", "$2"], "$5"]], 2),
        ])
      check a.concat(b) == a_concat_b_result
      check b.concat(a) == a_concat_b_result
      check a.join(b) == a_join_b_result
      check b.join(a) == b_join_a_result
      check a.filter(proc (e: Entry): bool = e.key == V "apple") == COL([
        (V ["apple", "$5"], 2),
      ])
      check a.map((e) => V([e.value, e.key])) == COL([
        (V ["$5", "apple"], 2),
        (V ["$2", "banana"], 1),
      ])
      check a.concat(b).count() == COL([
        (V ["apple", 4], 1),
        (V ["banana", 1], 1),
        (V ["kiwi", 1], 1),
      ])
      check a.concat(b).distinct() == COL([
        (V ["apple", "$5"], 1),
        (V ["banana", "$2"], 1),
        (V ["apple", "$3"], 1),
        (V ["apple", ["granny smith", "$2"]], 1),
        (V ["kiwi", "$2"], 1),
      ])
      check d.min() == COL([
        (V ["apple", 3], 1),
        (V ["banana", 2], 1),
        (V ["coconut", 3], 1),
      ])
      check d.max() == COL([
        (V ["apple", 11], 1),
        (V ["banana", 2], 1),
        (V ["coconut", 3], 1),
      ])
      check d.sum() == COL([
        (V ["apple", 17], 1),
        (V ["banana", 6], 1),
        (V ["coconut", 3], 1),
      ])
      check c.min() == COL([
        (V ["apple", "$2"], 1),
        (V ["banana", "$2"], 1),
      ])
      check c.max() == COL([
        (V ["apple", "$5"], 1),
        (V ["banana", "$2"], 1),
      ])
    
    test "negate":
      var a = COL([
        (V ["foo", Nil], 3),
        (V ["foo", Nil], 1),
        (V ["bar", Nil], 2),
      ])
      check a.negate == COL([
        (V ["foo", Nil], -3),
        (V ["foo", Nil], -1),
        (V ["bar", Nil], -2),
      ])

    test "consolidate":
      var a = COL([
        (V ["foo", Nil], 1),
        (V ["foo", Nil], 3),
        (V ["bar", Nil], 3),
        (V ["foo", Nil], 9),
        (V ["bar", Nil], 3),
        (V ["was", Nil], 3),
        (V ["foo", Nil], 1),
        (V ["bar", Nil], -47),
        (V ["was", Nil], -3),
      ])
      check a.consolidate == COL([
        (V ["foo", Nil], 14),
        (V ["bar", Nil], -41),
      ])
      check a.concat(a.negate).consolidate == COL([])

    test "iterate":
      var a = COL([(V [1, Nil], 1)])
      proc add_one(c: Collection): Collection =
        return c.map((e) => V([(e.key.as_f64 + 1.0).v, e.value]))
          .concat(c)
          .filter(proc (e: Entry): bool = e.key < V 5.0)
          .distinct
          .consolidate
      check a.iterate(add_one) == COL([
        (V [1, Nil], 1),
        (V [2, Nil], 1),
        (V [3, Nil], 1),
        (V [4, Nil], 1),
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
          ([0].VER, [(V [0, 1], 1)].COL),
          ([0].VER, [(V [2, 3], 1)].COL),
        ]
        result_rows: seq[Row] = @[]
        result_data: seq[(Version, Collection)] = @[]
        correct_rows: seq[Row] = @[(V [0, 1], -1), (V [2, 3], -1)]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V [0, 1], -1)].COL),
          ([0].VER, [(V [2, 3], -1)].COL),
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
          ([0].VER, [(V [0, 1], 1)].COL),
          ([0].VER, [(V [2, 3], 1)].COL),
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V [0, 1], -1)].COL),
          ([0].VER, [(V [2, 3], -1)].COL),
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
          ([0].VER, [(V [0, 1], 1), (V [8, 9], 5)].COL),
          ([0].VER, [(V [2, 3], 1)].COL),
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V [1, 0], 1), (V [9, 8], 5)].COL),
          ([0].VER, [(V [3, 2], 1)].COL),
        ]
        b = init_builder()
          .map((e) => V([e[1], e[0]]))
          .accumulate_results
        g = b.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check b.node.results == correct_data

    test "simple filter":
      var
        initial_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V [0, 1], 1)].COL),
          ([0].VER, [(V [0, 1], 1), (V [8, 9], 5)].COL),
          ([0].VER, [(V [2, 3], 1)].COL),
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V [8, 9], 5)].COL),
        ]
        b = init_builder()
          .filter((e) => e[0] > 5.0.v)
          .accumulate_results
        g = b.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check b.node.results == correct_data

    test "simple flat_map":
      var
        initial_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V [0, 1], 1)].COL),
          ([0].VER, [(V [0, 1], 1), (V [8, 9], 5)].COL),
          ([0].VER, [(V [2, 3], 1)].COL),
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V 0, 1), (V 1, 1)].COL),
          ([0].VER, [(V 0, 1), (V 1, 1), (V 8, 5), (V 9, 5)].COL),
          ([0].VER, [(V 2, 1), (V 3, 1)].COL),
        ]
        b = init_builder()
          .flat_map((e) => Arr([e[0], e[1]]))
          .accumulate_results
        g = b.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check b.node.results == correct_data

#[
    test "task: send more money":
      var
        initial_data: seq[(Version, Collection)] = @[
          ([0].VER, toSeq(0..<10).map(i => (i.float64.v, 1)).COL)
        ]
        correct_data: seq[(Version, Collection)] = @[
          ([0].VER, [(V 0, 1), (V 1, 1)].COL),
          ([0].VER, [(V 0, 1), (V 1, 1), (V 8, 5), (V 9, 5)].COL),
          ([0].VER, [(V 2, 1), (V 3, 1)].COL),
        ]
        flat_map_fn = proc (e: Entry): ImArray =
          return [e].ARR.as_arr
        # sendmory
        input = init_builder()
        s = input.filter(e => e != 0.0)
          .map(e => [(STR"s", e)].MAP)
          .join(0, input)
        e = s.filter(e => e[STR"s"] != e[1])
          .map(e => e[0].set(STR"e", e[1]))
          .join(0, input)
        n = e.filter(e => e[STR"s"] != e[1] && e[STR"e"] != e[1])
          .map(e => e[0].set(STR"n", e[1]))
          .join(0, input)
        d = e.filter(e => e[STR"s"] != e[1] && e[STR"e"] != e[1] && e[STR"n"] != e[1])
          .map(e => e[0].set(STR"d", e[1]))
          .join(0, input)
        m = e.filter(e => e[STR"s"] != e[1] && e[STR"e"] != e[1] && e[STR"n"] != e[1] && e[STR"d"] != e[1] && e[1] != 0.0)
          .map(e => e[0].set(STR"m", e[1]))
          .join(0, input)
        o = e.filter(e => e[STR"s"] != e[1] && e[STR"e"] != e[1] && e[STR"n"] != e[1] && e[STR"d"] != e[1] && e[STR"m"] != e[1])
          .map(e => e[0].set(STR"o", e[1]))
          .join(0, input)
        r = e.filter(e => e[STR"s"] != e[1] && e[STR"e"] != e[1] && e[STR"n"] != e[1] && e[STR"d"] != e[1] && e[STR"m"] != e[1] && e[STR"o"] != e[1])
          .map(e => e[0].set(STR"r", e[1]))
          .join(0, input)
        y = e.filter(e => e[STR"s"] != e[1] && e[STR"e"] != e[1] && e[STR"n"] != e[1] && e[STR"d"] != e[1] && e[STR"m"] != e[1] && e[STR"o"] != e[1] && e[STR"r"] != e[1])
          .map(e => e[0].set(STR"y", e[1]))
          .join(0, input)
        results = s.accumulate_results
        g = input.graph
      for (v, c) in initial_data: g.send(v, c)
      g.send([[1].VER].FTR)
      g.step
      check results.node.results == correct_data
]#

