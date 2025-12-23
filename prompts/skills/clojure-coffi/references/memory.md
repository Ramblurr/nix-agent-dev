# Coffi Memory Management Reference

## Table of Contents

1. [Arena Types](#arena-types)
2. [Allocation Functions](#allocation-functions)
3. [Serialization](#serialization)
4. [Pointer Operations](#pointer-operations)
5. [Primitive Read/Write](#primitive-readwrite)
6. [Layout Utilities](#layout-utilities)


## Arena Types

Arenas control when off-heap memory is freed.

| Arena | Thread Safety | Cleanup | Use Case |
|-------|--------------|---------|----------|
| `confined-arena` | Single thread | On `.close` | Stack-like temp allocations |
| `shared-arena` | Multi-thread | On `.close` | Cross-thread data |
| `auto-arena` | Multi-thread | GC | Long-lived, GC-managed |
| `global-arena` | Multi-thread | Never | Permanent allocations |

### Confined Arena (most common)

Thread-local, deterministic cleanup. Use with `with-open`:

```clojure
(with-open [arena (mem/confined-arena)]
  (let [ptr (mem/serialize data type arena)]
    (native-fn ptr)
    ;; Memory freed when exiting block
    ))
```

### Shared Arena

For data accessed from multiple threads:

```clojure
(def shared (mem/shared-arena))
;; ... use from multiple threads ...
(.close shared) ;; Only when all threads done
```

### Auto Arena

GC-managed, no explicit close:

```clojure
(let [arena (mem/auto-arena)]
  (mem/serialize data type arena))
;; Memory freed when GC collects
```

### Global Arena

Never freed (use sparingly):

```clojure
(mem/serialize data type (mem/global-arena))
```


## Allocation Functions

### alloc

Allocate raw bytes:

```clojure
(mem/alloc 1024)              ;; 1024 bytes, auto-arena
(mem/alloc 1024 arena)        ;; 1024 bytes in arena
(mem/alloc 1024 arena 8)      ;; 1024 bytes, 8-byte alignment
```

### alloc-instance

Allocate memory for a type:

```clojure
(mem/alloc-instance ::mem/int arena)
(mem/alloc-instance ::point arena)
```

### alloc-with

Allocate using a SegmentAllocator (for raw downcalls):

```clojure
(mem/alloc-with allocator 1024)
```


## Serialization

### High-level (recommended)

```clojure
;; Serialize: Clojure -> Native
(mem/serialize value type)        ;; auto-arena
(mem/serialize value type arena)  ;; specific arena

;; Deserialize: Native -> Clojure
(mem/deserialize segment type)
```

### Low-level (into existing segment)

```clojure
;; Write into pre-allocated segment
(mem/serialize-into value type segment arena)

;; Read from segment
(mem/deserialize-from segment type)
```

### When to Use Each

- `serialize`/`deserialize` - Most cases, allocates as needed
- `serialize-into`/`deserialize-from` - Pre-allocated buffers, performance-critical


## Pointer Operations

### Address Operations

```clojure
(mem/address-of segment)  ;; Get numeric address
(mem/null)                ;; NULL pointer
(mem/null? ptr)           ;; Check if null
(mem/address? x)          ;; Check if MemorySegment or nil
```

### Slicing

```clojure
;; Get slice starting at offset
(mem/slice segment offset)
(mem/slice segment offset size)
```

### Reinterpret

Change segment size or associate with arena:

```clojure
;; Resize segment
(mem/reinterpret segment new-size)

;; Associate with arena (for cleanup)
(mem/reinterpret segment size arena)

;; Add cleanup function
(mem/reinterpret segment size arena cleanup-fn)
```

### as-segment

Dereference pointer to segment:

```clojure
(mem/as-segment address size arena)
```

### Copying

```clojure
(mem/copy-segment src dest)     ;; Copy contents
(mem/clone-segment segment)     ;; Clone to new segment
```


## Primitive Read/Write

Direct memory access functions. All support optional offset and byte-order.

### Read Functions

```clojure
(mem/read-byte segment)
(mem/read-byte segment offset)
(mem/read-byte segment offset byte-order)

(mem/read-short segment)
(mem/read-int segment)
(mem/read-long segment)
(mem/read-char segment)
(mem/read-float segment)
(mem/read-double segment)
(mem/read-address segment)  ;; Read pointer
```

### Write Functions

```clojure
(mem/write-byte segment value)
(mem/write-byte segment offset value)
(mem/write-byte segment offset value byte-order)

(mem/write-short segment value)
(mem/write-int segment value)
(mem/write-long segment value)
(mem/write-char segment value)
(mem/write-float segment value)
(mem/write-double segment value)
(mem/write-address segment value)
```

### Bulk Read/Write

```clojure
;; Read arrays
(mem/read-bytes segment offset count)   ;; => byte[]
(mem/read-shorts segment offset count)  ;; => short[]
(mem/read-ints segment offset count)    ;; => int[]
(mem/read-longs segment offset count)   ;; => long[]
(mem/read-floats segment offset count)  ;; => float[]
(mem/read-doubles segment offset count) ;; => double[]

;; Write arrays
(mem/write-bytes segment offset byte-array)
(mem/write-ints segment offset int-array)
;; etc.
```

### Byte Order Constants

```clojure
mem/big-endian
mem/little-endian
mem/native-endian
```


## Layout Utilities

### with-c-layout

Add C-compatible padding to structs:

```clojure
(require '[coffi.layout :as layout])

(mem/defalias ::needs-padding
  (layout/with-c-layout
    [::mem/struct
     [[:a ::mem/char]    ;; 1 byte
      [:x ::mem/double]  ;; needs 8-byte alignment
      [:y ::mem/float]]]));; needs 4-byte alignment

(mem/size-of ::needs-padding)  ;; => 24 (with padding)
(mem/align-of ::needs-padding) ;; => 8
```

Without `with-c-layout`, fields are packed without padding, which may not match C struct layout.

### Struct Field Offset

Get byte offset of a field:

```clojure
(mem/struct-field-offset ::my-struct :field-name)
```
