import std/[bitops, tables]
import values

proc main =
  var
    m2 = init_map([])
    m3 = m2.v.set_in([1.0.v], 4.0.v)
    m4 = m2.set(1.0.v, 4.0.v)
    m5 = init_map([(3.0.v, 5.0.v)])
  echo "m2.as_map: ", m2.as_map
  echo "m2.v:      ", m2.v
  echo "m5.as_map: ", m5.as_map
  echo "m5.v:      ", m5.v
  echo "m3.size    ", m3.as_map.size
  echo "m4.as_map: ", m4.as_map
  echo "m4.v:      ", m4.v
  echo "m3.as_map: ", m3.as_map
  echo "m3.v:      ", m3.v
  echo "========================================"
  doAssert m3.v == m4.v
  var
    m6 = m3.v.set_in([m2.v], m3.v)
    m7 = init_map([(init_map([]).v, init_map([(1.0.v, 4.0.v)]).v), (1.0.v, 4.0.v)])
  echo "m6.v:      ", m6.v
  echo "m7.v:      ", m7.v
  doAssert m6.v == m7.v

main()
