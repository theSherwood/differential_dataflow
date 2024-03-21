import std/[bitops, tables]
import values

proc main =
  var
    m1 = init_map([(1.0.v, 2.0.v)])
    m2 = init_map([(m1.v, m1.v)])
    m3 = m2.v.set_in([1.0.v], 4.0.v)
    m4 = m2.set(1.0.v, 4.0.v)
  echo "m3.size ", m3.as_map.size
  echo "m4.as_map: ", m4.as_map
  echo "m4.v:      ", m4.v
  echo "m3.as_map: ", m3.as_map
  echo "m3.v:      ", m3.v
  echo "========================================"
  doAssert m3 == m4.v

main()
