# Clojure Style Guide

## Core Principles

1. Code is written for humans; optimize readability
2. Prefer functional approaches and immutable data
3. Consistency: project > file > form > this guide
4. Deviate only when readability, compatibility, or history demand it


## Layout & Formatting

### Indentation

Spaces only, no tabs.
2-space indent for body forms: `def`, `defn`, `let`, `when`, `cond`, `case`, `with-*`, `loop`, etc.
Vertically align fn args spanning lines, or 1-space indent if no args on first line.

```clojure
(when something
  (something-else))

(filter even?
        (range 1 10))

(filter
 even?
 (range 1 10))
```

### Alignment

Vertically align `let` bindings and map keys:

```clojure
(let [thing1 "x"
      thing2 "y"] ...)

{:name "Bruce"
 :age  30}
```

### Line Length & Whitespace

- Max 80 chars preferred (120 absolute max)
- Unix line endings, newline at EOF
- No trailing whitespace
- Single blank line between top-level forms (group related `def`s together)
- No blank lines within function bodies

### Brackets & Parens

- Space before opening bracket if preceded by text; space after closing if followed by text
- No space inside brackets: `(foo (bar baz) quux)`
- Gather trailing parens on single line (exception: `comment` form)
- No commas in vectors/lists; optional in maps for readability


## Namespace Declarations

### Structure

```clojure
(ns project.module
  (:refer-clojure :exclude [next replace])
  (:require
   [clojure.string :as str]
   [clojure.set :as set])
  (:import
   java.util.Date
   [java.util.concurrent Executors LinkedBlockingQueue]))
```

### Rules

- Avoid single-segment namespaces; use `project.module` or `org.project.module`
- Max 5 segments
- Prefer `:require :as` > `:require :refer` > `:require :refer :all`; avoid `:use`
- Sort requirements alphabetically
- One file per namespace, one namespace per file

### Idiomatic Aliases

| Namespace | Alias |
|-----------|-------|
| clojure.string | str |
| clojure.set | set |
| clojure.java.io | io |
| clojure.edn | edn |
| clojure.walk | walk |
| clojure.pprint | pp |
| clojure.spec.alpha | s |
| clojure.core.async | async |
| clojure.tools.logging | log |


## Naming

### Case Conventions

- `lisp-case`: functions, variables, namespace segments
- `CapitalCase`: protocols, records, structs, types (keep acronyms uppercase: HTTP, XML)

### Suffixes & Prefixes

- `?` suffix: predicates returning boolean (`even?`, `palindrome?`)
- `!` suffix: STM-unsafe/mutating functions (`reset!`, `swap!`)
- `->` infix: conversions (`f->c`)
- `*earmuffs*`: dynamic vars (`^:dynamic *config*`)
- `_` or `_name`: unused bindings

### Function Naming

Following Stuart Sierra conventions:

- Pure functions: nouns describing return value (`age` not `get-age`)
- Side-effect functions: verbs (`create-user`, `fetch-data`, `send-message`)
- Coercions (multiple input types → one output): name for output (`file`, `reader`)
- Conversions (specific input→output): `input->output`
- Don't repeat namespace in function name (`products/price` not `products/product-price`)
- Functions returning functions: suffix with `-fn` if not a standard pattern

### Idiomatic Parameter Names

`f g h` fn | `n` int size | `i` index | `x y` numbers | `xs` seq | `m` map | `k v` key/value | `s` string | `coll` collection | `pred` predicate | `xf` transducer | `expr body binding` in macros | `this` in protocols


## Functions

### Definition Style

```clojure
(defn foo [x]
  (bar x))

(defn foo
  [x]
  (bar x))

;; multi-arity: fewest→most args, align bodies
(defn foo
  ([x]
   (foo x 1))
  ([x y]
   (+ x y)))

;; multimethod: dispatch-val on same line
(defmethod foo :bar [x]
  (baz x))
```

### Guidelines

- Functions <10 LOC ideal, <5 LOC better (smaller functions reduce tokens and make edits faster)
- Max 3-4 positional parameters
- Use pre/post conditions over internal checks: `{:pre [(pos? x)]}`
- Functions should do one thing
- Pure functions preferred over functions with side effects
- Return useful values that callers can use

### Variable Binding

Minimize code by avoiding unnecessary `let` bindings:

```clojure
;; avoid: binding used only once
(let [result (process x)]
  (send result))

;; prefer: inline
(send (process x))

;; use let when: value used multiple times OR clarity demands it
(let [user (fetch-user id)]
  (log/info "Found" (:name user))
  (validate user)
  (save user))
```

### Destructuring

Use destructuring in function parameters when accessing multiple keys:

```clojure
;; prefer
(defn process [{:keys [id name email]}]
  ...)

;; for namespaced keys
(defn process [{:keys [::zloc ::match-form] :as ctx}]
  ...)
```


## Control Flow & Idioms

### Conditionals

```clojure
;; use when (not if with single branch)
(when pred (foo) (bar))

;; use if-let/when-let for binding and testing
(if-let [result (foo)] (use result) (fallback))
(when-let [result (foo)] (use result))

;; use if-not/when-not
(if-not pred (foo))
(when-not pred (foo) (bar))

;; use not=
(not= a b)

;; cond: use :else for default
(cond
  (neg? n) "negative"
  (pos? n) "positive"
  :else "zero")

;; condp when predicate constant
(condp = x
  10 :ten
  20 :twenty
  :dunno)

;; case for compile-time constants (fastest)
(case x
  10 :ten
  20 :twenty
  :dunno)

;; cond-> and cond->> for conditional threading
(cond-> m
  add-foo? (assoc :foo 1)
  add-bar? (assoc :bar 2))
```

Use `if` for single condition checks, not `cond`.
Use `cond` only for multiple condition branches.

### Threading

Prefer threading over nesting to eliminate intermediate bindings:

```clojure
(-> x foo :bar first frob)
(->> coll (filter even?) (map inc) (take 5))

;; omit parens when no extra args
(-> x foo :bar)
```

### Common Patterns

```clojure
;; nil punning
(when (seq s) ...)

;; conversions
(vec some-seq)
(boolean x)

;; sets as predicates
(filter #{1 2 3} coll)
(remove #{\a \e} s)

;; prefer inc/dec, pos?/neg?/zero?
(inc x)
(pos? x)

;; comparison chains
(< 5 x 10)

;; function literals
#(foo %)       ; single param
#(foo %1 %2)   ; multiple params
```

### Control Flow Design

- Track actual values instead of boolean flags where possible
- Use early returns with `when` rather than deeply nested conditionals
- Return `nil` for "not found" conditions rather than objects with boolean flags

### Avoid

- Unnecessary anonymous wrappers: `(map even? coll)` not `(map #(even? %) coll)`
- `complement`/`comp`/`partial` when anonymous fn is clearer
- Multiple forms in `#()` literals (use `fn` instead)
- `def` inside functions
- Shadowing `clojure.core` names
- Forward references (use `declare` if necessary)


## Data Structures

- Prefer vectors over lists for data
- Keywords for map keys: `{:name "x"}` not `{"name" "x"}`
- Use literal syntax: `[1 2 3]` `#{1 2 3}` `{:a 1}`
- Keywords as functions: `(:name m)` not `(get m :name)`
- Avoid transient/Java collections except for performance-critical code
- Avoid index-based access


## Types & Records

```clojure
;; use generated constructors
(->Foo 1 2)
(map->Foo {:a 1 :b 2})

;; not interop syntax
(Foo. 1 2)  ; avoid

;; custom constructors: don't override ->Foo
(defn make-foo [x]
  {:pre [(pos? x)]}
  (->Foo x))
```


## Mutation & Concurrency

### Refs

- Wrap I/O in `io!` macro
- Prefer `alter` over `ref-set`
- Keep transactions small
- Don't mix long & short txns on same ref

### Atoms

- Avoid updates inside STM transactions
- Prefer `swap!` over `reset!`

### Agents

- `send` for CPU-bound actions
- `send-off` for blocking/I/O actions


## Strings, Math & Java Interop

Prefer Clojure functions over Java interop:

```clojure
;; strings: use clojure.string
(str/ends-with? s ".txt")    ; not (.endsWith s ".txt")
(str/starts-with? s "http")  ; not (.startsWith s "http")
(str/includes? s "foo")      ; not (.contains s "foo")
(str/blank? s)               ; not (.isEmpty s)

;; math: use clojure.math (Clojure 1.11+)
(math/pow 2 10)              ; not (Math/pow 2 10)
```

### Sugared Interop Forms

```clojure
(ArrayList. 100)        ; not (new ArrayList 100)
(.substring "hi" 1 2)   ; not (. "hi" substring 1 2)
Integer/MAX_VALUE       ; not (. Integer MAX_VALUE)
```

### Exceptions

- Reuse standard exception types
- Prefer `with-open` over `finally`


## Macros

- Don't write macro if function suffices
- Write usage example first
- Break into smaller helper functions
- Core logic in plain function, macro provides syntax sugar
- Prefer syntax-quote over manual list building


## Metadata

```clojure
;; compact notation for true flags
(def ^:private x 5)
(defn- private-fn [] ...)

;; version metadata
(def ^{:added "1.0" :deprecated "2.0" :superseded-by "bar"} foo ...)

;; exclude from docs
(defn ^:no-doc internal-helper [] ...)

;; see-also
(def ^{:see-also ["bar" "other.ns/baz"]} foo ...)
```

Public API metadata keys: `:added`, `:changed`, `:deprecated`, `:superseded-by`, `:supersedes`, `:see-also`, `:no-doc`


## Comments

Minimize comments.
Prefer self-explanatory code.
Do not add comments unless the code is complex and requires additional context.

```clojure
;;;; Section headings (4 semicolons)

;;; Top-level comments (3 semicolons)

(defn foo []
  ;; Code fragment comments (2 semicolons)
  (bar)
  x)  ; Margin comments (1 semicolon, rare)

;; prefer #_ to comment out forms
(+ foo #_(bar) baz)

;; annotations: TODO, FIXME, OPTIMIZE, HACK, REVIEW
;; format above code, not inline
;; FIXME: Description here. (initials date)
```

Do not create comments that act as section separators (e.g., `;; =====` or `;; -----`).


## Docstrings

```clojure
(defn process-users
  "Filters and transforms users based on `criteria`.

  Returns a sequence of user maps with `:status` added.
  See also [[validate-user]] and [[user.db/save!]].

  Options map supports:
  | key        | description                    |
  |------------|--------------------------------|
  | `:active`  | include only active users      |
  | `:limit`   | max users to return            |

  \```clojure
  (process-users db {:active true :limit 10})
  ;; => [{:id 1 :name \"Alice\" :status :processed} ...]
  \```
  "
  [db criteria]
  ...)
```

### Docstring Guidelines

- First line: complete sentence summarizing function
- Wrap arguments and special keywords in backticks: `` `x` ``
- Link to other vars with wikilink syntax: `[[other-fn]]` or `[[other.ns/fn]]`
- Use Markdown tables for complex options maps
- Include small code examples showing typical usage
- Place docstring after fn name, not after arg vector
- Exception: defprotocol methods have docstring after args


## REPL Best Practices

### Context Maintenance

```clojure
;; always reload namespaces to get latest code
(require '[my.namespace] :reload)

;; switch into namespace you're working on
(in-ns 'my.namespace)

;; keep references fully qualified when crossing namespace boundaries
(other.ns/some-fn x)
```

### Shell Commands

When executing shell commands:

```clojure
(require '[clojure.java.shell :as shell])

;; use explicit working directory for relative paths
(shell/sh "cmd" :dir "/path")
```


## Testing

### Structure

- Directory: `test/project/`
- Namespace: `project.module-test`
- Test names: `something-test` (with `deftest`)

### Guidelines

```clojure
(ns project.core-test
  (:require [clojure.test :refer [deftest testing is are use-fixtures]]
            [project.core :as core]))

(deftest addition-test
  (testing "positive numbers"
    (is (= 4 (core/add 2 2)))))
```

- Use `is`, `are`, `testing`, `use-fixtures`
- Simple assertions: `(is (= expected actual))`
- Descriptive names including edge cases
- Isolated, deterministic, focused tests
- AAA pattern: Arrange-Act-Assert
- Mock external dependencies
- Test both normal execution paths and error conditions
- Always reload namespaces before running tests: `(require '[namespace] :reload)`
