# TODO
# 
# -[ ] Handle 64-bit systems so that refs don't trample the struct
#

import std/[tables, sets, bitops, strutils, strbasics]
import hashes

## # Immutable Value Types
## =================
##
## ## Priority
## -----------
##
##   Immediates:
##     number(float64), NaN, nil, bool, atom(small string)
##
##   Heaps:
##     string, bignum, array, map, set
##
## ## Some additional types we could add later
## --------------------------------
##
##   Immediates:
##     atom-symbol, timestamp(no timezone?), bitset(48-bit), binary(48-bit),
##     int, small byte array (48-bit, useful for small tuples)
##
##   Heaps:
##     regex, time, date, datetime, pair, tuple, closure, symbol, tag, path,
##     var/box(reactive?), email, version, typedesc/class, vector(homogenous),
##     bitset, binary, unit(measurements), ...
##     (...or mutable types?:)
##     mut-array, mut-map, mut-set, mut-vector, ...
##     (...or ruliad-specific:) 
##     id, branch, patch
##
##
## # NaN-boxing scheme for Immediates (it's the same for 32-bit and 64-bt)
## =======================================================================
##
## 32 bits                          | 32 bits
## XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  number(float64)
##
## 0000... - plain NaN
##
## +- Immediate bit (1)
## |+- Exponent bits (11)
## ||          +- Quiet bit (1)
## ||          |
## 01111111111110000000000000000000 | 00000000000000000000000000000000  NaN
##
## Immediate types (3 bits, because atom needs a 48-bit payload)
## 000 - (cannot use because of collision with NaN)
## 001 - logical (nil | true | false)
## 010 - atom (string of max 6 bytes)
## 011-111 - (unused, 5 values)
##
## If there are other types that don't need 6 bytes of payload, we could add
## a lot more types. If we only need 4 bytes of payload, for example, we
## could add thousands of types. So we really aren't short of bits for
## specifying types.
##
## +- Immediate bit (1)
## |+- Exponent bits (11)
## ||          +- Quiet bit (1)
## ||          |+- Immediate type bits (3)
## ||          ||  +- Payload bits (48)
## ||          ||  |
## 01111111111110010000000000000000 | 00000000000000000000000000000000  nil
## 01111111111110011000000000000000 | 00000000000000000000000000000000  false
## 01111111111110011100000000000000 | 00000000000000000000000000000000  true
## 0111111111111010XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  atom
##
## 
## # NaN-boxing scheme for Heaps (differs for 32-bit and 64-bt)
## ============================================================
##
## Specifically, the smaller pointers of a 32-bit system let us take
## advantage of the lower 15 or 16 bits of the top 32 bits to store a short
## hash. This lets us do equality checks for values of the same type without
## following the pointer and without interning/hash-consing. Each heap-
## allocated value has a full hash as well.
## 
## With 64-bit systems, we make use of the lower 48-bits as a pointer. In
## order to perform equality checks for values of the same type, we have to
## dereference the pointer to get to the full hash.
## 
## Currently, the designs have the Heap types avoiding 000, but this may not
## be necessary because we should be able to discriminate by using the
## leading/sign/heap bit.
## 
## 
## ## 32-bit systems
## -----------------
## 
## ### OPTION 1 : (4 bits, leaves 15-bit short hash, 32768 values)
## 
## Heap types (4 bits)
## 0000 - (cannot use because of collision with NaN)
## 0001 - string
## 0010 - bignum
## 0011 - array
## 0100 - set
## 0101 - map
## 0110-1111 - (unused, 10 values)
##
## ### OPTION 2 : (3 bits, leaves 16-bit short hash, 65536 values)
## 
## Heap types (3 bits)
## 000 - (cannot use because of collision with NaN)
## 001 - string
## 010 - bignum
## 011 - array
## 100 - set
## 101 - map
## 110-111 - (unused, 2 values)
##
## ### Going with OPTION 1 for now
## 
## The extra types may prove to be more useful than the extra bit in the short
## hash. Of course, we can also use one value as a Box for any number of
## other types. Though OPTION 2 is more consistent with 64-bit systems.
##
## +- Heap bit (1)
## |            +- Heap type bits (4)
## |            |   +- Short content hash (15 bits, only 32768 values)
## |            |   |                 +- Pointer (32)
## |            |   |                 |
## 11111111111110001XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  string
## 11111111111110010XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  bignum
## 11111111111110011XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  array
## 11111111111110100XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  set
## 11111111111110101XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  map
##
##
## ## 64-bit systems
## -----------------
##
## Heap types (3 bits)
## 001 - string
## 010 - bignum
## 011 - array
## 100 - set
## 101 - map
## 110-111 - (unused, 2 values)
##
## +- Heap bit (1)
## |            +- Heap type bits (3)
## |            |  +- Pointer (48 bits)
## |            |  |
## 1111111111111001XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  string
## 1111111111111010XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  bignum
## 1111111111111011XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  array
## 1111111111111100XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  set
## 1111111111111101XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  map
##

const NaN_boxing = true
const cpu_32 = defined(cpu32)

# Utils #
# ---------------------------------------------------------------------

# XOR is commutative, associative, and is its own inverse.
# So we can use this same function to unhash as well.
proc calc_hash(i1, i2: uint64): uint64 = return bitxor(i1, i2)
proc calc_hash(i1, i2: uint32): uint32 = return bitxor(i1, i2)

# Types #
# ---------------------------------------------------------------------

type
  ImValueKind* = enum
    # Immediate Kinds
    kPlainNaN
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

when NaN_boxing:
  when cpu_32:
    type
      # Always put the tail first because we are targeting 32-bit little-endian
      # systems. So tail, head lets us cast directly to and from float64.
      ImValue* {.final, acyclic.} = object
        tail*: uint32
        head*: uint32
      ImValueRef* = ref ImValue

      ImStringPayloadRef* = ref object
        hash: uint32
        data: string
      ImArrayPayloadRef* = ref object
        hash: uint32
        data: seq[ImValue]
      ImMapPayloadRef* = ref object
        hash: uint32
        data: Table[ImValue, ImValue]
      ImSetPayloadRef* = ref object
        hash: uint32
        data: HashSet[ImValue]

  else:
    type
      # Always put the tail first because we are targeting 32-bit little-endian
      # systems. So tail, head lets us cast directly to and from float64.
      ImValue* {.final, acyclic.} = object
        tail*: uint32
        head*: uint32
      ImValueRef* = ref ImValue

      ImStringPayloadRef* = ref object
        hash: uint32
        data: string
      ImArrayPayloadRef* = ref object
        hash: uint32
        data: seq[ImValue]
      ImMapPayloadRef* = ref object
        hash: uint32
        data: Table[ImValue, ImValue]
      ImSetPayloadRef* = ref object
        hash: uint32
        data: HashSet[ImValue]


  when cpu_32:
    type
      ImStackValue* = object
        tail*: uint32
        head*: uint32
      # TODO - change ImNumber to alias float64
      ImNumber* {.borrow: `.`.} = distinct ImStackValue
      ImNaN* {.borrow: `.`.} = distinct ImStackValue
      ImNil* {.borrow: `.`.} = distinct ImStackValue
      ImBool* {.borrow: `.`.} = distinct ImStackValue
      ImAtom* {.borrow: `.`.} = distinct ImStackValue
  
  else:
    type
      ImStackValue* = object
        tail*: uint32
        head*: uint32
      # TODO - change ImNumber to alias float64
      ImNumber* {.borrow: `.`.} = distinct ImStackValue
      ImNaN* {.borrow: `.`.} = distinct ImStackValue
      ImNil* {.borrow: `.`.} = distinct ImStackValue
      ImBool* {.borrow: `.`.} = distinct ImStackValue
      ImAtom* {.borrow: `.`.} = distinct ImStackValue

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

  type
    ImSV* = ImStackValue or ImNumber or ImNaN or ImNil or ImBool or ImAtom
    ImHV* = ImString or ImArray or ImMap or ImSet
    ImV* = ImSV or ImHV

# Casts #
# ---------------------------------------------------------------------

template as_f64*(v: typed): float64 = cast[float64](v)
template as_u64*(v: typed): uint64 = cast[uint64](v)
template as_i64*(v: typed): int64 = cast[int64](v)
template as_u32*(v: typed): uint32 = cast[uint32](v)
template as_i32*(v: typed): int32 = cast[int32](v)
template as_byte_array_8*(v: typed): array[8, byte] = cast[array[8, byte]](v)
template as_v*(v: typed): ImValue = cast[ImValue](cast[uint64](v))
template as_str*(v: typed): ImString = cast[ImString](cast[uint64](v))
template as_arr*(v: typed): ImArray = cast[ImArray](cast[uint64](v))
template as_map*(v: typed): ImMap = cast[ImMap](cast[uint64](v))
template as_set*(v: typed): ImSet = cast[ImSet](cast[uint64](v))

# Masks #
# ---------------------------------------------------------------------

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

const MASK_TYPE_STRING = 0b10000000000000001000000000000000'u32
const MASK_TYPE_BIGNUM = 0b10000000000000010000000000000000'u32
const MASK_TYPE_ARRAY  = 0b10000000000000011000000000000000'u32
const MASK_TYPE_SET    = 0b10000000000000100000000000000000'u32
const MASK_TYPE_MAP    = 0b10000000000000101000000000000000'u32

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

# Type Detection #
# ---------------------------------------------------------------------

template is_float(head: uint32): bool =
  return bitand(bitnot(head), MASK_EXPONENT) == 0
template is_nil(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_NIL
template is_bool(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_BOOL
template is_atom(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_ATOM
template is_string(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_STRING
template is_bignum(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_BIGNUM
template is_array(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_ARRAY
template is_set(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_SET
template is_map(head: uint32): bool =
  return bitand(head, MASK_SIGNATURE) == MASK_TYPE_MAP
proc is_heap(head: uint32): bool =
  return bitand(head, MASK_EXP_OR_Q) == MASK_HEAP
  
template is_float(v: ImValue): bool =
  return v.head.is_float
template is_nil(v: ImValue): bool =
  return v.head.is_nil
template is_bool(v: ImValue): bool =
  return v.head.is_bool
template is_atom(v: ImValue): bool =
  return v.head.is_atom
template is_string(v: ImValue): bool =
  return v.head.is_string
template is_bignum(v: ImValue): bool =
  return v.head.is_bignum
template is_array(v: ImValue): bool =
  return v.head.is_array
template is_set(v: ImValue): bool =
  return v.head.is_set
template is_map(v: ImValue): bool =
  return v.head.is_map
proc is_heap(v: ImValue): bool =
  return v.head.is_heap

proc get_type(head: uint32): ImValueKind =
  echo toHex(head), " ", toHex(MASK_EXPONENT)
  if bitand(bitnot(head), MASK_EXPONENT) != 0: return kNumber
  let signature = bitand(head, MASK_SIGNATURE)
  case signature:
    of MASK_SIG_NIL:    return kNil
    of MASK_SIG_BOOL:   return kBool
    of MASK_SIG_ATOM:   return kAtom
    of MASK_SIG_STRING: return kString
    of MASK_SIG_BIGNUM: return kBigNum
    of MASK_SIG_ARRAY:  return kArray
    of MASK_SIG_SET:    return kSet
    of MASK_SIG_MAP:    return kMap
    else:               discard

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

proc `$`*(v: ImValue): string =
  # echo "v: ", v.as_byte_array, " ", v.to_hex
  let kind = get_type(v.head)
  case kind:
    of kNumber: return "Num(" & $(v.as_f64) & ")"
    of kString: return "Str(" & $(v.as_str.tail.data) & ")"
    of kMap:    return "Map(" & $(v.as_map.tail.data) & ")"
    else:       discard

proc debug*(v: ImValue): string =
  # echo "v: ", v.as_byte_array, " ", v.to_hex
  # echo "bin: ", v.to_bin_str
  let kind = get_type(v.head)
  let shallow_str = "( head: " & to_hex(v.head) & ", tail: " & to_hex(v.tail) & " )"
  case kind:
    of kNumber: return "Num" & shallow_str
    of kString: return "Str" & shallow_str
    of kMap:    return "Map" & shallow_str
    else:       discard

if false:
  echo "MASK_SIG_NIL    ", MASK_SIG_NIL.to_bin_str
  echo "MASK_SIG_BOOL   ", MASK_SIG_BOOL.to_bin_str
  echo "MASK_SIG_STRING ", MASK_SIG_STRING.to_bin_str
  echo "MASK_SIG_BIGNUM ", MASK_SIG_BIGNUM.to_bin_str
  echo "MASK_SIG_ARRAY  ", MASK_SIG_ARRAY.to_bin_str
  echo "MASK_SIG_SET    ", MASK_SIG_SET.to_bin_str
  echo "MASK_SIG_MAP    ", MASK_SIG_MAP.to_bin_str

# Equality Testing #
# ---------------------------------------------------------------------

template eq_heap_tail(v1, v2: typed) =
  # echo v1.as_v.debug, " ", v2.as_v.debug
  # echo "tail: ", as_byte_array(v1.ImV), "  ", as_byte_array(v2.ImV)
  result = false
  if v1.tail.hash == v2.tail.hash:
    result = v1.tail.data == v2.tail.data
template eq_heap_value_specific(v1, v2: typed) =
  # echo v1.as_v.debug, " ", v2.as_v.debug
  result = false
  if v1.head == v2.head:
    eq_heap_tail(v1, v2)
template eq_heap_value_generic*(v1, v2: typed) =
  if v1.head == v2.head:
    echo v1, " ", v2
    let signature = bitand(v1.head, MASK_SIGNATURE)
    case signature:
      of MASK_SIG_STRING: eq_heap_tail(v1.as_str, v2.as_str)
      of MASK_SIG_ARRAY:  eq_heap_tail(v1.as_arr, v2.as_arr)
      of MASK_SIG_MAP:    eq_heap_tail(v1.as_map, v2.as_map)
      of MASK_SIG_SET:    eq_heap_tail(v1.as_set, v2.as_set)
      else:               discard
    
proc `==`*(v1, v2: ImString): bool = eq_heap_value_specific(v1, v2)
proc `==`*(v1, v2: ImArray): bool = eq_heap_value_specific(v1, v2)
proc `==`*(v1, v2: ImMap): bool = eq_heap_value_specific(v1, v2)
proc `==`*(v1, v2: ImSet): bool = eq_heap_value_specific(v1, v2)

proc `==`*(v1, v2: ImValue): bool =
  if bitand(MASK_HEAP, v1.head) == MASK_HEAP: eq_heap_value_generic(v1, v2)
  else: return v1.as_u64 == v2.as_u64
proc `==`*(v: ImValue, f: float64): bool = return v == f.as_v
proc `==`*(f: float64, v: ImValue): bool = return v == f.as_v

proc `==`*(v1, v2: ImHV): bool = eq_heap_value_generic(v1, v2)

proc `==`*(v1: ImSV, v2: float64): bool = return v1.as_f64 == v2
proc `==`*(v1: float64, v2: ImSV): bool = return v1 == v2.as_f64
proc `==`*(v1, v2: ImSV): bool = return v1.as_u64 == v2.as_u64
  
proc `==`*(v1, v2: ImV): bool =
  if bitand(MASK_HEAP, v1.head) == MASK_HEAP: eq_heap_value_generic(v1, v2)
  else: return v1.as_u64 == v2.as_u64
proc `==`*(v: ImV, f: float64): bool = return v == f.as_v
proc `==`*(f: float64, v: ImV): bool = return v == f.as_v

# Globals #
# ---------------------------------------------------------------------

proc float_from_mask*(mask: uint32): float64 =
  return (mask.as_u64 shl 32).as_f64

let Nil* = cast[ImNil](float_from_mask(MASK_SIG_NIL))
let True* = cast[ImBool](float_from_mask(MASK_SIG_TRUE))
let False* = cast[ImBool](float_from_mask(MASK_SIG_FALSE))

echo to_hex(Nil)
echo to_hex(True)
echo to_hex(False)
echo as_byte_array_8(Nil)
echo as_byte_array_8(True)
echo as_byte_array_8(False)
echo to_bin_str(Nil)
echo to_bin_str(True)
echo to_bin_str(False)

if false:
  echo "Nil.head: ", Nil.head.to_bin_str
  echo "Nil.tail: ", Nil.tail.as_i32.to_bin_str
  echo "Nil:      ", Nil.to_bin_str
  echo "True.head: ", True.head.to_bin_str
  echo "True.tail: ", True.tail.as_i32.to_bin_str
  echo "True:      ", True.to_bin_str

# Hash Handling #
# ---------------------------------------------------------------------

proc hash*(v: ImValue): Hash =
  if is_heap(v):
    # We cast to ImString so that we can get the hash, but all the ImHeapValues have a hash in the tail.
    let vh = cast[ImString](v)
    result = cast[Hash](vh.tail.hash)
  else:
    result = cast[Hash](v.head)
  
# full_hash is 32 bits
# short_hash is something like 15 bits (top 17 are zeroed)
proc update_head(previous_head: uint32, full_hash: uint32): uint32 =
  let short_hash = bitand(full_hash.uint32, MASK_SHORT_HASH)
  let truncated_head = bitand(previous_head, bitnot(MASK_SHORT_HASH))
  return bitor(truncated_head, short_hash.uint32).uint32

# ImNumber Impl #
# ---------------------------------------------------------------------

# TODO - eliminate this completely by just using floats?
proc init_number*(f: float64 = 0): ImNumber =
  return (cast[ImStackValue](f)).ImNumber

# ImString Impl #
# ---------------------------------------------------------------------

let empty_string = ImString(
  head: MASK_SIG_STRING,
  tail: ImStringPayloadRef(hash: 0)
)

proc init_string*(s: string = ""): ImString =
  if s.len == 0: return empty_string
  let hash = hash(s).uint32
  return ImString(
    head: update_head(MASK_SIG_STRING, hash),
    tail: ImStringPayloadRef(hash: hash, data: s)
  )

proc `[]`*(s: ImString, i: int32): ImValue =
  result = Nil.as_v
  if i < s.tail.data.len:
    if i >= 0:
      result = (init_string($s.tail.data[i])).as_v

proc concat*(s1, s2: ImString): ImString =
  let new_s = s1.tail.data & s2.tail.data
  return init_string(new_s)

proc size*(s: ImString): int32 =
  return s.tail.data.len.int32

# ImMap Impl #
# ---------------------------------------------------------------------
  
var empty_map = ImMap(
  head: MASK_SIG_MAP,
  tail: ImMapPayloadRef(hash: 0)
)
var empty_map2 = ImMap()
empty_map2.head = MASK_SIG_MAP
empty_map2.tail = ImMapPayloadRef(hash: 0)

if true:
  echo "empty_map.head:         ", empty_map.head.to_bin_str
  echo "empty_map.tail:         ", empty_map.tail.as_i32.to_bin_str
  echo "empty_map:              ", empty_map.to_bin_str
  echo "sizeof empty_map:       ", sizeof empty_map
  echo "empty_map2.head:        ", empty_map2.head.to_bin_str
  echo "empty_map2.tail:        ", empty_map2.tail.as_i32.to_bin_str
  echo "empty_map2:             ", empty_map2.to_bin_str
  echo "sizeof empty_map2:      ", sizeof empty_map2
  echo "sizeof ImValue:         ", sizeof ImValue
  echo "sizeof Nil:             ", sizeof Nil
  echo "typeof empty_map.tail:  ", typeof empty_map.tail
  echo "addr empty_map.tail:    ", (addr empty_map.tail).as_i32.to_bin_str
  echo "empty_map.as_v.tail:    ", empty_map.as_v.tail.as_i32.to_bin_str
  echo "sizeof empty_map.head   ", sizeof empty_map.head
  echo "sizeof empty_map.tail   ", sizeof empty_map.tail
  echo "addr empty_map.head:    ", (addr empty_map.head).as_i64
  echo "addr empty_map.tail:    ", (addr empty_map.tail).as_i64
  echo "addr empty_map.head:    ", (addr empty_map.head).as_i64.to_bin_str
  echo "addr empty_map.tail:    ", (addr empty_map.tail).as_i64.to_bin_str

proc init_map*(): ImMap =
  return empty_map
  
# There's probably no point in having this. It suggests reference semantics.
proc clear*(m: ImMap): ImMap =
  return empty_map

proc `[]`*(m: ImMap, k: ImValue): ImValue = return m.tail.data.getOrDefault(k, Nil.as_v).as_v
proc `[]`*(m: ImMap, k: float64): ImValue = return m.tail.data.getOrDefault(k.as_v, Nil.as_v).as_v
proc get*(m: ImMap, k: ImValue): ImValue  = return m.tail.data.getOrDefault(k, Nil.as_v).as_v
proc get*(m: ImMap, k: float64): ImValue  = return m.tail.data.getOrDefault(k.as_v, Nil.as_v).as_v

proc del*(m: ImMap, k: ImValue): ImMap =
  if not(k in m.tail.data): return m
  let v = m.tail.data[k]
  var table_copy = m.tail.data
  table_copy.del(k)
  let k_hash = hash(k)
  let v_hash = hash(v)
  let entry_hash = (k_hash + v_hash).uint32
  let new_m_map_hash = calc_hash(m.tail.hash, entry_hash)
  let new_m_payload = ImMapPayloadRef(
    hash: new_m_map_hash,
    data: table_copy
  )
  let new_m = ImMap( 
    head: update_head(m.head, new_m_map_hash),
    tail: new_m_payload
  )
  return new_m
proc del*(m: ImMap, k: float64): ImMap = return m.del(k.as_v)

proc set*(m: ImMap, k: ImValue, v: ImValue): ImMap =
  if v == Nil.as_v: return m.del(k)
  if m.tail.data.getOrDefault(k, Nil.as_v) == v: return m
  var table_copy = m.tail.data
  table_copy[k] = v
  let k_hash = hash(k)
  let v_hash = hash(v)
  let entry_hash = (k_hash + v_hash).uint32
  let new_m_map_hash = calc_hash(m.tail.hash, entry_hash)
  let new_m_payload = ImMapPayloadRef(
    hash: new_m_map_hash,
    data: table_copy
  )
  let new_m = ImMap( 
    head: update_head(m.head, new_m_map_hash),
    tail: new_m_payload
  )
  return new_m
proc set*(m: ImMap, k: float64, v: float64): ImMap = return m.set(k.as_v, v.as_v)
proc set*(m: ImMap, k: ImValue, v: float64): ImMap = return m.set(k, v.as_v)
proc set*(m: ImMap, k: float64, v: ImValue): ImMap = return m.set(k.as_v, v)

proc size*(m: ImMap): int32 =
  return m.tail.data.len.int32

# ImArray Impl #
# ---------------------------------------------------------------------

# ImSet Impl #
# ---------------------------------------------------------------------