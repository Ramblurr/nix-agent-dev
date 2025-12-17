# Generator Cheatsheet

## Table of Contents
- [Dev Utilities](#dev-utilities)
- [Simple Generators](#simple-generators)
- [Numbers](#numbers)
- [Characters & Strings](#characters--strings)
- [Heterogeneous Collections](#heterogeneous-collections)
- [Homogeneous Collections](#homogeneous-collections)
- [Combinators](#combinators)
- [Sizing & Shrinking Control](#sizing--shrinking-control)

## Dev Utilities

```clojure
(gen/sample g)           ; 10 smallish samples
(gen/sample g n)         ; n samples
(gen/generate g)         ; single moderately sized value
(gen/generate g size)    ; value with specific size (0-200)
(gen/generator? g)       ; check if g is a generator
```

## Simple Generators

```clojure
(gen/return x)           ; constant, always generates x
gen/boolean              ; true/false
gen/uuid                 ; random UUIDs, does not shrink
(gen/elements coll)      ; random element from non-empty coll
(gen/shuffle coll)       ; vectors with coll elements shuffled
gen/any                  ; any Clojure value
gen/any-printable        ; printable Clojure values
gen/any-equatable        ; values that can be equal
gen/simple-type          ; any non-collection
gen/simple-type-printable
```

## Numbers

```clojure
gen/nat                  ; small non-negative (bounded by size)
gen/small-integer        ; small integers (bounded by size)
gen/large-integer        ; large range integers
(gen/large-integer* {:min x :max y})
gen/size-bounded-bigint  ; bigints up to 2^(6*size)
gen/double               ; doubles with infinities & NaN
(gen/double* {:min x :max y :infinite? true :NaN? true})
gen/ratio                ; ratios using small-integer
gen/big-ratio            ; ratios using size-bounded-bigint
gen/byte                 ; Byte values
(gen/choose low high)    ; uniform distribution [low, high]
```

## Characters & Strings

```clojure
gen/char                 ; characters
gen/char-ascii           ; printable ASCII
gen/char-alphanumeric    ; alphanumeric ASCII
gen/char-alpha           ; alphabetic ASCII
gen/string               ; strings
gen/string-ascii         ; ASCII strings
gen/string-alphanumeric  ; alphanumeric strings
gen/keyword              ; keywords
gen/keyword-ns           ; namespaced keywords
gen/symbol               ; symbols
gen/symbol-ns            ; namespaced symbols
```

## Heterogeneous Collections

```clojure
(gen/tuple g1 g2 ...)    ; [x1 x2 ...] where xi from gi
(gen/hash-map k1 g1 k2 g2 ...)  ; {k1 v1 k2 v2 ...} vi from gi
```

## Homogeneous Collections

```clojure
(gen/vector g)                        ; vectors
(gen/vector g num)                    ; fixed size
(gen/vector g min max)                ; size range
(gen/list g)                          ; lists
(gen/set g)                           ; sets
(gen/set g {:num-elements n})         ; fixed size
(gen/set g {:min-elements x :max-elements y :max-tries 20})
(gen/map key-gen val-gen)             ; maps (same opts as set)
(gen/sorted-set g)                    ; sorted sets
(gen/vector-distinct g)               ; distinct element vectors
(gen/list-distinct g)                 ; distinct element lists
(gen/vector-distinct-by key-fn g)     ; distinct by key-fn
(gen/list-distinct-by key-fn g)
gen/bytes                             ; byte arrays
```

## Combinators

```clojure
;; gen/let - macro, bindings are generators, body is value/generator
(gen/let [x g1
          y g2]
  {:x x :y y})

;; fmap - transform values
(gen/fmap f g)           ; generates (f x) for x from g

;; bind - chain generators, f returns generator
(gen/bind g f)           ; generates from (f x) for x from g

;; filtering
(gen/such-that pred g)         ; only values matching pred
(gen/such-that pred g max-tries)

;; choosing
(gen/one-of [g1 g2 ...])       ; random generator selection
(gen/frequency [[w1 g1] [w2 g2] ...])  ; weighted selection

;; modifiers
(gen/not-empty g)              ; non-empty collections

;; recursive
(gen/recursive-gen container-gen scalar-gen)  ; tree structures
```

## Sizing & Shrinking Control

```clojure
(gen/resize n g)         ; fix size to n
(gen/scale f g)          ; size becomes (f size)
(gen/no-shrink g)        ; disable shrinking
```
