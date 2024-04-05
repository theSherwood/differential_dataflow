import std/[tables, sets, bitops, strutils, sequtils, sugar, algorithm]
import hashes
import values

# Collections #
# ---------------------------------------------------------------------

type
  Key* = ImValue
  Value* = ImValue
  Entry* = (Key, Value)

  Row* = (Entry, int)
  
  Collection* = object
    rows*: seq[Row]

  MapFn* = proc (e: Entry): Entry {.closure.}
  FilterFn* = proc (e: Entry): bool {.closure.}
  ReduceFn* = proc (rows: seq[Row]): seq[Row] {.closure.}
  IterateFn* = proc (c: Collection): Collection {.closure.}

proc size*(c: Collection): int = return c.rows.len

template key*(e: Entry): Key = e[0]
template value*(e: Entry): Value = e[1]
template entry*(r: Row): Entry = r[0]
template key*(r: Row): Key = r[0][0]
template value*(r: Row): Value = r[0][1]
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

proc to_row_table_by_key(t: var Table[Key, seq[Row]], c: Collection) =
  for r in c:
    if t.hasKey(r.key):
      t[r.key].add(r)
    else:
      t[r.key] = @[r]

proc join*(c1, c2: Collection): Collection =
  let empty_seq = newSeq[Row]()
  var t = initTable[Key, seq[Row]]()
  t.to_row_table_by_key(c1)
  for r in c2:
    for r2 in t.getOrDefault(r.key, empty_seq):
      result.add(((r.key, init_array([r2.value, r.value]).v), r.multiplicity * r2.multiplicity))

## Keys must not be changed by the reduce fn
proc reduce*(c: Collection, f: ReduceFn): Collection =
  var t = initTable[Key, seq[Row]]()
  t.to_row_table_by_key(c)
  for r in t.values:
    for r2 in f(r):
      result.add(r2)

proc count_inner(rows: seq[Row]): seq[Row] =
  let k = rows[0].key
  var cnt = 0
  for r in rows: cnt += r.multiplicity
  return @[((k, cnt.float64.v), 1)]

proc count*(c: Collection): Collection =
  return c.reduce(count_inner)

proc sum_inner(rows: seq[Row]): seq[Row] =
  let k = rows[0].key
  var cnt = 0.float64
  for r in rows: cnt += r.value.as_f64 * r.multiplicity.float64
  return @[((k, cnt.v), 1)]

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
    return @[((k, min_val), 1)]
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
    return @[((k, max_val), 1)]
  else:
    return @[]

proc max*(c: Collection): Collection =
  try:
    return c.reduce(max_inner)
  except TypeException as e:
    raise newException(TypeException, "Incomparable types")

proc iterate*(c: Collection, f: IterateFn): Collection =
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
  Mapper* = object
    map_fn*: proc (): void
  Filterer* = object
    filter_fn*: proc (): void
  Reducer* = object
    reducer_fn*: proc (): void

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
    queue*: seq[int]
  
  NodeTag* = enum
    tPassThrough
    tIterate
    tInput
    tOutput
    tIndex
    tJoin
    tConcat
    tMap
    tFilter
    tReduce
    tDistinct
    tCount
    tMin
    tMax
    tSum
    tPrint
    tNegate
    tConsolidate
    tVersionPush
    tVersionIncrement
    tVersionPop

  Node* = ref object
    id*: int
    inputs*: seq[Edge]
    outputs*: seq[Edge]
    frontier*: Frontier
    case tag*: NodeTag:
      of tPrint:
        label*: string
      of tMap:
        mapper*: Mapper
      of tFilter:
        filterer*: Filterer
      of tReduce:
        init_value*: Value
        reducer*: Reducer
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
    doAssert n in g.nodes
  var e = Edge()
  e.id = edge_id
  edge_id += 1
  e.input = n
  e.output = n2
  e.queue = @[]
  n.outputs.add(e)
  n2.inputs.add(e)
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
    frontier: f,
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

proc init_builder*(g: Graph, f: Frontier): Builder =
  var b = Builder()
  b.graph = g
  b.frontier = f
  b.node = nil
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
  result.node = n

proc concat*(b: Builder, other: Node): Builder =
  build_binary(b, tConcat, other)
template concat*(b1, b2: Builder): Builder = b1.concat(b2.node)

# proc send_data*(e: Edge, v: Version, c: Collection) =
#   discard

proc step*(n: Node) =
  case n.tag:
    of tPassThrough:
      discard
    of tPrint:
      discard
    else:
      discard


