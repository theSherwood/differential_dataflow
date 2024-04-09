## TODO
## 
## -[ ] add Infinity, -Infinity
## -[ ] add a converter from int to ImValue
## -[ ] add an ability to push onto the end of an array

import std/[tables, sets, bitops, strutils, strbasics, strformat, macros]
import hashes

## # Immutable Value Types
## =======================
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
## -------------------------------------------
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
## 001 - string
## 010 - bignum
## 011 - array
## 100 - set
## 101 - map
## 110-111 - (unused, 2 values)
##
## ### Going with OPTION 2 for now
## 
## Option 2 is more consistent with 64-bit systems
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

const c32 = defined(cpu32)

# Types #
# ---------------------------------------------------------------------

type
  TypeException* = object of CatchableError

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

when c32:
  type ImValue* = object
    tail: uint32
    head: uint32

  proc `=destroy`(x: var ImValue)
  proc `=copy`(x: var ImValue, y: ImValue)

else:
  type ImValue* = distinct uint64

type
  ImStringPayload* = object
    hash: Hash
    data: string
  ImArrayPayload* = object
    hash: Hash
    data: seq[ImValue]
  ImMapPayload* = object
    hash: Hash
    data: Table[ImValue, ImValue]
  ImSetPayload* = object
    hash: Hash
    data: HashSet[ImValue]
  ImStringPayloadRef* = ref ImStringPayload
  ImArrayPayloadRef*  = ref ImArrayPayload
  ImMapPayloadRef*    = ref ImMapPayload
  ImSetPayloadRef*    = ref ImSetPayload

  ImNaN*    = distinct uint64
  ImNil*    = distinct uint64
  ImBool*   = distinct uint64
  ImAtom*   = distinct uint64

when c32:
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
  ImSV* = ImNaN or ImNil or ImBool or ImAtom
  ImHV* = ImString or ImArray or ImMap or ImSet
  ImV* = ImSV or ImHV

# Casts #
# ---------------------------------------------------------------------

template as_f64*(v: typed): float64 = cast[float64](v)
template as_u64*(v: typed): uint64 = cast[uint64](v)
template as_i64*(v: typed): int64 = cast[int64](v)
template as_u32*(v: typed): uint32 = cast[uint32](v)
template as_i32*(v: typed): int32 = cast[int32](v)
template as_hash*(v: typed): Hash = cast[Hash](v)
template as_p*(v: typed): pointer = cast[pointer](v)
template as_byte_array_8*(v: typed): array[8, byte] = cast[array[8, byte]](v)
template as_v*(v: typed): ImValue = cast[ImValue](cast[uint64](v))
template as_str*(v: typed): ImString = cast[ImString](cast[uint64](v))
template as_arr*(v: typed): ImArray = cast[ImArray](cast[uint64](v))
template as_map*(v: typed): ImMap = cast[ImMap](cast[uint64](v))
template as_set*(v: typed): ImSet = cast[ImSet](cast[uint64](v))

# Conversions #
# ---------------------------------------------------------------------

template v*(x: ImValue): ImValue = x
template v*(x: ImString): ImValue = x.as_v
template v*(x: ImSet): ImValue = x.as_v
template v*(x: ImArray): ImValue = x.as_v
template v*(x: ImMap): ImValue = x.as_v
template v*(x: ImNil): ImValue = x.as_v
template v*(x: ImBool): ImValue = x.as_v
template v*(x: float64): ImValue = x.as_v

# Masks #
# ---------------------------------------------------------------------

when c32:
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

  const MASK_TYPE_STR    = 0b10000000000000010000000000000000'u32
  const MASK_TYPE_BIGNUM = 0b10000000000000100000000000000000'u32
  const MASK_TYPE_ARR    = 0b10000000000000110000000000000000'u32
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

  const MASK_TYPE_STR    = 0b10000000000000010000000000000000'u64 shl 32
  const MASK_TYPE_BIGNUM = 0b10000000000000100000000000000000'u64 shl 32
  const MASK_TYPE_ARR    = 0b10000000000000110000000000000000'u64 shl 32
  const MASK_TYPE_SET    = 0b10000000000001000000000000000000'u64 shl 32
  const MASK_TYPE_MAP    = 0b10000000000001010000000000000000'u64 shl 32

  const MASK_POINTER     = 0x0000ffffffffffff'u64

const MASK_SIG_NAN     = MASK_EXP_OR_Q
const MASK_SIG_NIL     = MASK_EXP_OR_Q or MASK_TYPE_NIL
const MASK_SIG_FALSE   = MASK_EXP_OR_Q or MASK_TYPE_FALSE
const MASK_SIG_TRUE    = MASK_EXP_OR_Q or MASK_TYPE_TRUE
const MASK_SIG_BOOL    = MASK_EXP_OR_Q or MASK_TYPE_BOOL
const MASK_SIG_ATOM    = MASK_EXP_OR_Q or MASK_TYPE_ATOM
const MASK_SIG_STR     = MASK_EXP_OR_Q or MASK_TYPE_STR
const MASK_SIG_BIGNUM  = MASK_EXP_OR_Q or MASK_TYPE_BIGNUM
const MASK_SIG_ARR     = MASK_EXP_OR_Q or MASK_TYPE_ARR
const MASK_SIG_SET     = MASK_EXP_OR_Q or MASK_TYPE_SET
const MASK_SIG_MAP     = MASK_EXP_OR_Q or MASK_TYPE_MAP

# Get Payload #
# ---------------------------------------------------------------------

when c32:
  template payload(v: ImString): ref ImStringPayload = v.tail
  template payload(v: ImMap): ref ImMapPayload       = v.tail
  template payload(v: ImArray): ref ImArrayPayload   = v.tail
  template payload(v: ImSet): ref ImSetPayload       = v.tail
else:
  template payload(v: ImString): ref ImStringPayload = cast[ref ImStringPayload](v.p.to_clean_ptr)
  template payload(v: ImMap): ref ImMapPayload       = cast[ref ImMapPayload](v.p.to_clean_ptr)
  template payload(v: ImArray): ref ImArrayPayload   = cast[ref ImArrayPayload](v.p.to_clean_ptr)
  template payload(v: ImSet): ref ImSetPayload       = cast[ref ImSetPayload](v.p.to_clean_ptr)

# Type Detection #
# ---------------------------------------------------------------------

when c32:
  template type_bits*(v: typed): uint32 =
    v.as_v.head
else:
  template type_bits*(v: typed): uint64 =
    v.as_u64

template is_num*(v: typed): bool =
  bitand(bitnot(v.type_bits), MASK_EXPONENT) != 0
template is_nil*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_NIL
template is_bool*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_BOOL
template is_atom*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_ATOM
template is_string*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_STR
template is_bignum*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_BIGNUM
template is_array*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_ARR
template is_set*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_SET
template is_map*(v: typed): bool =
  bitand(v.type_bits, MASK_SIGNATURE) == MASK_SIG_MAP
template is_heap*(v: typed): bool =
  bitand(bitor(v.type_bits, MASK_EXP_OR_Q), MASK_HEAP) == MASK_HEAP

proc get_type*(v: ImValue): ImValueKind =
  let type_carrier = v.type_bits
  if v.is_num: return kNumber
  let signature = bitand(type_carrier, MASK_SIGNATURE)
  case signature:
    of MASK_SIG_NIL:    return kNil
    of MASK_SIG_BOOL:   return kBool
    of MASK_SIG_ATOM:   return kAtom
    of MASK_SIG_STR:    return kString
    of MASK_SIG_BIGNUM: return kBigNum
    of MASK_SIG_ARR:    return kArray
    of MASK_SIG_SET:    return kSet
    of MASK_SIG_MAP:    return kMap
    else:               echo "Unknown Type!"

# GC Hooks #
# ---------------------------------------------------------------------

when c32:
  proc `=destroy`(x: var ImValue) =
    if x.is_map:
      GC_unref(cast[ImMapPayloadRef](x.tail))
    elif x.is_array:
      GC_unref(cast[ImArrayPayloadRef](x.tail))
    elif x.is_set:
      GC_unref(cast[ImSetPayloadRef](x.tail))
    elif x.is_string:
      GC_unref(cast[ImStringPayloadRef](x.tail))
  proc `=copy`(x: var ImValue, y: ImValue) =
    if x.as_u64 == y.as_u64: return
    if y.is_map:
      GC_ref(cast[ImMapPayloadRef](y.tail))
    elif y.is_array:
      GC_ref(cast[ImArrayPayloadRef](y.tail))
    elif y.is_set:
      GC_ref(cast[ImSetPayloadRef](y.tail))
    elif y.is_string:
      GC_ref(cast[ImStringPayloadRef](y.tail))
    `=destroy`(x)
    x.head = y.head
    x.tail = y.tail

when not c32:
  template to_clean_ptr(v: typed): pointer =
    cast[pointer](bitand((v).as_u64, MASK_POINTER))

  proc `=destroy`[T](x: var MaskedRef[T]) =
    GC_unref(cast[ref T](to_clean_ptr(x.p)))
  proc `=copy`[T](x: var MaskedRef[T], y: MaskedRef[T]) =
    GC_ref(cast[ref T](to_clean_ptr(y.p)))
    x.p = y.p

# Globals #
# ---------------------------------------------------------------------

when c32:
  proc u64_from_mask(mask: uint32): uint64 =
    return (mask.as_u64 shl 32).as_u64
  let Nil*   = cast[ImNil](u64_from_mask(MASK_SIG_NIL))
  let True*  = cast[ImBool](u64_from_mask(MASK_SIG_TRUE))
  let False* = cast[ImBool](u64_from_mask(MASK_SIG_FALSE))
else:
  let Nil*   = cast[ImNil]((MASK_SIG_NIL))
  let True*  = cast[ImBool]((MASK_SIG_TRUE))
  let False* = cast[ImBool]((MASK_SIG_FALSE))

let Infinity*       = Inf
let PosInfinity*    = Inf
let NegInfinity*    = NegInf
let MaxNumber*      = (0x7fefffffffffffff'u64).as_f64
let MinNumber*      = (0xffefffffffffffff'u64).as_f64
let MinSafeInteger* = -9007199254740991.0'f64
let MaxSafeInteger* = 9007199254740991.0'f64

# Equality Testing #
# ---------------------------------------------------------------------

template initial_eq_heap_value(v1, v2: typed): bool =
  when c32:
    v1.head == v2.head
  else:
    bitand(v1.as_u64, MASK_SIGNATURE) == bitand(v2.as_u64, MASK_SIGNATURE)
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
    when c32:
      let signature = bitand(v1.head, MASK_SIGNATURE)
    else:
      let signature = bitand(v1.as_u64, MASK_SIGNATURE)
    case signature:
      of MASK_SIG_STR:    eq_heap_payload(v1.as_str.payload, v2.as_str.payload)
      of MASK_SIG_ARR:    eq_heap_payload(v1.as_arr.payload, v2.as_arr.payload)
      of MASK_SIG_MAP:    eq_heap_payload(v1.as_map.payload, v2.as_map.payload)
      of MASK_SIG_SET:    eq_heap_payload(v1.as_set.payload, v2.as_set.payload)
      else:               discard

template complete_eq(v1, v2: typed): bool =
  if bitand(MASK_HEAP, v1.type_bits) == MASK_HEAP: eq_heap_value_generic(v1, v2) else: v1.as_u64 == v2.as_u64
func `==`*(v1, v2: ImValue): bool =
  if bitand(MASK_HEAP, v1.type_bits) == MASK_HEAP: eq_heap_value_generic(v1, v2)
  else: return v1.as_u64 == v2.as_u64
func `==`*(v: ImValue, f: float64): bool = return v == f.as_v
func `==`*(f: float64, v: ImValue): bool = return v == f.as_v
    
func `==`*(v1, v2: ImString): bool = eq_heap_value_specific(v1, v2)
func `==`*(v1, v2: ImMap): bool = eq_heap_value_specific(v1, v2)
func `==`*(v1, v2: ImArray): bool = eq_heap_value_specific(v1, v2)
func `==`*(v1, v2: ImSet): bool = eq_heap_value_specific(v1, v2)

func `==`*(v1, v2: ImHV): bool = eq_heap_value_generic(v1, v2)

func `==`*(v1: ImSV, v2: float64): bool = return v1.as_f64 == v2
func `==`*(v1: float64, v2: ImSV): bool = return v1 == v2.as_f64
func `==`*(v1, v2: ImSV): bool = return v1.as_u64 == v2.as_u64
  
func `==`*(v1, v2: ImV): bool =
  if bitand(MASK_HEAP, v1.type_bits) == MASK_HEAP: eq_heap_value_generic(v1, v2)
  else: return v1.as_u64 == v2.as_u64
func `==`*(v: ImV, f: float64): bool = return v == f.as_v
func `==`*(f: float64, v: ImV): bool = return v == f.as_v

proc `<`*(a, b: ImValue): bool
proc `<=`*(a, b: ImValue): bool

template `<`*(a: float64, b: ImValue): bool = return a.v < b.v
template `<`*(a: ImValue, b: float64): bool = return a.v < b.v
template `<=`*(a: float64, b: ImValue): bool = return a.v <= b.v
template `<=`*(a: ImValue, b: float64): bool = return a.v <= b.v

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

proc pprint(v: ImValue, indent: Natural, results: var seq[string]): void

const MAX_PRINT_WIDTH = 50
proc pprint(m: ImMap, indent: Natural, results: var seq[string]): void =
  results.add("M[")
  # for (k, v) in m.payload.data.pairs:
  #   var i_results = newSeq[string]()
  #   pprint(k, 0, i_results)
  #   i_results.add(": ")
  #   pprint(v, 0, i_results)
  #   var tall = false
  #   var sum = 0
  #   for r in i_results:
  #     if '\n' in r:
  #       tall = true
  #       break
  #     sum = sum + r.len
  #     if sum > MAX_PRINT_WIDTH:
  #       tall = true
  #       break
  #   i_results.add("( ")
  #   i_results.add(": ")
  #   i_results.add(" )")
  # results.add("]")

  for (k, v) in m.payload.data.pairs:
    results.add("\n")
    results.add("( ".indent(indent + 2))
    pprint(k, indent + 4, results)
    if v.is_heap:
      results.add(" :\n")
      results.add("".indent(indent + 4))
    else:
      results.add(" : ")
    pprint(v, indent + 4, results)
    results.add(" ),")
  results.add("]")

proc pprint(a: ImArray, indent: Natural, results: var seq[string]): void =
  results.add("A[")
  for v in a.payload.data:
    results.add("\n")
    results.add("".indent(indent + 2))
    pprint(v, indent + 2, results)
    results.add(",")
  results.add("]")

proc pprint(s: ImSet, indent: Natural, results: var seq[string]): void =
  results.add("S[")
  for v in s.payload.data:
    results.add("\n")
    results.add("".indent(indent + 2))
    pprint(v, indent + 2, results)
    results.add(",")
  results.add("]")

proc pprint(s: ImString, indent: Natural, results: var seq[string]): void =
  results.add("Str[".indent(indent))
  results.add($s.payload.data)
  results.add("]")

proc pprint(v: ImValue, indent: Natural, results: var seq[string]): void =
  let kind = get_type(v)
  case kind:
    of kNumber:  results.add($(v.as_f64))
    of kNil:     results.add("Nil")
    of kString:  pprint(v.as_str, indent, results)
    of kMap:     pprint(v.as_map, indent, results)
    of kArray:   pprint(v.as_arr, indent, results)
    of kSet:     pprint(v.as_set, indent, results)
    of kBool:
      if v == True.v:      results.add("True")
      elif v == False.v:   results.add("False")
      else: discard
    else:        discard
proc pprint*(v: ImValue): string =
  var results = newSeq[string]()
  pprint(v, 0, results)
  return results.join("")

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
  # return pprint(v)
  let kind = get_type(v)
  case kind:
    of kNumber:           return $(v.as_f64)
    of kNil:              return "Nil"
    of kBool:
      if v == True.as_v:  return "True"
      if v == False.as_v: return "False"
      # TODO - type error
    of kString:           return $(v.as_str.payload.data)
    of kMap:              return $(v.as_map.payload.data)
    of kArray:            return $(v.as_arr.payload.data)
    of kSet:              return $(v.as_set.payload.data) 
    # of kString:           return "Str\"" & $(v.as_str.payload.data) & "\""
    # of kMap:              return "M[" & $(v.as_map.payload.data) & "]"
    # of kArray:            return "A[" & $(v.as_arr.payload.data) & "]" 
    # of kSet:              return "S[" & $(v.as_set.payload.data) & "]" 
    else:                 discard

proc debug*(v: ImValue): string =
  let kind = get_type(v)
  when c32:
    let shallow_str = "( head: " & to_hex(v.head) & ", tail: " & to_hex(v.tail) & " )"
  else:
    let shallow_str = "( " & to_hex(v.as_u64) & " )"
  case kind:
    of kNumber:           return "Num" & shallow_str
    of kNil:              return "Nil" & shallow_str
    of kBool:
      if v == True.as_v:  return "True" & shallow_str
      if v == False.as_v: return "False" & shallow_str
      # TODO - type error
    of kString:           return "Str" & shallow_str
    of kMap:              return "Map" & shallow_str
    of kArray:            return "Arr" & shallow_str
    of kSet:              return "Set" & shallow_str
    else:                 discard

template type_label*(v: ImValue): string = $(v.get_type)

# Hash Handling #
# ---------------------------------------------------------------------

# XOR is commutative, associative, and is its own inverse.
# So we can use this same function to unhash as well.
when c32:
  template calc_hash(i1, i2: typed): Hash = bitxor(i1.as_u32, i2.as_u32).as_hash
else:
  template calc_hash(i1, i2: typed): Hash = bitxor(i1.as_u64, i2.as_u64).as_hash

func hash*(v: ImValue): Hash =
  if is_heap(v):
    # We cast to ImString so that we can get the hash, but all the ImHeapValues have a hash in the tail.
    let vh = cast[ImString](v)
    result = vh.payload.hash.as_hash
  else:
    when c32:
      # We fold it and hash it for 32-bit stack values because a lot of them
      # don't have anything interesting happening in the top 32 bits.
      result = calc_hash(v.head, v.tail).as_hash
    else:
      result = v.as_u64.as_hash

when c32:
  # full_hash is 32 bits
  # short_hash is something like 15 bits (top 17 are zeroed)
  func update_head(previous_head: uint32, full_hash: uint32): uint32 =
    let short_hash = bitand(full_hash.uint32, MASK_SHORT_HASH)
    let truncated_head = bitand(previous_head, bitnot(MASK_SHORT_HASH))
    return bitor(truncated_head, short_hash.uint32).as_u32

# ImString Impl #
# ---------------------------------------------------------------------

template buildImString(new_hash, new_data: typed) {.dirty.} =
  when c32:
    let h = new_hash
    var new_string = ImString(
      head: update_head(MASK_SIG_STR, h.as_u32).as_u32,
      tail: ImStringPayloadRef(hash: h, data: new_data)
    )
  else:
    var re = new ImStringPayload
    GC_ref(re)
    re.hash = new_hash
    re.data = new_data
    var new_string = ImString(p: bitor(MASK_SIG_STR, re.as_p.as_u64).as_p)
  
func init_string_empty(): ImString =
  let hash = 0
  let data = ""
  buildImString(hash, data)
  return new_string

let empty_string = init_string_empty()

proc init_string*(s: string = ""): ImString =
  if s.len == 0: return empty_string
  let hash = hash(s)
  buildImString(hash, s)
  return new_string
template to_str*(s: string): ImString = s.init_string

proc `[]`*(s: ImString, i: int): ImValue =
  result = Nil.as_v
  if i < s.payload.data.len:
    if i >= 0:
      result = (init_string($s.payload.data[i])).as_v

proc concat*(s1, s2: ImString): ImString =
  let new_s = s1.payload.data & s2.payload.data
  return init_string(new_s)
proc `&`*(s1, s2: ImString): ImString =
  let new_s = s1.payload.data & s2.payload.data
  return init_string(new_s)

func size*(s: ImString): int =
  return s.payload.data.len.int

func `<`*(v1, v2: ImString): bool = return v1.payload.data < v2.payload.data
func `<=`*(v1, v2: ImString): bool = return v1.payload.data <= v2.payload.data

# ImMap Impl #
# ---------------------------------------------------------------------

template buildImMap(new_hash, new_data: typed) {.dirty.} =
  when c32:
    let h = new_hash
    var new_map = ImMap(
      head: update_head(MASK_SIG_MAP, h.as_u32),
      tail: ImMapPayloadRef(hash: h, data: new_data)
    )
  else:
    var re = new ImMapPayload
    GC_ref(re)
    re.hash = new_hash
    re.data = new_data
    var new_map = ImMap(p: bitor(MASK_SIG_MAP, re.as_p.as_u64).as_p)

func init_map_empty(): ImMap =
  let hash = 0
  let data = initTable[ImValue, ImValue]()
  buildImMap(hash, data)
  return new_map
  
let empty_map = init_map_empty()

template hash_entry(k, v: typed): Hash = (hash(k).as_u64 + hash(v).as_u64).as_hash

proc init_map*(): ImMap = return empty_map
proc init_map*(init_data: openArray[(ImValue, ImValue)]): ImMap
proc init_map*(init_data: openArray[(ImValue, ImValue)]): ImMap =
  if init_data.len == 0: return empty_map
  var new_data: Table[ImValue, ImValue]
  var new_hash = 0.as_hash
  for (k, v) in init_data:
    if k in new_data:
      new_hash = calc_hash(new_hash, hash_entry(k, new_data[k]))
    if v.v == Nil.v:
      new_data.del(k)
    else:
      new_hash = calc_hash(new_hash, hash_entry(k, v))
      new_data[k] = v
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
proc `[]`*(m: ImMap, k: float64): ImValue = return get_impl(m, k.v)
proc get*(m: ImMap, k: ImValue): ImValue  = return get_impl(m, k)
proc get*(m: ImMap, k: float64): ImValue  = return get_impl(m, k.v)

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

proc set*(m: ImMap, k, v: ImValue): ImMap =
  if v == Nil.as_v: return m.del(k)
  let existing = m.payload.data.getOrDefault(k, Nil.as_v)
  if existing == v: return m
  let entry_hash = hash_entry(k, v)
  var new_hash = calc_hash(m.payload.hash, entry_hash)
  if existing != Nil.v:
    new_hash = calc_hash(new_hash, hash_entry(k, existing))
  var table_copy = m.payload.data
  table_copy[k] = v
  buildImMap(new_hash, table_copy)
  return new_map
proc set*(m: ImMap, k: float64, v: float64): ImMap = return m.set(k.as_v, v.as_v)
proc set*(m: ImMap, k: ImValue, v: float64): ImMap = return m.set(k, v.as_v)
proc set*(m: ImMap, k: float64, v: ImValue): ImMap = return m.set(k.as_v, v)

func size*(m: ImMap): int =
  return m.payload.data.len.int

iterator values*(m: ImMap): ImValue =
  for v in m.payload.data.values:
    yield v
iterator keys*(m: ImMap): ImValue =
  for k in m.payload.data.keys:
    yield k
iterator pairs*(m: ImMap): (ImValue, ImValue) =
  for p in m.payload.data.pairs:
    yield p

## Asymmetric. Entries in m2 overwrite m1
proc `&`*(m1, m2: ImMap): ImMap =
  if m2.size == 0: return m1
  if m1.size == 0: return m2
  if m1.size > m2.size:
    var new_data = m1.payload.data
    var new_hash = m1.payload.hash
    for k, v in m2.payload.data.pairs:
      if k in new_data:
        new_hash = calc_hash(calc_hash(new_hash, hash_entry(k, v)), hash_entry(k, new_data[k]))
      else:
        new_hash = calc_hash(new_hash, hash_entry(k, v))
      new_data[k] = v
    buildImMap(new_hash, new_data)
    return new_map
  else:
    var new_data = m2.payload.data
    var new_hash = m2.payload.hash
    for k, v in m1.payload.data.pairs:
      if k in new_data:
        continue
      new_hash = calc_hash(new_hash, hash_entry(k, v))
      new_data[k] = v
    buildImMap(new_hash, new_data)
    return new_map

# ImArray Impl #
# ---------------------------------------------------------------------

template buildImArray(new_hash, new_data: typed) {.dirty.} =
  when c32:
    let h = new_hash
    var new_array = ImArray(
      head: update_head(MASK_SIG_ARR, h.as_u32),
      tail: ImArrayPayloadRef(hash: h, data: new_data)
    )
  else:
    var re = new ImArrayPayload
    GC_ref(re)
    re.hash = new_hash
    re.data = new_data
    var new_array = ImArray(p: bitor(MASK_SIG_ARR, re.as_p.as_u64).as_p)

proc init_array_empty(): ImArray =
  let new_hash = 0
  let new_data: seq[ImValue] = @[]
  buildImArray(new_hash, new_data)
  return new_array

let empty_array = init_array_empty()

proc init_array*(): ImArray = return empty_array
proc init_array*(init_data: openArray[ImValue]): ImArray =
  if init_data.len == 0: return empty_array
  var new_hash = 0.as_hash
  var new_data = newSeq[ImValue]()
  for v in init_data:
    new_hash = calc_hash(new_hash, v.hash)
    new_data.add(v)
  buildImArray(new_hash, new_data)
  return new_array
proc init_array*(new_data: seq[ImValue]): ImArray =
  if new_data.len == 0: return empty_array
  var new_hash = 0.as_hash
  for v in new_data:
    new_hash = calc_hash(new_hash, v.hash)
  buildImArray(new_hash, new_data)
  return new_array

## TODO
## - ImValue indices
## - Negative indices
## - range indices
template get_impl(a: ImArray, i: int) =
  let data = a.payload.data
  if i >= data.len:
    return Nil.as_v
  else:
    return data[i]
template get_impl(a: ImArray, i: ImValue) =
  if i.is_num:
    get_impl(a, i.as_f64.int)
  else:
    # TODO - raise exception
    discard
template get_impl(a: ImArray, i: float64) =
  if i.is_num:
    get_impl(a, i.as_f64.int)
  else:
    # TODO - raise exception
    discard

proc `[]`*(a: ImArray, i: int): ImValue = get_impl(a, i)
proc `[]`*(a: ImArray, i: ImValue): ImValue = get_impl(a, i)
proc `[]`*(a: ImArray, i: float64): ImValue = get_impl(a, i)
proc get*(a: ImArray, i: int): ImValue  = get_impl(a, i)
proc get*(a: ImArray, i: ImValue): ImValue  = get_impl(a, i)
proc get*(a: ImArray, i: float64): ImValue  = get_impl(a, i)

iterator items*(a: ImArray): ImValue =
  for v in a.payload.data:
    yield v

template set_impl*(a: ImArray, i: int, v: ImValue) =
  let derefed = a.payload
  # hash the previous version's hash with the new value and the old value
  let new_hash = calc_hash(calc_hash(derefed.hash, derefed.data[i].hash), v.hash)
  var new_data = derefed.data
  new_data[i] = v
  buildImArray(new_hash, new_data)
  return new_array
template set_impl*(a: ImArray, i: ImValue, v: ImValue) =
  if i.is_num: set_impl(a, i.as_f64.int, v)
  else:
    # TODO - raise exception
    discard
template set_impl*(a: ImArray, i: float64, v: ImValue) =
  if i.is_num: set_impl(a, i.as_f64.int, v)
  else:
    # TODO - raise exception
    discard

## TODO
## - ImValue indices
## - Negative indices
## - range indices???
## - indices beyond the end of the sequence (fill the gap with Nil)
proc set*(a: ImArray, i: int, v: ImValue): ImArray = set_impl(a, i, v)
proc set*(a: ImArray, i: ImValue, v: ImValue): ImArray = set_impl(a, i, v)
proc set*(a: ImArray, i: float64, v: ImValue): ImArray = set_impl(a, i, v)

proc concat*(a1, a2: ImArray): ImArray =
  let new_a = a1.payload.data & a2.payload.data
  return init_array(new_a)
proc `&`*(a1, a2: ImArray): ImArray =
  let new_a = a1.payload.data & a2.payload.data
  return init_array(new_a)

proc size*(a: ImArray): int =
  return a.payload.data.len.int

proc `<`*(v1, v2: ImArray): bool =
  let l = min(v1.size, v2.size)
  for i in 0..<l:
    if v1[i] < v2[i]: return true
    if v1[i] > v2[i]: return false
  if v1.size < v2.size: return true
  return false
proc `<=`*(v1, v2: ImArray): bool =
  let l = min(v1.size, v2.size)
  for i in 0..<l:
    if v1[i] < v2[i]: return true
    if v1[i] > v2[i]: return false
  if v1.size < v2.size: return true
  if v1.size > v2.size: return false
  return true

# ImSet Impl #
# ---------------------------------------------------------------------

template buildImSet(new_hash, new_data: typed) {.dirty.} =
  when c32:
    let h = new_hash
    var new_set = ImSet(
      head: update_head(MASK_SIG_SET, h.as_u32),
      tail: ImSetPayloadRef(hash: h, data: new_data)
    )
  else:
    var re = new ImSetPayload
    GC_ref(re)
    re.hash = new_hash
    re.data = new_data
    var new_set = ImSet(p: bitor(MASK_SIG_SET, re.as_p.as_u64).as_p)

proc init_set_empty(): ImSet =
  let new_hash = 0
  var new_data: HashSet[ImValue]
  buildImSet(new_hash, new_data)
  return new_set

let empty_set = init_set_empty()

proc init_set*(): ImSet = return empty_set
proc init_set*(init_data: openArray[ImValue]): ImSet =
  if init_data.len == 0: return empty_set
  var new_hash = 0.as_hash
  var new_data = toHashSet(init_data)
  for v in new_data:
    new_hash = calc_hash(new_hash, v.hash)
  buildImSet(new_hash, new_data)
  return new_set

proc contains*(s: ImSet, k: ImValue): bool = k.as_v in s.payload.data
proc contains*(s: ImSet, k: float64): bool = k.as_v in s.payload.data

template has_inner(s: ImSet, k: typed) =
  let derefed = s.payload
  if k.as_v in derefed.data: return True
  return False
proc has*(s: ImSet, k: ImValue): ImBool = has_inner(s, k)
proc has*(s: ImSet, k: float64): ImBool = has_inner(s, k)

proc get*(s: ImSet, k: ImValue): ImValue =
  if k.v in s: return k.v else: return Nil.v
proc get*(s: ImSet, k: float): ImValue =
  if k.v in s: return k.v else: return Nil.v

proc add*(s: ImSet, k: ImValue): ImSet =
  let derefed = s.payload
  if k.as_v in derefed.data: return s
  let new_hash = calc_hash(derefed.hash, k.hash)
  var new_data = derefed.data
  new_data.incl(k.as_v)
  buildImSet(new_hash, new_data)
  return new_set

proc del*(s: ImSet, k: ImValue): ImSet =
  let derefed = s.payload
  if not(k.as_v in derefed.data): return s
  let new_hash = calc_hash(derefed.hash, k.hash)
  var new_data = derefed.data
  new_data.excl(k.as_v)
  buildImSet(new_hash, new_data)
  return new_set

proc size*(s: ImSet): int =
  return s.payload.data.len.int

# More Conversions #
# ---------------------------------------------------------------------

template v*(x: int): ImValue = x.float64.v
template v*(x: string): ImValue = x.to_str.v
template v*(x: openArray[int]): ImValue = toSeq(x).map(x => x.v).init_array.v
template v*(x: openArray[float64]): ImValue = toSeq(x).map(x => x.v).init_array.v
template v*(x: openArray[ImValue]): ImValue = x.init_array.v

proc V_impl(x: NimNode): NimNode =
  case x.kind:
    # a plain tuple of ImValues
    of nnkTupleConstr, nnkPar:
      var tup = quote do: ()
      for c in x.children:
        tup.add(V_impl(c))
      return tup
    # a ImArray as ImValue
    of nnkBracket:
      var brak = copyNimNode(x)
      for c in x.children:
        brak.add(V_impl(c))
      return newCall("v", newCall("init_array", brak))
    # a ImSet as ImValue
    of nnkCurly:
      var brak = quote do: []
      for c in x.children:
        brak.add(V_impl(c))
      return newCall("v", newCall("init_set", brak))
    # a ImMap as ImValue
    of nnkTableConstr:
      var brak = quote do: []
      var parens = quote do: ()
      for colon_expr in x.children:
        parens = quote do: ()
        for c in colon_expr.children:
          parens.add(V_impl(c))
        brak.add(parens)
      return newCall("v", newCall("init_map", brak))
    # some other ImValue that doesn't have any special treatment of literals
    else: 
      return newCall("v", x)
macro V*(x: untyped): untyped =
  V_impl(x)

proc Map_impl(x: NimNode): NimNode =
  case x.kind:
    of nnkBracket:
      var brak = copyNimNode(x)
      var parens = quote do: ()
      for tup in x.children:
        if tup.kind != nnkTupleConstr:
          raise newException(TypeException, &"Cannot call Map on {x.repr}")
        parens = quote do: ()
        for c in tup.children:
          parens.add(V_impl(c))
        brak.add(parens)
      return quote do: init_map(`brak`)
    of nnkCurly:
      var brak = quote do: []
      if x.len > 0:
        raise newException(TypeException, &"Cannot call Map on {x.repr}")
      return quote do: init_map(`brak`)
    of nnkTableConstr:
      var brak = quote do: []
      var parens = quote do: ()
      for colon_expr in x.children:
        parens = quote do: ()
        for c in colon_expr.children:
          parens.add(V_impl(c))
        brak.add(parens)
      return quote do: init_map(`brak`)
    else:
      raise newException(TypeException, &"Cannot call Map on {x.repr}")
macro Map*(x: untyped): untyped =
  Map_impl(x)

# ImValue Fns #
# ---------------------------------------------------------------------

proc get_in(it: ImValue, path: openArray[ImValue], i: int, default: ImValue): ImValue =
  var new_it: ImValue
  if it.is_map:     new_it = it.as_map.get(path[i].v)
  elif it.is_array: new_it = it.as_arr.get(path[i].v)
  elif it.is_set:   new_it = it.as_set.get(path[i].v)
  elif it == Nil.v:
    return default
  else:
    # TODO - error
    discard
  if i == path.high:
    if new_it != Nil.v: return new_it
    return default
  else: return get_in(new_it, path, i + 1, default)
proc get_in*(it: ImValue, path: openArray[ImValue], default: ImValue): ImValue =
  return get_in(it, path, 0, default)
proc get_in*(it: ImValue, path: openArray[ImValue]): ImValue =
  return get_in(it, path, 0, Nil.v)

## If a key in the path does not exist, maps are created
proc set_in*(it: ImValue, path: openArray[ImValue], v: ImValue): ImValue =
  var payload = v
  var stack = newSeq[ImValue]()
  var k: ImValue
  var curr = it
  var max = 0
  for i in 0..path.high:
    k = path[i]
    if curr.is_map:
      stack.add(curr)
      curr = curr.as_map.get(k)
    elif curr.is_array:
      stack.add(curr)
      curr = curr.as_arr.get(k)
    elif curr == Nil.v:
      for j in countdown(path.high, i):
        k = path[j]
        payload = init_map([(k, payload)]).v
      break
    else:
      echo "TODO - add exceptions"
    max = i
  for i in countdown(max, 0):
    k = path[i]
    curr = stack[i]
    if curr.is_map:     payload = curr.as_map.set(k, payload).v
    elif curr.is_array: payload = curr.as_arr.set(k, payload).v
    else:               echo "TODO - add exceptions2"
  return payload

proc `<`*(a, b: ImValue): bool =
  if a.is_num and b.is_num: return a.as_f64 < b.as_f64
  let a_sig = bitand(a.type_bits, MASK_SIGNATURE)
  let b_sig = bitand(b.type_bits, MASK_SIGNATURE)
  case a_sig:
    of MASK_SIG_STR:
      if b_sig == MASK_SIG_STR: return a.as_str < b.as_str
    of MASK_SIG_ARR:
      if b_sig == MASK_SIG_ARR: return a.as_arr < b.as_arr
    else: discard
  raise newException(TypeException, &"Cannot compare {a.type_label} and {b.type_label}")
  
proc `<=`*(a, b: ImValue): bool =
  if a.is_num and b.is_num: return a.as_f64 < b.as_f64
  let a_sig = bitand(a.type_bits, MASK_SIGNATURE)
  let b_sig = bitand(b.type_bits, MASK_SIGNATURE)
  case a_sig:
    of MASK_SIG_STR:
      if b_sig == MASK_SIG_STR: return a.as_str <= b.as_str
    of MASK_SIG_ARR:
      if b_sig == MASK_SIG_ARR: return a.as_arr <= b.as_arr
    else: discard
  raise newException(TypeException, &"Cannot compare {a.type_label} and {b.type_label}")

proc `[]`*(a, b: ImValue): ImValue =
  let a_sig = bitand(a.type_bits, MASK_SIGNATURE)
  case a_sig:
    of MASK_SIG_ARR: return a.as_arr[b]
    of MASK_SIG_MAP: return a.as_map[b]
    of MASK_SIG_SET: return a.as_map[b]
    # of MASK_SIG_STR: return a.as_map[b]
    else: discard
  raise newException(TypeException, &"Cannot index into {$a} of type {a.type_label} with {$b} of type {b.type_label}")
template `[]`*(a: ImValue, b: float64): ImValue = a[b.v]
template `[]`*(a: ImValue, b: int): ImValue = a[b.float64.v]
template `[]`*(a: ImValue, b: string): ImValue = a[b.to_str.v]

proc set*(coll, k, v: ImValue): ImValue =
  let coll_sig = bitand(coll.type_bits, MASK_SIGNATURE)
  case coll_sig:
    of MASK_SIG_ARR: return coll.as_arr.set(k, v).v
    of MASK_SIG_MAP: return coll.as_map.set(k, v).v
    # of MASK_SIG_STR: return coll.as_str.set(k, v)
    else: discard
  raise newException(TypeException, &"Cannot set into {$coll} of type {coll.type_label} with key {$k} of type {k.type_label} and value {$v} of type {v.type_label}")
template set*(coll, k: ImValue, v: string): ImValue = set(coll, k, v.to_str.v)
template set*(coll, k: ImValue, v: float64): ImValue = set(coll, k, v.v)

proc size*(coll: ImValue): ImValue =
  let coll_sig = bitand(coll.type_bits, MASK_SIGNATURE)
  case coll_sig:
    of MASK_SIG_ARR: return coll.as_arr.size.v
    of MASK_SIG_MAP: return coll.as_map.size.v
    of MASK_SIG_STR: return coll.as_str.size.v
    of MASK_SIG_SET: return coll.as_set.size.v
    else: discard
  raise newException(TypeException, &"Cannot get the size of {$coll} of type {coll.type_label}")

##
## nil < boolean < number < string < set < array < map
## 
## What about bignum and the rest of the gang?
proc compare*(a, b: ImValue): int =
  let a_sig = bitand(a.type_bits, MASK_SIGNATURE)
  let b_sig = bitand(b.type_bits, MASK_SIGNATURE)

  # Nil
  block:
    if a_sig == MASK_SIG_NIL:
      if b_sig == MASK_SIG_NIL: return 0
      return -1
    if b_sig == MASK_SIG_NIL: return 1
  
  # Bool
  block:
    if a_sig == MASK_SIG_BOOL:
      if b_sig != MASK_SIG_BOOL: return -1
      if a == False.v:
        if b == False.v: return 0
        return -1
      if b == False.v: return 1
      if b == True.v: return 0
      return -1
    if b_sig == MASK_SIG_BOOL: return 1
  
  # Number
  block:
    if a.is_num:
      if b.is_num:
        if a.as_f64 < b.as_f64: return -1
        if a.as_f64 > b.as_f64: return 1
        return 0
      return -1
    if b.is_num: return 1

  # String
  block:
    if a_sig == MASK_SIG_STR:
      if b_sig == MASK_SIG_STR:
        if a.as_str.payload.data < b.as_str.payload.data: return -1
        if a.as_str.payload.data > b.as_str.payload.data: return 1
        return 0
      return -1
    if b_sig == MASK_SIG_STR: return 1
    
        
