import fs from "node:fs";
import path from "node:path";
import { strict as assert } from "node:assert";
import { Map as ImMap, List as ImArr } from "immutable";
import nools from "nools";
import { fileURLToPath } from "node:url";
import { load_manners_data } from "./data/manners.js";
import { load_waltz_db_data } from "./data/waltz_db.js";
import { produce } from "immer";
import deep_eq from "deep-equal";

// Polyfill __dirname because we are doing some ESM nonsense
const __dirname = path.dirname(fileURLToPath(import.meta.url));

const OUTPUT_PATH = "./benchmark/results_js.csv";
const WARMUP = 100_000; // microseconds
// We are probably going to be running into issues with JIT massively optimizing
// things if we are using a timeout this long. So we also include a LOW_TIMEOUT
// for use when we want it.
const TIMEOUT = 100_000;
const LOW_TIMEOUT = 2;
const RUN_NOOLS = false;

let csv_rows = [];

function get_time() {
  return performance.now() * 1000;
}

let form = (f) => f.toFixed(2);

function to_row(tr) {
  let l = tr.runs.length,
    s = `"${tr.key}","js","${tr.desc}",${l},`,
    sorted_runs = tr.runs.toSorted(),
    sum = 0,
    minimum = Infinity,
    maximum = 0,
    mean = 0,
    median = 0,
    r = 0;
  for (let i = 0; i < l; i++) {
    r = sorted_runs[i];
    sum += r;
    minimum = Math.min(minimum, r);
    maximum = Math.max(maximum, r);
  }
  mean = sum / l;
  if (l == 1) median = sorted_runs[0];
  else median = (sorted_runs[Math.floor(l / 2)] + sorted_runs[Math.ceil(l / 2)]) / 2;
  s += `${form(minimum)},${form(maximum)},${form(mean)},${form(median)}`;
  return s;
}

async function warmup() {
  return setTimeout(() => {}, WARMUP / 1000);
}

function bench_sync(key, desc, fn, sz, iterations, timeout = TIMEOUT) {
  let tr = { key: `${key}_${sz}_${iterations}`, desc, runs: [] };
  csv_rows.push(tr);
  let start = get_time();
  let end = get_time();
  // Ensure that it runs at least once
  do {
    fn(tr, sz, iterations);
    end = get_time();
  } while (timeout > end - start);
  console.log(`done js ${tr.key}`);
}

async function bench_async(key, desc, fn, sz, iterations, timeout = TIMEOUT) {
  let tr = { key: `${key}_${sz}_${iterations}`, desc, runs: [] };
  csv_rows.push(tr);
  let start = get_time();
  let end = get_time();
  // Ensure that it runs at least once
  do {
    await fn(tr, sz, iterations);
    end = get_time();
  } while (timeout > end - start);
  console.log(`done js ${tr.key}`);
}

// #endregion ==========================================================
//            BENCHMARK DEFINITIONS
// #region =============================================================

function sanity_check(tr, _sz, n) {
  let start = get_time();
  var s = 0.0;
  for (let f = 0; f < n; f++) {
    s += f;
    // Add these lines to keep this from getting optimized away
    if (tr.runs.length > 1000000) console.log(s);
    if (tr.runs.length > 10000000) console.log(s);
  }
  tr.runs.push(get_time() - start);
}

/* VALUE BENCHMARKS */
/*--------------------------------------------------------------------*/

function pojo_create(tr, sz, n) {
  let start = get_time();
  let objs = [];
  for (let i = 0; i < n; i++) {
    objs.push({ i: i });
  }
  tr.runs.push(get_time() - start);
}

function plain_arr_create(tr, sz, n) {
  let start = get_time();
  let arrs = [];
  for (let i = 0; i < n; i++) {
    arrs.push([i]);
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_create(tr, sz, n) {
  let start = get_time();
  let maps = [];
  for (let i = 0; i < n; i++) {
    maps.push(ImMap({ i: i }));
  }
  tr.runs.push(get_time() - start);
}

function immutable_arr_create(tr, sz, n) {
  let start = get_time();
  let arrs = [];
  for (let i = 0; i < n; i++) {
    arrs.push(ImArr([i]));
  }
  tr.runs.push(get_time() - start);
}

function setup_arr_of_pojos(sz, n, offset = 0) {
  let pojos = [];
  let i_off, k;
  for (let i = 0; i < n; i++) {
    i_off = i + offset;
    let pojo = { [i_off]: i_off };
    for (let j = 1; j < sz; j++) {
      k = i_off + j * 17;
      pojo[k] = k;
    }
    pojos.push(pojo);
  }
  return pojos;
}

function setup_arr_of_immutable_maps(sz, n, offset = 0) {
  let maps = [];
  let i_off, k;
  for (let i = 0; i < n; i++) {
    i_off = i + offset;
    let map = ImMap({ [i_off]: i_off });
    for (let j = 1; j < sz; j++) {
      k = i_off + j * 17;
      map = map.set(k, k);
    }
    maps.push(map);
  }
  return maps;
}

function force_copy(m) {
  return m.set(-1, -1).delete(-1);
}

function pojo_add_entry_by_mutation(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs[i][i + 1] = i + 1;
  }
  tr.runs.push(get_time() - start);
}

function pojo_add_entry_by_spread(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs[i] = { ...objs[i], [i + 1]: i + 1 };
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_add_entry(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = maps[i].set(i + 1, i + 1);
  }
  tr.runs.push(get_time() - start);
}

function immer_pojo_add_entry(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = produce(maps[i], (m) => {
      m[i + 1] = i + 1;
    });
  }
  tr.runs.push(get_time() - start);
}

function pojo_add_entry_by_mutation_multiple(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    let o = objs[i];
    o[i + 1] = i + 1;
    o[i + 2] = i + 2;
    o[i + 3] = i + 3;
    o[i + 4] = i + 4;
    o[i + 5] = i + 5;
  }
  tr.runs.push(get_time() - start);
}

function pojo_add_entry_by_spread_multiple(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs[i] = {
      ...{
        ...{
          ...{
            ...{
              ...objs[i],
              [i + 1]: i + 1,
            },
            [i + 2]: i + 2,
          },
          [i + 3]: i + 3,
        },
        [i + 4]: i + 4,
      },
      [i + 5]: i + 5,
    };
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_add_entry_multiple(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = maps[i]
      .set(i + 1, i + 1)
      .set(i + 2, i + 2)
      .set(i + 3, i + 3)
      .set(i + 4, i + 4)
      .set(i + 5, i + 5);
  }
  tr.runs.push(get_time() - start);
}

function immer_pojo_add_entry_multiple(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = produce(maps[i], (m) => {
      m[i + 1] = i + 1;
    });
    maps[i] = produce(maps[i], (m) => {
      m[i + 2] = i + 2;
    });
    maps[i] = produce(maps[i], (m) => {
      m[i + 3] = i + 3;
    });
    maps[i] = produce(maps[i], (m) => {
      m[i + 4] = i + 4;
    });
    maps[i] = produce(maps[i], (m) => {
      m[i + 5] = i + 5;
    });
  }
  tr.runs.push(get_time() - start);
}

function pojo_add_entry_by_spread_multiple_batched(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs[i] = {
      ...objs[i],
      [i + 1]: i + 1,
      [i + 2]: i + 2,
      [i + 3]: i + 3,
      [i + 4]: i + 4,
      [i + 5]: i + 5,
    };
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_add_entry_multiple_batched(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = maps[i].withMutations((m) =>
      m
        .set(i + 1, i + 1)
        .set(i + 2, i + 2)
        .set(i + 3, i + 3)
        .set(i + 4, i + 4)
        .set(i + 5, i + 5)
    );
  }
  tr.runs.push(get_time() - start);
}

function immer_pojo_add_entry_multiple_batched(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = produce(maps[i], (m) => {
      m[i + 1] = i + 1;
      m[i + 2] = i + 2;
      m[i + 3] = i + 3;
      m[i + 4] = i + 4;
      m[i + 5] = i + 5;
    });
  }
  tr.runs.push(get_time() - start);
}

function pojo_overwrite_entry(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs[i][i] = i + 1;
  }
  tr.runs.push(get_time() - start);
}

function pojo_overwrite_entry_by_spread(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs[i] = { ...objs[i], [i]: i + 1 };
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_overwrite_entry(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = maps[i].set(i, i + 1);
  }
  tr.runs.push(get_time() - start);
}

function immer_pojo_overwrite_entry(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = produce(maps[i], (m) => {
      m[i] = i + 1;
    });
  }
  tr.runs.push(get_time() - start);
}

function pojo_del_entry_by_mutation(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    delete objs[i][i];
  }
  tr.runs.push(get_time() - start);
}

function pojo_del_entry_by_spread(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs[i] = { ...objs[i] };
    delete objs[i][i];
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_del_entry(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = maps[i].delete(i);
  }
  tr.runs.push(get_time() - start);
}

function immer_pojo_del_entry(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_pojos(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps[i] = produce(maps[i], (m) => {
      delete m[i];
    });
  }
  tr.runs.push(get_time() - start);
}

function pojo_merge_by_mutation(tr, sz, n) {
  /* setup */
  let objs1 = setup_arr_of_pojos(sz, n);
  let objs2 = setup_arr_of_pojos(sz, n, 3);
  let objs3 = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs3[i] = Object.assign(objs1[i], objs2[i]);
  }
  tr.runs.push(get_time() - start);
}

function pojo_merge_by_spread(tr, sz, n) {
  /* setup */
  let objs1 = setup_arr_of_pojos(sz, n);
  let objs2 = setup_arr_of_pojos(sz, n, 3);
  let objs3 = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs3[i] = { ...objs1[i], ...objs2[i] };
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_merge(tr, sz, n) {
  /* setup */
  let maps1 = setup_arr_of_immutable_maps(sz, n);
  let maps2 = setup_arr_of_immutable_maps(sz, n, 3);
  let maps3 = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    maps3[i] = maps1[i].merge(maps2[i]);
  }
  tr.runs.push(get_time() - start);
}

function immer_pojo_merge(tr, sz, n) {
  /* setup */
  let objs1 = setup_arr_of_pojos(sz, n);
  let objs2 = setup_arr_of_pojos(sz, n, 3);
  let objs3 = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    objs3[i] = produce(objs1[i], (m) => {
      Object.assign(m, objs2[i]);
    });
  }
  tr.runs.push(get_time() - start);
}

function pojo_has_key_true(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let bools = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    bools[i] = i in objs[i];
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b === true)
  );
}

function pojo_has_key_false(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let bools = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    bools[i] = i + 1 in objs[i];
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b === false)
  );
}

function immutable_map_has_key_true(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let bools = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    bools[i] = maps[i].has(i + "");
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b === true)
  );
}

function immutable_map_has_key_false(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let bools = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    bools[i] = maps[i].has(i + 1 + "");
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b === false)
  );
}

function pojo_get_existing(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let vals = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    vals[i] = objs[i][i];
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    vals.every((v) => v !== undefined)
  );
}

function pojo_get_non_existing(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let vals = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    vals[i] = objs[i][i + 1];
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    vals.every((v) => v === undefined)
  );
}

function immutable_map_get_existing(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let vals = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    vals[i] = maps[i].get(i + "");
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    vals.every((v) => v !== undefined)
  );
}

function immutable_map_get_non_existing(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let vals = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    vals[i] = maps[i].get(i + 1 + "");
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    vals.every((v) => v === undefined)
  );
}

function pojo_iter_keys(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let iters = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    iters.push(Object.keys(objs[i]));
  }
  tr.runs.push(get_time() - start);
}

function pojo_iter_values(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let iters = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    iters.push(Object.values(objs[i]));
  }
  tr.runs.push(get_time() - start);
}

function pojo_iter_entries(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let iters = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    iters.push(Object.entries(objs[i]));
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_iter_keys(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let iters = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    let vals = [];
    for (let v of maps[i].keys()) vals.push(v);
    iters.push(vals);
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_iter_values(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let iters = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    let vals = [];
    for (let v of maps[i].values()) vals.push(v);
    iters.push(vals);
  }
  tr.runs.push(get_time() - start);
}

function immutable_map_iter_entries(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let iters = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    let vals = [];
    for (let v of maps[i].entries()) vals.push(v);
    iters.push(vals);
  }
  tr.runs.push(get_time() - start);
}

function pojo_equal_true(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let copies = objs.map((o) => Object.assign({}, o));
  let bools = [];
  /* test */
  let start = get_time();
  let opts = { strict: true };
  for (let i = 0; i < n; i++) {
    bools[i] = deep_eq(objs[i], copies[i], opts);
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b)
  );
}

function pojo_equal_false(tr, sz, n) {
  /* setup */
  let objs = setup_arr_of_pojos(sz, n);
  let objs2 = setup_arr_of_pojos(sz, n, 3);
  let bools = [];
  /* test */
  let start = get_time();
  let opts = { strict: true };
  for (let i = 0; i < n; i++) {
    bools[i] = deep_eq(objs[i], objs2[i], opts);
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b === false)
  );
}

function immutable_map_equal_true(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let copies = maps.map(force_copy);
  let bools = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    bools[i] = maps[i].equals(copies[i]);
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b)
  );
}

function immutable_map_equal_false(tr, sz, n) {
  /* setup */
  let maps = setup_arr_of_immutable_maps(sz, n);
  let maps2 = setup_arr_of_immutable_maps(sz, n, 3);
  let bools = [];
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    bools[i] = maps[i].equals(maps2[i]);
  }
  tr.runs.push(get_time() - start);
  assert.equal(
    true,
    bools.every((b) => b === false)
  );
}

/* RULES BENCHMARKS */
/*--------------------------------------------------------------------*/

/**
 *
 * @link
 * https://github.com/noolsjs/nools/blob/master/examples/browser/sendMoreMoney.html
 */
function send_more_money_nools(tr, sz, n) {
  let nools_code = fs
    .readFileSync(path.resolve(__dirname, "./src/send_more_money.nools"))
    .toString();
  var flow = nools.compile(nools_code, { name: "SendMoreMoney" });
  let start = get_time();
  let session;
  for (let i = 0; i < n; i++) {
    // calculate
    (session = flow.getSession(0, 1, 2, 3, 4, 5, 6, 7, 8, 9))
      .on("solved", function (solved) {})
      .match()
      .then(function () {
        session.dispose();
      });
  }
  tr.runs.push(get_time() - start);
}

/**
 * @link
 * https://github.com/noolsjs/nools/blob/master/examples/browser/manners.html
 *
 * @param {128 | 64 | 32 | 16 | 8 | 5} sz
 */
async function manners_nools(tr, sz, _n) {
  let name = "manners_" + sz;
  let nools_code = fs.readFileSync(path.resolve(__dirname, "./src/manners.nools")).toString();
  let session,
    flow = nools.compile(nools_code, { name }),
    Count = flow.getDefined("count"),
    guests = load_manners_data(flow, name);
  session = flow.getSession();
  for (var i = 0, l = guests.length; i < l; i++) {
    session.assert(guests[i]);
  }
  session.assert(new Count({ value: 1 }));
  let start = get_time();
  await new Promise((resolve, reject) => {
    session
      .on("pathDone", function (obj) {})
      .match()
      .then(
        function () {
          /* done */
          resolve();
        },
        function (e) {
          console.error(e);
          reject();
        }
      );
  });
  tr.runs.push(get_time() - start);
}

/**
 * @link
 * https://github.com/noolsjs/nools/blob/master/examples/browser/waltzDb.html
 *
 * @param {16 | 12 | 8 | 4} sz
 */
async function waltz_db_nools(tr, sz, _n) {
  let name = "waltz_db_" + sz;
  let nools_code = fs.readFileSync(path.resolve(__dirname, "./src/waltz_db.nools")).toString();
  let session,
    flow = nools
      .compile(nools_code, { name })
      .conflictResolution(["salience", "factRecency", "activationRecency"]),
    data = load_waltz_db_data(flow, name);
  session = flow.getSession();
  for (var i = 0, l = data.length; i < l; i++) {
    session.assert(data[i]);
  }
  session.assert(new (flow.getDefined("stage"))({ value: "DUPLICATE" }));
  let start = get_time();
  await new Promise((resolve, reject) => {
    session
      .on("log", function (obj) {})
      .match()
      .then(
        function () {
          /* done */
          resolve();
        },
        function (e) {
          console.error(e);
          reject();
        }
      );
  });
  tr.runs.push(get_time() - start);
}

// #endregion ==========================================================
//            RUN BENCHMARKS
// #region =============================================================

/* descriptions */
const PLAIN = "plain";
const PLAIN_MUTATION = "plain_mutation";
const PLAIN_SPREAD = "plain_spread";
const IMMER_POJO = "immer_pojo";
const IMMUTABLEJS = "_immutable.js"; /* add a leading _ so it sorts first; we compare against it */

async function run_benchmarks() {
  await warmup();
  bench_sync("sanity_check", "--", sanity_check, 0, 5000000);
  /* value benchmarks */
  {
    /* prettier-ignore */
    for (let it of [10, 100, 1000]) {
      /* array */
      bench_sync("arr_create", PLAIN, plain_arr_create, 0, it, LOW_TIMEOUT);
      bench_sync("arr_create", IMMUTABLEJS, immutable_arr_create, 0, it, LOW_TIMEOUT);
      /* map */
      bench_sync("map_create", PLAIN, pojo_create, 0, it, LOW_TIMEOUT);
      bench_sync("map_create", IMMUTABLEJS, immutable_map_create, 0, it, LOW_TIMEOUT);
      for (let sz of [1, 10, 100, 1000]) {
        if (it > 10 && sz > 10) continue;
        bench_sync("map_add_entry", PLAIN_MUTATION, pojo_add_entry_by_mutation, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry", PLAIN_SPREAD, pojo_add_entry_by_spread, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry", IMMUTABLEJS, immutable_map_add_entry, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry", IMMER_POJO, immer_pojo_add_entry, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple", PLAIN_MUTATION, pojo_add_entry_by_mutation_multiple, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple", PLAIN_SPREAD, pojo_add_entry_by_spread_multiple, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple", IMMUTABLEJS, immutable_map_add_entry_multiple, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple", IMMER_POJO, immer_pojo_add_entry_multiple, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple_batched", PLAIN_MUTATION, pojo_add_entry_by_mutation_multiple, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple_batched", PLAIN_SPREAD, pojo_add_entry_by_spread_multiple_batched, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple_batched", IMMUTABLEJS, immutable_map_add_entry_multiple_batched, sz, it, LOW_TIMEOUT);
        bench_sync("map_add_entry_multiple_batched", IMMER_POJO, immer_pojo_add_entry_multiple_batched, sz, it, LOW_TIMEOUT);
        bench_sync("map_overwrite_entry", PLAIN_MUTATION, pojo_overwrite_entry, sz, it, LOW_TIMEOUT);
        bench_sync("map_overwrite_entry", PLAIN_SPREAD, pojo_overwrite_entry_by_spread, sz, it, LOW_TIMEOUT);
        bench_sync("map_overwrite_entry", IMMUTABLEJS, immutable_map_overwrite_entry, sz, it, LOW_TIMEOUT);
        bench_sync("map_overwrite_entry", IMMER_POJO, immer_pojo_overwrite_entry, sz, it, LOW_TIMEOUT);
        bench_sync("map_del_entry", PLAIN_MUTATION, pojo_del_entry_by_mutation, sz, it, LOW_TIMEOUT)
        bench_sync("map_del_entry", PLAIN_SPREAD, pojo_del_entry_by_spread, sz, it, LOW_TIMEOUT)
        bench_sync("map_del_entry", IMMUTABLEJS, immutable_map_del_entry, sz, it, LOW_TIMEOUT)
        bench_sync("map_del_entry", IMMER_POJO, immer_pojo_del_entry, sz, it, LOW_TIMEOUT)
        bench_sync("map_merge", PLAIN_MUTATION, pojo_merge_by_mutation, sz, it, LOW_TIMEOUT)
        bench_sync("map_merge", PLAIN_SPREAD, pojo_merge_by_spread, sz, it, LOW_TIMEOUT)
        bench_sync("map_merge", IMMUTABLEJS, immutable_map_merge, sz, it, LOW_TIMEOUT)
        bench_sync("map_merge", IMMER_POJO, immer_pojo_merge, sz, it, LOW_TIMEOUT)
        bench_sync("map_has_key_true", PLAIN, pojo_has_key_true, sz, it, LOW_TIMEOUT)
        bench_sync("map_has_key_true", IMMUTABLEJS, immutable_map_has_key_true, sz, it, LOW_TIMEOUT)
        bench_sync("map_has_key_false", PLAIN, pojo_has_key_false, sz, it, LOW_TIMEOUT)
        bench_sync("map_has_key_false", IMMUTABLEJS, immutable_map_has_key_false, sz, it, LOW_TIMEOUT)
        bench_sync("map_get_existing", PLAIN, pojo_get_existing, sz, it, LOW_TIMEOUT)
        bench_sync("map_get_existing", IMMUTABLEJS, immutable_map_get_existing, sz, it, LOW_TIMEOUT)
        bench_sync("map_get_non_existing", PLAIN, pojo_get_non_existing, sz, it, LOW_TIMEOUT)
        bench_sync("map_get_non_existing", IMMUTABLEJS, immutable_map_get_non_existing, sz, it, LOW_TIMEOUT)
        bench_sync("map_iter_keys", PLAIN, pojo_iter_keys, sz, it, LOW_TIMEOUT)
        bench_sync("map_iter_keys", IMMUTABLEJS, immutable_map_iter_keys, sz, it, LOW_TIMEOUT)
        bench_sync("map_iter_values", PLAIN, pojo_iter_values, sz, it, LOW_TIMEOUT)
        bench_sync("map_iter_values", IMMUTABLEJS, immutable_map_iter_values, sz, it, LOW_TIMEOUT)
        bench_sync("map_iter_entries", PLAIN, pojo_iter_entries, sz, it, LOW_TIMEOUT)
        bench_sync("map_iter_entries", IMMUTABLEJS, immutable_map_iter_entries, sz, it, LOW_TIMEOUT)
        bench_sync("map_equal_true", PLAIN, pojo_equal_true, sz, it, LOW_TIMEOUT)
        bench_sync("map_equal_true", IMMUTABLEJS, immutable_map_equal_true, sz, it, LOW_TIMEOUT)
        bench_sync("map_equal_false", PLAIN, pojo_equal_false, sz, it, LOW_TIMEOUT)
        bench_sync("map_equal_false", IMMUTABLEJS, immutable_map_equal_false, sz, it, LOW_TIMEOUT)
      }
    }
  }
  /* rules benchmarks */
  {
    /* nools */
    if (RUN_NOOLS) {
      await Promise.all([
        bench_sync("send_more_money", "nools", send_more_money_nools, 0, 1),
        bench_async("manners", "nools", manners_nools, 5, 1),
        bench_async("manners", "nools", manners_nools, 8, 1),
        // bench_async("manners", "nools", manners_nools, 16, 1),
        // bench_async("manners", "nools", manners_nools, 32, 1),
        // bench_async("manners", "nools", manners_nools, 64, 1),
        // bench_async("manners", "nools", manners_nools, 128, 1),
        bench_async("waltz_db", "nools", waltz_db_nools, 4, 1),
        bench_async("waltz_db", "nools", waltz_db_nools, 8, 1),
        // bench_async("waltz_db", "nools", waltz_db_nools, 12, 1),
        // bench_async("waltz_db", "nools", waltz_db_nools, 16, 1),
      ]);
    }
  }
}

run_benchmarks().then(() => {
  fs.writeFileSync(
    OUTPUT_PATH,
    '"key","sys","desc","runs","minimum","maximum","mean","median"\n' +
      csv_rows.map(to_row).join("\n")
  );
});
