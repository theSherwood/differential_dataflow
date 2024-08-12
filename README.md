# differential_dataflow

**WIP**

Based on the ideas of [Frank McSherry](https://github.com/frankmcsherry/blog) and [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow).

If you are unfamiliar with the concept, it's basically a model of computation for incremental view maintenance. There is a suite of operators that can be used to form a dataflow graph. The operators act on streams of batches of state deltas (hence the term "differential") to performing mapping, filtering, joins, and even loops/recursion.

The basic idea is pretty promising for databases, ui, and even rule engines and constraint programming. There are additional tricks that can be used to do automatic data parallelization and automatic versioning.

**Disclaimer**: This was written using the Nimskull compiler, which has not reached a stable version and, as of the time of this writing, continues to see rapid changes. There are already several differences between the Nimskull and Nim compilers. As such, if you wish to use any of this code... good luck!

**Disclaimer 2** As of the time of this writing, Nimskull did not have a package manager. So dependencies are handled through git submodules, which are a bit annoying to use.

## Acknowledgements

- [Frank McSherry's incredible blog](https://github.com/frankmcsherry/blog)
- [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow)
- https://github.com/jamii/dida
- https://github.com/vlcn-io/materialite

## Usage

An Game of Life implementation in `differential_dataflow`. Honestly, Game of Life probably makes more sense to be written in an imperative style, but this really isn't too bad if the board is small. What is more, it provides an example of iteration.

```nim
proc game_of_life(b: Builder): Builder =
  var
    maybe_live_cells_flat_map_fn = proc (e: Value): iterator(): Value =
      return iterator(): Value =
        var
          x = e[0]
          x_0 = x.as_f64
          x_m_1 = (x_0 - 1.0).v
          x_p_1 = (x_0 + 1.0).v
          y = e[1]
          y_0 = y.as_f64
          y_m_1 = (y_0 - 1.0).v
          y_p_1 = (y_0 + 1.0).v
        yield V [x_m_1, y_m_1]
        yield V [x_m_1, y    ]
        yield V [x_m_1, y_p_1]
        yield V [x,     y_m_1]
        yield V [x,     y_p_1]
        yield V [x_p_1, y_m_1]
        yield V [x_p_1, y    ]
        yield V [x_p_1, y_p_1]
    maybe_live_cells = b.flat_map(maybe_live_cells_flat_map_fn)
      .map((e) => V([e, Nil])).count()
    live_with_3_neighbors = maybe_live_cells
      .filter((e) => e[1] == 3)
      .map((e) => e[0])
    live_with_2_neighbors = maybe_live_cells
      .filter((e) => e[1] == 2)
      .join(b.map(proc (e: Value): Value = V([e, Nil])))
      .map((e) => e[0])
    live_next_round = live_with_2_neighbors
      .concat(live_with_3_neighbors)
      .distinct()
  return live_next_round

const
  W = 6
  H = 6

var
  board_window: array[H, array[W, bool]]
  reset_board_window = proc () =
    for y in 0..<H:
      for x in 0..<W:
        board_window[y][x] = false
  print_board_window = proc () =
    for y in board_window:
      var s = ""
      for x in y:
        if x: s.add("#")
        else: s.add("_")
      echo s
  set_collection_in_board_window = proc (c: Collection) =
    for r in c:
      if r.multiplicity > 0:
        board_window[r.value.as_f64.int][r.key.as_f64.int] = true
      else:
        board_window[r.value.as_f64.int][r.key.as_f64.int] = false
  on_message_fn = proc (m: Message) =
    case m.tag:
      of tData:
        for r in m.collection:
          if r.multiplicity > 0:
            board_window[r.value.as_f64.int][r.key.as_f64.int] = true
          else:
            board_window[r.value.as_f64.int][r.key.as_f64.int] = false
        print_board_window()
      of tFrontier:
        reset_board_window()
  vmultiset = init_versioned_multiset()
  initial_data = [(V [2, 2], 1), (V [2, 3], 1), (V [2, 4], 1), (V [3, 2], 1)].COL
  v0 = [0].VER
  v1 = [1].VER
  fallback = 20
  b = init_builder().iterate(game_of_life).sink(vmultiset).on_message(on_message_fn)
  g = b.graph

g.send(v0, initial_data)
g.send([v1].FTR)
while b.node.probe_frontier_less_than([v1].FTR):
  g.step
  block:
    doAssert fallback > 0
    fallback -= 1
```

## State and considerations

### Comparison with Rete

I started implementing this after doing a couple rough implementations of the Rete algorithm (for rule engines and constraint programming). I was dissatisfied with the limitations of the Rete approach. I found it a little clunky to implement, particularly around negation, and every extension to it, whether for features or performance, feels like an unnecessarily complicated hack. In contrast, the differential dataflow approach is fairly elegant and much more expressive. Negation is a consistent part of the overall model. Loops and recursion are possible, as well as more generic stream processing. I didn't get as far with this as implementing a nice Rete-like interface on top of this differential dataflow implementation, but the underlying ability to set up similar networks of constraints is demonstrably present.

### Typing limitations

One of the issues with this implementation is that it uses dynamic types (through [my dynamic_value lib](https://github.com/theSherwood/dynamic_value)) and does not support static typing. It was much easier to make that work with building a graph of streams that (pull from)/(push to) each other's buffers. In future, I might like to try another implementation that supports static typing, but this one does not.

### Time

Differential dataflow can have a somewhat complex relationship to time (the state deltas must occur with respect to some model of time). Reference implementations use multi-dimensional, partial-ordered time, which is very flexible but relies on frontiers and antichains. For my purposes, I want something fractal like a partial-ordered, branching tree of history. This is simpler in some respects than the reference implementations' approach but also more limited in some respects and is still not that simple. I'm not satisfied with where I ended up in my implementation.

### Performance

I haven't done any real benchmarking yet, but I'm sure the performance is a disaster. In fact, I had to turn off history compaction because it basically constituted a performance bug. Until that is fixed, it's probably no good for long-running scripts. I used a pretty terrible data structure for the index. I suspect using a B+ tree would be a big improvement.

### Operators

The suite of operators supported is limited at present, particularly around joins.

### Considerations for the future

It would be nice to add more support for simple stream support similar to the way it is done in [materialite](https://github.com/vlcn-io/materialite). More generally, [materialite](https://github.com/vlcn-io/materialite) also has a nice approach to sources and sinks that may be worth emulating.

In general, the interest around the [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow) approach seems to be slowly building. There is now the alternative of [Feldera](https://www.feldera.com/), which is quite similar in its purposes to [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow). They have published a couple of very accessible papers that formalize their approach. I'm not clear on what additional guarantees the formalism provides, but I would probably start there if I were to implement something like this again.

## Scripts and commands

### Build Native

```sh
./run.sh -tu native
```

### Test Native

```sh
./run.sh -tur native
```

### Test Wasm in Node

```sh
./run.sh -tur node32
```

### Test Wasm in Browser

Compile wasm:

```sh
./run.sh -tur browser32
```

Start the server:

```sh
dev start
```

Go to http://localhost:3000/

### Benchmark

```sh
./run.sh -bur
```
