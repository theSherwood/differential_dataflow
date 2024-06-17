import std/[tables, strutils]
import ../src/[test_utils, kanren]

proc main* =
  suite "kanren":
    test "simple":
      let x = V Sym x
      var res = run(10, [x], eqo(x, 1))
      check res == @[V Map {x: 1}]

      res = run(10, [x], oro(@[eqo(x, 1), eqo(x, 2)]))
      check res == @[V Map {x: 1}, V Map {x: 2}]
    
    test "simple and":
      let x = V Sym x
      let y = V Sym y
      var res = run(10, [x, y], ando(@[eqo(x, y), eqo(x, 1)]))
      check res == @[V Map {x: 1, y: 1}]

    test "simple arrays":
      let x = V Sym x
      let y = V Sym y
      var res = run(10, [x, y], conso(x, y, [1, 2, 3]))
      check res == @[V Map {x: 1, y: [2, 3]}]

      res = run(10, [x], firsto(x, [1, 2, 3]))
      check res == @[V Map {x: 1}]

      res = run(10, [x], resto(x, [1, 2, 3]))
      check res == @[V Map {x: [2, 3]}]

      res = run(10, [x], emptyo(x))
      check res == @[V Map {x: []}]
    
    test "arrays":
      let q = V Sym q
      var res = run(10, [q], membero(q, [1, 2, 3]))
      check res == @[V Map {q: 1}, V Map {q: 2}, V Map {q: 3}]

      let x = V Sym x
      let y = V Sym y
      res = run(10, [x, y], conso(x, y, [1, 2, 3]))
      check res == @[V Map {x: 1, y: [2, 3]}]

      res = run(10, [x, y], appendo(x, y, [1, 2, 3]))
      check res == @[
        V Map {x: [],        y: [1, 2, 3]},
        V Map {x: [1],       y: [2, 3]   },
        V Map {x: [1, 2],    y: [3]      },
        V Map {x: [1, 2, 3], y: []       },
      ]

    test "fresh":
      let q = V Sym q
      var res = run(10, [q], fresh([x, y], eqo(x, y)))
      check res == @[V Map {q: q}]

      res = run(10, [q], fresh([x, y, z], ando(@[eqo(x, y), eqo(z, 3)])))
      check res == @[V Map {q: q}]

      res = run(10, [q], fresh([x, y], ando(@[eqo(q, 3), eqo(x, y)])))
      check res == @[V Map {q: 3}]

      res = run(10, [q], fresh([x, y], ando(@[eqo(x, y), eqo(3, y), eqo(x, q)])))
      check res == @[V Map {q: 3}]

      let y = V Sym y
      res = run(10, [y], ando(@[
        fresh([x, y], ando(@[eqo(4, x), eqo(x, y)])),
        eqo(3, y)
      ]))
      check res == @[V Map {y: 3}]
    
    test "no result":
      let x = V Sym x
      var res = run(10, [x], eqo(4, 5))
      check res == newSeq[Val]()

      res = run(10, [x], ando(@[eqo(x, 5), eqo(x, 6)]))
      check res == newSeq[Val]()
    
    suite "arithmetic":
      test "simple addition and subtraction":
        let x = V Sym x
        let y = V Sym y
        var res = run(10, [x], add(2, x, 5))
        check res == @[V Map {x: 3}]

        res = run(10, [x], sub(5, x, 2))
        check res == @[V Map {x: 3}]

        res = run(10, [x, y], ando(@[
          membero(x, [4, 5, 6]),
          add(x, 2, y),
        ]))
        check res == @[V Map {x:4,y:6}, V Map {x:5,y:7}, V Map {x:6,y:8}]

        res = run(10, [x, y], ando(@[
          membero(x, [4, 5, 6]),
          sub(x, 2, y),
        ]))
        check res == @[V Map {x:4,y:2}, V Map {x:5,y:3}, V Map {x:6,y:4}]

        res = run(10, [x, y], ando(@[
          oro(@[eqo(x, 4), eqo(x, 5), eqo(x, 6)]),
          add(x, y, 8),
        ]))
        check res == @[V Map {x:4,y:4}, V Map {x:5,y:3}, V Map {x:6,y:2}]

        res = run(10, [x, y], ando(@[
          oro(@[eqo(x, 4), eqo(x, 5), eqo(x, 6)]),
          sub(x, y, 8),
        ]))
        check res == @[V Map {x:4,y: -4}, V Map {x:5,y: -3}, V Map {x:6,y: -2}]

      test "simple multiplication and division":
        let x = V Sym x
        let y = V Sym y
        var res = run(10, [x], mul(2, x, 5))
        check res == @[V Map {x: 2.5}]

        res = run(10, [x], dis(5, x, 2))
        check res == @[V Map {x: 2.5}]

        res = run(10, [x, y], ando(@[
          membero(x, [4, 5, 6]),
          mul(x, 2, y),
        ]))
        check res == @[V Map {x:4,y:8}, V Map {x:5,y:10}, V Map {x:6,y:12}]

        res = run(10, [x, y], ando(@[
          membero(x, [4, 5, 6]),
          dis(x, 2, y),
        ]))
        check res == @[V Map {x:4,y:2}, V Map {x:5,y:2.5}, V Map {x:6,y:3}]

        res = run(10, [x, y], ando(@[
          oro(@[eqo(x, 4), eqo(x, 5), eqo(x, 2)]),
          mul(x, y, 8),
        ]))
        check res == @[V Map {x:4,y:2}, V Map {x:5,y:1.6}, V Map {x:2,y:4}]

        res = run(10, [x, y], ando(@[
          oro(@[eqo(x, 4), eqo(x, 5), eqo(x, 6)]),
          dis(x, y, 8),
        ]))
        check res == @[V Map {x:4,y:0.5}, V Map {x:5,y:0.625}, V Map {x:6,y:0.75}]

#[
]#

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