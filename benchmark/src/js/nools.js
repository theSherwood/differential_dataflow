import fs from "node:fs";
import path from "node:path";
import nools from "nools";
import { load_manners_data } from "../../data/manners.js";
import { load_waltz_db_data } from "../../data/waltz_db.js";

/**
 *
 * @link
 * https://github.com/noolsjs/nools/blob/master/examples/browser/sendMoreMoney.html
 */
export function send_more_money_nools(tr, sz, n) {
  let nools_code = fs
    .readFileSync(path.resolve(__dirname, "../nools/send_more_money.nools"))
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
export async function manners_nools(tr, sz, _n) {
  let name = "manners_" + sz;
  let nools_code = fs.readFileSync(path.resolve(__dirname, "../nools/manners.nools")).toString();
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
export async function waltz_db_nools(tr, sz, _n) {
  let name = "waltz_db_" + sz;
  let nools_code = fs.readFileSync(path.resolve(__dirname, "../nools/waltz_db.nools")).toString();
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
