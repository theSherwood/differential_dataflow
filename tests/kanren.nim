import std/[tables, strutils]
import ../src/[test_utils, kanren]

proc main* =
  suite "kanren":
    test "simple":
      let x = V Sym x
      var res = run(1, [x], eqo(x, V 1))
      check res == @[V Map {x: 1}]

      let y = V Sym y
      res = run(1, [x, y], conso(x, y, V [1, 2, 3]))
      check res == @[V Map {x: 1, y: [2, 3]}]
      res = run(1, [x], firsto(x, V [1, 2, 3]))
      check res == @[V Map {x: 1}]
      res = run(1, [x], resto(x, V [1, 2, 3]))
      check res == @[V Map {x: [2, 3]}]
      res = run(1, [x], emptyo(x))
      check res == @[V Map {x: []}]

  echo "done"