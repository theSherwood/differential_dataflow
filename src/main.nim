# import std/[times]

when defined(isNimSkull):
  {.pragma: ex, exportc, dynlib.}
else:
  import std/[macros]
  macro ex*(t: typed): untyped =
    if t.kind notin {nnkProcDef, nnkFuncDef}:
      error("Can only export procedures", t)
    let
      newProc = copyNimTree(t)
      codeGen = nnkExprColonExpr.newTree(ident"codegendecl",
          newLit"EMSCRIPTEN_KEEPALIVE $# $#$#")
    if newProc[4].kind == nnkEmpty:
      newProc[4] = nnkPragma.newTree(codeGen)
    else:
      newProc[4].add codeGen
    newProc[4].add ident"exportC"
    result = newStmtList()
    result.add:
      quote do:
        {.emit: "/*INCLUDESECTION*/\n#include <emscripten.h>".}
    result.add:
      newProc
  # {.pragma: ex, exportc, dynlib.}

type
  State = ref object
    str: StringBoxRef
    aos: ArrOfStringsRef
    aof: ArrOfFloatsRef
    aoi: ArrOfIntsRef
  StringBox = object
    data: string
  StringBoxRef = ref StringBox
  ArrOfStrings = object
    data: seq[string]
  ArrOfStringsRef = ref ArrOfStrings
  ArrOfFloats = object
    data: seq[float64]
  ArrOfFloatsRef = ref ArrOfFloats
  ArrOfInts = object
    data: seq[int32]
  ArrOfIntsRef = ref ArrOfInts

when defined(wasm):
  proc bar(): int {.importc.}
  proc get_time(): int {.importc.}
  proc get_mutate_state_boxes_test_count(): int {.importc.}
  proc get_number_crunching_test_count(): int {.importc.}
  proc get_number_crunching_test_2_count(): int {.importc.}
  proc random_int(): int {.importc.}
else:
  import std/[times]
  proc bar(): int =
    return 173
  proc get_time(): int =
    return (cpuTime() * 1000).int
  proc get_mutate_state_boxes_test_count(): int =
    return 10000
  proc get_number_crunching_test_count(): int =
    return 10000000
  proc get_number_crunching_test_2_count(): int =
    return 10000
  proc random_int(): int =
    # TODO
    return 17


proc p_break(): void {.ex.} =
  echo "------------------------------------"

var s: State

proc print_state(): void {.ex.} =
  echo s.str.data, " ", s.str.data.len, " ", cast[uint](s.str.data.addr)
  echo s.aos.data
  echo s.aof.data
  echo s.aoi.data

proc reset_state(s: State): void =
  s.str.data = "this_is_broken"
  s.aos.data = @["so_cool", "yay_math", "and_so_on"]
  s.aof.data = @[1.4, 8324.83924, -0.3423]
  s.aoi.data = @[5i32, -90, 139]

proc mutate_state_boxes*(): void {.ex.} =
  reset_state(s)
  s.str.data = s.str.data & "_badly"
  s.aos.data.add(s.str.data)
  s.aof.data.add(s.str.data.len.float64)
  s.aoi.data.add(s.aos.data.len.int32)
  # s.aoi.data.add(bar().int32)

proc mutate_state_boxes_test*(): void {.ex.} =
  let count = get_mutate_state_boxes_test_count()
  let start = get_time()
  for i in 0..<count:
    mutate_state_boxes()
  echo "wasm time: ", get_time() - start
  echo "wasm ok"

proc number_crunching_test*(): void {.ex.} =
  let count = get_number_crunching_test_count()
  let start = get_time()
  var sum = 0
  for i in 0..<count:
    sum += i + 1
    sum -= i
  echo "wasm time: ", get_time() - start
  echo "sum: ", sum
  echo "wasm ok"

proc number_crunching_test_2*(): void {.ex.} =
  let count = get_number_crunching_test_2_count()
  # let count = 10
  var nums: seq[int] = @[]
  # populate seq
  for i in 0..<count:
    nums.add(random_int())
  let start = get_time()
  var sum = 0
  for i in 0..<count:
    if (i and 1) == 0:
      sum += nums[i]
    else:
      sum -= nums[i]
  echo "wasm time: ", get_time() - start
  echo "sum: ", sum
  echo "wasm ok"


proc get_string*(): ptr string {.ex.} =
  return addr s.str.data

proc get_array_of_strings*(): ptr seq[string] {.ex.} =
  return addr s.aos.data

proc get_array_of_floats*(): ptr seq[float64] {.ex.} =
  return addr s.aof.data

proc get_array_of_ints*(): ptr seq[int32] {.ex.} =
  return addr s.aoi.data

proc p_p[T](thing: T): void =
  echo(cast[uint](addr(thing)))

proc setup_state*(): void {.ex.} =
  s = State(str: StringBoxRef(), aos: ArrOfStringsRef(),
      aof: ArrOfFloatsRef(), aoi: ArrOfIntsRef())
  reset_state(s)

  p_break()
  let s1 = get_time()
  echo "time test: ", get_time() - s1
  p_break()

  if false:
    echo "str: ", s.str.data
    p_p(s)
    p_p(s.str)
    p_p(s.aos)
    p_p(s.aof)
    p_p(s.aoi)
    p_p(s.str.data)
    p_p(s.aos.data)
    p_p(s.aof.data)
    p_p(s.aoi.data)
    # echo "foo: ", foo
    echo bar()
    discard
