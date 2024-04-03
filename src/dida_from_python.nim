import std/[tables, sets, bitops, strutils, sequtils, sugar]
import hashes
import values

when defined(isNimSkull):
  {.pragma: ex, exportc, dynlib.}
else:
  import std/[macros]
  macro ex*(t: typed): untyped =
    if t.kind notin {nnkProcDef, nnkFuncDef}:
      error("Can only export procedures", t)
    let
      newProc = copyNimTree(t)
      codeGen = nnkExprColonExpr.newTree(ident"codegendecl",
          newLit"EMSCRIPTEN_KEEPALIVE $# $#$#")
    if newProc[4].kind == nnkEmpty:
      newProc[4] = nnkPragma.newTree(codeGen)
    else:
      newProc[4].add codeGen
    newProc[4].add ident"exportC"
    result = newStmtList()
    result.add:
      quote do:
        {.emit: "/*INCLUDESECTION*/\n#include <emscripten.h>".}
    result.add:
      newProc
  # {.pragma: ex, exportc, dynlib.}

type
  Key* = ImValue
  Value* = ImValue
  Entry* = (Key, Value)

  Row* = (Entry, int)
  
  Collection* = object
    rows*: seq[Row]

  MapFn* = proc (e: Entry): Entry {.closure.}
  FilterFn* = proc (e: Entry): bool {.closure.}

proc size*(c: Collection): int = return c.rows.len

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
    t[e] = m + t.getOrDefault(e, m)
  for e, m in t.pairs:
    if m != 0: result.add((e, m))

proc join*(c1, c2: Collection): Collection =
  let empty_seq = newSeq[Row]()
  var t = initTable[Key, seq[Row]]()
  for r in c1:
    if t.hasKey(r.key):
      t[r.key].add(r)
    else:
      t[r.key] = @[r]
  for r in c2:
    for r2 in t.getOrDefault(r.key, empty_seq):
      result.add(((r.key, init_array([r.value, r2.value]).v), r.multiplicity * r2.multiplicity))


