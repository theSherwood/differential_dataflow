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

const cpu_32 = defined(cpu32)

# Types #
# ---------------------------------------------------------------------

when cpu_32:
  type
    ImHash = uint32
else:
  type
    ImHash = Hash

type
  ImValueKind* = enum
    # Immediate Kinds
    kNaN
    kNil
    kBool
    kNumber           # like js, we just have a float64 number type
    kAtom
    # Heap Kinds
    kString
    kBigNum
    kArray
    kMap
    kSet

  ImValue* = distinct uint64

  ImStringPayload* = object
    hash: ImHash
    data*: string
  ImArrayPayload* = object
    hash: ImHash
    data*: seq[ImValue]
  ImMapPayload* = object
    hash: ImHash
    data*: Table[ImValue, ImValue]
  ImSetPayload* = object
    hash: ImHash
    data*: HashSet[ImValue]
  ImStringPayloadRef* = ref ImStringPayload
  ImArrayPayloadRef*  = ref ImArrayPayload
  ImMapPayloadRef*    = ref ImMapPayload
  ImSetPayloadRef*    = ref ImSetPayload

  ImNumber* = distinct float64
  ImNaN*    = distinct uint64
  ImNil*    = distinct uint64
  ImBool*   = distinct uint64
  ImAtom*   = distinct uint64

when cpu_32:
  type
    ImString* = object
      tail*: ImStringPayloadRef
      head*: uint32
    ImArray* = object
      tail*: ImArrayPayloadRef
      head*: uint32
    ImMap* = object
      tail*: ImMapPayloadRef
      head*: uint32
    ImSet* = object
      tail*: ImSetPayloadRef
      head*: uint32
  
else:
  type
    MaskedRef*[T] = object
      # distinct should work in theory, but I'm not entirely sure how well phantom types work with distinct at the moment
      p: pointer
    ImString* = MaskedRef[ImStringPayload]
    ImArray*  = MaskedRef[ImArrayPayload]
    ImMap*    = MaskedRef[ImMapPayload]
    ImSet*    = MaskedRef[ImSetPayload]

type
  ImSV* = ImNumber or ImNaN or ImNil or ImBool or ImAtom
  ImHV* = ImString or ImArray or ImMap or ImSet
  ImV* = ImSV or ImHV

# Casts #
# ---------------------------------------------------------------------

template as_f64*(v: typed): float64 = cast[float64](v)
template as_u64*(v: typed): uint64 = cast[uint64](v)
template as_i64*(v: typed): int64 = cast[int64](v)
template as_u32*(v: typed): uint32 = cast[uint32](v)
template as_i32*(v: typed): int32 = cast[int32](v)
template as_p*(v: typed): pointer = cast[pointer](v)
template as_byte_array_8*(v: typed): array[8, byte] = cast[array[8, byte]](v)
template as_v*(v: typed): ImValue = cast[ImValue](cast[uint64](v))
template v*(v: typed): ImValue = cast[ImValue](cast[uint64](v))
template as_str*(v: typed): ImString = cast[ImString](cast[uint64](v))
template as_arr*(v: typed): ImArray = cast[ImArray](cast[uint64](v))
template as_map*(v: typed): ImMap = cast[ImMap](cast[uint64](v))
template as_set*(v: typed): ImSet = cast[ImSet](cast[uint64](v))

# Masks #
# ---------------------------------------------------------------------

when cpu_32:
  const MASK_SIGN        = 0b10000000000000000000000000000000'u32
  const MASK_EXPONENT    = 0b01111111111100000000000000000000'u32
  const MASK_QUIET       = 0b00000000000010000000000000000000'u32
  const MASK_EXP_OR_Q    = 0b01111111111110000000000000000000'u32
  const MASK_SIGNATURE   = 0b11111111111111111000000000000000'u32
  const MASK_SHORT_HASH  = 0b00000000000000000111111111111111'u32
  const MASK_HEAP        = 0b11111111111110000000000000000000'u32

  const MASK_TYPE_NAN    = 0b00000000000000000000000000000000'u32
  const MASK_TYPE_NIL    = 0b00000000000000010000000000000000'u32
  const MASK_TYPE_FALSE  = 0b00000000000000011000000000000000'u32
  const MASK_TYPE_TRUE   = 0b00000000000000011100000000000000'u32
  const MASK_TYPE_BOOL   = 0b00000000000000011000000000000000'u32
  const MASK_TYPE_ATOM   = 0b00000000000000100000000000000000'u32

  const MASK_TYPE_STRING = 0b10000000000000010000000000000000'u32
  const MASK_TYPE_BIGNUM = 0b10000000000000100000000000000000'u32
  const MASK_TYPE_ARRAY  = 0b10000000000000110000000000000000'u32
  const MASK_TYPE_SET    = 0b10000000000001000000000000000000'u32
  const MASK_TYPE_MAP    = 0b10000000000001010000000000000000'u32

else:
  const MASK_SIGN        = 0b10000000000000000000000000000000'u64 shl 32
  const MASK_EXPONENT    = 0b01111111111100000000000000000000'u64 shl 32
  const MASK_QUIET       = 0b00000000000010000000000000000000'u64 shl 32
  const MASK_EXP_OR_Q    = 0b01111111111110000000000000000000'u64 shl 32
  const MASK_SIGNATURE   = 0b11111111111111110000000000000000'u64 shl 32
  const MASK_HEAP        = 0b11111111111110000000000000000000'u64 shl 32

  const MASK_TYPE_NAN    = 0b00000000000000000000000000000000'u64 shl 32
  const MASK_TYPE_NIL    = 0b00000000000000010000000000000000'u64 shl 32
  const MASK_TYPE_FALSE  = 0b00000000000000011000000000000000'u64 shl 32
  const MASK_TYPE_TRUE   = 0b00000000000000011100000000000000'u64 shl 32
  const MASK_TYPE_BOOL   = 0b00000000000000011000000000000000'u64 shl 32
  const MASK_TYPE_ATOM   = 0b00000000000000100000000000000000'u64 shl 32

  const MASK_TYPE_STRING = 0b10000000000000010000000000000000'u64 shl 32
  const MASK_TYPE_BIGNUM = 0b10000000000000100000000000000000'u64 shl 32
  const MASK_TYPE_ARRAY  = 0b10000000000000110000000000000000'u64 shl 32
  const MASK_TYPE_SET    = 0b10000000000001000000000000000000'u64 shl 32
  const MASK_TYPE_MAP    = 0b10000000000001010000000000000000'u64 shl 32

  const MASK_POINTER     = 0x0000ffffffffffff'u64

const MASK_SIG_NAN     = MASK_EXP_OR_Q
const MASK_SIG_NIL     = MASK_EXP_OR_Q or MASK_TYPE_NIL
const MASK_SIG_FALSE   = MASK_EXP_OR_Q or MASK_TYPE_FALSE
const MASK_SIG_TRUE    = MASK_EXP_OR_Q or MASK_TYPE_TRUE
const MASK_SIG_BOOL    = MASK_EXP_OR_Q or MASK_TYPE_BOOL
const MASK_SIG_ATOM    = MASK_EXP_OR_Q or MASK_TYPE_ATOM
const MASK_SIG_STRING  = MASK_EXP_OR_Q or MASK_TYPE_STRING
const MASK_SIG_BIGNUM  = MASK_EXP_OR_Q or MASK_TYPE_BIGNUM
const MASK_SIG_ARRAY   = MASK_EXP_OR_Q or MASK_TYPE_ARRAY
const MASK_SIG_SET     = MASK_EXP_OR_Q or MASK_TYPE_SET
const MASK_SIG_MAP     = MASK_EXP_OR_Q or MASK_TYPE_MAP

# GC #
# ---------------------------------------------------------------------

when not cpu_32:
  template to_clean_ptr(v: typed): pointer =
    cast[pointer](bitand((v).as_u64, MASK_POINTER))

  proc `=destroy`[T](x: var MaskedRef[T]) =
    GC_unref(cast[ref T](to_clean_ptr(x.p)))
  proc `=copy`[T](x: var MaskedRef[T], y: MaskedRef[T]) =
    GC_ref(cast[ref T](to_clean_ptr(y.p)))
    x.p = y.p

# Get Payload #
# ---------------------------------------------------------------------

template head(v: typed): uint32 = (v.as_u64 shr 32).as_u32
template tail(v: typed): uint32 = v.as_u32

template payload*(v: ImMap): ref ImMapPayload       = v.tail
template payload*(v: ImArray): ref ImArrayPayload   = v.tail

# Type Detection #
# ---------------------------------------------------------------------

when cpu_32:
  template type_bits(v: typed): uint32 =
    v.head
else:
  template type_bits(v: typed): uint64 =
    v.as_u64

template is_float(v: typed): bool =
  bitand(bitnot(v.type_bits), MASK_EXPONENT) != 0
template is_nil(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_NIL
template is_bool(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_BOOL
template is_atom(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_ATOM
template is_string(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_STRING
template is_bignum(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_BIGNUM
template is_array(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_ARRAY
template is_set(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_SET
template is_map(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_MAP
template is_heap(v: typed): bool =
  bitand(bitor(v.type_bits, MASK_EXP_OR_Q), MASK_HEAP) == MASK_HEAP

proc get_type*(v: ImValue): ImValueKind =
  let type_carrier = v.type_bits
  # echo toHex(type_carrier), " ", toHex(MASK_EXPONENT)
  if bitand(bitnot(type_carrier), MASK_EXPONENT) != 0: return kNumber
  let signature = bitand(type_carrier, MASK_SIGNATURE)
  case signature:
    of MASK_SIG_NIL:    return kNil
    of MASK_SIG_BOOL:   return kBool
    of MASK_SIG_ATOM:   return kAtom
    of MASK_SIG_STRING: return kString
    of MASK_SIG_BIGNUM: return kBigNum
    of MASK_SIG_ARRAY:  return kArray
    of MASK_SIG_SET:    return kSet
    of MASK_SIG_MAP:    return kMap
    else:
      echo "Unknown Type!"

# Globals #
# ---------------------------------------------------------------------

proc u64_from_mask(mask: uint32): uint64 =
  return (mask.as_u64 shl 32).as_u64
let Nil* = cast[ImNil](u64_from_mask(MASK_SIG_NIL))
let True* = cast[ImBool](u64_from_mask(MASK_SIG_TRUE))
let False* = cast[ImBool](u64_from_mask(MASK_SIG_FALSE))

# Equality Testing #
# ---------------------------------------------------------------------

template initial_eq_heap_value(v1, v2: typed): bool =
  v1.head == v2.head
template eq_heap_payload(t1, t2: typed) =
  result = false
  if t1.hash == t2.hash:
    result = t1.data == t2.data
template eq_heap_value_specific(v1, v2: typed) =
  result = false
  if initial_eq_heap_value(v1, v2):
    eq_heap_payload(v1.payload, v2.payload)
template eq_heap_value_generic*(v1, v2: typed) =
  if initial_eq_heap_value(v1, v2):
    when cpu_32:
      let signature = bitand(v1.head, MASK_SIGNATURE)
    else:
      let signature = bitand(v1.as_u64, MASK_SIGNATURE)
    case signature:
      of MASK_SIG_ARRAY:  eq_heap_payload(v1.as_arr.payload, v2.as_arr.payload)
      of MASK_SIG_MAP:    eq_heap_payload(v1.as_map.payload, v2.as_map.payload)
      else:               discard

template complete_eq(v1, v2: typed): bool =
  if bitand(MASK_HEAP, v1.type_bits) == MASK_HEAP: eq_heap_value_generic(v1, v2) else: v1.as_u64 == v2.as_u64
func `==`*(v1, v2: ImValue): bool =
  if bitand(MASK_HEAP, v1.type_bits) == MASK_HEAP: eq_heap_value_generic(v1, v2)
  else: return v1.as_u64 == v2.as_u64
func `==`*(v: ImValue, f: float64): bool = return v == f.as_v
func `==`*(f: float64, v: ImValue): bool = return v == f.as_v
    
func `==`*(v1, v2: ImMap): bool = eq_heap_value_specific(v1, v2)
func `==`*(v1, v2: ImArray): bool = eq_heap_value_specific(v1, v2)

func `==`*(v1, v2: ImHV): bool = eq_heap_value_generic(v1, v2)

func `==`*(v1: ImSV, v2: float64): bool = return v1.as_f64 == v2
func `==`*(v1: float64, v2: ImSV): bool = return v1 == v2.as_f64
func `==`*(v1, v2: ImSV): bool = return v1.as_u64 == v2.as_u64
  
func `==`*(v1, v2: ImV): bool =
  if bitand(MASK_HEAP, v1.type_bits) == MASK_HEAP: eq_heap_value_generic(v1, v2)
  else: return v1.as_u64 == v2.as_u64
func `==`*(v: ImV, f: float64): bool = return v == f.as_v
func `==`*(f: float64, v: ImV): bool = return v == f.as_v

func `==`*(n1: ImNumber, n2: float64): bool = return n1.as_f64 == n2
func `==`*(n1: float64, n2: ImNumber): bool = return n1 == n2.as_f64

# Debug String Conversion #
# ---------------------------------------------------------------------

proc to_hex*(f: float64): string = return toHex(f.as_u64)
proc to_hex*(v: ImV): string = return toHex(v.as_u64)
proc to_hex*(v: ImValue): string = return toHex(v.as_u64)
proc to_bin_str*(v: ImV): string = return toBin(v.as_i64, 64)
proc to_bin_str*(v: ImValue): string = return toBin(v.as_i64, 64)
proc to_bin_str*(v: uint32): string = return toBin(v.as_i64, 32)
proc to_bin_str*(v: int32): string = return toBin(v.as_i64, 32)
proc to_bin_str*(v: int64): string = return toBin(v, 64)
proc to_bin_str*(v: uint64): string = return toBin(v.as_i64, 64)

proc `$`*(k: ImValueKind): string =
  case k:
    of kNumber: return "Number"
    of kNil:    return "Nil"
    of kString: return "String"
    of kMap:    return "Map"
    of kArray:  return "Array"
    of kSet:    return "Set"
    of kBool:   return "Boolean"
    else:       return "<unknown>"

proc `$`*(v: ImValue): string =
  let kind = get_type(v)
  case kind:
    of kNumber:           return $(v.as_f64.int)
    of kNil:              return "Nil"
    of kMap:              return $(v.as_map.payload.data)
    of kArray:            return $(v.as_arr.payload.data)
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

# full_hash is 32 bits
# short_hash is something like 15 bits (top 17 are zeroed)
func update_head(previous_head: uint32, full_hash: uint32): uint32 =
  let short_hash = bitand(full_hash.uint32, MASK_SHORT_HASH)
  let truncated_head = bitand(previous_head, bitnot(MASK_SHORT_HASH))
  return bitor(truncated_head, short_hash.uint32).uint32

# ImMap Impl #
# ---------------------------------------------------------------------

template buildImMap(new_hash, new_data: typed) {.dirty.} =
  let h = new_hash.uint32
  var new_map = ImMap(
    head: update_head(MASK_SIG_MAP, h),
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
proc contains*(m: ImMap, k: float64): bool = k.as_v in m.payload.data

template get_impl(m: ImMap, k: typed): ImValue =
  m.payload.data.getOrDefault(k.as_v, Nil.as_v).as_v
proc `[]`*(m: ImMap, k: ImValue): ImValue = return get_impl(m, k)
proc `[]`*(m: ImMap, k: float64): ImValue = return get_impl(m, k)
proc get*(m: ImMap, k: ImValue): ImValue  = return get_impl(m, k)
proc get*(m: ImMap, k: float64): ImValue  = return get_impl(m, k)

proc del*(m: ImMap, k: ImValue): ImMap =
  if not(k in m.payload.data): return m
  let v = m.payload.data[k]
  var table_copy = m.payload.data
  table_copy.del(k)
  let entry_hash = hash_entry(k, v)
  let new_hash = calc_hash(m.payload.hash, entry_hash)
  buildImMap(new_hash, table_copy)
  return new_map
proc del*(m: ImMap, k: float64): ImMap = return m.del(k.as_v)

proc set*(m: ImMap, k: ImValue, v: ImValue): ImMap =
  if v == Nil.as_v: return m.del(k)
  if m.payload.data.getOrDefault(k, Nil.as_v) == v: return m
  var table_copy = m.payload.data
  table_copy[k] = v
  let entry_hash = hash_entry(k, v)
  let new_hash = calc_hash(m.payload.hash, entry_hash)
  buildImMap(new_hash, table_copy)
  return new_map
proc set*(m: ImMap, k: float64, v: float64): ImMap = return m.set(k.as_v, v.as_v)
proc set*(m: ImMap, k: ImValue, v: float64): ImMap = return m.set(k, v.as_v)
proc set*(m: ImMap, k: float64, v: ImValue): ImMap = return m.set(k.as_v, v)

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
    # echo ""
    k = path[i]
    echo "i: ", i
    # echo "k: ", k
    if curr.is_map:
      stack.add(curr)
      curr = curr.as_map.get(k)
    else:
      echo "TODO - add exceptions"
    max = i
  # echo "\nmax: ", max
  # echo "====================================="
  # echo "stack: ", stack
  # echo "====================================="
  # for i in countdown(path.high, 0):
  for i in countdown(max, 0):
    # echo ""
    var p = false
    # echo "payload?: ", payload
    # echo "get_type(payload): ", get_type(payload)
    # if payload.is_map: p = true
    # if p: echo "payload?: ", payload.as_map.payload.data
    # if p: echo "payload?1: ", payload.as_map.payload.data
    # echo "payload?1: ", payload
    # if p: echo "payload?2: ", payload.as_map.payload.data
    # if p: echo "payload?3: ", payload.as_map.payload.data
    k = path[i]
    curr = stack[i]
    # if p: echo "payload?4: ", payload.as_map.payload.data
    # if p: echo "payload?5: ", payload.as_map.payload.data
    # if p: echo "payload?6: ", payload.as_map.payload.data
    # echo "k: ", k
    # echo "payload?2: ", payload
    # echo "i:       ", i
    # echo "k:       ", k
    # echo "curr:    ", curr
    # if payload.is_array:
    #   echo "payload.arr.len: ", payload.as_arr.payload.data.len
    # elif payload.is_map:
    #   echo "payload.map.len: ", payload.as_map.payload.data.len
    # echo "payload: ", payload
    # echo "payload: ", payload
    # echo "payload: ", payload
    # echo "payload: ", payload
    # echo "payload: ", payload
    # if p: echo "payload!: ", payload.as_map.payload.data
    # echo "payload.tail: ", payload.v.tail.as_u32
    # echo ""
    if curr.is_map:
      payload = curr.as_map.set(k, payload).v
    else:               echo "TODO - add exceptions2"
    # echo "!!!!!!!!!==========================!!!!!!"
    # echo "curr: ", curr
  echo "pay.len: ", payload.as_map.payload.data.len
  echo "pay: ", payload
  echo "payload.tail: ", payload.v.tail.as_u32
  echo "pay.len: ", payload.as_map.payload.data.len
  echo "pay: ", payload
  echo "payload.tail: ", payload.v.tail.as_u32
  return payload


