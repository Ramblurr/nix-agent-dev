# Growth and Shrinking

## Table of Contents
- [The Size Parameter](#the-size-parameter)
- [Size Progression During Tests](#size-progression-during-tests)
- [Controlling Size](#controlling-size)
- [Shrinking](#shrinking)
- [Common Gotchas](#common-gotchas)

## The Size Parameter

Generators produce values based on a `size` parameter (0-200). This allows test.check to start simple and grow complexity.

**Inspect size behavior:**
```clojure
(defn sizing-sample [g]
  (into {} (for [size [0 5 25 200]]
             [size (repeatedly 5 #(gen/generate g size))])))

(sizing-sample gen/nat)
;; {0   (0 0 0 0 0),
;;  5   (4 1 3 3 5),
;;  25  (12 8 24 25 22),
;;  200 (63 143 31 199 7)}

(sizing-sample gen/large-integer)
;; {0   (-1 0 -1 -1 -1),
;;  200 (8371567737 -393642130983883 ...)}
```

**Collection generators grow both size and element count:**
```clojure
(sizing-sample (gen/vector gen/nat))
;; {0  ([] [] [] [] []),
;;  25 ([8 10 0 16 7 7 2 19 16 10] [16 8 0 18 11 ...] ...)}
```

**Some generators ignore size:**
```clojure
gen/uuid  ; Always uniformly random
```

## Size Progression During Tests

`quick-check` uses `(cycle (range 200))`:
- Trial 1: size=0
- Trial 2: size=1
- ...
- Trial 200: size=199
- Trial 201: size=0 (restarts)

This catches simple bugs quickly before complex inputs.

## Controlling Size

**gen/sized - Read current size:**
```clojure
(gen/sized
  (fn [size]
    (gen/let [x gen/large-integer]
      (format "Generated %d at size=%d" x size))))
```

**gen/resize - Fix size:**
```clojure
(gen/resize 100 gen/large-integer)  ; Always uses size=100
```

**gen/scale - Transform size:**
```clojure
;; Small vectors of large numbers
(def small-vecs-big-nums
  (gen/scale #(max 0 (Math/log %))
             (gen/vector (gen/scale #(* % 100) gen/large-integer))))
```

## Shrinking

Shrinking is deterministic and independent of size. When a test fails, test.check tries progressively simpler values.

**Example failure shrinking:**
```clojure
(tc/quick-check 100
  (prop/for-all [v (gen/vector gen/small-integer)]
    (not-any? #{42} v)))

;; :fail [[-35 -9 -31 12 ... 42 ... 44 -1 -8 27 16]]
;; :shrunk {:smallest [[42]]}
```

Shrinking found that `[42]` is the minimal failing case.

## Common Gotchas

### Integer Generator Ranges

`gen/nat` and `gen/small-integer` are bounded by size (~200 max). Use `gen/large-integer` for real integer testing:

```clojure
;; Bad: won't test numbers > 200
(gen/vector gen/nat)

;; Good: tests full integer range
(gen/vector gen/large-integer)
```

### Small Test Counts

Tests < 200 trials get incomplete size coverage. Tests < 10 trials are especially poor.

**Mitigation for small counts:**
```clojure
(tc/quick-check 10
  (prop/for-all [x (gen/scale #(* 20 %) g)]  ; sizes 0,20,40...180
    (f x)))
```

### gen/sample Misleading Output

`gen/sample` starts at size=0, so first 10 values are small. Use `gen/generate` with explicit size:

```clojure
(gen/generate my-gen 100)  ; See values at size=100
```

### Nested Collections Explosion

Nested collection generators can produce enormous output:

```clojure
;; Can exhaust memory!
(-> gen/nat gen/vector gen/vector gen/vector)
```

**Fix with strategic resizing:**
```clojure
(gen/scale #(/ % 3)
           (gen/vector (gen/vector (gen/vector gen/nat))))
```

### gen/bind Hampers Shrinking

`gen/bind` (and multi-clause `gen/let`) makes shrinking less effective because the second generator depends on the first value.

**Bad (shrinks poorly):**
```clojure
(gen/let [n (gen/fmap #(* 2 %) gen/nat)]
  (gen/vector gen/large-integer n))
;; Shrunk to 70 elements instead of 2
```

**Good (shrinks well):**
```clojure
(gen/fmap #(cond-> % (odd? (count %)) pop)
          (gen/vector gen/large-integer))
;; Shrinks to [42 0]
```

**When you must use bind**, be aware that:
- Shrinking the first generator creates new second generator
- New values unlikely to also fail
- Shrinking is less effective overall

Prefer `gen/fmap` transformations when possible.
