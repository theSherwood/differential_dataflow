##
## https://github.com/shd101wyy/logic.js/blob/master/lib/logic.js
## 

import macros
import strutils
import strformat
import values
export values

const DEBUG_ITER* = true
const ITER_ID* = 0

type
  Val* = ImValue

  Stream* = iterator(): Val
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

## a list of which indents are in use (true is in use; false is free)
## We start with the first value in use. This corresponds to the main thread.
var indents = @[true]
## map of ids (the index) to indent (the value)
## We start with the first value in use. This corresponds to the main thread. 
var registry = @[ITER_ID]
proc print_impl*(id: int, s: string) =
  let indent = registry[id]
  echo indent(&"{id} {s}", indent, "|   ")
template print*(the_print_string: string) {.dirty.} =
  when DEBUG_ITER:
    print_impl(ITER_ID, the_print_string)
  else:
    echo the_print_string
template yeet*(val: untyped) =
  let THE_VALUE = val
  when DEBUG_ITER:
    print("yeet: " & $THE_VALUE)
  yield THE_VALUE
proc register(debug_label: string = ""): int = 
  var idx = indents.find(false)
  if idx < 0:
    idx = indents.len
    indents.add(true)
  indents[idx] = true
  let id = registry.len
  registry.add(idx)
  print_impl(id, &"START {debug_label}")
  return id
proc deregister(id: int) =
  indents[registry[id]] = false
  print_impl(id, "END")
macro iter(name, params, yield_type, body: untyped): untyped =
  let name_string = name.strVal
  var resolved_params = @[newIdentNode(yield_type.strVal)]
  for colon_expr in params:
    resolved_params.add(nnkIdentDefs.newTree(
      colon_expr[0],
      colon_expr[1],
      newEmptyNode()
    ))
  let new_body = quote do: 
    when DEBUG_ITER:
      let ITER_ID {.inject.} = register(`name_string`)
      `body`
      deregister(ITER_ID)
    else:
      `body`
  result = newProc(
    params = resolved_params,
    procType = nnkIteratorDef,
    body = new_body)
  echo "\nITER::"
  echo treeRepr(result)
  # echo "BODY::"
  # echo treeRepr(new_body)
  echo "\n"

proc succeedo*(): proc(smap: Val): Stream =
  return proc(smap: Val): Stream =
    return iter(succeedo, (), Val):
      yeet smap

proc failo*(): proc(smap: Val): Stream =
  return proc(smap: Val): Stream =
    return iter(failo, (), Val):
      yeet Nil.v

proc ando_helper(clauses: seq[SMapStream], offset: int, smap: Val): Stream =
  return iter(ando_helper, (), Val):
    if offset == clauses.len: return
    let clause = clauses[offset]
    for x in clause(smap):
      if x == Nil: yeet x                             # error?
      elif offset == clauses.len - 1: yeet x
      else:
        var it = ando_helper(clauses, offset + 1, x)
        print(&"finished: {finished(it)}")
        for y in it():
          yeet y
proc ando*(clauses: seq[SMapStream]): SMapStream =
  return iter(ando, (smap: Val), Val):
    var it = ando_helper(clauses, 0, smap)
    for x in it():
      yeet x

proc oro_helper(clauses: seq[SMapStream], offset, sol_num: int, smap: Val): Stream =
  return iter(oro_helper, (), Val):
    if offset != clauses.len:
      let clause = clauses[offset]
      var x = smap
      var s_num = sol_num
      for x in clause(smap):
        if x != Nil:
          yeet x
          s_num += 1
      var it = oro_helper(clauses, offset + 1, s_num, x)
      for y in it():
        yeet y
proc oro*(clauses: seq[SMapStream]): SMapStream =
  let
    offset = 0
    sol_num = 0
  return iter(oro, (smap: Val), Val):
    var it = oro_helper(clauses, offset, sol_num, smap)
    for x in it():
      yeet x

proc run*(num: int, vars: openArray[Val], goal: SMapStream): seq[Val] =
  print "RUN"
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
  print &"result: {result}"

macro fresh*(lvars, body: untyped): untyped =
  template def_lvar(x): untyped =
    let x = V Sym x
  var defs = newStmtList()
  for lvar in lvars:
    defs.add(getAst(def_lvar(lvar)))
  result = quote do: (proc(): SMapStream =
    `defs`
    return iter(fresh, (smap: Val), Val):
      var it = `body`
      for z in it(smap):
        yeet z
  )()

proc eqo_impl*(x, y: Val): SMapStream =
  return iter(eqo_impl, (smap: Val), Val):
    yeet unify(x, y, smap)
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

proc membero_impl*(x, arr: Val): SMapStream =
  # return oro(@[
  #   fresh([first], ando(@[firsto(first, arr), eqo(first, x)])),
  #   fresh([rest], ando(@[resto(rest, arr), membero_impl(x, rest)])),
  # ])
  return iter(membero_impl, (smap: Val), Val):
    var it = oro(@[
      fresh([first], ando(@[firsto(first, arr), eqo(first, x)])),
      fresh([rest], ando(@[resto(rest, arr), membero_impl(x, rest)])),
    ])
    for x in it(smap):
      yeet x
macro membero*(x, arr: untyped): untyped =
  return newCall("membero_impl", V_impl(x), V_impl(arr))

proc appendo_impl*(arr1, arr2, output: Val): SMapStream =
  return oro(@[
    ando(@[emptyo(arr1), eqo(arr2, output)]),
    fresh([first, rest, rec], ando(@[
      conso(first, rest, arr1),
      conso(first, rec, output),
      appendo_impl(rest, arr2, rec),
    ]))
  ])
macro appendo*(arr1, arr2, output: untyped): untyped =
  return newCall("appendo_impl", V_impl(arr1), V_impl(arr2), V_impl(output)) 

proc stringo_impl*(x: Val): SMapStream =
  return iter(stringo_impl, (smap: Val), Val):
    if walk(x, smap).is_string: yeet smap
    yeet Nil.v
macro stringo*(x: untyped): untyped =
  return newCall("stringo_impl", V_impl(x))

proc numbero_impl*(x: Val): SMapStream =
  return iter(numbero_impl, (smap: Val), Val):
    if walk(x, smap).is_num: yeet smap
    yeet Nil.v
macro numbero*(x: untyped): untyped =
  return newCall("numbero_impl", V_impl(x))

proc arrayo_impl*(x: Val): SMapStream =
  return iter(arrayo_impl, (smap: Val), Val):
    if walk(x, smap).is_array: yeet smap
    yeet Nil.v
macro arrayo*(x: untyped): untyped =
  return newCall("arrayo_impl", V_impl(x))

proc add_impl*(a, b, c: Val): SMapStream =
  ## a + b = c
  return iter(add_impl, (smap: Val), Val):
    let x = walk(a, smap)
    let y = walk(b, smap)
    let z = walk(c,  smap)
    var
      lvars_count = 0
      lvar = Nil.v
    if x.is_symbol:
      lvars_count += 1
      lvar = x
    if y.is_symbol:
      lvars_count += 1
      lvar = y
    if z.is_symbol:
      lvars_count += 1
      lvar = z
    if lvars_count == 0:
      if x + y == z: yeet smap
      else: yeet Nil.v
    elif lvars_count == 1:
      if lvar == x:
        if y.is_num and z.is_num:
          var it = eqo(x, z - y)
          for a in it(smap): yeet a
        else: yeet Nil.v
      elif lvar == y:
        if x.is_num and z.is_num:
          var it = eqo(y, z - x)
          for b in it(smap): yeet b
        else: yeet Nil.v
      else:
        if x.is_num and y.is_num:
          var it = eqo(z, x + y)
          for c in it(smap): yeet c
        else: yeet Nil.v
    else: yeet Nil.v
macro add*(a, b, c: untyped): untyped =
  return newCall("add_impl", V_impl(a), V_impl(b), V_impl(c))
macro sub*(a, b, c: untyped): untyped =
  return newCall("add_impl", V_impl(b), V_impl(c), V_impl(a))

proc mul_impl*(a, b, c: Val): SMapStream =
  ## a * b = c
  return iter(mul_impl, (smap: Val), Val):
    let x = walk(a, smap)
    let y = walk(b, smap)
    let z = walk(c,  smap)
    var
      lvars_count = 0
      lvar = Nil.v
    if x.is_symbol:
      lvars_count += 1
      lvar = x
    if y.is_symbol:
      lvars_count += 1
      lvar = y
    if z.is_symbol:
      lvars_count += 1
      lvar = z
    if lvars_count == 0:
      if x * y == z: yeet smap
      else: yeet Nil.v
    elif lvars_count == 1:
      if lvar == x:
        if y.is_num and z.is_num:
          var it = eqo(x, z / y)
          for a in it(smap): yeet a
        else: yeet Nil.v
      elif lvar == y:
        if x.is_num and z.is_num:
          var it = eqo(y, z / x)
          for b in it(smap): yeet b
        else: yeet Nil.v
      else:
        if x.is_num and y.is_num:
          var it = eqo(z, x * y)
          for c in it(smap): yeet c
        else: yeet Nil.v
    else: yeet Nil.v
macro mul*(a, b, c: untyped): untyped =
  return newCall("mul_impl", V_impl(a), V_impl(b), V_impl(c))
macro dis*(a, b, c: untyped): untyped =
  return newCall("mul_impl", V_impl(b), V_impl(c), V_impl(a))
