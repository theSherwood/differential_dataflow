# import std/[math, algorithm, strutils, strformat, sequtils, tables]
# import ../src/[values]
import ./src/nim/[common, map, arr]

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

proc run_benchmarks() =
  warmup()
  bench("sanity_check", "--", sanity_check, 0, 5000000)
  bench("sanity_check", "--", sanity_check, 0, 50000)
  bench("sanity_check", "--", sanity_check, 0, 500)

  # value benchmarks
  block:
    for it in [10, 100, 1000]:
      bench("arr_create", "immutable", arr_create, 0, it)
      bench("map_create", "immutable", map_create, 0, it)
      for sz in [1, 10, 100, 1000]:
        if it < 100 and sz < 100: continue
        if it > 100 and sz >= 100: continue
        if it >= 100 and sz > 100: continue
        block arr:
          bench("arr_push", "immutable", arr_push, sz, it)
          bench("arr_pop", "immutable", arr_pop, sz, it)
          bench("arr_slice", "immutable", arr_slice, sz, it)
          bench("arr_get_existing", "immutable", arr_get_existing, sz, it)
          bench("arr_get_non_existing", "immutable", arr_get_non_existing, sz, it)
          bench("arr_set", "immutable", arr_set, sz, it)
          bench("arr_iter", "immutable", arr_iter, sz, it)
          bench("arr_equal_true", "immutable", arr_equal_true, sz, it)
          bench("arr_equal_false", "immutable", arr_equal_false, sz, it)
        block map:
          bench("map_add_entry", "immutable", map_add_entry, sz, it)
          bench("map_add_entry_multiple", "immutable", map_add_entry_multiple, sz, it)
          bench("map_overwrite_entry", "immutable", map_overwrite_entry, sz, it)
          bench("map_del_entry", "immutable", map_del_entry, sz, it)
          bench("map_merge", "immutable", map_merge, sz, it)
          bench("map_has_key_true", "immutable", map_has_key_true, sz, it)
          bench("map_has_key_false", "immutable", map_has_key_false, sz, it)
          bench("map_get_existing", "immutable", map_get_existing, sz, it)
          bench("map_get_non_existing", "immutable", map_get_non_existing, sz, it)
          bench("map_iter_keys", "immutable", map_iter_keys, sz, it)
          bench("map_iter_values", "immutable", map_iter_values, sz, it)
          bench("map_iter_entries", "immutable", map_iter_entries, sz, it)
          bench("map_equal_true", "immutable", map_equal_true, sz, it)
          bench("map_equal_false", "immutable", map_equal_false, sz, it)

  # rules benchmarks
  block:
    discard

run_benchmarks()
output_results()
