import fs from "node:fs";
import path from "node:path";
import csvParser from "csv-parser";

const COLUMNS = "key sys desc runs minimum maximum mean median".split(" ");
const COLUMNS_PLUS = "key sys desc runs run_m minimum min_m maximum, max_m mean mean_m median med_m".split(" ");

function flatten(row) {
  let arr = [];
  COLUMNS.forEach((c) => arr.push(row[c]));
  return arr;
}

// Function to recursively search for CSV files in a directory
function searchForCSVFiles(directoryPath, fileList) {
  const files = fs.readdirSync(directoryPath);

  files.forEach((file) => {
    const filePath = path.join(directoryPath, file);
    const stats = fs.statSync(filePath);

    if (stats.isDirectory()) {
      searchForCSVFiles(filePath, fileList); // Recursive call for subdirectories
    } else if (path.extname(file) === ".csv") {
      fileList.push(filePath);
    }
  });

  return fileList;
}

// Function to read contents of CSV files
async function readCSVFiles(fileList) {
  const csvData = [];
  await Promise.all(
    fileList.map((file) => {
      return new Promise((resolve, reject) =>
        fs
          .createReadStream(file)
          .pipe(csvParser())
          .on("data", (row) => {
            // Process each row as it is read
            csvData.push(flatten(row));
          })
          .on("end", () => {
            // This callback is called when all rows have been read from the CSV file
            console.log(`Finished reading ${file}`);
            resolve();
          })
          .on("error", (error) => {
            console.error(`Error reading ${file}: ${error.message}`);
            reject();
          })
      );
    })
  );
  return csvData;
}

function print_table(data) {
  let max_lengths = COLUMNS.map((c) => c.length);
  for (let row of data) {
    for (let i = 0; i < row.length; i++) {
      max_lengths[i] = Math.max(max_lengths[i], row[i].length);
    }
  }
  console.log(COLUMNS.map((d, i) => d.padStart(max_lengths[i], " ")).join(" "));
  let last_key = "";
  for (let row of data) {
    if (row[0] !== last_key) {
      console.log("");
      last_key = row[0];
    }
    console.log(row.map((d, i) => d.padStart(max_lengths[i], " ")).join(" "));
  }
}

async function main() {
  const parentDirectory = process.cwd();
  const fileList = searchForCSVFiles(parentDirectory, []);

  if (fileList.length === 0) {
    console.log("No CSV files found in the directory.");
    return;
  }

  const csvData = await readCSVFiles(fileList);
  let sorted = csvData.toSorted((a, b) => {
    if (a[0] < b[0]) return -1;
    if (b[0] < a[0]) return 1;
    if (a[1] < b[1]) return -1;
    if (b[1] < a[1]) return 1;
    if (a[2] < b[2]) return -1;
    if (b[2] < a[2]) return 1;
    return 0;
  });

  // console.table(sorted);
  print_table(sorted);
}

main();
