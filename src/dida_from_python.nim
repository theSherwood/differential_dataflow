import std/[tables, sets, bitops, strutils, sequtils, sugar]
import hashes
import values

# Collection #
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

# Difference Collection #
# ---------------------------------------------------------------------

