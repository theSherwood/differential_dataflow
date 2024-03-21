import std/[tables, sets, bitops, strutils, strbasics]
import hashes

when defined(isNimSkull) or true:
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

# Types #
# ---------------------------------------------------------------------

type
  ImHash = uint32

  ImValueKind* = enum
    # Immediate Kinds
    kNaN
    kNil
    kNumber           # like js, we just have a float64 number type
    # Heap Kinds
    kMap

  ImValue* = distinct uint64

  ImMapPayload* = object
    hash: ImHash
    data*: Table[ImValue, ImValue]
  ImMapPayloadRef*    = ref ImMapPayload

  ImNumber* = distinct float64
  ImNaN*    = distinct uint64
  ImNil*    = distinct uint64

  ImMap* = object
    tail*: ImMapPayloadRef
    head*: uint32

type
  ImSV* = ImNumber or ImNaN or ImNil
  ImV* = ImSV or ImMap

# Casts #
# ---------------------------------------------------------------------

template as_f64*(v: typed): float64 = cast[float64](v)
template as_u64*(v: typed): uint64 = cast[uint64](v)
template as_i64*(v: typed): int64 = cast[int64](v)
template as_u32*(v: typed): uint32 = cast[uint32](v)
template as_i32*(v: typed): int32 = cast[int32](v)
template as_v*(v: typed): ImValue = cast[ImValue](cast[uint64](v))
template v*(v: typed): ImValue = cast[ImValue](cast[uint64](v))
template as_map*(v: typed): ImMap = cast[ImMap](cast[uint64](v))

# Masks #
# ---------------------------------------------------------------------

const MASK_SIGN        = 0b10000000000000000000000000000000'u32
const MASK_EXPONENT    = 0b01111111111100000000000000000000'u32
const MASK_QUIET       = 0b00000000000010000000000000000000'u32
const MASK_EXP_OR_Q    = 0b01111111111110000000000000000000'u32
const MASK_SIGNATURE   = 0b11111111111111111000000000000000'u32
const MASK_SHORT_HASH  = 0b00000000000000000111111111111111'u32
const MASK_HEAP        = 0b11111111111110000000000000000000'u32

const MASK_TYPE_NIL    = 0b00000000000000010000000000000000'u32
const MASK_TYPE_MAP    = 0b10000000000001010000000000000000'u32

const MASK_SIG_NIL     = MASK_EXP_OR_Q or MASK_TYPE_NIL
const MASK_SIG_MAP     = MASK_EXP_OR_Q or MASK_TYPE_MAP

# Get Payload #
# ---------------------------------------------------------------------

template head(v: typed): uint32 = (v.as_u64 shr 32).as_u32
template tail(v: typed): uint32 = v.as_u32

template payload*(v: ImMap): ref ImMapPayload       = v.tail

# Type Detection #
# ---------------------------------------------------------------------

template type_bits(v: typed): uint32 =
  v.head

template is_map(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_MAP
template is_heap(v: typed): bool =
  bitand(bitor(v.type_bits, MASK_EXP_OR_Q), MASK_HEAP) == MASK_HEAP

proc get_type*(v: ImValue): ImValueKind =
  let type_carrier = v.type_bits
  if bitand(bitnot(type_carrier), MASK_EXPONENT) != 0: return kNumber
  let signature = bitand(type_carrier, MASK_SIGNATURE)
  case signature:
    of MASK_SIG_NIL:    return kNil
    of MASK_SIG_MAP:    return kMap
    else:
      echo "Unknown Type!"

# Globals #
# ---------------------------------------------------------------------

proc u64_from_mask(mask: uint32): uint64 =
  return (mask.as_u64 shl 32).as_u64
let Nil* = cast[ImNil](u64_from_mask(MASK_SIG_NIL))

# Equality Testing #
# ---------------------------------------------------------------------

func `==`*(v1, v2: ImValue): bool =
  if bitand(v1.head, MASK_SIGNATURE) == MASK_SIG_MAP:
    if v1.as_map.payload.hash == v2.as_map.payload.hash:
      return v1.as_map.payload.data == v2.as_map.payload.data
    else:
      return false
  else: return v1.as_u64 == v2.as_u64

# Debug String Conversion #
# ---------------------------------------------------------------------

proc `$`*(k: ImValueKind): string =
  case k:
    of kNumber: return "Number"
    of kNil:    return "Nil"
    of kMap:    return "Map"
    else:       return "<unknown>"

proc `$`*(v: ImValue): string =
  let kind = get_type(v)
  case kind:
    of kNumber:           return $(v.as_f64)
    of kNil:              return "Nil"
    of kMap:              return $(v.as_map.payload.data)
    else:                 discard

# Hash Handling #
# ---------------------------------------------------------------------

# XOR is commutative, associative, and is its own inverse.
# So we can use this same function to unhash as well.
template calc_hash(i1, i2: typed): ImHash = cast[ImHash](bitxor(i1.as_u32, i2.as_u32))

func hash*(v: ImValue): ImHash =
  if is_heap(v):
    # We cast to ImString so that we can get the hash, but all the ImHeapValues have a hash in the tail.
    let vh = cast[ImMap](v)
    result = cast[ImHash](vh.payload.hash)
  else:
    # We fold it and hash it for 32-bit stack values because a lot of them
    # don't have anything interesting happening in the top 32 bits.
    result = cast[ImHash](calc_hash(v.head, v.tail))

# ImMap Impl #
# ---------------------------------------------------------------------

template buildImMap(new_hash, new_data: typed) {.dirty.} =
  let h = new_hash.uint32
  var new_map = ImMap(
    head: MASK_SIG_MAP,
    tail: ImMapPayloadRef(hash: h, data: new_data)
  )

func init_map_empty(): ImMap =
  let hash = 0
  let data = initTable[ImValue, ImValue]()
  buildImMap(hash, data)
  return new_map
let empty_map = init_map_empty()

template hash_entry(k, v: typed): ImHash = cast[ImHash](hash(k).as_u64 + hash(v).as_u64)

proc init_map*(): ImMap = return empty_map
proc init_map*(init_data: openArray[(ImValue, ImValue)]): ImMap =
  if init_data.len == 0: return empty_map
  var new_data = toTable(init_data)
  var new_hash = cast[ImHash](0)
  var deletions = newSeq[ImValue]()
  for (k, v) in new_data.pairs:
    if v.v == Nil.v: deletions.add(k.v)
    else:            new_hash = calc_hash(new_hash, hash_entry(k, v))
  for k in deletions:
    new_data.del(k)
  buildImMap(new_hash, new_data)
  return new_map
  
# There's probably no point in having this. It suggests reference semantics.
proc clear*(m: ImMap): ImMap =
  return empty_map

proc contains*(m: ImMap, k: ImValue): bool = k.as_v in m.payload.data

template get_impl(m: ImMap, k: typed): ImValue =
  m.payload.data.getOrDefault(k.as_v, Nil.as_v).as_v
proc `[]`*(m: ImMap, k: ImValue): ImValue = return get_impl(m, k)
proc get*(m: ImMap, k: ImValue): ImValue  = return get_impl(m, k)

proc del*(m: ImMap, k: ImValue): ImMap =
  if not(k in m.payload.data): return m
  let v = m.payload.data[k]
  var table_copy = m.payload.data
  table_copy.del(k)
  let entry_hash = hash_entry(k, v)
  let new_hash = calc_hash(m.payload.hash, entry_hash)
  buildImMap(new_hash, table_copy)
  return new_map

proc set*(m: ImMap, k: ImValue, v: ImValue): ImMap =
  if v == Nil.as_v: return m.del(k)
  if m.payload.data.getOrDefault(k, Nil.as_v) == v: return m
  var table_copy = m.payload.data
  table_copy[k] = v
  let entry_hash = hash_entry(k, v)
  let new_hash = calc_hash(m.payload.hash, entry_hash)
  buildImMap(new_hash, table_copy)
  return new_map

func size*(m: ImMap): int =
  return m.payload.data.len.int

# ImValue Fns #
# ---------------------------------------------------------------------

## If a key in the path does not exist, maps are created
proc set_in*(it: ImValue, path: openArray[ImValue], v: ImValue): ImValue {.ex.} =
  var payload: ImValue = v
  var stack = newSeq[ImValue]()
  var k: ImValue
  var curr = it
  var max = 0
  for i in 0..path.high:
    k = path[i]
    echo "i: ", i
    if curr.is_map:
      stack.add(curr)
      curr = curr.as_map.get(k)
    else:
      echo "TODO - add exceptions"
    max = i
  for i in countdown(max, 0):
    k = path[i]
    curr = stack[i]
    if curr.is_map:
      payload = curr.as_map.set(k, payload).v
    else:               echo "TODO - add exceptions2"
  echo "pay.len: ", payload.as_map.payload.data.len
  echo "pay: ", payload
  echo "payload.tail: ", payload.v.tail.as_u32
  echo "pay.len: ", payload.as_map.payload.data.len
  echo "pay: ", payload
  echo "payload.tail: ", payload.v.tail.as_u32
  return payload
