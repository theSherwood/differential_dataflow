import std/[tables, sets]

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
const tagged_union = false

when NaN_boxing:
  type
    ImValueKind* = enum
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
    ImValue* {.final, acyclic.} = object
      head*: uint32
      tail*: uint32
    ImHeapPayloadRef* = ref object of RootObj
    ImStringPayloadRef* = ref ImStringPayloadRef
      hash: int32
      str: string
    ImArrayPayloadRef* = ref ImHeapPayloadRef
      hash: int32
      arr: seq[ImValue]
    ImMapPayloadRef* = ref ImHeapPayloadRef
      hash: int32
      map: Table[ImValue, ImValue]
    ImSetPayloadRef* = ref ImHeapPayloadRef
      hash: int32
      set: HashSet[ImValue]
    ImHeapValue* = object
      head*: uint32
      tail*: ImHeapPayloadRef
    ImValueRef* = ref ImValue
  
  method `==`(v1, v2: ImHeapPayloadRef): bool {.base.} =
    return false

  # method `==`(v1, v2: ImStringPayloadRef): bool =
  #   result = false
  #   if v1.hash == v2.hash:
  #     result = v1.str == v2.str
  
  proc `==`(v1, v2: ImValueRef): bool =
    result = false
    if v1.head == v2.head:
      result = true

  # TODO
  const mask_heap: uint32 = 0b11111111111110000000000000000000'u32
  const mask_plain_NaN: uint32 = 0b01111111111110000000000000000000'u32
  proc is_map(v: ImValue): bool =
    return v.head == mask_heap
  # const mask_NaN = 0b
  proc kind_from_value(v: ImValue): ImValueKind =
    discard
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