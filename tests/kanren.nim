## TODO
## - perf
##   - reduce recursion in:
##     - oro
##     - ando
##   - array methods?
## 

import std/[tables, strutils, macros]
import ../src/[test_utils, kanren]

macro Sy(x): untyped = newCall("v", Sym_impl(x))

proc main* =
  suite "kanren":
    test "simple":
      let x = Sy x
      var res = run(10, [x], eqo(x, 1))
      check res == @[V {x: 1}]

      res = run(10, [x], oro(eqo(x, 1), eqo(x, 2)))
      check res == @[V {x: 1}, V {x: 2}]

    test "simple and":
      let x = Sy x
      let y = Sy y
      var res = run(10, [x, y], ando(eqo(x, y), eqo(x, 1)))
      check res == @[V {x: 1, y: 1}]

    test "conde":
      let x = Sy x
      let y = Sy y
      var res = run(10, [x, y], conde(
        @[eqo(x, y), eqo(x, 1)],
        @[eqo(x, y), eqo(x, 2)],
        @[eqo(x, y), eqo(x, 1), eqo(y, 2)],
      ))
      check res == @[V {x: 1, y: 1}, V {x: 2, y: 2}]

    test "simple arrays":
      let x = Sy x
      let y = Sy y
      var res = run(10, [x, y], conso(x, y, [1, 2, 3]))
      check res == @[V {x: 1, y: [2, 3]}]

      res = run(10, [x], firsto(x, [1, 2, 3]))
      check res == @[V {x: 1}]

      res = run(10, [x], resto(x, [1, 2, 3]))
      check res == @[V {x: [2, 3]}]

      res = run(10, [x], emptyo(x))
      check res == @[V {x: []}]
    
    test "arrays":
      let q = Sy q
      var res = run(10, [q], membero(q, [1, 2, 3]))
      check res == @[V {q: 1}, V {q: 2}, V {q: 3}]

      let x = Sy x
      let y = Sy y
      res = run(10, [x, y], conso(x, y, [1, 2, 3]))
      check res == @[V {x: 1, y: [2, 3]}]

      res = run(10, [x, y], appendo(x, y, [1, 2, 3]))
      check res == @[
        V {x: [],        y: [1, 2, 3]},
        V {x: [1],       y: [2, 3]   },
        V {x: [1, 2],    y: [3]      },
        V {x: [1, 2, 3], y: []       },
      ]

    test "fresh":
      let q = Sy q
      var res = run(10, [q], fresh([x, y], eqo(x, y)))
      check res == @[V {q: q}]

      res = run(10, [q], fresh([x, y, z], ando(eqo(x, y), eqo(z, 3))))
      check res == @[V {q: q}]

      res = run(10, [q], fresh([x, y], ando(eqo(q, 3), eqo(x, y))))
      check res == @[V {q: 3}]

      res = run(10, [q], fresh([x, y], ando(eqo(x, y), eqo(3, y), eqo(x, q))))
      check res == @[V {q: 3}]

      let y = Sy y
      res = run(10, [y], ando(
        fresh([x, y], ando(eqo(4, x), eqo(x, y))),
        eqo(3, y)
      ))
      check res == @[V {y: 3}]
    
    test "no result":
      let x = Sy x
      var res = run(10, [x], eqo(4, 5))
      check res == newSeq[Val]()

      res = run(10, [x], ando(eqo(x, 5), eqo(x, 6)))
      check res == newSeq[Val]()
    
    suite "arithmetic":
      test "simple addition and subtraction":
        let x = Sy x
        let y = Sy y
        var res = run(10, [x], add(2, x, 5))
        check res == @[V {x: 3}]

        res = run(10, [x], sub(5, x, 2))
        check res == @[V {x: 3}]

        res = run(10, [x, y], ando(
          membero(x, [4, 5, 6]),
          add(x, 2, y),
        ))
        check res == @[V {x:4,y:6}, V {x:5,y:7}, V {x:6,y:8}]

        res = run(10, [x, y], ando(
          membero(x, [4, 5, 6]),
          sub(x, 2, y),
        ))
        check res == @[V {x:4,y:2}, V {x:5,y:3}, V {x:6,y:4}]

        res = run(10, [x, y], ando(
          oro(eqo(x, 4), eqo(x, 5), eqo(x, 6)),
          add(x, y, 8),
        ))
        check res == @[V {x:4,y:4}, V {x:5,y:3}, V {x:6,y:2}]

        res = run(10, [x, y], ando(
          oro(eqo(x, 4), eqo(x, 5), eqo(x, 6)),
          sub(x, y, 8),
        ))
        check res == @[V {x:4,y: -4}, V {x:5,y: -3}, V {x:6,y: -2}]

      test "simple multiplication and division":
        let x = Sy x
        let y = Sy y
        var res = run(10, [x], mul(2, x, 5))
        check res == @[V {x: 2.5}]

        res = run(10, [x], dis(5, x, 2))
        check res == @[V {x: 2.5}]

        res = run(10, [x, y], ando(
          membero(x, [4, 5, 6]),
          mul(x, 2, y),
        ))
        check res == @[V {x:4,y:8}, V {x:5,y:10}, V {x:6,y:12}]

        res = run(10, [x, y], ando(
          membero(x, [4, 5, 6]),
          dis(x, 2, y),
        ))
        check res == @[V {x:4,y:2}, V {x:5,y:2.5}, V {x:6,y:3}]

        res = run(10, [x, y], ando(
          oro(eqo(x, 4), eqo(x, 5), eqo(x, 2)),
          mul(x, y, 8),
        ))
        check res == @[V {x:4,y:2}, V {x:5,y:1.6}, V {x:2,y:4}]

        res = run(10, [x, y], ando(
          oro(eqo(x, 4), eqo(x, 5), eqo(x, 6)),
          dis(x, y, 8),
        ))
        check res == @[V {x:4,y:0.5}, V {x:5,y:0.625}, V {x:6,y:0.75}]

    test "comparisons":
      let a = Sy a
      let b = Sy b
      var res = run(10, [a, b], ando(
        membero(a, [1, 2, 3]),
        membero(b, [1, 2, 3]),
        lt(a, b),
      ))
      check res == @[V {a:1, b:2}, V {a:1, b:3}, V {a:2, b:3}]

      res = run(10, [a, b], ando(
        membero(a, [1, 2, 3]),
        membero(b, [1, 2, 3]),
        gt(a, b),
      ))
      check res == @[V {a:2, b:1}, V {a:3, b:1}, V {a:3, b:2}]

      res = run(10, [a, b], ando(
        membero(a, [1, 2, 3]),
        membero(b, [1, 2, 3]),
        le(a, b),
      ))
      check res == @[V {a:1,b:1}, V {a:1,b:2}, V {a:1,b:3}, V {a:2,b:2}, V {a:2,b:3}, V {a:3,b:3}]

      res = run(10, [a, b], ando(
        membero(a, [1, 2, 3]),
        membero(b, [1, 2, 3]),
        ge(a, b),
      ))
      check res == @[V {b:1,a:1}, V {b:1,a:2}, V {b:2,a:2}, V {b:1,a:3}, V {b:2,a:3}, V {b:3,a:3}]
    
    test "other":
      let a = Sy a
      var res = run(7, [a], anyo(membero(a, [1, 2, 3])))
      check res == @[V {a:1}, V {a:2}, V {a:3}, V {a:1}, V {a:2}, V {a:3}, V {a:1}]
    
    test "stream run":
      let a = Sy a
      var
        it = run([a], anyo(membero(a, [1, 2, 3])))
        n = 7
        res = newSeq[Val]()
      for x in it():
        if n == 0: break
        n -= 1
        res.add(x)
      check res == @[V {a:1}, V {a:2}, V {a:3}, V {a:1}, V {a:2}, V {a:3}, V {a:1}]

    test "rules":
      let parent = facts(@[
        V ["Steve", "Bob"],
        V ["Steve", "Henry"],
        V ["Henry", "Alice"],
      ])

      let x = Sy x
      var res = run(10, [x], parent(@[x, V "Alice"]))
      check res == @[V {x: "Henry"}]
      res = run(10, [x], parent(@[V "Steve", x]))
      check res == @[V {x: "Bob"}, V {x: "Henry"}]

      proc grandparent(x, y: Val): GenStream =
        result = fresh([z], ando(parent(@[x, z]), parent(@[z, y])))
      
      res = run(10, [x], grandparent(x, V "Alice"))
      check res == @[V {x: "Steve"}]

  echo "done"