import fs from "node:fs";
import { Map as ImMap, List as ImArr } from "immutable";
import nools from "nools";

const OUTPUT_PATH = "./benchmark/results_js.csv";
const WARMUP = 100_000; // microseconds
// We are probably going to be running into issues with JIT massively optimizing
// things if we are using a timeout this long. So we also include a LOW_TIMEOUT
// for use when we want it.
const TIMEOUT = 100_000;
const LOW_TIMEOUT = 2;

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

async function bench(key, desc, fn, iterations, timeout = TIMEOUT) {
  let tr = { key: key + "_" + iterations, desc, runs: [] };
  csv_rows.push(tr);
  let start = get_time();
  let end = get_time();
  while (timeout > end - start) {
    fn(tr, iterations);
    end = get_time();
  }
}

// #endregion ==========================================================
//            BENCHMARK DEFINITIONS
// #region =============================================================

function sanity_check(tr, n) {
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

function create_plain_maps(tr, n) {
  let start = get_time();
  let maps = [];
  for (let i = 0; i < n; i++) {
    maps.push({ i: i });
  }
  tr.runs.push(get_time() - start);
}

function create_plain_arrays(tr, n) {
  let start = get_time();
  let arrs = [];
  for (let i = 0; i < n; i++) {
    arrs.push([i]);
  }
  tr.runs.push(get_time() - start);
}

function create_immutable_maps(tr, n) {
  let start = get_time();
  let maps = [];
  for (let i = 0; i < n; i++) {
    maps.push(ImMap({ i: i }));
  }
  tr.runs.push(get_time() - start);
}

function create_immutable_arrays(tr, n) {
  let start = get_time();
  let arrs = [];
  for (let i = 0; i < n; i++) {
    arrs.push(ImArr([i]));
  }
  tr.runs.push(get_time() - start);
}

/**
 * 
 * @link
 * https://github.com/noolsjs/nools/blob/master/examples/browser/rules/sendMoreMoney.nools
 * https://github.com/noolsjs/nools/blob/master/examples/browser/sendMoreMoney.html
 */
function send_more_money_nools(tr, n) {
  let nools_code = `
rule SendMoreMoney {
  when {
      s : Number s != 0;
      e : Number e != s;
      n : Number n != s && n != e;
      d : Number d != s && d != e && d != n;
      m : Number m != 0 && m != s && m != e && m != n && m != d;
      o : Number o != s && o != e && o != n && o != d && o != m;
      r : Number r != s && r != e && r != n && r != d && r != m && r != o;
      y : Number y != s && y != e && y != n && y != d && y != m && y != o && y != r
          && (s*1000 + e*100 + n*10 + d + m*1000 + o*100 + r*10 + e) == (m*10000 + o*1000 + n*100 + e*10 + y);
  }
  then {
      emit("solved", {s : s, e : e, n : n, d : d, m : m, o: o, r : r, y : y});
  }
}`;
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

// #endregion ==========================================================
//            RUN BENCHMARKS
// #region =============================================================

async function run_benchmarks() {
  await warmup();
  bench("sanity_check", "--", sanity_check, 5000000);
  for (let it of [10, 100, 1000]) {
    bench("create_map", "plain", create_plain_maps, it, LOW_TIMEOUT);
    bench("create_arr", "plain", create_plain_arrays, it, LOW_TIMEOUT);
    bench("create_map", "immutable.js", create_immutable_maps, it, LOW_TIMEOUT);
    bench("create_arr", "immutable.js", create_immutable_arrays, it, LOW_TIMEOUT);
  }
  bench("send_more_money", "nools", send_more_money_nools, 1);
}

run_benchmarks().then(() => {
  fs.writeFileSync(
    OUTPUT_PATH,
    '"key","sys","desc","runs","minimum","maximum","mean","median"\n' +
      csv_rows.map(to_row).join("\n")
  );
});
