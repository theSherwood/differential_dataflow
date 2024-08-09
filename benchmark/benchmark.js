import fs from "node:fs";
import {
  LOW_TIMEOUT,
  OUTPUT_PATH,
  RUN_NOOLS,
  bench_async,
  bench_sync,
  csv_rows,
  get_time,
  to_row,
  warmup,
} from "./src/js/common.js";
import {
  manners_nools,
  send_more_money_imperative,
  send_more_money_nools,
  waltz_db_nools,
} from "./src/js/nools.js";

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

async function run_benchmarks() {
  await warmup();
  bench_sync("sanity_check", "--", sanity_check, 0, 5000000);
  bench_sync("sanity_check", "--", sanity_check, 0, 50000);
  bench_sync("sanity_check", "--", sanity_check, 0, 500);

  /* rules benchmarks */
  {
    bench_sync("send_more_money", "imperative", send_more_money_imperative, 0, 1);
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
