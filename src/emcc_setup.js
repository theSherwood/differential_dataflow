import { WASI, File, OpenFile, ConsoleStdout } from "@bjorn3/browser_wasi_shim";

let args = [];
let env = [];
let fds = [
  new OpenFile(new File([])), // stdin
  ConsoleStdout.lineBuffered((msg) => console.log(msg)),
  ConsoleStdout.lineBuffered((msg) => console.warn(msg)),
];

const MUTATE_STATE_BOXES_TEST_COUNT = 10_000;
const NUMBER_CRUNCHING_TEST_COUNT = 10_000_000;
const NUMBER_CRUNCHING_TEST_2_COUNT = 100_000;
const RANDOM_INT_MAX = 100;

function random_int(max) {
  return Math.floor(Math.random() * max);
}

function get_imports() {
  let memory = new WebAssembly.Memory({
    initial: 10000,
    maximum: 10000,
  });
  // let HEAPU8 = new Uint8Array(memory.buffer);
  const imports = {
    env: {
      bar: () => 173,
      get_time: () => Date.now(),
      get_mutate_state_boxes_test_count: () => MUTATE_STATE_BOXES_TEST_COUNT,
      get_number_crunching_test_count: () => NUMBER_CRUNCHING_TEST_COUNT,
      get_number_crunching_test_2_count: () => NUMBER_CRUNCHING_TEST_2_COUNT,
      random_int: () => random_int(RANDOM_INT_MAX),
      memory,
    },
  };
  return imports;
}

function run_mutate_state_boxes_test(exports) {
  const count = MUTATE_STATE_BOXES_TEST_COUNT;
  console.group("Mutate State Boxes");
  /* wasm */
  {
    exports.mutate_state_boxes_test();
  }
  /* wasm<->js */
  {
    let { mutate_state_boxes } = exports;
    // print_state();
    let start = Date.now();
    for (let i = 0; i < count; i++) {
      mutate_state_boxes();
    }
    let end = Date.now();
    console.log("wasm<->js time:", end - start);
    console.log("wasm<->js ok");
    if (0) {
      console.group("wasm<->js");
      // print_state();
      console.groupEnd();
    }
  }
  /* js */
  {
    let s = {
      str: { data: "this_is_broken" },
      aos: { data: ["so_cool", "yay_math", "and_so_on"] },
      aof: { data: [1.4, 8324.83924, -0.3423] },
      aoi: { data: [5, -90, 139] },
    };
    let reset_state = (s) => {
      s.str.data = "this_is_broken";
      s.aos.data = ["so_cool", "yay_math", "and_so_on"];
      s.aof.data = [1.4, 8324.83924, -0.3423];
      s.aoi.data = [5, -90, 139];
    };
    let mutate_state_boxes = () => {
      reset_state(s);
      s.str.data = s.str.data + "_badly";
      s.aos.data.push(s.str.data);
      s.aof.data.push(s.str.data.length);
      s.aoi.data.push(s.aos.data.length);
    };
    let start = Date.now();
    for (let i = 0; i < count; i++) {
      mutate_state_boxes();
    }
    let end = Date.now();
    console.log("js time:", end - start);
    console.log("js ok");
    /* print state */
    if (0) {
      console.group("js");
      console.log(s.str.data);
      console.log(s.aos.data);
      console.log(s.aof.data);
      console.log(s.aoi.data);
      console.groupEnd();
    }
  }
  console.groupEnd();
}

function run_number_crunching_test(exports) {
  let count = NUMBER_CRUNCHING_TEST_COUNT;
  console.group("Number Crunching");
  /* wasm */
  {
    exports.number_crunching_test();
  }
  /* wasm<->js */
  {
    /* none */
  }
  /* js */
  {
    let start = performance.now();
    let sum = 0;
    for (let i = 0; i < count; i++) {
      sum += i + 1;
      sum -= i;
    }
    let end = performance.now();
    console.log("js time:", end - start);
    console.log("sum:", sum);
    console.log("js ok");
  }
  console.groupEnd();
}

function run_number_crunching_test_2(exports) {
  let count = NUMBER_CRUNCHING_TEST_2_COUNT;
  console.group("Number Crunching 2");
  /* wasm */
  {
    exports.number_crunching_test_2();
  }
  /* wasm<->js */
  {
    /* none */
  }
  /* js */
  {
    /* populate array */
    let nums = Array.of(count);
    for (let i = 0; i < count; i++) {
      nums[i] = random_int(RANDOM_INT_MAX);
    }
    let start = performance.now();
    let sum = 0;
    for (let i = 0; i < count; i++) {
      if ((i & 1) === 0) {
        sum += nums[i];
      } else {
        sum -= nums[i];
      }
    }
    let end = performance.now();
    console.log("js time:", end - start);
    console.log("sum:", sum);
    console.log("js ok");
  }
  console.groupEnd();
}

function on_instance_init(wasi, instance, imports) {
  let { exports } = instance;
  console.log("exports", exports);
  /*
      Fix - We do this to add a memory export (even though we are importing
      memory). Wasi requires a memory export for fd_write. However, this may
      break all sorts of other stuff.
    */
  let fake_instance = { exports: { ...exports, memory: imports.env.memory } };
  wasi.initialize(fake_instance);
  let new_exports = fake_instance.exports;
  /* cannot forget this step */
  exports.setup_state();
  {
    run_mutate_state_boxes_test(new_exports);
    run_number_crunching_test(new_exports);
    run_number_crunching_test_2(new_exports);
  }
}

async function instantiate_wasm() {
  let env_imports = get_imports();
  let wasi = new WASI(args, env, fds);
  console.log("wasi", wasi.wasiImport);
  let imports = {
    env: env_imports.env,
    wasi_snapshot_preview1: wasi.wasiImport,
  };
  let wasm = await WebAssembly.compileStreaming(fetch("out.wasm"));
  let inst = await WebAssembly.instantiate(wasm, imports);
  let { exports } = inst;
  console.log("inst", inst, exports, wasi);
  on_instance_init(wasi, inst, imports);
}

instantiate_wasm();
