import std/[tables, sets, bitops, strutils, strbasics]
import hashes

# Types #
# ---------------------------------------------------------------------

type
  ImHash = uint32

  ImValueKind* = enum
    # Immediate Kinds
    kNil
    kNumber
    # Heap Kinds
    kMap

  ImValue* = object
    tail*: pointer
    head*: uint32

proc `=destroy`(x: var ImValue)
proc `=copy`(x: var ImValue, y: ImValue)

type
  ImMapPayload* = object
    hash: ImHash
    data*: Table[ImValue, ImValue]
  ImMapPayloadRef* = ref ImMapPayload

  ImNumber* = distinct float64
  ImNil*    = distinct uint64

  ImMap* = object
    tail*: ImMapPayloadRef
    head*: uint32

# Masks #
# ---------------------------------------------------------------------

const MASK_EXPONENT    = 0b01111111111100000000000000000000'u32
const MASK_EXP_OR_Q    = 0b01111111111110000000000000000000'u32
const MASK_HEAP        = 0b11111111111110000000000000000000'u32
const MASK_SIGNATURE   = 0b11111111111111111000000000000000'u32

const MASK_TYPE_NIL    = 0b00000000000000010000000000000000'u32
const MASK_TYPE_MAP    = 0b10000000000001010000000000000000'u32

const MASK_SIG_NIL     = MASK_EXP_OR_Q or MASK_TYPE_NIL
const MASK_SIG_MAP     = MASK_EXP_OR_Q or MASK_TYPE_MAP

# Casts #
# ---------------------------------------------------------------------

template v*(v: typed): ImValue = cast[ImValue](cast[uint64](v))
template as_f64*(v: typed): float64 = cast[float64](v)
template as_u64*(v: typed): uint64 = cast[uint64](v)
template as_u32*(v: typed): uint32 = cast[uint32](v)
template as_map*(v: typed): ImMap = cast[ImMap](cast[uint64](v))

# Get Payload #
# ---------------------------------------------------------------------

template payload*(v: ImMap): ref ImMapPayload = v.tail

# Type Detection #
# ---------------------------------------------------------------------

template is_map(v: typed): bool =
  bitand(v.head, MASK_SIGNATURE) == MASK_SIG_MAP
template is_heap(v: typed): bool =
  bitand(bitor(v.head, MASK_EXP_OR_Q), MASK_HEAP) == MASK_HEAP

proc get_type*(v: ImValue): ImValueKind =
  if bitand(bitnot(v.head), MASK_EXPONENT) != 0: return kNumber
  let signature = bitand(v.head, MASK_SIGNATURE)
  case signature:
    of MASK_SIG_NIL:    return kNil
    of MASK_SIG_MAP:    return kMap
    else:
      echo "Unknown Type!"

# GC Hooks #
# ---------------------------------------------------------------------

proc `=destroy`(x: var ImValue) =
  if x.is_map:
    GC_unref(cast[ImMapPayloadRef](x.tail))
proc `=copy`(x: var ImValue, y: ImValue) =
  if x.tail.as_u32 == y.tail.as_u32: return
  if y.is_map:
    GC_ref(cast[ImMapPayloadRef](y.tail))
    `=destroy`(x)
    x.head = y.head
    x.tail = y.tail
  else:
    `=destroy`(x)

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
  for (k, v) in new_data.pairs:
    new_hash = calc_hash(new_hash, hash_entry(k, v))
  buildImMap(new_hash, new_data)
  return new_map
  
# There's probably no point in having this. It suggests reference semantics.
proc clear*(m: ImMap): ImMap =
  return empty_map

proc contains*(m: ImMap, k: ImValue): bool = k.v in m.payload.data

template get_impl(m: ImMap, k: typed): ImValue =
  m.payload.data.getOrDefault(k.v, Nil.v).v
proc `[]`*(m: ImMap, k: ImValue): ImValue = return get_impl(m, k)
proc get*(m: ImMap, k: ImValue): ImValue  = return get_impl(m, k)

proc set*(m: ImMap, k: ImValue, v: ImValue): ImMap =
  if m.payload.data.getOrDefault(k, Nil.v) == v: return m
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

proc set_in*(it: ImValue, path: openArray[ImValue], v: ImValue): ImValue =
  # var stuff: ImValue = v
  result = v
  var stack = @[it]
  if it.is_map:
    echo "\nit:"
    echo "v.head: ", it.head
    echo "v.tail: ", it.tail.as_u32
    echo "m.head: ", it.as_map.head.as_u32
    echo "m.tail: ", it.as_map.tail.as_u32
    let m = it.as_map.set(path[0], result)
    # GC_ref(m.tail)
    result = m.v
  echo "\nresult:"
  echo "v.head: ", result.head
  echo "v.tail: ", result.tail.as_u32
  echo "m.head: ", result.as_map.head.as_u32
  echo "m.tail: ", result.as_map.tail.as_u32
  echo "\nstack:"
  echo "v.head: ", stack[0].head
  echo "v.tail: ", stack[0].tail.as_u32
  echo "m.head: ", stack[0].as_map.head.as_u32
  echo "m.tail: ", stack[0].as_map.tail.as_u32
  echo "\nresult:"
  echo "result.len:  ", result.as_map.payload.data.len
  echo "result:      ", result
  echo "result.tail: ", result.v.tail.as_u32
  echo "result.len:  ", result.as_map.payload.data.len
  echo "result:      ", result
  echo "result.tail: ", result.v.tail.as_u32
  # return stuff
