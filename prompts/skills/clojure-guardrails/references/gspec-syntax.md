# Gspec Syntax Reference

## Table of Contents

1. [Syntax Overview](#syntax-overview)
2. [Operators](#operators)
3. [Argument Specifications](#argument-specifications)
4. [Return Specifications](#return-specifications)
5. [Constraints](#constraints)
6. [Multi-arity Functions](#multi-arity-functions)
7. [Variadic Functions](#variadic-functions)
8. [Nested Gspecs](#nested-gspecs)
9. [Malli Schema Types](#malli-schema-types)
10. [Registry Usage](#registry-usage)

## Syntax Overview

The gspec appears as the first form after the argument vector in `>defn`:

```clojure
(>defn function-name
  "docstring"
  [arg1 arg2]
  [spec1 spec2 => ret-spec]  ; <-- gspec
  (body))
```

**Full syntax:**
```
[arg-specs* (| arg-preds+)? => ret-spec (| ret-preds+)?]
```

## Operators

| Operator | Keyword | Purpose |
|----------|---------|---------|
| `=>` | `:ret` | Separates argument specs from return spec |
| `\|` | `:st` | "Such that" - adds predicate constraints |
| `?` | - | Shorthand for `[:maybe schema]` (nilable) |

Operators and keywords are interchangeable:
```clojure
;; These are equivalent:
[:int :int => :int]
[:int :int :ret :int]
```

## Argument Specifications

Each argument must have a corresponding spec (count must match):

```clojure
(>defn process [a b c]
  [:int :string :boolean => :any]
  ...)
```

### Spec Elements

Argument specs can be:

| Type | Example |
|------|---------|
| Keywords | `:int`, `:string`, `:boolean`, `:any` |
| Registered schemas | `:user/id`, `:app/config` |
| Inline schemas | `[:map [:id :int]]` |
| Predicates | `pos-int?`, `string?` |
| Sets | `#{:a :b :c}` |
| Nested gspecs | `[:=> [:cat :int] :string]` |

## Return Specifications

The return spec follows `=>`:

```clojure
;; Simple return
[:int => :string]

;; Nilable return
[:int => (? :user/record)]

;; Collection return
[:string => [:vector :int]]
```

## Constraints

The `|` operator adds predicate constraints that must be satisfied.

### Argument Constraints

Predicates on input arguments:

```clojure
(>defn divide [a b]
  [:number :number | #(not (zero? b))  ; b cannot be zero
   => :number]
  (/ a b))
```

### Return Constraints

Predicates that can reference both return value (`%`) and arguments:

```clojure
(>defn ranged-rand [start end]
  [:int :int | #(< start end)           ; arg constraint
   => :int | #(>= % start) #(< % end)]  ; return constraints
  (+ start (long (rand (- end start)))))
```

### Multiple Constraints

Multiple predicates are combined with AND:

```clojure
[:int :int | #(pos? a) #(pos? b) #(< a b)
 => :int | #(> % a) #(> % b)]
```

## Multi-arity Functions

Each arity has its own gspec:

```clojure
(>defn greet
  ([name]
   [:string => :string]
   (str "Hello, " name))

  ([greeting name]
   [:string :string => :string]
   (str greeting ", " name))

  ([greeting name punctuation]
   [:string :string :string => :string]
   (str greeting ", " name punctuation)))
```

## Variadic Functions

Use `[:* schema]` for rest arguments:

```clojure
(>defn sum [x & more]
  [:int [:* :int] => :int]
  (apply + x more))

(>defn log [level & messages]
  [:keyword [:* :string] => :nil]
  (println level (str/join " " messages)))
```

For one-or-more, use `[:+ schema]`:

```clojure
(>defn concat-all [& strings]
  [[:+ :string] => :string]
  (apply str strings))
```

## Nested Gspecs

When a function takes or returns another function:

```clojure
;; Function that returns a function
(>defn make-adder [n]
  [:int => [:=> [:cat :int] :int]]
  (fn [x] (+ x n)))

;; Function that takes a function
(>defn apply-twice [f x]
  [[:=> [:cat :int] :int] :int => :int]
  (f (f x)))
```

### Higher-order with map

```clojure
(>defn map-indexed-fn [f coll]
  [[:=> [:cat :int :any] :any] (? [:sequential :any]) => [:sequential :any]]
  (map-indexed f coll))
```

## Malli Schema Types

### Primitive Types

```clojure
:int :string :boolean :keyword :symbol :uuid :nil :any
:double :float :number
pos-int? neg-int? nat-int?
```

### Collections

```clojure
[:vector :int]           ; vector of ints
[:set :string]           ; set of strings
[:sequential :any]       ; any sequential
[:map :int :string]      ; map int->string
```

### Maps

```clojure
;; Required keys
[:map [:id :int] [:name :string]]

;; Optional keys
[:map [:id :int] [:name {:optional true} :string]]

;; Qualified keys
[:map :user/id :user/name]
```

### Unions and Intersections

```clojure
[:or :int :string]         ; int or string
[:and :int pos-int?]       ; positive int
```

### Constrained Types

```clojure
[:int {:min 0 :max 100}]   ; bounded int
[:string {:min 1 :max 50}] ; string with length bounds
```

## Registry Usage

### Registering Schemas

```clojure
(require '[com.fulcrologic.guardrails.malli.core :refer [>def]])

(>def :user/id :uuid)
(>def :user/name [:string {:min 1}])
(>def :user/email [:re #"^[^@]+@[^@]+$"])

(>def :user/record
  [:map
   [:user/id :user/id]
   [:user/name :user/name]
   [:user/email {:optional true} :user/email]])
```

### Using Registered Schemas

```clojure
(>defn create-user [name]
  [:user/name => :user/record]
  {:user/id (random-uuid)
   :user/name name})

(>defn find-user [id]
  [:user/id => (? :user/record)]
  (get @users id))
```

### Merging External Schemas

```clojure
(require '[com.fulcrologic.guardrails.malli.registry :as gr.reg])

;; Merge a map of schemas
(gr.reg/merge-schemas!
  {:app/config [:map [:debug :boolean]]
   :app/state  [:map [:initialized :boolean]]})
```

## Common Patterns

### CRUD Operations

```clojure
(>defn create [data]
  [:user/input => :user/record]
  ...)

(>defn read [id]
  [:user/id => (? :user/record)]
  ...)

(>defn update [id data]
  [:user/id :user/partial => (? :user/record)]
  ...)

(>defn delete [id]
  [:user/id => :boolean]
  ...)
```

### Validation Functions

```clojure
(>defn valid-email? [s]
  [:string => :boolean]
  (re-matches #"^[^@]+@[^@]+$" s))

(>defn parse-int [s]
  [:string => (? :int)]
  (try (Integer/parseInt s) (catch Exception _ nil)))
```

### Collection Processing

```clojure
(>defn filter-active [users]
  [[:vector :user/record] => [:vector :user/record]]
  (filterv :active users))

(>defn group-by-role [users]
  [[:vector :user/record] => [:map :keyword [:vector :user/record]]]
  (group-by :role users))
```
