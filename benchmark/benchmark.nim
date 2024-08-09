# import std/[math, algorithm, strutils, strformat, sequtils, tables]
# import nimprof
import ./src/nim/[common, rules]

const RUN_SANITY     = true
const RUN_RULES      = true

proc sanity_check(tr: TaskResult, sz, n: int) =
  var s = 0.0
  let Start = get_time()
  for i in 0..<n:
    s += i.float64
    if tr.runs.len > 1000000: echo s
    if tr.runs.len > 10000000: echo s
  tr.add(get_time() - Start)

proc output_results() =
  write_row("\"key\",\"sys\",\"desc\",\"runs\",\"minimum\",\"maximum\",\"mean\",\"median\"")
  for tr in csv_rows:
    tr.to_row.write_row

const IMPERATIVE = "imperative"

proc run_benchmarks() =
  warmup()
  if RUN_SANITY:
    bench("sanity_check", "--", sanity_check, 0, 5000000)
    bench("sanity_check", "--", sanity_check, 0, 50000)
    bench("sanity_check", "--", sanity_check, 0, 500)

  # rules benchmarks
  if RUN_RULES:
    bench("send_more_money", IMPERATIVE, send_more_money_imperative, 0, 1)

run_benchmarks()
output_results()
