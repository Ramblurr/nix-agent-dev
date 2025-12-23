# Coffi Type System Reference

## Table of Contents

1. [Primitive Types](#primitive-types)
2. [C-String Type](#c-string-type)
3. [Structs](#structs)
4. [Arrays](#arrays)
5. [Enums](#enums)
6. [Flagsets](#flagsets)
7. [Unions](#unions)
8. [Function Pointers](#function-pointers)
9. [Custom Types](#custom-types)


## Primitive Types

All types are keywords in the `coffi.mem` namespace.

| Type | C Equivalent | Size (bytes) | Clojure Coercion |
|------|--------------|--------------|------------------|
| `::mem/byte` | `int8_t` | 1 | `byte` |
| `::mem/short` | `int16_t` | 2 | `short` |
| `::mem/int` | `int32_t` | 4 | `int` |
| `::mem/long` | `int64_t` | 8 | `long` |
| `::mem/char` | `char` | 1 | `char` |
| `::mem/float` | `float` | 4 | `float` |
| `::mem/double` | `double` | 8 | `double` |
| `::mem/pointer` | `void*` | platform | none |
| `::mem/void` | `void` | 0 | return type only |


## C-String Type

`::mem/c-string` represents null-terminated UTF-8 strings.

- Serializes as `::mem/pointer`
- Allocates from arena using `Arena.allocateFrom`
- Deserializes by reading until null terminator

```clojure
(defcfn strlen
  strlen [::mem/c-string] ::mem/long)

(strlen "hello") ;; => 5
```


## Structs

Two ways to define structs:

### Using defalias (recommended for FFI)

```clojure
(require '[coffi.mem :as mem])
(require '[coffi.layout :as layout])

;; Without padding (fields packed)
(mem/defalias ::point
  [::mem/struct
   [[:x ::mem/float]
    [:y ::mem/float]]])

;; With C-compatible padding (use for FFI)
(mem/defalias ::aligned-struct
  (layout/with-c-layout
    [::mem/struct
     [[:a ::mem/char]
      [:x ::mem/double]
      [:y ::mem/float]]]))
```

### Using defstruct (creates record-like type)

```clojure
(mem/defstruct Point [x ::mem/float y ::mem/float])

;; Create instances
(Point. 1.0 2.0)

;; Returned as maps from native
{:x 1.0 :y 2.0}
```

### Struct Serialization

Structs serialize to/from Clojure maps:

```clojure
;; Serialize
(mem/serialize {:x 1.0 :y 2.0} ::point arena)

;; Deserialize
(mem/deserialize segment ::point)
;; => {:x 1.0 :y 2.0}
```

### Nested Structs

```clojure
(mem/defalias ::rect
  (layout/with-c-layout
    [::mem/struct
     [[:origin ::point]
      [:size ::point]]]))

;; Usage
{:origin {:x 0.0 :y 0.0}
 :size {:x 100.0 :y 50.0}}
```


## Arrays

Fixed-size arrays: `[::mem/array element-type count]`

```clojure
;; Array of 10 ints
[::mem/array ::mem/int 10]

;; Serialize from vector
(mem/serialize [1 2 3 4 5] [::mem/array ::mem/int 5] arena)

;; Deserialize to vector
(mem/deserialize segment [::mem/array ::mem/int 5])
;; => [1 2 3 4 5]
```

### Raw Arrays (for performance)

Use `:raw? true` to get native Java arrays instead of vectors:

```clojure
;; Deserialize to int[]
(mem/deserialize segment [::mem/array ::mem/int 5 :raw? true])
;; => #object[int[] ...]

;; Serialize from Java array
(mem/serialize (int-array [1 2 3]) [::mem/array ::mem/int 3 :raw? true] arena)
```


## Enums

Map symbolic names to integer values.

### Map form

```clojure
(mem/defalias ::color
  [::mem/enum {:red 0 :green 1 :blue 2}])

(mem/serialize :green ::color arena) ;; => 1
(mem/deserialize segment ::color)    ;; => :green
```

### Vector form (C-style auto-counting)

```clojure
(mem/defalias ::color
  [::mem/enum [:red :green :blue]])
;; :red=0, :green=1, :blue=2
```

### Custom representation

Default is `::mem/int`. Override with `:repr`:

```clojure
[::mem/enum {:a 0 :b 1} :repr ::mem/byte]
```


## Flagsets

Bit flags that serialize to/from sets.

```clojure
(mem/defalias ::flags
  [::mem/flagset {:read 1 :write 2 :exec 4}])

(mem/serialize #{:read :write} ::flags arena) ;; => 3
(mem/deserialize segment ::flags)             ;; => #{:read :write}
```


## Unions

Unions overlay multiple types in the same memory.

```clojure
[::mem/union
 #{::mem/float ::mem/int}
 :dispatch #(if (float? %) ::mem/float ::mem/int)]
```

- `:dispatch` - function to select type for serialization
- `:extract` - optional function to extract value before serialization

Deserialization returns raw segment (must deserialize manually with known type).


## Function Pointers

For callbacks from native code to Clojure.

```clojure
[::ffi/fn [arg-types...] return-type]

;; Example: qsort comparator
[::ffi/fn [::mem/pointer ::mem/pointer] ::mem/int]
```

### Creating Callbacks

```clojure
(defcfn qsort
  qsort [::mem/pointer    ;; array
         ::mem/long       ;; count
         ::mem/long       ;; element size
         [::ffi/fn [::mem/pointer ::mem/pointer] ::mem/int]] ;; comparator
  ::mem/void)

;; Pass Clojure fn as callback
(qsort arr-ptr count size
  (fn [a b]
    (compare (mem/read-int a) (mem/read-int b))))
```

### Callback Lifetime Warning

- Callbacks can be GC'd if not retained
- If native code stores callback for later, keep a reference
- Exceptions in callbacks crash the JVM - wrap with try/catch


## Custom Types

Extend the type system via multimethods.

### Primitive-based Custom Type

For types that serialize to a single primitive:

```clojure
;; Type that serializes to pointer
(defmethod mem/primitive-type ::vector3
  [_type]
  ::mem/pointer)

(defmethod mem/serialize* ::vector3
  [obj _type arena]
  (mem/serialize obj [::mem/array ::mem/float 3] arena))

(defmethod mem/deserialize* ::vector3
  [segment _type]
  (mem/deserialize
    (mem/reinterpret segment (mem/size-of [::mem/array ::mem/float 3]))
    [::mem/array ::mem/float 3]))
```

### Composite Custom Type

For types with their own memory layout:

```clojure
(defmethod mem/c-layout ::tagged-union
  [[_tagged-union tags type-map]]
  (mem/c-layout [::mem/struct
                 [[:tag ::mem/long]
                  [:value [::mem/union (vals type-map)]]]]))

(defmethod mem/serialize-into ::tagged-union
  [obj [_tagged-union tags type-map] segment arena]
  ;; Write to segment
  )

(defmethod mem/deserialize-from ::tagged-union
  [segment [_tagged-union tags type-map]]
  ;; Read from segment
  )
```

### Type Query Functions

```clojure
(mem/primitive? ::mem/int)    ;; => true
(mem/primitive? ::point)      ;; => false
(mem/size-of ::mem/int)       ;; => 4
(mem/size-of ::point)         ;; => 8
(mem/align-of ::mem/double)   ;; => 8
```
