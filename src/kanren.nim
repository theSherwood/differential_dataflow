##
## https://github.com/shd101wyy/logic.js/blob/master/lib/logic.js
## 

import macros
import values
export values

type
  Val* = ImValue

  Stream* = iterator(): Val
  StreamGen* = proc(x: Val): iterator(): Val {.closure.}
  SMapStream* = iterator(x: Val): Val {.closure.}

let dot* = V Sym "."

template is_lvar*(x: Val): bool = x.is_symbol and x != dot

proc walk(key, smap: Val): Val =
  if key.is_lvar:
    let x = smap[key]
    if x == Nil: return key
    return walk(x, smap)
  else:
    return key

proc deep_walk(key, smap: Val): Val =
  let x = walk(key, smap)
  if x.is_array:
    var o = init_array().v
    for i in 0..<(x.len):
      let y = x[i]
      if y == dot:
        let rest = deep_walk(x[i + 1], smap)
        o = o.concat(rest)
        break
      else:
        o = o.add(deep_walk(y, smap))
    return o
  else:
    return x

proc unify_array*(x, y, smap: Val): Val

proc unify*(x, y, smap: Val): Val =
  let rx = x.walk(smap)
  let ry = y.walk(smap)
  if rx == ry: return smap
  if rx.is_lvar: return smap.set(rx, ry)
  if ry.is_lvar: return smap.set(ry, rx)
  if rx.is_array and ry.is_array: return unify_array(rx, ry, smap)
  return Nil.v

proc unify_array*(x, y, smap: Val): Val =
  if x.len == 0 and y.len == 0: return smap
  if x[0] == dot: return unify(x[1], y, smap)
  if y[0] == dot: return unify(y[1], x, smap)
  if x.len == 0 or y.len == 0: return Nil.v
  let s = unify(x[0], y[0], smap)
  if s != Nil: return unify(x.slice(1, x.len), y.slice(1, y.len), s)
  return s

proc succeedo*(): proc(smap: Val): iterator(): Val =
  return proc(smap: Val): iterator(): Val =
    return iterator(): Val =
      yield smap

proc failo*(): proc(smap: Val): iterator(): Val =
  return proc(smap: Val): iterator(): Val =
    return iterator(): Val =
      yield Nil.v

proc ando_helper(clauses: seq[SMapStream], offset: int, smap: Val): Stream =
  return iterator(): Val =
    if offset == clauses.len: return
    let clause = clauses[offset]
    for x in clause(smap):
      if x == Nil: yield x                             # error?
      elif offset == clauses.len - 1: yield x
      else:
        var it = ando_helper(clauses, offset + 1, x)
        for y in it():
          yield y
proc ando*(clauses: seq[SMapStream]): SMapStream =
  return iterator(smap: Val): Val =
    var it = ando_helper(clauses, 0, smap)
    for x in it():
      yield x

proc oro_helper(clauses: seq[SMapStream], offset, sol_num: int, smap: Val): Stream =
  return iterator(): Val =
    if offset == clauses.len: return
    let clause = clauses[offset]
    var x: Val
    var s_num = sol_num
    for x in clause(smap):
      if x != Nil:
        yield x
        s_num += 1
    var it = oro_helper(clauses, offset + 1, s_num, x)
    for y in it():
      yield y
proc oro*(clauses: seq[SMapStream]): SMapStream =
  let
    offset = 0
    sol_num = 0
  return iterator(smap: Val): Val =
    for x in oro_helper(clauses, offset, sol_num, smap)():
      yield x

proc run*(num: int, vars: openArray[Val], goal: SMapStream): seq[Val] =
  echo "RUN"
  var n = num
  let smap = init_map().v
  for x in goal(smap):
    if n == 0: break
    n -= 1
    if x != Nil:
      var new_map = init_map().v
      for lvar in vars:
        new_map = new_map.set(lvar, deep_walk(lvar, x))
      result.add(new_map)
  echo "result: ", result

macro fresh*(lvars, body: untyped): untyped =
  template def_lvar(x): untyped =
    let x = V Sym x
  var defs = newStmtList()
  for lvar in lvars:
    defs.add(getAst(def_lvar(lvar)))
  result = quote do: (proc(): SMapStream =
    `defs`
    `body`
  )()
  echo treeRepr(defs)

proc eqo_impl*(x, y: Val): SMapStream =
  return iterator(smap: Val): Val =
    yield unify(x, y, smap)
macro eqo*(x, y: untyped): untyped =
  return newCall("eqo_impl", V_impl(x), V_impl(y))

proc conso_impl*(first, rest, output: Val): SMapStream =
  if rest.is_lvar: return eqo(V [first, dot, rest], output)
  return eqo(rest.prepend(first), output)
macro conso*(first, rest, output: untyped): untyped =
  return newCall("conso_impl", V_impl(first), V_impl(rest), V_impl(output))

proc firsto_impl*(first, output: Val): SMapStream =
  return conso(first, V Sym(rest), output)
macro firsto*(first, output: untyped): untyped =
  return newCall("firsto_impl", V_impl(first), V_impl(output))

proc resto_impl*(rest, output: Val): SMapStream =
  return conso(V Sym(first), rest, output)
macro resto*(rest, output: untyped): untyped =
  return newCall("resto_impl", V_impl(rest), V_impl(output))

proc emptyo_impl*(x: Val): SMapStream =
  return eqo(x, V Arr [])
macro emptyo*(x: untyped): untyped =
  return newCall("emptyo_impl", V_impl(x))
