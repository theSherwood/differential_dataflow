import { WASI, File, OpenFile, ConsoleStdout } from "@bjorn3/browser_wasi_shim";

let args = [];
let env = [];
let fds = [
  new OpenFile(new File([])), // stdin
  ConsoleStdout.lineBuffered((msg) => console.log(msg)),
  ConsoleStdout.lineBuffered((msg) => console.warn(msg)),
];

function get_imports() {
  let memory = new WebAssembly.Memory({
    initial: 10000,
    maximum: 10000,
  });
  // let HEAPU8 = new Uint8Array(memory.buffer);
  const imports = {
    env: {
      foo: () => 173,
      memory,
    },
  };
  return imports;
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
  new_exports.NimMain()
  {
    /* TODO */
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
