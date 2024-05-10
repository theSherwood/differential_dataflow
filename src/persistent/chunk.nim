type
  Chunk[Count: static int, T] = object
    len: uint32
    data: array[Count, T]
  ChunkRef[Count: static int, T] = ref Chunk[Count, T]

proc clone*[Count, T](c: Chunk[Count, T]): Chunk[Count, T] =
  result = c

template is_empty*[Count, T](c: var Chunk[Count, T]): bool = c.len == 0
template is_full*[Count, T](c: var Chunk[Count, T]): bool = c.len == Count

# Assume the caller has done the bounds checks
template set_unsafe*[Count, T](c: var Chunk[Count, T], i: int, v: T) = c.data[i] = v
template get_unsafe*[Count, T](c: var Chunk[Count, T], i: int): T = c.data[i]
template add_unsafe*[Count, T](c: var Chunk[Count, T], v: T) =
  c.data[c.len] = v
  c.len += 1

proc get*[Count, T](c: Chunk[Count, T], i: int): T =
  if i < 0 or not(i < c.len):
    raise newException(IndexError, "Index is out of bounds")
  return c.data[i]
template `[]`*[Count, T](c: Chunk[Count, T], i: int): T = c.get(i)
template set*[Count, T](c: var Chunk[Count, T], i: int, v: T) =
  if i < 0 or not(i < c.len):
    raise newException(IndexError, "Index is out of bounds")
  c.data[i] = v
template `[]=`*[Count, T](c: var Chunk[Count, T], i: int, v: T) = c.set(i, v)
template add*[Count, T](c: var Chunk[Count, T], v: T) =
  if c.len == Count:
    raise newException(IndexError, "Chunk is full")
  c.data[c.len] = v
  c.len += 1
template add*[Count, T](c: var Chunk[Count, T], items: openArray[T]) =
  if c.len + items.len >= Count:
    raise newException(IndexError, "Chunk is full")
  for i in 0..<items.len:
    c.data[c.len + i] = items[i]
  c.len += items.len


proc getOrDefault*[Count, T](c: Chunk[Count, T], i: int, d: T): T =
  if i < 0 or not(i < len): return d
  return c.data[i]
template getOrDefault*[Count, T](c: Chunk[Count, T], i: int): T = c.getOrDefault(i, default(T))

template pop_multiple*[Count, T](c: var Chunk[Count, T], n: int) =
  c.len = max(0, c.len - n)
template pop*[Count, T](c: var Chunk[Count, T]) =
  c.pop_multiple(0)

proc get_run*[Count, T](c: Chunk[Count, T], idx: int, length: int): Chunk[Count, T] =
  var
    len = 0
    target = min(idx + length, c.len)
  while idx + len < target:
    result.data[len] = c.data[idx + len]
    len += 1
  result.len = len
# TODO - add support for negative indices
template get_slice*[Count, T](c: Chunk[Count, T], idx1: int, idx2: int): Chunk[Count, T] =
  c.get_run(idx1, max(0, idx2 - idx1))

template delete_run*[Count, T](c: var Chunk[Count, T], idx: int, length: int) =
  if idx + length < c.len:
    var
      run2_idx = start + length
      offset = 0
      diff = c.len - run2_idx
    while offset < diff:
      c.data[i + offset] = c.data[run2_idx + offset]
      offset += 1
    c.len -= length
  else:
    c.len = idx
# TODO - add support for negative indices
template delete_slice*[Count, T](c: var Chunk[Count, T], idx1: int, idx2: int) =
  c.delete_run(idx1, max(0, idx2 - idx1))

# This is an in-place concat
# Returns the number of items from c2 that were added to c1
proc fill*[Count, T](c1: var Chunk[Count, T], c2: Chunk[Count, T]): int =
  var
    i = 0
    len = c1.len
    target = min(Count, c1.len + c2.len)
  while len + i < target:
    c1.data[len + i] = c2.data[i]
    i += 1
  c1.len = len + i
  return i
template concat_in_place*[Count, T](c1: var Chunk[Count, T], c2: Chunk[Count, T]): int =
  fill(c1, c2)

# Returns a pair: (the new chunk, the number of items from c2 that made it in)
proc concat*[Count, T](c1: Chunk[Count, T], c2: Chunk[Count, T]): (Chunk[Count, T], int) =
  var
    # make clone
    c = c1
    # fill remaining space with c2
    n = c.concat_in_place(c2)
  return (c, n)

proc insert*[Count, T](c: var Chunk[Count, T], idx: int, items: openArray[T]) =
  var len = items.len
  if len + c.len >= Count or idx < 0 or not(idx <= len):
    raise newException(IndexError, "Index is out of bounds")
  var offset = len - 1
  for i in countdown(c.len, idx):
    c.data[i + offset] = c.data[i - 1]
  for i in 0..<len:
    c.data[idx + i] = items[i]
  c.len += len
proc insert*[Count, T](c: var Chunk[Count, T], idx: int, t: T) =
  if c.len == Count or idx < 0 or not(idx <= c.len):
    raise newException(IndexError, "Index is out of bounds")
  for i in countdown(c.len, idx):
    c.data[i] = c.data[i - 1]
  c.data[idx] = t
  c.len += 1

proc reverse_in_place*[Count, T](c: var Chunk[Count, T]) =
  var
    idx1 = 0
    idx2 = c.len - 1
    tmp: T
  while idx1 < idx2:
    tmp = c.data[idx1]
    c.data[idx1] = c.data[idx2]
    c.data[idx2] = tmp
    idx1 += 1
    idx2 -= 1
proc to_reversed*[Count, T](c: Chunk[Count, T]): Chunk[Count, T] =
  var offset = c.len - 1
  for i in 0..<c.len:
    result[offset - i] = c.data[i]
  result.len = c.len

# Iterators #
# ---------------------------------------------------------------------

iterator items*[Count, T](c: Chunk[Count, T]): T =
  for i in 0..<c.len:
    yield c.data[i]
iterator mitems*[Count, T](c: var Chunk[Count, T]): var T =
  for i in 0..<c.len:
    yield c.data[i]

iterator pairs*[Count, T](c: Chunk[Count, T]): (int, T) =
  for i in 0..<c.len:
    yield (i, c.data[i])
iterator mpairs*[Count, T](c: var Chunk[Count, T]): (int, var T) =
  for i in 0..<c.len:
    yield (i, c.data[i])

iterator iter_run_items*[Count, T](c: Chunk[Count, T], idx: int, length: int): T =
  for i in idx..<min(c.len, idx + length):
    yield c.data[i]
iterator miter_run_items*[Count, T](c: var Chunk[Count, T], idx: int, length: int): var T =
  for i in idx..<min(c.len, idx + length):
    yield c.data[i]

iterator iter_run_pairs*[Count, T](c: Chunk[Count, T], idx: int, length: int): (int, T) =
  for i in idx..<min(c.len, idx + length):
    yield (i, c.data[i])
iterator miter_run_pairs*[Count, T](c: var Chunk[Count, T], idx: int, length: int): (int, var T) =
  for i in idx..<min(c.len, idx + length):
    yield (i, c.data[i])

# TODO - add support for negative indices
iterator iter_slice_items*[Count, T](c: Chunk[Count, T], idx1: int, idx2: int): T =
  for t in c.iter_run_items(idx1, max(0, idx2 - idx1)): yield t
iterator miter_slice_items*[Count, T](c: var Chunk[Count, T], idx1: int, idx2: int): var T =
  for t in c.miter_run_items(idx1, max(0, idx2 - idx1)): yield t

# TODO - add support for negative indices
iterator iter_slice_pairs*[Count, T](c: Chunk[Count, T], idx1: int, idx2: int): (int, T) =
  for pair in c.iter_run_pairs(idx1, max(0, idx2 - idx1)): yield pair
iterator miter_slice_pairs*[Count, T](c: var Chunk[Count, T], idx1: int, idx2: int): (int, var T) =
  for pair in c.miter_run_pairs(idx1, max(0, idx2 - idx1)): yield pair
