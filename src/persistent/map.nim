##[

https://github.com/paranim/parazoa/blob/master/src/parazoa.nim

I had to fix some bugs (when using int keys).
Though I'm pretty sure it's still broken as I don't think there's any handling
of hash collisions.

]##

import hashes
from math import `^`
from strutils import nil
import chunk
export chunk

const
  parazoaBits* {.intdefine.} = 5
  branchWidth = 1 shl parazoaBits
  mask = branchWidth - 1
  array_capacity = branchWdith shr 1

type
  NodeKind = enum
    Array,
    Interior,
  KeyError* = object of CatchableError
  IndexError* = object of CatchableError

func copyRef[T](thing: T): T =
  new result
  if thing != nil:
    result[] = thing[]

type
  HashedEntry[K, V] = object
    hash: Hash
    entry: tuple[key: K, value: V]
  HashedEntryRef[K, V] = ref HashedEntry[K, V]
  
  NodeListEntryKind = enum
    kEmpty    # If we implement HAMT, get rid of this
    kInterior
    kCollision
    kLeaf

  NodeListEntry = object
    case kind: NodeListEntryKind:
      of kEmpty:
        discard
      of kInterior:
        node: MapNodeRef[K, V]
      of kCollision:
        hashed_entries: seq[HashedEntry[K, V]]
      of kLeaf:
        hashed_entry: HashedEntryRef[K, V]

  MapNode*[K, V] = object
    case kind: NodeKind:
      of Array:
        entries: Chunk[array_capacity, HashedEntry[K, V]]
      of Interior:
        nodes: array[branchWidth, NodeListEntry[K, V]]
  MapNodeRef*[K, V] = ref MapNode[K, V]

  Map*[K, V] = object
    node: MapNode[K, V]
    hash: Hash
    size: Natural
  MapRef*[K, V] = ref Map[K, V]

template key*[K, V](h_entry_ref: HashedEntryRef[K, V]): K =
  h_entry_ref.entry.key
template value*[K, V](h_entry_ref: HashedEntryRef[K, V]): V =
  h_entry_ref.entry.value
template key*[K, V](h_entry_ref: HashedEntry[K, V]): K =
  h_entry.entry.key
template value*[K, V](h_entry_ref: HashedEntry[K, V]): V =
  h_entry.entry.value

template entry_hash*[K, V](h_entry: HashedEntryRef[K, V]): Hash =
  h_entry.hash + hash(h_entry.value)
template entry_hash*[K, V](h_entry: HashedEntry[K, V]): Hash =
  h_entry.hash + hash(h_entry.value)

func initMap*[K, V](): MapRef[K, V]  =
  ## Returns a new `Map`
  result.node = MapNode[K, V](kind: Array)

func len*[K, V](m: MapRef[K, V]): Natural =
  ## Returns the number of key-value pairs in the `Map`
  m.size

iterator hashed_entries*[K, V](m: MapRef[K, V]): HashedEntry[K, V] =
  ## Iterates over the hash-key-value triples in the `Map`
  if m.node.kind == Array:
    for h_entry in m.node.entries:
      yield h_entry
  else:
    var
      node = ref n.node
      node_list_entry: NodeListEntry
      stack: seq[tuple[parent: MapNodeRef[K, V], index: int]] = @[(node, 0)]
    while stack.len > 0:
      let (parent, index) = stack[stack.len-1]
      if index == parent.nodes.len:
        discard stack.pop()
        if stack.len > 0:
          stack[stack.len-1].index += 1
      else:
        node_list_entry = parent.nodes[index]
        case node_list_entry.kind:
          of kEmpty:
            stack[stack.len-1].index += 1
          of kLeaf:
            yield node_list_entry.hash_entry[]
            stack[stack.len-1].index += 1
          of kCollision:
            for h_entry in node_list_entry.hashed_entries:
              yield h_entry
            stack[stack.len-1].index += 1
          of kInterior:
            stack.add((node_list_entry.node, 0))

iterator pairs*[K, V](m: MapRef[K, V]): (K, V) =
  ## Iterates over the key-value entries in the `Map`
  for h_entry in m.hashed_entries:
    yield h_entry.entry
iterator keys*[K, V](m: MapRef[K, V]): K =
  ## Iterates over the keys in the `Map`
  for h_entry in m.hashed_entries:
    yield h_entry.key
iterator values*[K, V](m: MapRef[K, V]): V =
  ## Iterates over the values in the `Map`
  for h_entry in m.hashed_entries:
    yield h_entry.value
iterator items*[K, V](m: MapRef[K, V]): V =
  ## Iterates over the values in the `Map`
  for h_entry in m.hashed_entries:
    yield h_entry.value

func shadow*[K, V](
    stack: seq[tuple[parent: MapNodeRef[K, V], index: int]],
    node_list_entry: NodeListEntry[K, V]
  ): MapNodeRef[K, V] =
  var
    parent: MapNodeRef[K, V]
    p_copy: MapNodeRef[K, V]
    idx: int
    n_l_entry = node_list_entry
  for i in countdown(stack.len - 1, 0):
    (parent, idx) = stack[i]
    p_copy = cloneRef(parent)
    p_copy.nodes[i] = n_l_entry
    n_l_entry = NodeListEntry(
      kind: kInterior,
      node: p_copy
    )
  return p_copy

template mut_add_to_interior_map[K, V](m: MapRef[K, V], h_entry: HashedEntry[K, V]): untyped =
  var
    h = h_entry.hash
    bits = 0
    parent = ref m.node
    index = (h shr bits) and mask
    node_list_entry: NodeListEntry[K, V]
  m.size += 1
  m.hash = m.hash xor entry_hash(h_entry)
  block outer:
    while true:
      node_list_entry = parent.nodes[index]
      case node_list_entry.kind:
        of kEmpty:
          parent.nodes[index] = NodeListEntry(
            kind: kLeaf
            hashed_entry: ref h_entry
          )
          break outer
        of kLeaf:
          let existing_entry = node_list_entry.hashed_entry
          if h_entry.hash == existing_entry.hash:
            # we have a hash collision
            if h_entry.key == existing_entry.key:
              m.hash = m.hash xor entry_hash(h_entry)
              m.size -= 1
              if h_entry.value == existing_entry.value:
                # bail early because we have an exact match
                break outer
              else:
                # overwrite the existing entry
                parent.nodes[index] = NodeListEntry(kind: kLeaf, hashed_entry: h_entry)
                break outer
            else:
              parent.nodes[index] = NodeListEntry(
                kind: kCollision,
                hashed_entries: @[h_entry, existing_entry[]]
                hashed_entry: h_entry
              )
              break outer
          else:
            # we have to expand to an Interior node because our leaf was a shortcut
            # and we don't create collisions at shortcuts
            bits += parazoaBits
            var
              new_node = new MapNode[K, V](kind: Interior)
              curr_node = new_node
              new_idx_for_h_entry = (h shr bits) and mask
              new_idx_for_existing_entry = (existing_entry.hash shr bits) and mask
            block inner:
              while true:
                if new_idx_for_h_entry == new_idx_for_existing_entry:
                  if bits < branch_width:
                    # keep building deeper
                    var new_node = new MapNode[K, V](kind: Interior)
                    curr_node.nodes[new_idx_for_h_entry] = NodeListEntry(kind: kInterior, node: new_node)
                    curr_node = new_node
                    bits += parazoaBits
                    new_idx_for_h_entry = (h shr bits) and mask
                    new_idx_for_existing_entry = (existing_entry.hash shr bits) and mask
                  else:
                    # build collision
                    curr_node.nodes[new_idx_for_h_entry] = NodeListEntry(
                      kind: kCollision,
                      hashed_entries: @[h_entry, existing_entry[]]
                    )
                    break inner
                else:
                  curr_node.nodes[new_idx_for_h_entry] = NodeListEntry(
                    kind: kLeaf,
                    hashed_entry: ref h_entry
                  )
                  curr_node.nodes[new_idx_for_existing_entry] = NodeListEntry(
                    kind: kLeaf,
                    hashed_entry: existing_entry
                  )
                  break inner
            parent.nodes[index] = NodeListEntry(kind: kInterior, node: new_node)
            break outer
        of kCollision:
          var new_entries = @[h_entry]
          for e in node_list_entry.hashed_entries:
            if e.key == h_entry.key:
              m.hash = m.hash xor entry_hash(e)
              m.size -= 1
              if e.value == h_entry.value:
                break outer
            else:
              new_entries.add(e.key)
          parent.nodes[index] = NodeListEntry(
            kind: kCollision,
            hashed_entries: new_entries
          )
          break outer
        of kInterior:
          parent = node_list_entry.node
          bits += parazoaBits
          index = (h shr bits) and mask

func to_interior_map[K, V](entries: openArray[HashedEntry[K, V]]): MapRef[K, V] =
  result.node = MapNode[K, V](kind: Interior)
  for e in entries:
    mut_add_to_interior_map(result, e)
func to_interior_map[K, V](m: MapRef[K, V]): MapRef[K, V] =
  result.node = MapNode[K, V](kind: Interior)
  for e in m.hashed_entries:
    mut_add_to_interior_map(result, e)

template add_to_array_map*[K, V](m: MapRef[K, V], h_entry: HashedEntry[K, V]): untyped  =
  result.node = MapNode[K, V](kind: Array)
  result.hash = m.hash xor entry_hash(h_entry)
  result.node.entries.add(h_entry)
  for e in m.hashed_entries:
    if e.hash == h_entry.hash && e.key == h_entry.key:
      if e.value == h_entry.value:
        # bail because the entry is an exact copy of an existing entry
        return m
      # matching key, so we remove it from the hash
      result.hash = result.hash xor entry_hash(e)
    else:
      result.node.entries.add(e)
  result.size = result.node.entries.len

func add*[K, V](m: MapRef[K, V], h_entry: HashedEntry[K, V]): MapRef[K, V]  =
  if m.size < array_capacity:
    add_to_array_map[K, V](m, h_entry)
  elif m.kind == Array:
    # We have an array but are at the size limit
    if m.contains(h_entry.hash, h_entry.key):
      add_to_array_map[K, V](m, h_entry)
    else:
      result = to_interior_map(m)
      result.add(h_entry)
  elif m.kind == Interior:
    result = m.copyRef
    result.hash = m.hash xor entry_hash(h_entry)
    result.size = m.size + 1
    var
      h = h_entry.hash
      bits = 0
      stack: seq[tuple[parent: MapNodeRef[K, V], index: int]] = @[(ref map.node, (h shr bits) and mask)]
    while true:
      var
        (parent, index) = stack[stack.len - 1]
        node_list_entry = parent.nodes[index]
      case node_list_entry.kind:
        of kEmpty:
          result.node = shadow(stack, NodeListEntry(
            kind: kLeaf
            hashed_entry: ref h_entry
          ))
          return result
        of kLeaf:
          let existing_entry = node_list_entry.hashed_entry
          if h_entry.hash == existing_entry.hash:
            # we have a hash collision
            if h_entry.key == existing_entry.key:
              if h_entry.value == existing_entry.value:
                # bail early because we have an exact match
                return m
              else:
                # overwrite the existing entry
                result.node = shadow(stack, NodeListEntry(kind: kLeaf, hashed_entry: h_entry))
                result.hash = result.hash xor entry_hash(existing_entry)
                result.size -= 1
                return result
            else:
              result.node = shadow(stack, NodeListEntry(
                kind: kCollision,
                hashed_entries: @[h_entry, existing_entry[]]
              ))
              return result
          else:
            # we have to expand to an Interior node because our leaf was a shortcut
            # and we don't create collisions at shortcuts
            bits += parazoaBits
            var
              new_node = new MapNode[K, V](kind: Interior)
              curr_node = new_node
              new_idx_for_h_entry = (h shr bits) and mask
              new_idx_for_existing_entry = (existing_entry.hash shr bits) and mask
            while true:
              if new_idx_for_h_entry == new_idx_for_existing_entry:
                if bits < branch_width:
                  # keep building deeper
                  var new_node = new MapNode[K, V](kind: Interior)
                  curr_node.nodes[new_idx_for_h_entry] = NodeListEntry(kind: kInterior, node: new_node)
                  curr_node = new_node
                  bits += parazoaBits
                  new_idx_for_h_entry = (h shr bits) and mask
                  new_idx_for_existing_entry = (existing_entry.hash shr bits) and mask
                else:
                  # build collision
                  curr_node.nodes[new_idx_for_h_entry] = NodeListEntry(
                    kind: kCollision,
                    hashed_entries: @[h_entry, existing_entry[]]
                  )
                  break
              else:
                curr_node.nodes[new_idx_for_h_entry] = NodeListEntry(
                  kind: kLeaf,
                  hashed_entry: ref h_entry
                )
                curr_node.nodes[new_idx_for_existing_entry] = NodeListEntry(
                  kind: kLeaf,
                  hashed_entry: existing_entry
                )
                break
            result.node = shadow(stack, NodeListEntry(kind: kInterior, node: new_node))
            return result
        of kCollision:
          var new_entries = @[h_entry]
          for e in node_list_entry.hashed_entries:
            if e.key == h_entry.key:
              result.hash = result.hash xor entry_hash(e)
              result.size -= 1
              if e.value == h_entry.value:
                break outer
            else:
              new_entries.add(e.key)
          result.node = shadow(stack, NodeListEntry(
            kind: kCollision
            hashed_entries: new_entries
          ))
          return result
        of kInterior:
          bits += parazoaBits
          stack.add((node_list_entry.node, (h shr bits) and mask))
template add*[K, V](m: MapRef[K, V], key: K, value: V): MapRef[K, V] =
  add(m, HashedEntry(hash(key), (key, value)))
template add*[K, V](m: MapRef[K, V], entry: (K, V)): MapRef[K, V] =
  add(m, HashedEntry(hash(entry[0]), entry))
template add*[K, V](m: MapRef[K, V], h: Hash, key: K, value: V): MapRef[K, V] =
  add(m, HashedEntry(h, (key, value)))
template add*[K, V](m: MapRef[K, V], h: Hash, entry: (K, V)): MapRef[K, V] =
  add(m, HashedEntry(h, entry))

func del[K, V](res: var MapRef[K, V], node: MapNode[K, V], level: int, keyHash: Hash)  =
  let
    index = (keyHash shr level) and mask
    child = node.nodes[index]
  if child == nil:
    discard
  else:
    case child.kind:
    of Branch:
      let newChild = copyRef(child)
      node.nodes[index] = newChild
      del(res, newChild, level + parazoaBits, keyHash)
    of Leaf:
      if child.keyHash == keyHash:
        node.nodes[index] = nil
        res.size -= 1

func del_by_hash[K, V](m: MapRef[K, V], keyHash: Hash): MapRef[K, V]  =
  var res = m
  res.root = copyRef(m.root)
  del(res, res.root, 0, keyHash)
  res

func del*[K, V](m: MapRef[K, V], key: K): MapRef[K, V] =
  ## Deletes the key-value pair at `key` from the `Map`
  del_by_hash(m, hash(key))

template get_impl*[K, V](m: MapRef[K, V], h: Hash, key: K, SUCCESS, FAILURE: untyped): untyped =
  if map.node.kind == Array:
    for h_entry in map.node.entries:
      if h_entry.hash == h and h_entry.entry.key == key:
        SUCCESS
    FAILURE
  else:
    var
      bits = 0
      node = ref map.node
    while true:
      var
        index = (h shr bits) and mask
        node_list_entry = node.nodes[index]
      case node_list_entry.kind:
        of kEmpty: discard
        of kLeaf:
          let h_entry = node_list_entry.hashed_entry
          if h_entry.hash == h and h_entry.entry.key == key:
            SUCCESS
          break
        of kCollision:
          for h_entry in node_list_entry.hashed_entries:
            if h_entry.hash == h and h_entry.entry.key == key:
              SUCCESS
          break
        of kInterior:
          node = node_list_entry.node
          bits += parazoaBits
    FAILURE

template get_success(): untyped =
  return h_entry.entry.value
template get_failure(): untyped =
  raise newException(KeyError, "Key not found")
func get*[K, V](m: MapRef[K, V], key: K): V =
  let h = hash(key)
  get_impl[K, V](m, h, key, get_success, get_failure)
template `[]`*[K, V](m: MapRef[K, V], key: K): V = m.get(k)
func get*[K, V](m: MapRef[K, V], h: Hash, key: K): V =
  get_impl[K, V](m, h, key, get_success, get_failure)

template get_or_default_failure(): untyped =
  return default(V)
func get_or_default*[K, V](m: MapRef[K, V], key: K): V =
  let h = hash(key)
  get_impl[K, V](m, h, key, get_success, get_or_default_failure)
func get_or_default*[K, V](m: MapRef[K, V], h: Hash, key: K): V =
  get_impl[K, V](m, h, key, get_success, get_or_default_failure)

template contains_success(): untyped =
  return true
template contains_failure(): untyped =
  return false
func contains*[K, V](m: MapRef[K, V], key: K): bool =
  let h = hash(key)
  get_impl[K, V](m, h, key, contains_success, contains_failure)
func contains*[K, V](m: MapRef[K, V], h: Hash, key: K): bool =
  get_impl[K, V](m, h, key, contains_success, contains_failure)

proc `==`*[K, V](m1: MapRef[K, V], m2: MapRef[K, V]): bool  =
  ## Returns whether the `Map`s are equal
  if m1.len != m2.len: return false
  if m1.hash != m2.hash: return false
  else:
    for (k, v) in m1.pairs:
      try:
        if m2.get(k) != v:
          return false
      except:
        return false
    return true

func toMap*[K, V](arr: openArray[(K, V)]): Map[K, V] =
  ## Returns a `Map` containing the key-value pairs in `arr`
  var m = initMap[K, V]()
  for (k, v) in arr:
    m = m.add(k, v)
  m

func `$`*[K, V](m: MapRef[K, V]): string =
  ## Returns a string representing the `Map`
  var x = newSeq[string]()
  for (k, v) in m.pairs:
    x.add($k & ": " & $v)
  "{" & strutils.join(x, ", ") & "}"

func hash*[K, V](m: MapRef[K, V]): Hash  =
  return m.hash

func `&`*[K, V](m1: MapRef[K, V], m2: MapRef[K, V]): MapRef[K, V] =
  ## Returns a merge of the `Map`s
  var res = m1
  for (k, v) in m2.pairs:
    res = res.add(k, v)
  res
