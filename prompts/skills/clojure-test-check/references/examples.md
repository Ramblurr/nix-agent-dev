# Generator Examples

## Table of Contents
- [Basic Transformations](#basic-transformations)
- [Constrained Values](#constrained-values)
- [Dependent Generation](#dependent-generation)
- [Custom Types](#custom-types)
- [Recursive Structures](#recursive-structures)

## Basic Transformations

**Range of integers:**
```clojure
(def five-through-nine (gen/choose 5 9))
```

**Random element from collection:**
```clojure
(def language (gen/elements ["clojure" "haskell" "erlang"]))
```

**Even positive integers:**
```clojure
(def even-positive (gen/fmap #(* 2 %) gen/nat))
```

**Powers of two:**
```clojure
(def powers-of-two (gen/fmap #(bit-shift-left 1 %) (gen/choose 0 30)))
```

**Sorted vectors:**
```clojure
(def sorted-vec (gen/fmap sort (gen/vector gen/small-integer)))
```

**Sets from vectors:**
```clojure
(gen/fmap set (gen/vector gen/nat))
```

## Constrained Values

**Integer or nil:**
```clojure
(def int-or-nil (gen/one-of [gen/small-integer (gen/return nil)]))
```

**Mostly integers (90%), sometimes nil:**
```clojure
(def mostly-ints (gen/frequency [[9 gen/small-integer] [1 (gen/return nil)]]))
```

**Anything except specific value:**
```clojure
(def anything-but-five (gen/such-that #(not= % 5) gen/small-integer))
```

**Non-empty collections:**
```clojure
(gen/not-empty (gen/vector gen/boolean))
```

## Dependent Generation

**Vector and random element from it:**
```clojure
(def vec-and-elem
  (gen/bind (gen/not-empty (gen/vector gen/small-integer))
            #(gen/tuple (gen/return %) (gen/elements %))))
```

**Using gen/let for cleaner syntax:**
```clojure
(def vec-and-elem
  (gen/let [v (gen/not-empty (gen/vector gen/small-integer))
            e (gen/elements v)]
    {:vector v :element e}))
```

**Map with subset of keys:**
```clojure
(def partial-map
  (gen/let [ks (gen/not-empty (gen/vector gen/keyword))
            selected (gen/set (gen/elements ks))]
    (zipmap selected (repeat :value))))
```

## Custom Types

**Simple record:**
```clojure
(defrecord Point [x y])

(def point-gen
  (gen/fmap (partial apply ->Point)
            (gen/tuple gen/small-integer gen/small-integer)))
```

**Complex record with custom fields:**
```clojure
(defrecord User [username user-id email active?])

(def domain (gen/elements ["gmail.com" "example.org"]))

(def email-gen
  (gen/fmap (fn [[name domain]] (str name "@" domain))
            (gen/tuple gen/string-alphanumeric domain)))

(def user-gen
  (gen/fmap (partial apply ->User)
            (gen/tuple gen/string-alphanumeric
                       gen/nat
                       email-gen
                       gen/boolean)))
```

**Maps with specific structure:**
```clojure
(def config-gen
  (gen/hash-map
    :port (gen/choose 1024 65535)
    :host (gen/elements ["localhost" "0.0.0.0"])
    :debug? gen/boolean
    :timeout (gen/fmap #(* 100 %) gen/nat)))
```

## Recursive Structures

**Nested vectors:**
```clojure
(def nested-bools (gen/recursive-gen gen/vector gen/boolean))
;; => [[[true] false] [[] []]]
```

**JSON-like structures:**
```clojure
(def compound
  (fn [inner]
    (gen/one-of [(gen/list inner)
                 (gen/map gen/keyword inner)])))

(def json-like
  (gen/recursive-gen compound
                     (gen/one-of [gen/small-integer gen/boolean gen/string])))
```

**Binary trees:**
```clojure
(defrecord Node [value left right])
(defrecord Leaf [value])

(def tree-gen
  (gen/recursive-gen
    (fn [inner]
      (gen/fmap (fn [[v l r]] (->Node v l r))
                (gen/tuple gen/small-integer inner inner)))
    (gen/fmap ->Leaf gen/small-integer)))
```

**S-expressions:**
```clojure
(def sexp-gen
  (gen/recursive-gen
    gen/list
    (gen/one-of [gen/symbol gen/small-integer gen/keyword])))
```

## Even-Length Collections (Shrink-Friendly)

**Bad approach (shrinks poorly):**
```clojure
(gen/let [n (gen/fmap #(* 2 %) gen/nat)]
  (gen/vector gen/large-integer n))
```

**Good approach (shrinks well):**
```clojure
(gen/fmap #(cond-> % (odd? (count %)) pop)
          (gen/vector gen/large-integer))
```
