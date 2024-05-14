# import std/[math, algorithm, strutils, strformat, sequtils, tables]
# import ../src/[values]
import ./src/nim/[common, map, arr, rules]
import ./src/nim/parazoa/arr as p_arr
import ./src/nim/parazoa/map as p_map
import ./src/nim/nim_persistent_vector/arr as pers_arr

const RUN_PARAZOA = true
const RUN_PERSVECTOR = true

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

const IMMUTABLE  = "immutable"
const PARAZOA    = "parazoa"
const PERSVECTOR = "persvector"
const IMPERATIVE = "imperative"

proc run_benchmarks() =
  warmup()
  bench("sanity_check", "--", sanity_check, 0, 5000000)
  bench("sanity_check", "--", sanity_check, 0, 50000)
  bench("sanity_check", "--", sanity_check, 0, 500)

  # value benchmarks
  block:
    # for it in [10]:
    for it in [10, 100, 1000]:
      bench("arr_create", IMMUTABLE, arr_create, 0, it)
      bench("map_create", IMMUTABLE, map_create, 0, it)
      if RUN_PERSVECTOR:
        bench("arr_create", PERSVECTOR, persvector_arr_create, 0, it)
      if RUN_PARAZOA:
        bench("arr_create", PARAZOA, parazoa_arr_create, 0, it)
        bench("map_create", PARAZOA, parazoa_map_create, 0, it)
      # for sz in [100]:
      for sz in [1, 10, 100, 1000]:
        if it < 100 and sz < 100: continue
        if it > 100 and sz >= 100: continue
        if it >= 100 and sz > 100: continue
        block arr:
          bench("arr_push", IMMUTABLE, arr_push, sz, it)
          bench("arr_pop", IMMUTABLE, arr_pop, sz, it)
          bench("arr_slice", IMMUTABLE, arr_slice, sz, it)
          bench("arr_get_existing", IMMUTABLE, arr_get_existing, sz, it)
          bench("arr_get_non_existing", IMMUTABLE, arr_get_non_existing, sz, it)
          bench("arr_set", IMMUTABLE, arr_set, sz, it)
          bench("arr_iter", IMMUTABLE, arr_iter, sz, it)
          bench("arr_equal_true", IMMUTABLE, arr_equal_true, sz, it)
          bench("arr_equal_false", IMMUTABLE, arr_equal_false, sz, it)
        # block map:
        if false:
          bench("map_add_entry", IMMUTABLE, map_add_entry, sz, it)
          bench("map_add_entry_multiple", IMMUTABLE, map_add_entry_multiple, sz, it)
          bench("map_overwrite_entry", IMMUTABLE, map_overwrite_entry, sz, it)
          bench("map_del_entry", IMMUTABLE, map_del_entry, sz, it)
          bench("map_merge", IMMUTABLE, map_merge, sz, it)
          bench("map_has_key_true", IMMUTABLE, map_has_key_true, sz, it)
          bench("map_has_key_false", IMMUTABLE, map_has_key_false, sz, it)
          bench("map_get_existing", IMMUTABLE, map_get_existing, sz, it)
          bench("map_get_non_existing", IMMUTABLE, map_get_non_existing, sz, it)
          bench("map_iter_keys", IMMUTABLE, map_iter_keys, sz, it)
          bench("map_iter_values", IMMUTABLE, map_iter_values, sz, it)
          bench("map_iter_entries", IMMUTABLE, map_iter_entries, sz, it)
          bench("map_equal_true", IMMUTABLE, map_equal_true, sz, it)
          bench("map_equal_false", IMMUTABLE, map_equal_false, sz, it)

        if RUN_PERSVECTOR:
          block arr:
            bench("arr_push", PERSVECTOR, persvector_arr_push, sz, it)
            bench("arr_pop", PERSVECTOR, persvector_arr_pop, sz, it)
            bench("arr_get_existing", PERSVECTOR, persvector_arr_get_existing, sz, it)
            # bench("arr_get_non_existing", PERSVECTOR, persvector_arr_get_non_existing, sz, it)
            bench("arr_set", PERSVECTOR, persvector_arr_set, sz, it)
            bench("arr_iter", PERSVECTOR, persvector_arr_iter, sz, it)
            # bench("arr_equal_true", PERSVECTOR, persvector_arr_equal_true, sz, it)
            # bench("arr_equal_false", PERSVECTOR, persvector_arr_equal_false, sz, it)

        if RUN_PARAZOA:
          block arr:
            bench("arr_push", PARAZOA, parazoa_arr_push, sz, it)
            bench("arr_pop", PARAZOA, parazoa_arr_pop, sz, it)
            bench("arr_get_existing", PARAZOA, parazoa_arr_get_existing, sz, it)
            bench("arr_get_non_existing", PARAZOA, parazoa_arr_get_non_existing, sz, it)
            bench("arr_set", PARAZOA, parazoa_arr_set, sz, it)
            bench("arr_iter", PARAZOA, parazoa_arr_iter, sz, it)
            bench("arr_equal_true", PARAZOA, parazoa_arr_equal_true, sz, it)
            bench("arr_equal_false", PARAZOA, parazoa_arr_equal_false, sz, it)
          # block map:
          if false:
            bench("map_add_entry", PARAZOA, parazoa_map_add_entry, sz, it)
            bench("map_add_entry_multiple", PARAZOA, parazoa_map_add_entry_multiple, sz, it)
            bench("map_overwrite_entry", PARAZOA, parazoa_map_overwrite_entry, sz, it)
            bench("map_del_entry", PARAZOA, parazoa_map_del_entry, sz, it)
            bench("map_merge", PARAZOA, parazoa_map_merge, sz, it)
            bench("map_has_key_true", PARAZOA, parazoa_map_has_key_true, sz, it)
            bench("map_has_key_false", PARAZOA, parazoa_map_has_key_false, sz, it)
            bench("map_get_existing", PARAZOA, parazoa_map_get_existing, sz, it)
            bench("map_get_non_existing", PARAZOA, parazoa_map_get_non_existing, sz, it)
            bench("map_iter_keys", PARAZOA, parazoa_map_iter_keys, sz, it)
            bench("map_iter_values", PARAZOA, parazoa_map_iter_values, sz, it)
            bench("map_iter_entries", PARAZOA, parazoa_map_iter_entries, sz, it)
            bench("map_equal_true", PARAZOA, parazoa_map_equal_true, sz, it)
            bench("map_equal_false", PARAZOA, parazoa_map_equal_false, sz, it)

  # rules benchmarks
  block:
    bench("send_more_money", IMPERATIVE, send_more_money_imperative, 0, 1)

run_benchmarks()
output_results()
