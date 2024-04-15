import fs from "node:fs";

const OUTPUT_PATH = "./benchmark/results_js.csv";

let csv_rows = [];

function run_benchmark() {
  csv_rows.push('"foo","bar","baz"');
  csv_rows.push('"0","1","2"');
}

run_benchmark();
fs.writeFileSync(OUTPUT_PATH, csv_rows.join("\n"));
