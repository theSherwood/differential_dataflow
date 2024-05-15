import std/[tables, strutils, sequtils, algorithm]
import ../../src/[test_utils]
import ../../src/persistent/[map]

proc main* =
  suite "persistent map":
    test "maps":
      let m1 = initMap[string, string]()
      let m2 = m1.add("hello", "world")
      # expect(KeyError):
      #   discard m1.get("hello")
      # check m2.get("hello") == "world"
      # check m1.getOrDefault("hello", "") == ""
      # check m2.getOrDefault("hello", "") == "world"
      # check m2.contains("hello")
      # let m3 = m2.add("hello", "goodbye")
      # check m3.get("hello") == "goodbye"
      # let m4 = m3.add("what's", "up")
      # let m5 = m3.del("what's").del("asdf")
      # check m5.get("hello") == "goodbye"
      # expect(KeyError):
      #   discard m5.get("what's")
      # check m1.len == 0
      # check m2.len == 1
      # check m3.len == 1
      # check m4.len == 2
      # check m5.len == 1
      # check m2 == {"hello": "world"}.toMap
      # # large map
      # var m6 = initMap[string, string]()
      # for i in 0 .. 1024:
      #   m6 = m6.add($i, $i)
      # check m6.len == 1025
      # check m6.get("1024") == "1024"
      # # pairs
      # var m7 = initMap[string, string]()
      # for (k, v) in m6.pairs:
      #   m7 = m7.add(k, v)
      # check m7.len == 1025
      # # keys
      # var m8 = initMap[string, string]()
      # for k in m7.keys:
      #   m8 = m8.add(k, k)
      # check m8.len == 1025
      # # values
      # var m9 = initMap[string, string]()
      # for v in m8.values:
      #   m9 = m9.add(v, v)
      # check m9.len == 1025
      # # equality
      # check m1 == m1
      # check m1 != m2
      # check m2 != m3
      # check m8 == m9
      # # non-initialized maps work
      # var m10: Map[string, string]
      # check m10.getOrDefault("hello", "") == ""
      # check m10.add("hello", "world").get("hello") == "world"
      # check m10 == m1
  
  echo "done"