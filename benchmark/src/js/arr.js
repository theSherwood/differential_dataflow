import { List as ImArr } from "immutable";
import { get_time } from "./common.js";

function setup_arr_of_arrs(sz, n, offset = 0) {
  let arrs = [];
  let i_off, k;
  for (let i = 0; i < n; i++) {
    i_off = i + offset;
    let arr = [i_off];
    for (let j = 1; j < sz; j++) {
      k = i_off + j * 17;
      arr.push[k];
    }
    arrs.push(arr);
  }
  return arrs;
}

export function setup_arr_of_immutable_arrs(sz, n, offset = 0) {
  let arrs = [];
  let i_off, k;
  for (let i = 0; i < n; i++) {
    i_off = i + offset;
    let arr = ImArr([i_off]);
    for (let j = 1; j < sz; j++) {
      k = i_off + j * 17;
      arr = arr.push(k);
    }
    arrs.push(arr);
  }
  return arrs;
}

export function plain_arr_create(tr, sz, n) {
  let start = get_time();
  let arrs = [];
  for (let i = 0; i < n; i++) {
    arrs.push([i]);
  }
  tr.runs.push(get_time() - start);
}

export function immutable_arr_create(tr, sz, n) {
  let start = get_time();
  let arrs = [];
  for (let i = 0; i < n; i++) {
    arrs.push(ImArr([i]));
  }
  tr.runs.push(get_time() - start);
}

export function plain_arr_push_by_mutation(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i].push(i);
  }
  tr.runs.push(get_time() - start);
}

export function plain_arr_push_by_spread(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i] = [...arrs[i], i];
  }
  tr.runs.push(get_time() - start);
}

export function immutable_arr_push(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_immutable_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i] = arrs[i].push(i);
  }
  tr.runs.push(get_time() - start);
}

export function plain_arr_pop_by_mutation(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i].pop();
  }
  tr.runs.push(get_time() - start);
}

export function plain_arr_pop_by_spread(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i] = [...arrs[i]];
    arrs[i].pop();
  }
  tr.runs.push(get_time() - start);
}

export function immutable_arr_pop(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_immutable_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i] = arrs[i].pop();
  }
  tr.runs.push(get_time() - start);
}

export function plain_arr_slice(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i] = arrs[i].slice(i, arrs[i].length / 2)
  }
  tr.runs.push(get_time() - start);
}

export function immutable_arr_slice(tr, sz, n) {
  /* setup */
  let arrs = setup_arr_of_immutable_arrs(sz, n);
  /* test */
  let start = get_time();
  for (let i = 0; i < n; i++) {
    arrs[i] = arrs[i].slice(i, arrs[i].length / 2)
  }
  tr.runs.push(get_time() - start);
}

