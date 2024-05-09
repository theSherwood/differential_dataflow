const
  SHIFT_BITS = 5
  BRANCHING_FACTOR = 1 shl SHIFT_BITS

type
  PVNodeTag = enum
    PVNodeInternal
    PVNodeLeaf
  PVNode[T] = object
    case tag*: PVNodeTag:
      of PVNodeInternal:
        data*: array[BRANCHING_FACTOR, PVNodeRef]
      of PVNodeLeaf:
        data*: array[BRANCHING_FACTOR, T]
  PVNodeRef[T] = ref PVNode[T]
  PVector[T] = object
    hash*: Hash
    count*: Natural
    shift*: Natural
    root*: PVNode[T]
    tail*: PVNode[T]
  PVectorRef[T] = ref PVector[T]

proc tail_offset*[T](vec: PVectorRef[T]): Natural =
  if vec.count < BRANCHING_FACTOR: 0 else: ((vec.count - 1) shr 5) shl 5

proc get[T](node: PVectorNodeRef[T], idx: int): T =
  discard
proc get*[T](vec: PVectorRef[T], idx: int): T =
  let to = vec.tail_offset

proc add*[T](vec: PVectorRef[T], val: T): PVectorRef[T] =
  discard


