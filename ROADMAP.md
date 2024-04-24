# ROADMAP

## Batch 1 (Differential Dataflow)

- [ ] perf improvements for value types
  - [ ] HAMT
    - [ ] map
    - [ ] set
  - [ ] persistent bit-partitioned vector trie
    - [ ] arr
      - https://dmiller.github.io/clojure-clr-next/general/2023/02/12/PersistentVector-part-2.html
    - [ ] str
  - [ ] interning
- [ ] finish differential dataflow
  - [ ] iteration
    - [ ] test with game of life
  - [ ] genericity
  - [ ] streams?
  - [ ] sources and sinks (views) similar to materialite
    - https://github.com/vlcn-io/materialite
- [ ] js interface for value types
- [ ] js interface for exceptions/errors

## Demos for Batch 1

- [ ] web demos of differential dataflow (include rendering)
  - refer to https://github.com/vlcn-io/materialite

## Batch 2 (Logic Programming)

- [ ] logic programming on top of differential_dataflow
  - [ ] unification for bindings and pattern-matching
    - refer to https://bguppl.github.io/interpreters/class_material.html
      - logic programming
      - type unification
      - functional substitution
- [ ] js interface for logic programming

## Demos for Batch 2

- [ ] web demos of logic programming (include rendering)

## Batch 3 (Jackal/Ruliad State)

- [ ] multi-version state
- [ ] multi-version sync

## Demos for Batch 3

- [ ] web demos of multi-version state and sync (include rendering)

## Batch 4 (Custom Logic Programming Language)

- [ ] logic programming language
  - [ ] design
    - refer to verse https://simon.peytonjones.org/assets/pdfs/verse-icfp23.pdf
  - [ ] parsing
  - [ ] IR
  - [ ] compilation (1 of the following)
    - [ ] wasm
    - [ ] js

## Batch 5 (Concurrency)

- [ ] parallelism and concurrency
  - [ ] async support
  - [ ] threads
    - [ ] data parallelism
    - [ ] dataflow parallelism
    - [ ] task parallelism
  - [ ] structured concurrency within PL
