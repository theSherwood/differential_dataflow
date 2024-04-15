import std/[math, algorithm, sequtils, strutils, strformat]
from std/times import cpuTime
import ../src/[values]

# We have to multiply our seconds by 1_000_000 to get microseconds
const SCALE = 1_000_000
const WARMUP = 100_000 # microseconds
const TIMEOUT = SCALE

when defined(wasm):
  proc get_time(): float64 {.importc.}
  proc write_row_string(p: ptr, len: int): void {.importc.}
  proc write_row(row: string): void =
    write_row_string(row[0].addr, row.len)
else:
  proc get_time(): float64 =
    return cpuTime() * SCALE
  let file_name = "./benchmark/results_native.csv"
  let fd = file_name.open(fmWrite)
  proc write_row(row: string): void =
    fd.writeLine(row)

type
  TaskResult = ref object
    key*: string
    runs*: seq[float64]

var csv_rows: seq[TaskResult] = @[] 

template form(f: float64): string = f.formatFloat(ffDecimal, 2)

proc to_row(tr: TaskResult): string =
  var
    l = tr.runs.len
    s = &"\"{tr.key}\",{l},"
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
  median = (
    sorted_runs[(l / 2).floor.int] + sorted_runs[(l / 2).ceil.int]
  ) / 2
  s = &"{s}{minimum.form},{maximum.form},{mean.form},{median.form}"
  return s

template add(tr: TaskResult, v: float64) = tr.runs.add(v)

proc make_tr(key: string): TaskResult = 
  var tr = TaskResult()
  tr.key = key
  tr.runs = @[]
  csv_rows.add(tr)
  return tr

proc warmup() =
  var
    Start = get_time()
    End = get_time()
  while WARMUP > End - Start:
    End = get_time()

proc bench(key: string, fn: proc(tr: TaskResult): void) =
  warmup()
  var
    tr = make_tr(key)
    Start = get_time()
    End = get_time()
  while TIMEOUT > (End - Start):
    fn(tr)
    End = get_time()

proc benchmark_test(tr: TaskResult) =
  let Start = get_time()
  var s = 0.0
  var f = 0.0
  for i in 0..<5000000:
    f = i.float64
    s += f
    if tr.runs.len > 1000000: echo s
    if tr.runs.len > 10000000: echo s
  tr.add(get_time() - Start)

proc run_benchmarks() =
  bench("test?", benchmark_test)
  block:
    for tr in csv_rows:
      tr.to_row.write_row
  echo get_time()
  echo get_time()

run_benchmarks()
