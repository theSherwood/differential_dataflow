# import std/[math, algorithm, strutils, strformat, sequtils, tables]
import ../../../src/[values]
import ./common

proc arr_create*(tr: TaskResult, sz, n: int) =
  let Start = get_time()
  var arrs: seq[ImValue] = @[]
  for i in 0..<n:
    arrs.add(V [i])
  tr.add(get_time() - Start)
