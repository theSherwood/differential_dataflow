import std/[tables, sets, bitops, strutils]
import hashes

# TODO - figure out how to make a macro for this pragma so it can be imported
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

proc get_one*(): int {.ex.} =
  return 1

# #endregion ==========================================================
#            IMMUTABLE DATA-STRUCTURES
# #region =============================================================

#[
  Possible immediates:
  float64, NaN, nil, bool, int, char, atom
  Heap types:
  string, bigint, bigfloat, array, map, set, user-defined

  We don't need char and atom as atom subsumes char

  #[
    NaN-boxing scheme for 32-bit systems

    32 bits                          | 32 bits
    XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  float64

    0000 - plain NaN

    +- Immediate bit (1)
    |+- Exponent bits (11)
    ||          +- Quiet bit (1)
    ||          |+- Not int bit (1)
    ||          ||+- NaN bits (2)
    ||          ||| +- Payload bits (48)
    ||          ||| |
    01111111111110000000000000000000 | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  NaN

    Immediate types (3 bits, because atom needs a 48-bit payload)
    000 - (cannot use because of collision with NaN)
    001 - logical (nil | true | false)
    010 - atom (string of max 6 bytes)
    011-111 - (unused, 5 values)

    Some types we could add:
    atom-symbol, timestamp(no timezone?), bitset(48-bit), binary(48-bit), int,
    small byte array (48-bit, useful for small tuples)

    If there are other types that don't need 6 bytes of payload, we could add
    a lot more types. If we only need 4 bytes of payload, for example, we
    could add thousands of types. So we really aren't short of bits for
    specifying types.

    +- Immediate bit (1)
    |+- Exponent bits (11)
    ||          +- Quiet bit (1)
    ||          |+- Immediate type bits (2)
    ||          || +- Payload bits (48)
    ||          || |
    01111111111110010000000000000000 | 00000000000000000000000000000000  nil
    01111111111110011000000000000000 | 00000000000000000000000000000000  false
    01111111111110011100000000000000 | 00000000000000000000000000000000  true
    0111111111111010XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  atom

    # OPTION 1 : (4 bits, leaves 15-bit short hash, 32768 values)
    Heap types (4 bits)
    0000 - (cannot use because of collision with NaN)
    0001 - string
    0010 - bignum
    0011 - array
    0100 - set
    0101 - map
    0110-1111 - (unused, 10 values)

    # OPTION 2 : (3 bits, leaves 16-bit short hash, 65536 values)
    Heap types (3 bits)
    000 - (cannot use because of collision with NaN)
    001 - string
    010 - bignum
    011 - array
    100 - set
    101 - map
    110-111 - (unused, 2 values)

    # Going with OPTION 1 for now
    The extra types may prove to be more useful than the extra bit in the short
    hash. Of course, we can also use one value as a Box for any number of
    other types.
    Some types we could add:
    regex, time, date, datetime, pair, tuple, closure, symbol, tag, path,
    var/box(reactive?), email, version, typedesc/class, vector(homogenous),
    bitset, binary, unit(measurements), ...
    (...or mutable types?:)
    mut-array, mut-map, mut-set, mut-vector, ...
    (...or ruliad-specific:) 
    id, branch, patch

    +- Heap bit (1)
    |            +- Heap type bits (4)
    |            |   +- Short content hash (15 bits, only 32768 values)
    |            |   |                 +- Pointer (32)
    |            |   |                 |
    11111111111110001XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  string
    11111111111110010XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  bignum
    11111111111110011XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  array
    11111111111110100XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  set
    11111111111110101XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  map

  ]#

  Bits for immutable value hashes

  Not considered by equality function:
  - 1  - invalid
  - 1  - subvariant of some kind (2 values, each kind can have 2 variants)
  Considered by equality function:
  - 4  - ImValueKind (16 values, which should be enough to cover all the kinds)
  - 26 - hash (67_108_864 values, which should be enough for big hash tables)

  Do we need anything else?

]#

const NaN_boxing = true
const system_32_bits = true
const tagged_union = false

when NaN_boxing and system_32_bits:
  type
    Foo = ref object of RootObj
      a: int32
    Bar = ref object of Foo
      b: int32
    ImValueKind* = enum
      # Immediate Kinds
      kPlainNaN
      kNil
      kBool
      kNumber # like js, we just have a float64 number type
      kAtom
      # Heap Kinds
      kBigNum
      kString
      kArray
      kMap
      kSet
      kUserDefined

    ImHeapPayloadRef* = ref object of RootObj
    ImStringPayloadRef* = ref object of ImHeapPayloadRef
      hash: uint32
      data: string
    ImArrayPayloadRef* = ref object of ImHeapPayloadRef
      hash: uint32
      data: seq[ImValue]
    ImMapPayloadRef* = ref object of ImHeapPayloadRef
      hash: uint32
      data: Table[ImValue, ImValue]
    ImSetPayloadRef* = ref object of ImHeapPayloadRef
      hash: uint32
      data: HashSet[ImValue]

    # Always put the tail first because we are targeting 32-bit little-endian
    # systems. So tail, head lets us cast directly to and from float64.
    ImValue* {.final, acyclic.} = object
      tail*: uint32
      head*: uint32
    ImValueRef* = ref ImValue

    ImStackValue* = object
      tail*: uint32
      head*: uint32
    # TODO - change ImNumber to alias float64
    ImNumber* {.borrow: `.`.} = distinct ImStackValue
    ImNaN* {.borrow: `.`.} = distinct ImStackValue
    ImNil* {.borrow: `.`.} = distinct ImStackValue
    ImBool* {.borrow: `.`.} = distinct ImStackValue
    ImAtom* {.borrow: `.`.} = distinct ImStackValue

    ImSV* = ImStackValue or ImNumber or ImNaN or ImNil or ImBool or ImAtom

    ImImmediateValueRef* = ref ImStackValue
    ImNumberRef* = ref ImNumber
    ImNaNRef* = ref ImNaN
    ImNilRef* = ref ImNil
    ImBoolRef* = ref ImBool
    ImAtomRef* = ref ImAtom

    ImHeapValue* = object of RootObj
    ImString* = object of ImHeapValue
      tail*: ImStringPayloadRef
      head*: uint32
    ImArray* = object of ImHeapValue
      tail*: ImArrayPayloadRef
      head*: uint32
    ImMap* = object of ImHeapValue
      tail*: ImMapPayloadRef
      head*: uint32
    ImSet* = object of ImHeapValue
      tail*: ImSetPayloadRef
      head*: uint32

    ImHV* = ImHeapValue or ImString or ImArray or ImMap or ImSet

    ImHeapValueRef* = ref ImHeapValue
    ImStringRef* = ref ImString
    ImArrayRef* = ref ImArray
    ImMapRef* = ref ImMap
    ImSetRef* = ref ImSet

    ImV* = ImSV or ImHV

  # XOR is commutative, associative, and is its own inverse.
  # So we can use this same function to unhash as well.
  proc calc_hash(i1, i2: uint32): uint32 =
    return bitxor(i1, i2)

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

  template as_v*(v: typed): ImValue =
    cast[ImValue](v)
  template as_f64*(v: typed): float64 =
    cast[float64](v)
  template as_u64*(v: typed): uint64 =
    cast[uint64](v)

  proc to_hex*(f: float64): string =
    return toHex(f.as_u64)
  proc to_hex*(v: ImV): string =
    return toHex(v.as_u64)
  proc to_byte_array*(v: ImV): array[8, byte] =
    return cast[array[8, byte]](v)

  proc get_kind(head: uint32): ImValueKind =
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
      else:
        discard

  template eq_heap_tail(v1, v2: typed) =
    # echo "tail: ", to_byte_array(v1.ImV), "  ", to_byte_array(v2.ImV)
    result = false
    if v1.tail.hash == v2.tail.hash:
      result = v1.tail.data == v2.tail.data
  template eq_heap_value(v1, v2: typed) =
    result = false
    if v1.head == v2.head:
      eq_heap_tail(v1, v2)
    
  proc `==`*(v1, v2: ImString): bool =
    eq_heap_value(v1, v2)
  proc `==`*(v1, v2: ImArray): bool =
    eq_heap_value(v1, v2)
  proc `==`*(v1, v2: ImMap): bool =
    eq_heap_value(v1, v2)
  proc `==`*(v1, v2: ImSet): bool =
    eq_heap_value(v1, v2)
  proc `==`*(v1, v2: ImHV): bool =
    result = false
    if v1.head == v2.head:
      let signature = bitand(v1.head, MASK_SIGNATURE)
      case signature:
        of MASK_SIG_STRING:
          eq_heap_tail(v1.ImString, v2.ImString)
        of MASK_SIG_ARRAY:
          eq_heap_tail(v1.ImArray, v2.ImArray)
        of MASK_SIG_MAP:
          eq_heap_tail(v1.ImMap, v2.ImMap)
        of MASK_SIG_SET:
          eq_heap_tail(v1.ImSet, v2.ImSet)
        else:
          discard

  proc `==`*(v1: ImSV, v2: float64): bool =
    return v1.as_f64 == v2
  proc `==`*(v1: float64, v2: ImSV): bool =
    return v1 == v2.as_f64
  proc `==`*(v1, v2: ImSV): bool =
    return v1.as_u64 == v2.as_u64
  
  proc `==`*(v1, v2: ImV): bool =
    if bitand(MASK_HEAP, v1.head) == MASK_HEAP:
      return v1.ImHV == v2.ImHV
    else:
      return v1.ImSV == v2.ImSV
  proc `==`*(v1: ImV, v2: float64): bool =
    return v1 == v2.as_v
  proc `==`*(v1: float64, v2: ImV): bool =
    return v1.as_v == v2
  
  # TODO - figure out how to make this work so we get some handy coercion
  #proc `==`*(v1, v2: ImValue): bool =
    #if bitand(MASK_HEAP, v1.head) == MASK_HEAP:
      #return v1.ImHV == v2.ImHV
    #else:
      #return v1.ImSV == v2.ImSV
  proc `==`*(v: ImValue, f: float64): bool =
    return cast[float64](v) == f
  proc `==`*(f: float64, v: ImValue): bool =
    return cast[float64](v) == f

  proc float_from_mask*(mask: uint32): float64 =
    return cast[float64](cast[uint64](mask) shl 32)

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

  let Nil* = cast[ImNil](float_from_mask(MASK_SIG_NIL))
  let True* = cast[ImBool](float_from_mask(MASK_SIG_TRUE))
  let False* = cast[ImBool](float_from_mask(MASK_SIG_FALSE))

  echo to_hex(Nil)
  echo to_hex(True)
  echo to_hex(False)
  echo to_byte_array(Nil)
  echo to_byte_array(True)
  echo to_byte_array(False)

  proc `$`*(v: ImValue): string =
    let kind = get_kind(v.head)
    case kind:
      of kNumber:
        result = "Num(" & $(cast[float64](v)) & ")"
      of kMap:
        result = "Map( TODO )"
      else:
        discard
  proc debug*(v: ImValue): string =
    let kind = get_kind(v.head)
    let shallow_str = "( head: " & to_hex(v.head) & ", tail: " & to_hex(v.tail) & " )"
    case kind:
      of kNumber:
        result = "Num" & shallow_str
      of kMap:
        result = "Map" & shallow_str
      else:
        discard

  # TODO - eliminate this completely by just using floats?
  proc init_number*(f: float64 = 0): ImNumber =
    return (cast[ImStackValue](f)).ImNumber

  let empty_map = ImMap(
    head: MASK_SIG_MAP,
    tail: ImMapPayloadRef(hash: 0)
  )

  proc init_map*(): ImMap =
    return empty_map
  
  # There's probably no point in having this. It suggests reference semantics.
  proc clear*(m: ImMap): ImMap =
    return empty_map

  proc `[]`*(m: ImMap, k: ImValue): ImValue =
    return m.tail.data.getOrDefault(k, Nil.as_v).as_v
  proc `[]`*(m: ImMap, k: float64): ImValue =
    return m.tail.data.getOrDefault(k.as_v, Nil.as_v).as_v
  proc get*(m: ImMap, k: ImValue): ImValue =
    return m.tail.data.getOrDefault(k, Nil.as_v).as_v
  proc get*(m: ImMap, k: float64): ImValue =
    return m.tail.data.getOrDefault(k.as_v, Nil.as_v).as_v

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
  proc del*(m: ImMap, k: float64): ImMap =
    return m.del(k.as_v)

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
  proc set*(m: ImMap, k: float64, v: float64): ImMap =
    return m.set(k.as_v, v.as_v)
  proc set*(m: ImMap, k: ImValue, v: float64): ImMap =
    return m.set(k, v.as_v)
  proc set*(m: ImMap, k: float64, v: ImValue): ImMap =
    return m.set(k.as_v, v)

  proc size*(m: ImMap): int32 =
    return m.tail.data.len.int32

else:
  type
    ImValueKind* = enum
      # Immediate Kinds
      kPlainNaN
      kNil
      kBool
      # Heap Kinds
      kNumber
      kAtom
      # BigNum
      kString
      kArray
      kMap
      kSet
      kUserDefined
    ImValueKindFlags* = set[ImValueKind]

    ImNumberRef* = ref float64

    ImString* = object
      hash*: int32
      data*: string
    ImArray* = object
      hash*: int32
      data*: seq[ImValue]
    ImMap* = object
      hash*: int32
      data*: Table[ImV, ImV]
    ImSet* = object
      hash*: int32
      data*: HashSet[ImValue]

    ImStringRef* = ref ImString
    ImArrayRef* = ref ImArray
    ImMapRef* = ref ImMap
    ImSetRef* = ref ImSet

    ImValue* {.final, acyclic.} = object
      case kind*: ImValueKind:
        of kPlainNaN, kNil, kBool:
          discard
        of kNumber:
          num*: ImNumberRef
        of kAtom, kString:
          str*: ImStringRef
        of kArray:
          arr*: ImArrayRef
        of kMap:
          map*: ImMapRef
        of kSet:
          set*: ImSetRef
        of kUserDefined:
          discard
    ImValueRef* = ref ImValue

  proc `==`(v1: ImValueRef, v2: ImValueRef): bool =
    if v1.kind == v2.kind:
      # if v1.tail.hash == v2.tail.hash:
      #   result = true
      discard
    else:
      result = false
