import std/[tables, strutils]
import ../src/[test_utils, kanren]

proc main* =
  suite "kanren":
    test "simple":
      let x = V Sym x
      var res = run(-1, [x], eqo(x, 1))
      check res == @[V Map {x: 1}]

      res = run(-1, [x], oro(@[eqo(x, 1), eqo(x, 2)]))
      check res == @[V Map {x: 1}, V Map {x: 2}]

    test "simple arrays":
      let x = V Sym x
      let y = V Sym y
      var res = run(-1, [x, y], conso(x, y, [1, 2, 3]))
      check res == @[V Map {x: 1, y: [2, 3]}]

      res = run(-1, [x], firsto(x, [1, 2, 3]))
      check res == @[V Map {x: 1}]

      res = run(-1, [x], resto(x, [1, 2, 3]))
      check res == @[V Map {x: [2, 3]}]

      res = run(-1, [x], emptyo(x))
      check res == @[V Map {x: []}]
    
    test "arrays":
      let q = V Sym q
      var res = run(-1, [q], membero(q, [1, 2, 3]))
      check res == @[V Map {q: 1}, V Map {q: 2}, V Map {q: 3}]

      let x = V Sym x
      let y = V Sym y
      res = run(-1, [x, y], conso(x, y, [1, 2, 3]))
      check res == @[V Map {x: 1, y: [2, 3]}]

      res = run(-1, [x, y], appendo(x, y, [1, 2, 3]))
      check res == @[
        V Map {x: [],        y: [1, 2, 3]},
        V Map {x: [1],       y: [2, 3]   },
        V Map {x: [1, 2],    y: [3]      },
        V Map {x: [1, 2, 3], y: []       },
      ]

    test "fresh":
      let q = V Sym q
      var res = run(-1, [q], fresh([x, y], eqo(x, y)))
      check res == @[V Map {q: q}]

      res = run(-1, [q], fresh([x, y, z], ando(@[eqo(x, y), eqo(z, 3)])))
      check res == @[V Map {q: q}]

      res = run(-1, [q], fresh([x, y], ando(@[eqo(q, 3), eqo(x, y)])))
      check res == @[V Map {q: 3}]

      res = run(-1, [q], fresh([x, y], ando(@[eqo(x, y), eqo(3, y), eqo(x, q)])))
      check res == @[V Map {q: 3}]

      let y = V Sym y
      res = run(-1, [y], ando(@[
        fresh([x, y], ando(@[eqo(4, x), eqo(x, y)])),
        eqo(3, y)
      ]))
      check res == @[V Map {y: 3}]
    
    test "no result":
      let x = V Sym x
      var res = run(-1, [x], eqo(4, 5))
      check res == newSeq[Val]()

      res = run(-1, [x], ando(@[eqo(x, 5), eqo(x, 6)]))
      check res == newSeq[Val]()
    
    test "arithmetic":
      let x = V Sym x
      let y = V Sym y
      var res = run(-1, [x], add(2, x, 5))
      check res == @[V Map {x: 3}]

      echo "========================"
      res = run(2, [x, y], ando(@[
        membero(x, [4, 5, 6]),
        add(2, x, y),
      ]))
      check res == @[V Map {x: 3}]

    #[
    test "length":
      let x = V Sym x
      proc leno(arr, n: Val): SMapStream =
        let head = V Sym head
        let rest = V Sym rest
        let n1   = V Sym n1
        return oro(@[
          ando(@[emptyo(x), eqo(n, 0)]),
          ando(@[
            conso(head, rest, arr),
            leno(rest, n1),
            addo(n1, 1, n),
          ]),
        ])
]#

  echo "done"