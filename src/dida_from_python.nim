import std/[tables, sets, bitops, strutils, sequtils, sugar, algorithm, strformat]
import hashes
import values

# Collections #
# ---------------------------------------------------------------------

type
  Value* = ImValue
  Entry* = Value

  Row* = (Entry, int)
  
  Collection* = object
    rows*: seq[Row]

  MapFn* = proc (e: Entry): Entry {.closure.}
  FilterFn* = proc (e: Entry): bool {.closure.}
  FlatMapFn* = proc (e: Entry): ImArray {.closure.}
  ReduceFn* = proc (rows: seq[Row]): seq[Row] {.closure.}
  CollIterateFn* = proc (c: Collection): Collection {.closure.}

proc size*(c: Collection): int = return c.rows.len

proc key*(e: Entry): Value =
  doAssert e.is_array
  return e.as_arr[0]
proc value*(e: Entry): Value =
  doAssert e.is_array
  return e.as_arr[1]
template entry*(r: Row): Entry = r[0]
template key*(r: Row): Value = r.entry.key
template value*(r: Row): Value = r.entry.value
template multiplicity*(r: Row): int = r[1]

template `[]`*(c: Collection, i: int): untyped = c.rows[i]
template `[]=`*(c: Collection, i: int, r: Row) = c.rows[i] = r
template add*(c: Collection, r: Row) = c.rows.add(r)

iterator items*(c: Collection): Row =
  for r in c.rows:
    yield r

## This is quite an expensive operation. It would be good to find a faster way
## to compute this.
## Using an xor-based hash for entries could help a lot.
proc `==`*(c1, c2: Collection): bool =
  var
    t1 = initTable[Entry, int]()
    t2 = initTable[Entry, int]()
  for (e, m) in c1:
    t1[e] = m + t1.getOrDefault(e, 0)
  for (e, m) in c2:
    t2[e] = m + t2.getOrDefault(e, 0)
  return t1 == t2

proc map*(c: Collection, f: MapFn): Collection =
  result.rows.setLen(c.size)
  for i in 0..<c.size:
    result[i] = (f(c[i].entry), c[i].multiplicity)

proc filter*(c: Collection, f: FilterFn): Collection =
  for r in c:
    if f(r.entry): result.add(r)

proc flat_map*(c: Collection, f: FlatMapFn): Collection =
  for r in c:
    for e in f(r.entry):
      result.add((e, r.multiplicity))

proc negate*(c: Collection): Collection =
  result.rows.setLen(c.size)
  for i in 0..<c.size:
    result[i] = (c[i].entry, 0 - c[i].multiplicity)

proc concat*(c1, c2: Collection): Collection =
  for r in c1: result.add(r)
  for r in c2: result.add(r)

proc consolidate*(c: Collection): Collection =
  var t = initTable[Entry, int]()
  for (e, m) in c:
    t[e] = m + t.getOrDefault(e, 0)
  for e, m in t.pairs:
    if m != 0: result.add((e, m))

proc print*(c: Collection, label: string): Collection =
  echo label, ": ", c
  return c

proc to_row_table_by_key(t: var Table[Value, seq[Row]], c: Collection) =
  for r in c:
    if t.hasKey(r.key):
      t[r.key].add(r)
    else:
      t[r.key] = @[r]

proc join*(c1, c2: Collection): Collection =
  let empty_seq = newSeq[Row]()
  var t = initTable[Value, seq[Row]]()
  t.to_row_table_by_key(c1)
  for r in c2:
    for r2 in t.getOrDefault(r.key, empty_seq):
      result.add((V [r.key, [r2.value, r.value]], r.multiplicity * r2.multiplicity))

## Keys must not be changed by the reduce fn
proc reduce*(c: Collection, f: ReduceFn): Collection =
  var t = initTable[Value, seq[Row]]()
  t.to_row_table_by_key(c)
  for r in t.values:
    for r2 in f(r):
      result.add(r2)

proc count_inner(rows: seq[Row]): seq[Row] =
  let k = rows[0].key
  var cnt = 0
  for r in rows: cnt += r.multiplicity
  return @[(V [k, cnt.float64], 1)]

proc count*(c: Collection): Collection =
  return c.reduce(count_inner)

proc sum_inner(rows: seq[Row]): seq[Row] =
  let k = rows[0].key
  var cnt = 0.float64
  for r in rows: cnt += r.value.as_f64 * r.multiplicity.float64
  return @[(V [k, cnt], 1)]

proc sum*(c: Collection): Collection =
  return c.reduce(sum_inner)

proc distinct_inner(rows: seq[Row]): seq[Row] =
  var t = initTable[Entry, int]()
  for r in rows:
    t[r.entry] = r.multiplicity + t.getOrDefault(r.entry, 0)
  result = @[]
  for e, i in t.pairs:
    doAssert i >= 0
    if i != 0:
      result.add((e, 1))

## Reduce a collection to a set
proc `distinct`*(c: Collection): Collection =
  return c.reduce(distinct_inner)

proc min_inner(rows: seq[Row]): seq[Row] =
  var t = initTable[Entry, int]()
  var k = rows[0].key
  for r in rows:
    t[r.entry] = r.multiplicity + t.getOrDefault(r.entry, 0)
  result = @[]
  var value_seen = false
  var min_val: ImValue
  for e, i in t.pairs:
    doAssert i >= 0
    if i != 0:
      if not(value_seen):
        value_seen = true
        min_val = e.value
      elif e.value < min_val:
        min_val = e.value
  if value_seen:
    return @[(V [k, min_val], 1)]
  else:
    return @[]

proc min*(c: Collection): Collection =
  try:
    return c.reduce(min_inner)
  except TypeException as e:
    raise newException(TypeException, "Incomparable types")

proc max_inner(rows: seq[Row]): seq[Row] =
  var t = initTable[Entry, int]()
  var k = rows[0].key
  for r in rows:
    t[r.entry] = r.multiplicity + t.getOrDefault(r.entry, 0)
  result = @[]
  var value_seen = false
  var max_val: ImValue
  for e, i in t.pairs:
    doAssert i >= 0
    if i != 0:
      if not(value_seen):
        value_seen = true
        max_val = e.value
      elif e.value > max_val:
        max_val = e.value
  if value_seen:
    return @[(V [k, max_val], 1)]
  else:
    return @[]

proc max*(c: Collection): Collection =
  try:
    return c.reduce(max_inner)
  except TypeException as e:
    raise newException(TypeException, "Incomparable types")

proc iterate*(c: Collection, f: CollIterateFn): Collection =
  var curr = c
  while true:
    result = f(curr)
    if curr == result: break
    curr = result

proc init_collection*(rows: openArray[Row]): Collection =
  for r in rows:
    result.add(r)

# Versions and Frontiers #
# ---------------------------------------------------------------------

type
  Version* = object
    hash*: Hash
    timestamps*: seq[int]

  Frontier* = ref object
    hash*: Hash
    versions*: seq[Version]

proc to_version(timestamps: seq[int]): Version =
  result.timestamps = timestamps
  result.hash = hash(timestamps)

template init_version*(): Version = to_version(@[0])
template init_version*(timestamps: openArray[int]): Version = to_version(toSeq[timestamps])

template `==`*(v1, v2: Version): bool = v1.hash == v2.hash and v1.timestamps == v2.timestamps
template size*(v: Version): int = v.timestamps.len
template `[]`*(v: Version, i: int): int = v.timestamps[i]

proc validate(v: Version) =
  doAssert v.size > 0
proc validate(v1, v2: Version) =
  doAssert v1.size > 0
  doAssert v1.size == v2.size

proc le*(v1, v2: Version): bool =
  validate(v1, v2)
  for i in 0..<v1.size:
    if v1[i] > v2[i]: return false
  return true
template lt*(v1, v2: Version): bool = v1.le(v2) and v1 != v2

proc join*(v1, v2: Version): Version =
  validate(v1, v2)
  var timestamps: seq[int] = @[]
  for i in 0..<v1.size:
    timestamps.add(max(v1[i], v2[i]))
  return to_version(timestamps)

proc meet*(v1, v2: Version): Version =
  validate(v1, v2)
  var timestamps: seq[int] = @[]
  for i in 0..<v1.size:
    timestamps.add(min(v1[i], v2[i]))
  return to_version(timestamps)

proc extend*(v: Version): Version =
  var timestamps = toSeq(v.timestamps)
  timestamps.add(0)
  return to_version(timestamps)

proc truncate*(v: Version): Version =
  var timestamps = toSeq(v.timestamps[0..^1])
  return to_version(timestamps)

proc step*(v: Version, delta: int): Version =
  doAssert delta > 0
  var timestamps = toSeq(v.timestamps)
  timestamps[^1] += 1
  return to_version(timestamps)

iterator items*(f: Frontier): Version =
  for v in f.versions:
    yield v

proc add(f: Frontier, v: Version) =
  var new_versions: seq[Version] = @[]
  for v2 in f:
    if v.le(v2): return
    if not(v2.le(v)):
      new_versions.add(v2)
  new_versions.add(v)
  f.versions = new_versions

## Must call after `add` or any other mutation is called
proc update_hash(f: Frontier) =
  var new_hash: Hash = 0
  for v in f:
    new_hash = new_hash xor v.hash
  f.hash = new_hash

proc init_frontier*(versions: openArray[Version]): Frontier =
  var new_f = Frontier()
  for v in versions:
    new_f.add(v)
  new_f.update_hash
  return new_f

proc meet*(f1, f2: Frontier): Frontier =
  var new_f = Frontier()
  for v in f1: new_f.add(v)
  for v in f2: new_f.add(v)
  new_f.update_hash
  return new_f

proc sort(f: Frontier) =
  f.versions.sort(
    proc (a, b: Version): int =
      let
        aa = a.timestamps
        bb = b.timestamps
        l = min(aa.len, bb.len)
      for i in 0..<l:
        if aa[i] < bb[i]: return -1
        if aa[i] > bb[i]: return 1
      return aa.len - bb.len
  )

proc `==`*(f1, f2: Frontier): bool =
  result = false
  if f1.hash == f2.hash:
    f1.sort
    f2.sort
    result = f1.versions == f2.versions

proc le*(f: Frontier, v: Version): bool =
  for v2 in f:
    if v2.le(v): return true
  return false

proc le*(f1, f2: Frontier): bool =
  var less_equal = false
  for v2 in f2:
    less_equal = false
    for v1 in f1:
      if v1.le(v2):
        less_equal = true
    if not(less_equal): return false
  return true
template lt*(f1, f2: Frontier): bool = f1.le(f2) and f1 != f2

proc extend*(f: Frontier): Frontier =
  var new_f = Frontier()
  for v in f:
    new_f.add(v.extend)
  new_f.update_hash
  return new_f

proc truncate*(f: Frontier): Frontier =
  var new_f = Frontier()
  for v in f:
    new_f.add(v.truncate)
  new_f.update_hash
  return new_f

proc step*(f: Frontier, delta: int): Frontier = 
  var new_f = Frontier()
  for v in f:
    new_f.add(v.step(delta))
  new_f.update_hash
  return new_f

# Nodes #
# ---------------------------------------------------------------------

type
  OnRowFn* = proc (r: Row): void
  OnCollectionFn* = proc (v: Version, c: Collection): void

  MessageTag* = enum
    tData
    tFrontier
  
  Message* = object
    case tag*: MessageTag:
      of tData:
        version*: Version
        collection*: Collection
      of tFrontier:
        frontier*: Frontier

  Edge* = ref object
    id*: Hash
    input*: Node
    output*: Node
    queue*: seq[Message]
  
  NodeTag* = enum
    tPassThrough
    tIterate
    tInput
    tOutput
    tIndex
    tMap
    tFilter
    tFlatMap
    tReduce
    tDistinct
    tCount
    tMin
    tMax
    tSum
    tPrint
    tNegate
    tConsolidate
    # binary
    tConcat
    tJoinColumns
    tJoin
    # freeform - useful for debugging and tests
    tOnRow
    tOnCollection
    tAccumulateResults
    # version manipulation - used in iteration
    tVersionPush
    tVersionIncrement
    tVersionPop

  Node* = ref object
    id*: int
    inputs*: seq[Edge]
    outputs*: seq[Edge]
    input_frontiers*: seq[Frontier]
    output_frontier*: Frontier
    case tag*: NodeTag:
      of tPrint:
        label*: string
      of tMap:
        map_fn*: MapFn
      of tFilter:
        filter_fn*: FilterFn
      of tFlatMap:
        flat_map_fn*: FlatMapFn
      of tReduce:
        init_value*: Value
        reduce_fn*: ReduceFn
      of tOnRow:
        on_row*: OnRowFn
      of tOnCollection:
        on_collection*: OnCollectionFn
      of tAccumulateResults:
        results*: seq[(Version, Collection)]
      else:
        discard
  
  Graph* = ref object
    top_node*: Node
    nodes*: HashSet[Node]
    edges*: HashSet[Edge]
  
  Builder* = object
    frontier*: Frontier
    graph*: Graph
    node*: Node

template hash(e: Edge): Hash = e.id
template hash(n: Node): Hash = n.id

var edge_id: int = 0
var node_id: int = 0

proc connect*(g: Graph, n1, n2: Node) =
  var n = n1
  if n == nil:
    n = g.top_node
  else:
    doAssert n in g.nodes or n == g.top_node
  var e = Edge()
  e.id = edge_id
  edge_id += 1
  e.input = n
  e.output = n2
  e.queue = @[]
  n.outputs.add(e)
  n2.inputs.add(e)
  n2.input_frontiers.add(n.output_frontier)
  if n2.output_frontier.isNil:
    n2.output_frontier = n.output_frontier
  g.edges.incl(e)
  g.nodes.incl(n2)

proc disconnect*(g: Graph, n: Node) =
  var i: int
  for e in n.inputs:
    i = e.input.outputs.find(e)
    e.input.outputs.del(i)
    g.edges.excl(e)
  for e in n.outputs:
    disconnect(g, e.output)
  g.nodes.excl(n)

proc init_node(t: NodeTag, f: Frontier): Node =
  var n = Node(
    tag: t,
    id: node_id,
    input_frontiers: @[],
    output_frontier: f,
    inputs: @[],
    outputs: @[],
  )
  node_id += 1
  return n

proc init_graph*(n: Node): Graph =
  return Graph(
    top_node: n,
    nodes: initHashSet[Node](),
    edges: initHashSet[Edge](),
  )
template is_empty*(e: Edge): bool = (e.queue.len == 0)

template clear(e: Edge) = e.queue.setLen(0)

proc pending_data*(n: Node): bool =
  for e in n.inputs:
    if not(e.is_empty): return true
  return false

template send*(e: Edge, v: Version, c: Collection) =
  e.queue.add(Message(tag: tData, version: v, collection: c))
template send*(e: Edge, f: Frontier) =
  e.queue.add(Message(tag: tFrontier, frontier: f))
template send*(e: Edge, m: Message) =
  e.queue.add(m)

template send(n: Node, v: Version, c: Collection) {.dirty.} =
  for e in n.outputs:
    e.send(v, c)
template send(n: Node, f: Frontier) {.dirty.} =
  for e in n.outputs:
    e.send(f)
template send(n: Node, m: Message) {.dirty.} =
  for e in n.outputs:
    e.send(m)

proc send*(g: Graph, v: Version, c: Collection) = g.top_node.send(v, c)
proc send*(g: Graph, f: Frontier) = g.top_node.send(f)
proc send*(g: Graph, m: Message) = g.top_node.send(m)

template handle_frontier_message(n: Node, m: Message, idx: int) {.dirty.} =
  doAssert n.input_frontiers[idx].le(m.frontier)
  n.input_frontiers[idx] = m.frontier
  doAssert n.output_frontier.le(m.frontier)
  if n.output_frontier.lt(m.frontier):
    n.output_frontier = m.frontier
    n.send(m)
template handle_frontier_message_unary(n: Node, m: Message) {.dirty.} =
  handle_frontier_message(n, m, 0)

# Builder #
# ---------------------------------------------------------------------

proc init_builder*(g: Graph, f: Frontier): Builder =
  var b = Builder()
  b.graph = g
  b.frontier = f
  b.node = g.top_node
  return b
template init_builder*(f: Frontier): Builder =
  init_builder(init_graph(init_node(tPassThrough, f)), f)
template init_builder*(g: Graph): Builder =
  init_builder(g, init_frontier([init_version()]))
template init_builder*(): Builder =
  let f = init_frontier([init_version()])
  init_builder(init_graph(init_node(tPassThrough, f)), f)

template build_unary(b: Builder, t: NodeTag) {.dirty.} =
  var n = init_node(t, b.frontier)
  connect(b.graph, b.node, n)
  result.graph = b.graph
  result.node = n

template build_binary(b: Builder, t: NodeTag, other: Node) {.dirty.} =
  var n = init_node(t, b.frontier)
  doAssert b.node != nil
  connect(b.graph, b.node, n)
  connect(b.graph, other, n)
  result.graph = b.graph
  result.node = n

proc print*(b: Builder, label: string): Builder =
  build_unary(b, tPrint)
  n.label = label

proc negate*(b: Builder): Builder =
  build_unary(b, tNegate)

proc concat*(b: Builder, other: Node): Builder =
  build_binary(b, tConcat, other)
template concat*(b1, b2: Builder): Builder = b1.concat(b2.node)

proc map*(b: Builder, fn: MapFn): Builder =
  build_unary(b, tMap)
  n.map_fn = fn

proc filter*(b: Builder, fn: FilterFn): Builder =
  build_unary(b, tFilter)
  n.filter_fn = fn

proc flat_map*(b: Builder, fn: FlatMapFn): Builder =
  build_unary(b, tFlatMap)
  n.flat_map_fn = fn

proc on_row*(b: Builder, fn: OnRowFn): Builder =
  build_unary(b, tOnRow)
  n.on_row = fn

proc on_collection*(b: Builder, fn: OnCollectionFn): Builder =
  build_unary(b, tOnCollection)
  n.on_collection = fn

proc accumulate_results*(b: Builder): Builder =
  build_unary(b, tAccumulateResults)
  n.results = @[]

# Pretty Print #
# ---------------------------------------------------------------------

proc `$`*(t: NodeTag): string =
  result = case t:
    of tInput:        "Input"
    of tPassThrough:  "PassThrough"
    of tPrint:        "Print"
    of tNegate:       "Negate"
    of tConcat:       "Concat"
    of tJoinColumns:  "JoinColumns"
    of tJoin:         "Join"
    of tMap:          "Map"
    of tFilter:       "Filter"
    of tOnRow:        "OnRow"
    of tOnCollection: "OnCollection"
    else:             "TODO"

proc string_from_pprint_seq(s: seq[(int, string)]): string =
  for (count, str) in s:
    result.add(str.indent(count))
    result.add('\n')

template pprint*(v: Version): string = "(" & v.timestamps.join(" ") & ")"
template pprint*(f: Frontier): string = "[" & f.versions.map(proc (v: Version): string = v.pprint).join(" ") & "]"

proc pprint_inner(m: Message, indent = 0): seq[(int, string)] =
  case m.tag:
    of tData:
      var s = &"DATA:     {m.version.pprint} {$m.collection.rows}"
      result.add((indent, s))
    of tFrontier:
      var s = &"FRONTIER: {m.frontier.pprint}"
      result.add((indent, s))

proc pprint_inner(e: Edge, indent = 0): seq[(int, string)] =
  var s = &"q:@{e.id} {e.queue.len}"
  result.add((indent, s))
  for m in e.queue:
    result.add(m.pprint_inner(indent + 2))

proc pprint_inner(n: Node, indent = 0): seq[(int, string)] =
  var s = &"[{$(n.tag)}] @{n.id} F:{n.output_frontier.pprint}"
  result.add((indent, s))
  for e in n.outputs:
    result.add(pprint_inner(e, indent + 1))
    discard

proc pprint_recursive_inner*(n: Node, indent = 0): seq[(int, string)] =
  result = n.pprint_inner(indent)
  if n.outputs.len > 0:
    result.add((indent + 1, &"children: {n.outputs.len}"))
    for e in n.outputs:
      result.add(pprint_recursive_inner(e.output, indent + 3))

template pprint*(n: Node, indent = 0): string =
  n.pprint_inner(indent).string_from_pprint_seq

template pprint_recursive*(n: Node, indent = 0): string =
  n.pprint_recursive_inner(indent).string_from_pprint_seq

proc pprint*(g: Graph): string =
  return g.top_node.pprint_recursive(0)

# Step #
# ---------------------------------------------------------------------

proc step(n: Node) =
  case n.tag:
    of tInput:
      discard "TODO"
    of tPassThrough:
      for m in n.inputs[0].queue:
        n.send(m)
      n.inputs[0].clear
    of tPrint:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:     echo &"{n.label}: D {m.version.pprint} {m.collection.rows}"
          of tFrontier: echo &"{n.label}: F {m.frontier.pprint}"
        n.send(m)
      n.inputs[0].clear
    of tNegate:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:     n.send(m.version, m.collection.negate)
          of tFrontier: n.handle_frontier_message_unary(m)
      n.inputs[0].clear
    of tMap:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:     n.send(m.version, m.collection.map(n.map_fn))
          of tFrontier: n.handle_frontier_message_unary(m)
      n.inputs[0].clear
    of tFilter:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:
            let new_coll = m.collection.filter(n.filter_fn)
            if new_coll.size > 0: n.send(m.version, new_coll)
          of tFrontier: n.handle_frontier_message_unary(m)
      n.inputs[0].clear
    of tFlatMap:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:
            let new_coll = m.collection.flat_map(n.flat_map_fn)
            if new_coll.size > 0: n.send(m.version, new_coll)
          of tFrontier: n.handle_frontier_message_unary(m)
      n.inputs[0].clear
    of tConcat:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:     n.send(m)
          of tFrontier: n.handle_frontier_message(m, 0)
      n.inputs[0].clear
      for m in n.inputs[1].queue:
        case m.tag:
          of tData:     n.send(m)
          of tFrontier: n.handle_frontier_message(m, 1)
      n.inputs[1].clear
    of tOnRow:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:
            for r in m.collection:
              n.on_row(r)
            n.send(m)
          of tFrontier: n.handle_frontier_message_unary(m)
      n.inputs[0].clear
    of tOnCollection:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:
            n.on_collection(m.version, m.collection)
            n.send(m)
          of tFrontier: n.handle_frontier_message_unary(m)
      n.inputs[0].clear
    of tAccumulateResults:
      for m in n.inputs[0].queue:
        case m.tag:
          of tData:
            n.results.add((m.version, m.collection))
            n.send(m)
          of tFrontier: n.handle_frontier_message_unary(m)
      n.inputs[0].clear
    else:
      discard
proc step*(g: Graph) =
  for n in g.nodes: n.step


