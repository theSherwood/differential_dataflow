# import std/[math, algorithm, strutils, strformat, sequtils, tables]
import ../../../src/[values]
import ./common

proc setup_seq_of_arrs*(sz, it, offset: int): seq[ImValue] =
  var i_off, k: int
  var a: ImArray
  for i in 0..<it:
    i_off = i + offset
    a = Arr [i_off]
    for j in 1..<sz:
      k = i_off + (j * 17)
      a = a.push(k.v)
    result.add(a.v)
template setup_seq_of_arrs*(sz, it: int): seq[ImValue] = setup_seq_of_arrs(sz, it, 0)

proc arr_create*(tr: TaskResult, sz, n: int) =
  var arrs: seq[ImValue] = @[]
  let Start = get_time()
  for i in 0..<n:
    arrs.add(V [i])
  tr.add(get_time() - Start)

proc arr_push*(tr: TaskResult, sz, n: int) =
  # setup
  var arrs = setup_seq_of_arrs(sz, n)
  # test
  let Start = get_time()
  for i in 0..<n:
    arrs[i] = arrs[i].push(i)
  tr.add(get_time() - Start)

proc arr_pop*(tr: TaskResult, sz, n: int) =
  # setup
  var arrs = setup_seq_of_arrs(sz, n)
  # test
  let Start = get_time()
  for i in 0..<n:
    arrs[i] = arrs[i].pop()[1]
  tr.add(get_time() - Start)

proc arr_slice*(tr: TaskResult, sz, n: int) =
  # setup
  var arrs = setup_seq_of_arrs(sz, n)
  # test
  let Start = get_time()
  for i in 0..<n:
    arrs[i] = arrs[i].slice(i, arrs[i].size.as_f64 / 2.0)
  tr.add(get_time() - Start)
