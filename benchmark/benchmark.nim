import std/[math, algorithm, strutils, strformat]
import ../src/[values]

const WARMUP = 100_000 # microseconds
const TIMEOUT = 100_000

when defined(wasm):
  proc get_time(): float64 {.importc.}
  proc write_row_string(p: ptr, len: int): void {.importc.}
  proc write_row(row: string): void =
    write_row_string(row[0].addr, row.len)
  const sys = "wasm"
else:
  from std/times import cpuTime
  # We have to multiply our seconds by 1_000_000 to get microseconds
  const SCALE = 1_000_000
  proc get_time(): float64 =
    return cpuTime() * SCALE
  let file_name = "./benchmark/results_native.csv"
  let fd = file_name.open(fmWrite)
  proc write_row(row: string): void =
    fd.writeLine(row)
  const sys = "native"

type
  TaskResult = ref object
    key*, desc*: string
    runs*: seq[float64]

var csv_rows: seq[TaskResult] = @[] 

template form(f: float64): string = f.formatFloat(ffDecimal, 2)

proc to_row(tr: TaskResult): string =
  var
    l = tr.runs.len
    s = &"\"{tr.key}\",\"{sys}\",\"{tr.desc}\",{l},"
    sorted_runs = tr.runs.sorted()
    sum     = 0.0
    minimum = Inf
    maximum = 0.0
    mean    = 0.0
    median  = 0.0
  for r in sorted_runs:
    sum += r
    minimum = min(minimum, r)
    maximum = max(maximum, r)
  mean = sum / l.float64
  if sorted_runs.len == 1:
    median = sorted_runs[0]
  else:
    median = (
      sorted_runs[(l / 2).floor.int] + sorted_runs[(l / 2).ceil.int]
    ) / 2
  s = &"{s}{minimum.form},{maximum.form},{mean.form},{median.form}"
  return s

template add(tr: TaskResult, v: float64) = tr.runs.add(v)

proc make_tr(key, desc: string): TaskResult = 
  var tr = TaskResult()
  tr.key = key
  tr.desc = desc
  tr.runs = @[]
  csv_rows.add(tr)
  return tr

proc warmup() =
  var
    Start = get_time()
    End = get_time()
  while WARMUP > End - Start:
    End = get_time()

proc bench(
  key, desc: string,
  fn: proc(tr: TaskResult, size, iterations: int): void,
  size, iterations, timeout: int
  ) =
  var
    tr = make_tr(&"{key}_{size}_{iterations}", desc)
    Start = get_time()
    End = get_time()
  # run it at least once
  block:
    fn(tr, size, iterations)
    End = get_time()
  while timeout.float64 > (End - Start):
    fn(tr, size, iterations)
    End = get_time()
  echo &"done {sys} {tr.key}"
template bench(
  key, desc: string,
  fn: proc(tr: TaskResult, size, iterations: int): void,
  size, iterations: int
  ) =
  bench(key, desc, fn, size, iterations, TIMEOUT)

# #endregion ==========================================================
#            BENCHMARK DEFINITIONS
# #region =============================================================

proc sanity_check(tr: TaskResult, sz, n: int) =
  let Start = get_time()
  var s = 0.0
  for i in 0..<n:
    s += i.float64
    if tr.runs.len > 1000000: echo s
    if tr.runs.len > 10000000: echo s
  tr.add(get_time() - Start)

# VALUE BENCHMARKS #
# ---------------------------------------------------------------------

proc map_create(tr: TaskResult, sz, n: int) =
  let Start = get_time()
  var maps: seq[ImValue] = @[]
  for i in 0..<n:
    maps.add(V {i:i})
  tr.add(get_time() - Start)

proc arr_create(tr: TaskResult, sz, n: int) =
  let Start = get_time()
  var arrs: seq[ImValue] = @[]
  for i in 0..<n:
    arrs.add(V [i])
  tr.add(get_time() - Start)

proc setup_seq_of_maps(sz, it, offset: int): seq[ImValue] =
  var k: int
  var m: ImMap
  for i in 0..<it:
    m = Map {}
    for j in 1..<sz:
      k = (i + offset) * j * 17
      m = m.set(k, k)
    result.add(m.v)
template setup_seq_of_maps(sz, it: int): seq[ImValue] = setup_seq_of_maps(sz, it, 0)

proc map_add_entry(tr: TaskResult, sz, n: int) =
  # setup
  var maps = setup_seq_of_maps(sz, n)
  # test
  let Start = get_time()
  for i in 0..<n:
    maps[i] = maps[i].set(i + 1, i)
  tr.add(get_time() - Start)

proc map_add_entry_multiple(tr: TaskResult, sz, n: int) =
  # setup
  var maps = setup_seq_of_maps(sz, n)
  # test
  let Start = get_time()
  for i in 0..<n:
    maps[i] = maps[i]
      .set(i + 1, i + 1)
      .set(i + 2, i + 2)
      .set(i + 3, i + 3)
      .set(i + 4, i + 4)
      .set(i + 5, i + 5)
  tr.add(get_time() - Start)

proc map_overwrite_entry(tr: TaskResult, sz, n: int) =
  # setup
  var maps = setup_seq_of_maps(sz, n)
  # test
  let Start = get_time()
  for i in 0..<n:
    maps[i] = maps[i].set(i, i + 1)
  tr.add(get_time() - Start)

proc map_del_entry(tr: TaskResult, sz, n: int) =
  # setup
  var maps = setup_seq_of_maps(sz, n)
  # test
  let Start = get_time()
  for i in 0..<n:
    maps[i] = maps[i].del(i)
  tr.add(get_time() - Start)

proc map_merge(tr: TaskResult, sz, n: int) =
  # setup
  var maps1 = setup_seq_of_maps(sz, n)
  var maps2 = setup_seq_of_maps(sz, n, 3)
  var maps3: seq[ImValue] = @[]
  # test
  let Start = get_time()
  for i in 0..<n:
    maps3.add(maps1[i].merge(maps2[i]))
  tr.add(get_time() - Start)

# RULES BENCHMARKS #
# ---------------------------------------------------------------------

# #endregion ==========================================================
#            RUN BENCHMARKS
# #region =============================================================

proc run_benchmarks() =
  warmup()
  bench("sanity_check", "--", sanity_check, 0, 5000000)

  # value benchmarks
  block:
    for it in [10, 100, 1000]:
      bench("arr_create", "immutable", arr_create, 0, it)
      bench("map_create", "immutable", map_create, 0, it)
      for sz in [1, 10, 100, 1000]:
        if it > 10 and sz > 10: continue
        bench("map_add_entry", "immutable", map_add_entry, sz, it)
        bench("map_add_entry_multiple", "immutable", map_add_entry_multiple, sz, it)
        bench("map_overwrite_entry", "immutable", map_overwrite_entry, sz, it)
        bench("map_del_entry", "immutable", map_del_entry, sz, it)
        bench("map_merge", "immutable", map_merge, sz, it)

  # rules benchmarks
  block:
    discard

  # output results
  block:
    write_row("\"key\",\"sys\",\"desc\",\"runs\",\"minimum\",\"maximum\",\"mean\",\"median\"")
    for tr in csv_rows:
      tr.to_row.write_row

run_benchmarks()
