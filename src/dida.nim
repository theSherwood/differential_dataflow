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
