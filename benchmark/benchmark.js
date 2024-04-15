import fs from "node:fs";

const OUTPUT_PATH = "./benchmark/results_js.csv";
const WARMUP = 100_000; // microseconds
const TIMEOUT = 500_000;

let csv_rows = [];

function get_time() {
  return performance.now() * 1000;
}

let form = (f) => f.toFixed(2);

function to_row(tr) {
  let l = tr.runs.length,
    s = `"${tr.key}",${l},`,
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
  median = (sorted_runs[Math.floor(l / 2)] + sorted_runs[Math.ceil(l / 2)]) / 2;
  s += `${form(minimum)},${form(maximum)},${form(mean)},${form(median)}`;
  return s;
}

async function warmup() {
  return setTimeout(() => {}, WARMUP / 1000);
}

async function bench(key, fn) {
  let tr = { key, runs: [] };
  csv_rows.push(tr);
  let start = get_time();
  let end = get_time();
  while (TIMEOUT > end - start) {
    fn(tr);
    end = get_time();
  }
}

function benchmark_test(tr) {
  let start = get_time();
  var s = 0.0;
  for (let f = 0; f < 5000000; f++) {
    s += f;
    if (tr.runs.length > 1000000) console.log(s);
    if (tr.runs.length > 10000000) console.log(s);
  }
  tr.runs.push(get_time() - start);
}

async function run_benchmarks() {
  await warmup();
  bench("test?", benchmark_test);
}

run_benchmarks().then(() => {
  fs.writeFileSync(OUTPUT_PATH, csv_rows.map(to_row).join("\n"));
});
