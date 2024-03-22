import { WASI, File, OpenFile, ConsoleStdout } from "@bjorn3/browser_wasi_shim";

function is_node() {
  return typeof process === "object";
}

const IS_NODE = is_node();
const WASM_PATH = "out.wasm";
const VERBOSE = 0;

function get_imports() {
  let memory = new WebAssembly.Memory({
    initial: 10000,
    maximum: 10000,
  });
  const imports = {
    env: { memory },
  };
  return imports;
}

function on_instance_init(wasi, instance, imports) {
  /*
      Fix - We do this to add a memory export (even though we are importing
      memory). Wasi requires a memory export for fd_write. However, this may
      break all sorts of other stuff.
    */
  let new_exports;
  {
    let { exports } = instance;
    if (VERBOSE) console.log("exports", exports);
    let fake_instance = { exports: { ...exports, memory: imports.env.memory } };
    wasi.initialize(fake_instance);
    new_exports = fake_instance.exports;
  }

  /* run */
  {
    if (IS_NODE) {
      try {
        new_exports.NimMain();
      } catch (e) {
        console.error(e);
        process.exitCode = 1;
      }
    } else {
      new_exports.NimMain();
    }
  }
}

async function instantiate_wasm() {
  if (VERBOSE) console.log("import.meta", import.meta);

  /* setup wasi */
  let wasi;
  {
    let args = [];
    let env = [];
    let fds = [
      new OpenFile(new File([])), // stdin
      ConsoleStdout.lineBuffered((msg) => console.log(msg)),
      ConsoleStdout.lineBuffered((msg) => console.warn(msg)),
    ];
    wasi = new WASI(args, env, fds);
    if (VERBOSE) console.log("wasi", wasi.wasiImport);
  }

  /* setup imports */
  let imports;
  {
    let env_imports = get_imports();
    imports = {
      env: env_imports.env,
      wasi_snapshot_preview1: wasi.wasiImport,
    };
  }

  /* setup the wasm module instance */
  let wasm_module_instance;
  {
    if (IS_NODE) {
      let fs = await import("node:fs");
      let wasm = fs.readFileSync(WASM_PATH);
      let wrapper = await WebAssembly.instantiate(wasm, imports);
      wasm_module_instance = wrapper.instance;
    } else {
      let wasm = await WebAssembly.compileStreaming(fetch(WASM_PATH));
      wasm_module_instance = await WebAssembly.instantiate(wasm, imports);
    }
  }

  /* run the instance */
  on_instance_init(wasi, wasm_module_instance, imports);
}

instantiate_wasm();
