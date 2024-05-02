import std/[strformat, sequtils]

func copyRef[T](node: T): T =
  new result
  if node != nil:
    result[] = node[]

const
  BRANCH_WIDTH = 32
  BUFFER_WIDTH = 64

type
  KeyError* = object of CatchableError
  IndexError* = object of CatchableError

  Summary[Data] = concept x, y, type T
    x + y is T
    x - y is T
    T.zero is T
    T.fromm(b: Natural, i: Natural) is T
  STBuffer[Data] = array[BUFFER_WIDTH, Data]
  STBufferRef[Data] = ref STBuffer[Data]
  STNodeKind* = enum
    STInterior
    STLeaf
  SumTree*[Data, Summ] = object
    # total count of Data items in the tree
    size*: Natural
    summary*: Summ
    case kind*: STNodeKind
    of STInterior:
      depth*: uint8
      nodes_count*: Natural
      nodes: array[BRANCH_WIDTH, SumTreeRef[Data, Summ]]
    of STLeaf:
      data_count*: Natural
      data: STBuffer[Data]
  SumTreeRef*[Data, Summ] = ref SumTree[Data, Summ]

proc `$`*[D, S](s: SumTreeRef[D, S]): string =
  result.add(&"ST(\n")
  result.add(&"  size: {s.size}\n")
  result.add(&"  summary: TODO\n")
  result.add(&"  kind: {s.kind}\n")
  result.add(&")")

proc clone*[D, S](s: SumTreeRef[D, S]): SumTreeRef[D, S] =
  result = SumTreeRef[D, S]()
  result.size = s.size
  result.kind = s.kind
  result.summary = s.summary
  if result.kind == STLeaf:
    result.data_count = s.data_count
    result.data = s.data
  else:
    result.depth = s.depth
    result.nodes_count = s.nodes_count
    result.nodes = s.nodes

proc get*[D, S](s: SumTreeRef[D, S], idx: int): D =
  if idx < 0 or idx > s.size:
    raise newException(IndexError, "Index is out of bounds")
  if s.kind == STLeaf:
    return s.data[idx]
  else:
    var adj_idx = idx
    var n = s
    block outer:
      while n.kind == STInterior:
        var candidate: SumTreeRef[D, S]
        block inner:
          for i in 0..<n.nodes_count:
            candidate = n.nodes[i]
            if adj_idx > candidate.size:
              adj_idx = adj_idx - candidate.size
            else:
              n = candidate
              break inner
    return n.data[adj_idx]

const
  VEC_BITS = 5
  VEC_BRANCHING_FACTOR = 1 shl VEC_BITS

type
  PVecSummary[T] = object
    size*: uint

proc `+`*[T](s1, s2: PVecSummary[T]): PVecSummary[T] =
  result.size = s1.size + s2.size
proc `-`*[T](s1, s2: PVecSummary[T]): PVecSummary[T] =
  result.size = s1.size - s2.size
proc zero*[T](t: typedesc[PVecSummary[T]]): PVecSummary[T] =
  result.size = 0
proc fromm*[T](t: typedesc[PVecSummary[T]], data_buf: Natural, l: Natural): PVecSummary[T] =
  result.size = l.uint
# proc fromm*[T](data_buf: ptr T, l: Natural): PVecSummary[T] =
#   result.size = l

type
  PVec*[T] = SumTree[T, PVecSummary[T]]
  PVecRef*[T] = SumTreeRef[T, PVecSummary[T]]

## Does not change the Node kind
proc reset*[D, S](s: SumTreeRef[D, S]) =
  s.summary = S.zero()
  s.size = 0
  if s.kind == STInterior:
    s.depth = 0
    s.nodes_count = 0
    s.nodes = array[BRANCH_WIDTH, D]
  else:
    s.data_count = 0
    s.data = array[BUFFER_WIDTH, D]

proc resummarize*[D, S](s: SumTreeRef[D, S]) =
  if s.kind == STInterior:
    s.summary = S.zero()
    for i in 0..<s.nodes_count:
      s.summary = s.summary + s.nodes[i].summary
  else:
    var arr: array[5, D]
    s.summary = S.fromm(10, s.data_count)

template mut_append_case_1*[D, S](s: SumTreeRef[D, S], d: D) =
  ## The node is a leaf and there's room in the data
  s.data[s.data_count] = d
  s.data_count += 1
  s.size += 1
  s.summary = S.fromm(10, s.data_count)

proc init_sumtree*[D, S](d: D): SumTreeRef[D, S] =
  var s = SumTreeRef[D, S](kind: STLeaf)
  s.mut_append_case_1(d)
  return s
proc init_sumtree*[D, S](kind: STNodeKind): SumTreeRef[D, S] =
  var s = SumTreeRef[D, S](kind: kind)
  s.summary = S.zero()
  return s
template init_sumtree*[D, S](): SumTreeRef[D, S] = init_sumtree(STLeaf)

proc mut_append_case_2*[D, S](s, child: SumTreeRef[D, S]) =
  ## The node is an interior with room for a new child
  s.nodes[s.nodes_count] = child
  s.nodes_count += 1
  s.size += 1
  s.summary = s.summary + child.summary
  if s.depth <= child.depth:
    s.depth = child.depth + 1

template mut_pop_case_1*[D, S](s: SumTreeRef[D, S]) =
  ## The node is a leaf
  s.data_count -= 1
  s.data[s.data_count] = default(D)
  s.size -= 1
  s.summary = S.fromm(10, s.data_count)

proc mut_pop_case_2*[D, S](s, child: SumTreeRef[D, S]) =
  ## The node is an interior
  s.nodes_count -= 1
  let child = s.nodes[s.nodes_count]
  s.nodes[s.nodes_count] = default(D)
  s.size -= 1
  s.summary = s.summary - child.summary
  var depth = 0
  for i in 0..<s.nodes_count:
    depth = max(s.nodes[i].depth, depth)
  s.depth = depth + 1

proc mut_append*[D, S](s: SumTreeRef[D, S], d: D) =
  var n = s
  var stack: seq[SumTreeRef]
  while n.kind == STInterior:
    if n.nodes_count == 0:
      # The node is being used to express a gap (sparse arr).
      # So we have to backtrack and add a child to the parent.
      n = stack.pop()
      while n.nodes_count == BRANCH_WIDTH:
        n = stack.pop()
        if n.isNil:
          # There is no more room at the end of any of the SumTrees
          let s_clone = s.clone()
          var new_st = init_sumtree(d)
          s.reset()
          s.mut_append_case_2(s_clone)
          s.mut_append_case_2(new_st)
          return
      # Add a child
      var new_st = init_sumtree(d)
      n.nodes[n.nodes_count] = new_st
      n.nodes_count += 1
      # Walk up what's left of the stack to increase the size and fix summaries
      while n.isNil.not:
        n.size += 1
        n.resummarize()
        n = stack.pop()
      return
    stack.add(n)
    n = n.nodes[n.nodes_count - 1]
  if n.data_count < BUFFER_WIDTH:
    n.mut_append_case_1(d)
  else:
    let s_clone = s.clone()
    var new_st = init_sumtree(d)
    s.reset()
    s.kind = STInterior
    s.mut_append_case_2(s_clone)
    s.mut_append_case_2(new_st)

template mut_prepend_case_1*[D, S](s: SumTreeRef[D, S], d: D) =
  ## The node is a leaf and there's room in the data
  for i in countdown(s.data_count, 1):
    s.data[i] = s.data[i - 1]
  s.data[0] = d
  s.data_count += 1
  s.size += 1
  s.summary = S.fromm(10, s.data_count)

proc mut_prepend_case_2*[D, S](s, child: SumTreeRef[D, S]) =
  ## The node is an interior with room for a new child
  for i in countdown(s.nodes_count, 1):
    s.nodes[i] = s.nodes[i - 1]
  s.nodes_count += 1
  s.size += 1
  s.summary = s.summary + child.summary
  if s.depth <= child.depth:
    s.depth = child.depth + 1

proc im_append_case_1*[D, S](s: SumTreeRef[D, S], d: D): SumTreeRef[D, S] =
  ## The node is a leaf and there's room in the data
  var new_st = s.clone
  new_st.mut_append_case_1(d)
  return new_st

proc im_append_case_2*[D, S](s: SumTreeRef[D, S], d: D): SumTreeRef[D, S] =
  ## The node is a leaf and there's room in the data
  var new_st = init_sumtree[D, S](STInterior)
  var new_leaf = init_sumtree[D, S](d)
  new_st.mut_append_case_2(s)
  new_st.mut_append_case_2(new_leaf)
  return new_st

proc im_append*[D, S](s: SumTreeRef[D, S], d: D): SumTreeRef[D, S] =
  var
    n = s
    stack: seq[SumTreeRef[D, S]]
  while n.kind == STInterior:
    if n.nodes_count == 0:
      # The node is being used to express a gap (sparse arr).
      # So we have to backtrack and add a child to the parent.
      n = stack.pop()
      while n.nodes_count == BRANCH_WIDTH:
        n = stack.pop()
        if n.isNil:
          # There is no more room at the end of any of the SumTrees
          var new_st = init_sumtree[D, S](STInterior)
          var new_leaf = init_sumtree[D, S](d)
          new_st.mut_append_case_2(s)
          new_st.mut_append_case_2(new_leaf)
          return new_st
      # Add a child
      var new_child = init_sumtree[D, S](d)
      # Walk up what's left of the stack to increase the size and fix summaries
      while n.isNil.not:
        var n_clone = n.clone()
        n_clone.nodes[n.nodes_count - 1] = new_child
        n_clone.size += 1
        n_clone.resummarize()
        new_child = n_clone
        n = stack.pop()
      return new_child
    stack.add(n)
    n = n.nodes[n.nodes_count - 1]
  var new_child: SumTreeRef[D, S]
  if n.data_count < BUFFER_WIDTH:
    new_child = n.im_append_case_1(d)
  else:
    new_child = n.im_append_case_2(d)
  if stack.len > 0:
    n = stack.pop()
  # Walk up what's left of the stack to increase the size and fix summaries
  while stack.len > 0:
    var n_clone = n.clone()
    n_clone.nodes[n.nodes_count - 1] = new_child
    n_clone.size += 1
    n_clone.resummarize()
    new_child = n_clone
    n = stack.pop()
  return new_child

proc im_prepend_case_1*[D, S](s: SumTreeRef[D, S], d: D): SumTreeRef[D, S] =
  ## The node is a leaf and there's room in the data
  var new_st = s.clone
  new_st.mut_prepend_case_1(d)
  return new_st

proc im_prepend_case_2*[D, S](s: SumTreeRef[D, S], d: D): SumTreeRef[D, S] =
  ## The node is a leaf and there's room in the data
  var new_st = init_sumtree[D, S](STInterior)
  var new_leaf = init_sumtree[D, S](d)
  new_st.mut_prepend_case_2(s)
  new_st.mut_prepend_case_2(new_leaf)
  return new_st

proc im_prepend*[D, S](s: SumTreeRef[D, S], d: D): SumTreeRef[D, S] =
  var
    n = s
    stack: seq[SumTreeRef[D, S]]
  while n.kind == STInterior:
    if n.nodes_count == 0:
      # The node is being used to express a gap (sparse arr).
      # So we have to backtrack and add a child to the parent.
      n = stack.pop()
      while n.nodes_count == BRANCH_WIDTH:
        n = stack.pop()
        if n.isNil:
          # There is no more room at the end of any of the SumTrees
          var new_st = init_sumtree[D, S](STInterior)
          var new_leaf = init_sumtree[D, S](d)
          new_st.mut_prepend_case_2(s)
          new_st.mut_prepend_case_2(new_leaf)
          return new_st
      # Add a child
      var new_child = init_sumtree[D, S](d)
      # Walk up what's left of the stack to increase the size and fix summaries
      while n.isNil.not:
        var n_clone = n.clone()
        n_clone.nodes[n.nodes_count - 1] = new_child
        n_clone.size += 1
        n_clone.resummarize()
        new_child = n_clone
        n = stack.pop()
      return new_child
    stack.add(n)
    n = n.nodes[n.nodes_count - 1]
  var new_child: SumTreeRef[D, S]
  if n.data_count < BUFFER_WIDTH:
    new_child = n.im_prepend_case_1(d)
  else:
    new_child = n.im_prepend_case_2(d)
  if stack.len > 0:
    n = stack.pop()
  # Walk up what's left of the stack to increase the size and fix summaries
  while stack.len > 0:
    var n_clone = n.clone()
    n_clone.nodes[n.nodes_count - 1] = new_child
    n_clone.size += 1
    n_clone.resummarize()
    new_child = n_clone
    n = stack.pop()
  return new_child

template iterate_pairs*[D, S](s: SumTreeRef[D, S]) {.dirty.} =
  var
    n = s
    idx: Natural
    total_idx: Natural = 0
    n_stack: seq[SumTreeRef[D, S]]
    idx_stack: seq[Natural]
  if s.kind == STLeaf:
    for i in 0..<s.data_count:
      yield (total_idx, s.data[i])
      total_idx += 1
  else:
    n_stack.add(s)
    # We push an extra idx onto the stack because we are going to be fiddling
    # with the top of the idx_stack after popping. This gives us a little 
    # cushion when the n_stack is empty before the while loop ends.
    idx_stack.add(0)
    idx_stack.add(0)
    while n_stack.len > 0:
      n = n_stack[^1]
      idx = idx_stack[^1]
      if n.kind == STLeaf:
        for i in 0..<n.data_count:
          yield (total_idx, n.data[i])
          total_idx += 1
        discard n_stack.pop()
        discard idx_stack.pop()
        idx_stack[^1] += 1
      else:
        if n.nodes_count == 0:
          # The node is empty but is being used to indicate a sparse section in the arr
          for i in 0..<n.size:
            yield (total_idx, default(D))
            total_idx += 1
          idx_stack[^1] += 1
        elif idx < n.nodes_count - 1:
          # We haven't reached the end of the node's children
          n_stack.add(n.nodes[idx])
          idx_stack.add(0)
        else:
          # We reached the end of the node's children
          discard n_stack.pop()
          discard idx_stack.pop()
          idx_stack[^1] += 1

iterator pairs*[D, S](s: SumTreeRef[D, S]): (int, D) =
  iterate_pairs(s)
iterator items*[D, S](s: SumTreeRef[D, S]): D =
  for (idx, d) in s.pairs:
    yield d
proc pairs_closure[D, S](s: SumTreeRef[D, S]): iterator(): (int, D) =
  return iterator(): (int, D) =
    iterate_pairs(s)

template len*[D, S](s: SumTreeRef[D, S]): Natural = s.size

proc `==`*[D](v1, v2: PVecRef[D]): bool =
  if v1.size != v2.size: return false
  var
    t1 = v1.pairs_closure()
    t2 = v2.pairs_closure()
    fin: bool
  while true:
    fin = finished(t1)
    if fin != finished(t2): return false
    if t1() != t2(): return false
    if fin: return true
  
template init_vec*[T](): PVecRef[T] = init_sumtree[T, PVecSummary[T]](STLeaf)

template append*[T](vec: PVecRef[T], item: T): PVecRef[T] = vec.im_append(item)
template push*[T](vec: PVecRef[T], item: T): PVecRef[T] = vec.im_append(item)

template prepend*[T](vec: PVecRef[T], item: T): PVecRef[T] = vec.im_prepend(item)
template push_front*[T](vec: PVecRef[T], item: T): PVecRef[T] = vec.im_prepend(item)
