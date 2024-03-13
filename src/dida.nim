import std/[tables, sets, bitops, strutils]
import hashes

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
    +- Sign bit (1)
    |            +- Int indicator bit (1)
    |            |+- Payload bits (51)
    |            ||
    X1111111111111XXXXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  int

    00 - plain NaN

    +- Immediate bit (1)
    |+- Exponent bits (11)
    ||          +- Quiet bit (1)
    ||          |+- Not int bit (1)
    ||          ||+- NaN bits (2)
    ||          ||| +- Payload bits (48)
    ||          ||| |
    01111111111110000000000000000000 | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  NaN

    Immediate types (2 bits)
    01 - logical (nil | true | false)
    10 - atom (string of max 6 bytes)
    11 - (unused)

    +- Immediate bit (1)
    |+- Exponent bits (11)
    ||          +- Quiet bit (1)
    ||          |+- Not int bit (1)
    ||          ||+- Immediate type bits (2)
    ||          ||| +- Payload bits (48)
    ||          ||| |
    01111111111110010000000000000000 | 00000000000000000000000000000000  nil
    01111111111110011000000000000000 | 00000000000000000000000000000000  false
    01111111111110011100000000000000 | 00000000000000000000000000000000  true
    0111111111111010XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  atom
    0111111111111011XXXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  (unused)

    Heap types (3 bits)
    00X - (cannot use because of collision with NaN)
    010 - string
    011 - bignum
    100 - array
    101 - set
    110 - map
    111 - user-defined

    +- Heap bit (1)
    |            +- Not int bit (1)
    |            |+- Heap type bits (3)
    |            ||  +- Short content hash (15 bits, only 32768 values)
    |            ||  |                 +- Pointer (32)
    |            ||  |                 |
    11111111111110010XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  string
    11111111111110011XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  bignum
    11111111111110100XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  array
    11111111111110101XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  set
    11111111111110110XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  map
    11111111111110111XXXXXXXXXXXXXXX | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  user-defined

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
      # Number Kinds
      Float64
      Int52
      # Immediate Kinds
      PlainNaN
      Nil
      Bool
      Number
      Atom
      # Heap Kinds
      BigNum
      String
      Array
      Map
      Set
      UserDefined

    ImHeapPayloadRef* = ref object of RootObj
    ImStringPayloadRef* = ref object of ImHeapPayloadRef
      hash: int32
      data: string
    ImArrayPayloadRef* = ref object of ImHeapPayloadRef
      hash: int32
      data: seq[ImValue]
    ImMapPayloadRef* = ref object of ImHeapPayloadRef
      hash: int32
      data: Table[ImValue, ImValue]
    ImSetPayloadRef* = ref object of ImHeapPayloadRef
      hash: int32
      data: HashSet[ImValue]

    ImValue* {.final, acyclic.} = object
      head*: int32
      tail*: int32
    ImValueRef* = ref ImValue

    ImImmediateValue* = object
      head*: int32
      tail*: int32
    ImFloat* {.borrow: `.`.} = distinct ImImmediateValue
    ImInt* {.borrow: `.`.} = distinct ImImmediateValue
    ImNaN* {.borrow: `.`.} = distinct ImImmediateValue
    ImNil* {.borrow: `.`.} = distinct ImImmediateValue
    ImBool* {.borrow: `.`.} = distinct ImImmediateValue
    ImAtom* {.borrow: `.`.} = distinct ImImmediateValue

    ImImmediateValueRef* = ref ImImmediateValue
    ImFloatRef* = ref ImFloat
    ImIntRef* = ref ImInt
    ImNaNRef* = ref ImNaN
    ImNilRef* = ref ImNil
    ImBoolRef* = ref ImBool
    ImAtomRef* = ref ImAtom

    ImHeapValue* = object of RootObj
    ImString* = object of ImHeapValue
      head*: int32
      tail*: ImStringPayloadRef
    ImArray* = object of ImHeapValue
      head*: int32
      tail*: ImArrayPayloadRef
    ImMap* = object of ImHeapValue
      head*: int32
      tail*: ImMapPayloadRef
    ImSet* = object of ImHeapValue
      head*: int32
      tail*: ImSetPayloadRef

    ImHeapValueRef* = ref ImHeapValue
    ImStringRef* = ref ImString
    ImArrayRef* = ref ImArray
    ImMapRef* = ref ImMap
    ImSetRef* = ref ImSet

  # XOR is commutative, associative, and is its own inverse.
  # So we can use this same function to unhash as well.
  proc calc_hash(i1, i2: int32): int32 =
    return bitxor(i1, i2)

  const MASK_SIGN        = 0b10000000000000000000000000000000'i32
  const MASK_EXPONENT    = 0b01111111111100000000000000000000'i32
  const MASK_QUIET       = 0b00000000000010000000000000000000'i32
  const MASK_EXP_OR_Q    = 0b01111111111110000000000000000000'i32
  const MASK_SIGNATURE   = 0b11111111111111111000000000000000'i32
  const MASK_SHORT_HASH  = 0b00000000000000000111111111111111'i32
  const MASK_HEAP        = 0b11111111111110000000000000000000'i32

  const MASK_TYPE_NAN    = 0b00000000000000000000000000000000'i32
  const MASK_TYPE_INT    = 0b00000000000001000000000000000000'i32
  const MASK_TYPE_NIL    = 0b00000000000000010000000000000000'i32
  const MASK_TYPE_FALSE  = 0b00000000000000011000000000000000'i32
  const MASK_TYPE_TRUE   = 0b00000000000000011100000000000000'i32
  const MASK_TYPE_BOOL   = 0b00000000000000011000000000000000'i32
  const MASK_TYPE_ATOM   = 0b00000000000000100000000000000000'i32
  const MASK_TYPE_TODO   = 0b00000000000000110000000000000000'i32

  const MASK_TYPE_STRING = 0b10000000000000010000000000000000'i32
  const MASK_TYPE_BIGNUM = 0b10000000000000011000000000000000'i32
  const MASK_TYPE_ARRAY  = 0b10000000000000100000000000000000'i32
  const MASK_TYPE_SET    = 0b10000000000000101000000000000000'i32
  const MASK_TYPE_MAP    = 0b10000000000000110000000000000000'i32
  const MASK_TYPE_DEF    = 0b10000000000000111000000000000000'i32

  const MASK_SIG_NAN     = MASK_EXP_OR_Q
  const MASK_SIG_INT     = MASK_EXP_OR_Q or MASK_TYPE_INT
  const MASK_SIG_NIL     = MASK_EXP_OR_Q or MASK_TYPE_NIL
  const MASK_SIG_BOOL    = MASK_EXP_OR_Q or MASK_TYPE_BOOL
  const MASK_SIG_ATOM    = MASK_EXP_OR_Q or MASK_TYPE_ATOM
  const MASK_SIG_STRING  = MASK_EXP_OR_Q or MASK_TYPE_STRING
  const MASK_SIG_BIGNUM  = MASK_EXP_OR_Q or MASK_TYPE_BIGNUM
  const MASK_SIG_ARRAY   = MASK_EXP_OR_Q or MASK_TYPE_ARRAY
  const MASK_SIG_SET     = MASK_EXP_OR_Q or MASK_TYPE_SET
  const MASK_SIG_MAP     = MASK_EXP_OR_Q or MASK_TYPE_MAP

  template is_float(head: int32): bool =
    return bitand(bitnot(head), MASK_EXPONENT) == 0
  template is_int(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_INT
  template is_nil(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_NIL
  template is_bool(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_BOOL
  template is_atom(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_ATOM
  template is_string(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_STRING
  template is_bignum(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_BIGNUM
  template is_array(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_ARRAY
  template is_set(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_SET
  template is_map(head: int32): bool =
    return bitand(head, MASK_SIGNATURE) == MASK_TYPE_MAP
  proc is_heap(head: int32): bool =
    return bitand(head, MASK_EXP_OR_Q) == MASK_HEAP
  
  template is_float(v: ImValue): bool =
    return v.head.is_float
  template is_int(v: ImValue): bool =
    return v.head.is_int
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

  proc get_kind(head: int32): ImValueKind =
    if bitand(bitnot(head), MASK_EXPONENT) != 0: return ImValueKind.Float64
    let signature = bitand(head, MASK_SIGNATURE)
    case signature:
      of MASK_TYPE_INT:    return ImValueKind.Int52
      of MASK_TYPE_NIL:    return ImValueKind.Nil
      of MASK_TYPE_BOOL:   return ImValueKind.Bool
      of MASK_TYPE_ATOM:   return ImValueKind.Atom
      of MASK_TYPE_STRING: return ImValueKind.String
      of MASK_TYPE_BIGNUM: return ImValueKind.BigNum
      of MASK_TYPE_ARRAY:  return ImValueKind.Array
      of MASK_TYPE_SET:    return ImValueKind.Set
      of MASK_TYPE_MAP:    return ImValueKind.Map
      else:
        discard
  
  method `==`(v1, v2: ImHeapPayloadRef): bool {.base.} =
    result = false
  method `==`(v1, v2: ImStringPayloadRef): bool =
    result = false
    if v1.hash == v2.hash:
      result = v1.data == v2.data
  method `==`(v1, v2: ImArrayPayloadRef): bool =
    result = false
    if v1.hash == v2.hash:
      result = v1.data == v2.data
  method `==`(v1, v2: ImMapPayloadRef): bool =
    result = false
    if v1.hash == v2.hash:
      result = v1.data == v2.data
  method `==`(v1, v2: ImSetPayloadRef): bool =
    result = false
    if v1.hash == v2.hash:
      result = v1.data == v2.data
  
  proc `==`*(v1, v2: ImValue): bool =
    result = false
    if v1.head == v2.head:
      result = v1.tail == v2.tail
  
  proc `==`*(v1, v2: ImFloat): bool =
    return cast[float64](v1) == cast[float64](v2)
  proc `==`*(v: ImValue, f: float64): bool =
    return cast[float64](v) == f
  proc `==`*(f: float64, v: ImValue): bool =
    return cast[float64](v) == f
  proc `==`*(v: ImFloat, f: float64): bool =
    return cast[float64](v) == f
  proc `==`*(f: float64, v: ImFloat): bool =
    return cast[float64](v) == f

  proc to_float*(v: ImFloat): float64 =
    return cast[float64](v)

  proc hash*(v: ImValue): Hash =
    if is_heap(v):
      # We cast to ImString so that we can get the hash, but all the ImHeapValues have a hash in the tail.
      let vh = cast[ImString](v)
      result = vh.tail.hash
    else:
      result = v.head
  
  proc update_head(previous_head: int32, full_hash: Hash): int32 =
    let short_hash = bitand(full_hash, MASK_SHORT_HASH)
    let truncated_head = bitand(previous_head, bitnot(MASK_SHORT_HASH))
    return bitor(truncated_head, short_hash.int32).int32

  proc init_float*(f: float64 = 0): ImFloat =
    var a: array[8,byte] = cast[array[8,byte]](f)
    echo "a: ", a
    echo "int: ", cast[array[4, byte]](1)
    echo "float: ", toHex(f.int64), " ", f
    return ImImmediateValue(head: (f.int64 shr 32).int32, tail: f.int32).ImFloat

  proc init_map*(): ImMap =
    var m = ImMap(head: MASK_SIG_MAP)
    return m

  proc `[]`*(m: ImMap, k: ImValue): ImValue =
    let nil_v = ImValue(head: MASK_SIG_NAN, tail: 0)
    return m.tail.data.getOrDefault(k, nil_v)

  proc `[]=`*(m: ImMap, k: ImValue, v: ImValue): ImMap =
    if m.tail.data[k] == v: return m
    var table_copy = m.tail.data
    table_copy[k] = v
    let k_hash = hash(k)
    let v_hash = hash(v)
    let entry_hash = (k_hash + v_hash).int32
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
  
  proc del*(m: ImMap, k: ImValue): ImMap =
    if not(k in m.tail.data): return m
    let v = m.tail.data[k]
    let k_hash = hash(k)
    let v_hash = hash(v)
    let entry_hash = (k_hash + v_hash).int32
    let new_m_map_hash = calc_hash(m.tail.hash, entry_hash)
    var table_copy = m.tail.data
    table_copy.del(k)
    let new_m_payload = ImMapPayloadRef(
      hash: new_m_map_hash,
      data: table_copy
    )
    let new_m = ImMap( 
      head: update_head(m.head, new_m_map_hash),
      tail: new_m_payload
    )
    return new_m

else:
  type
    ImValueKind* = enum
      # Immediate Kinds
      PlainNaN
      Nil
      Bool
      # Heap Kinds
      Number
      Atom
      # BigNum
      String
      Array
      Map
      Set
      UserDefined
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
      data*: Table[string, ImValue]
    ImSet* = object
      hash*: int32
      data*: HashSet[ImValue]

    ImStringRef* = ref ImString
    ImArrayRef* = ref ImArray
    ImMapRef* = ref ImMap
    ImSetRef* = ref ImSet

    ImValue* {.final, acyclic.} = object
      case kind*: ImValueKind:
        of PlainNaN, Nil, Bool:
          discard
        of Number:
          num*: ImNumberRef
        of Atom, String:
          str*: ImStringRef
        of Array:
          arr*: ImArrayRef
        of Map:
          map*: ImMapRef
        of Set:
          set*: ImSetRef
        of UserDefined:
          discard
    ImValueRef* = ref ImValue

  proc `==`(v1: ImValueRef, v2: ImValueRef): bool =
    if v1.kind == v2.kind:
      # if v1.tail.hash == v2.tail.hash:
      #   result = true
      discard
    else:
      result = false

proc do_thing(): void =
  var
    f1 = init_float()
    f2 = init_float()
  doAssert f1 == f2

do_thing()