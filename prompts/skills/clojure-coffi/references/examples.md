# Coffi Real-World Examples

## Table of Contents

1. [Library Loading](#library-loading)
2. [Simple Function Wrapping](#simple-function-wrapping)
3. [Output Parameters](#output-parameters)
4. [Struct Handling](#struct-handling)
5. [Blob and Array Handling](#blob-and-array-handling)
6. [Static Variables](#static-variables)
7. [Callbacks](#callbacks)
8. [Variable-Length Arrays](#variable-length-arrays)
9. [Varargs Functions](#varargs-functions)


## Library Loading

### Platform-specific bundled library (from sqlite4clj)

```clojure
(ns mylib.native
  (:require [coffi.ffi :as ffi]
            [clojure.java.io :as io]
            [clojure.string :as str])
  (:import [java.nio.file Files]))

(defn copy-resource [resource-path output-path]
  (with-open [in  (io/input-stream (io/resource resource-path))
              out (io/output-stream (io/file output-path))]
    (io/copy in out)))

(defn get-arch+os []
  (let [os-name (str/lower-case (System/getProperty "os.name"))]
    (str (System/getProperty "os.arch") "-"
      (cond (str/includes? os-name "win") "windows"
            (str/includes? os-name "nux") "linux"
            (str/includes? os-name "mac") "macos"))))

(defn load-bundled-library []
  (let [res-file (case (get-arch+os)
                   "aarch64-linux"   "mylib_aarch64-linux.so"
                   "aarch64-macos"   "mylib_aarch64-macos.dylib"
                   ("x86-linux" "amd64-linux") "mylib_x86_64-linux.so"
                   ("x86-macos" "amd64-macos") "mylib_x86_64-macos.dylib")
        temp-file (str "mylib_temp_" res-file)]
    (copy-resource res-file temp-file)
    (ffi/load-library temp-file)
    (Files/deleteIfExists (.toPath (io/file temp-file)))))

;; Load with system property override
(let [src (System/getProperty "mylib.native-lib")]
  (cond
    (or (nil? src) (= src "bundled")) (load-bundled-library)
    (= src "system") (ffi/load-system-library "mylib")
    :else (ffi/load-library src)))
```


## Simple Function Wrapping

### Basic primitives

```clojure
(require '[coffi.ffi :as ffi :refer [defcfn]]
         '[coffi.mem :as mem])

;; Simple function with primitives
(defcfn add-numbers
  add_numbers [::mem/int ::mem/int] ::mem/int)

(add-numbers 2 3) ;; => 5

;; String argument and return
(defcfn strlen
  strlen [::mem/c-string] ::mem/long)

(strlen "hello") ;; => 5

;; Void return
(defcfn initialize
  mylib_initialize [] ::mem/void)
```

### Using cfn for anonymous functions

```clojure
;; Without defining a var
((ffi/cfn "add_numbers" [::mem/int ::mem/int] ::mem/int) 2 3)
;; => 5
```


## Output Parameters

### Pointer output parameter (from sqlite4clj)

```clojure
(defcfn open-v2
  "sqlite3_open_v2"
  [::mem/c-string ::mem/pointer ::mem/int ::mem/c-string] ::mem/int
  sqlite3-open-native
  [filename flags]
  (with-open [arena (mem/confined-arena)]
    ;; Allocate space for output pointer
    (let [pdb (mem/alloc-instance ::mem/pointer arena)
          code (sqlite3-open-native filename pdb flags nil)]
      (if (zero? code)
        ;; Read the pointer value written by native code
        (mem/deserialize-from pdb ::mem/pointer)
        (throw (ex-info "Open failed" {:code code}))))))
```

### Serialize-into pattern

```clojure
(defcfn is-42?
  "is_42" [[::mem/pointer ::mem/pointer]] ::mem/int
  native-is-42?
  [number]
  (with-open [arena (mem/confined-arena)]
    (let [int-ptr (mem/alloc-instance ::mem/int arena)]
      ;; Write value into pre-allocated memory
      (mem/serialize-into (int number) ::mem/int int-ptr arena)
      (native-is-42? int-ptr))))

(is-42? 42) ;; => non-zero (true)
(is-42? 41) ;; => 0 (false)
```


## Struct Handling

### Struct definition with defalias

```clojure
(require '[coffi.layout :as layout])

(mem/defalias ::point
  [::mem/struct
   [[:x ::mem/float]
    [:y ::mem/float]]])

;; With C-compatible padding
(mem/defalias ::alignment-test
  (layout/with-c-layout
    [::mem/struct
     [[:a ::mem/char]
      [:x ::mem/double]
      [:y ::mem/float]]]))

(defcfn add-points
  add_points [::point ::point] ::point)

(add-points {:x 1 :y 2} {:x 1 :y 0})
;; => {:x 2.0 :y 2.0}
```

### Using defstruct

```clojure
(mem/defstruct Point [x ::mem/float y ::mem/float])

;; Create with constructor
(Point. 1.0 2.0)

;; Use in function calls
(defcfn add-points
  add_points [::Point ::Point] ::Point)

(add-points (Point. 1 2) (Point. 1 0))
;; => {:x 2.0 :y 2.0}
```

### Nested structs with arrays

```clojure
(mem/defstruct ComplexType
  [x ::Point
   y ::mem/byte
   z [::mem/array ::mem/int 4 :raw? true]
   w ::mem/c-string])

(defcfn complex-test
  complexTypeTest [::ComplexType] ::ComplexType)

(complex-test
  (ComplexType. (Point. 2 3) 4 (int-array [5 6 7 8]) "hello"))
```


## Blob and Array Handling

### Reading blob with unknown size (from sqlite4clj)

```clojure
(defcfn column-blob
  "sqlite3_column_blob"
  [::mem/pointer ::mem/int] ::mem/pointer
  sqlite3_column_blob-native
  [stmt idx]
  (let [result (sqlite3_column_blob-native stmt idx)
        size (column-bytes stmt idx)  ;; Get size from another call
        ;; Reinterpret raw pointer as array of known size
        blob (mem/deserialize
               (mem/reinterpret result
                 (mem/size-of [::mem/array ::mem/byte size]))
               [::mem/array ::mem/byte size :raw? true])]
    blob))
```

### Serializing arrays

```clojure
(defcfn bind-blob
  "sqlite3_bind_blob"
  [::mem/pointer ::mem/int ::mem/pointer ::mem/int ::mem/pointer] ::mem/int
  sqlite3-bind-blob-native
  [pdb idx blob]
  (let [blob-l (count blob)]
    (sqlite3-bind-blob-native pdb idx
      ;; Serialize byte array to native memory
      (mem/serialize blob [::mem/array ::mem/byte blob-l])
      blob-l
      transient-ptr)))
```


## Static Variables

### Mutable static variables

```clojure
;; Define a reference to a native static variable
(ffi/defvar counter "counter" ::mem/int)

;; Read value
@counter ;; => current value

;; Set value
(ffi/freset! counter 42)

;; Update value
(ffi/fswap! counter inc)
```

### Using static-variable directly

```clojure
(let [mut-str (ffi/static-variable "mut_str" ::mem/c-string)]
  (ffi/freset! mut-str nil)
  (println @mut-str)  ;; => nil
  (ffi/freset! mut-str "Hello world!")
  (println @mut-str)) ;; => "Hello world!"
```

### Constants

```clojure
;; Fetch constant value once
(def my-const (ffi/const "MY_CONST" ::mem/int))

;; Or use defconst macro
(ffi/defconst my-const "MY_CONST" ::mem/int)
```


## Callbacks

### Simple callback (upcall)

```clojure
(defcfn upcall-test
  upcall_test [[::ffi/fn [] ::mem/c-string]] ::mem/c-string)

;; Pass Clojure function as callback
(upcall-test (fn [] "hello from clojure"))
;; => "hello from clojure"
```

### Callback with arguments

```clojure
(defcfn upcall-test-int
  upcall_test [[::ffi/fn [::mem/int ::mem/int] ::mem/int]] ::mem/int)

(upcall-test-int (fn [a b] (+ a b)))
```

### Callback safety pattern

```clojure
;; Wrap callbacks to prevent JVM crashes from exceptions
(defn safe-callback [f default-value]
  (fn [& args]
    (try
      (apply f args)
      (catch Throwable t
        (println "Callback error:" (.getMessage t))
        default-value))))

(upcall-test (safe-callback my-fn "error"))
```


## Variable-Length Arrays

### Reading native-allocated array with cleanup

```clojure
;; Low-level downcalls for array functions
(def get-array* (ffi/make-downcall "get_array" [::mem/pointer] ::mem/int))
(def free-array* (ffi/make-downcall "free_array" [::mem/pointer] ::mem/void))

(defn get-variable-array []
  (with-open [arena (mem/confined-arena)]
    ;; Allocate space for output pointer
    (let [out-ptr (mem/alloc mem/pointer-size arena)
          ;; Native function writes pointer and returns count
          count (get-array* out-ptr)
          ;; Read the pointer value
          array-addr (mem/read-address out-ptr)
          ;; Reinterpret as array of known size
          array-seg (mem/reinterpret array-addr
                      (* mem/float-size count))]
      (try
        ;; Read elements manually for performance
        (loop [result (transient [])
               i 0]
          (if (>= i count)
            (persistent! result)
            (recur (conj! result (mem/read-float array-seg (* i mem/float-size)))
                   (inc i))))
        (finally
          ;; Must free native-allocated memory
          (free-array* array-addr))))))
```


## Varargs Functions

### Creating varargs function factory

```clojure
;; Create factory for printf-like function
(def printf-factory
  (ffi/vacfn-factory "printf" [::mem/c-string] ::mem/int))

;; Specialize for specific argument types
(def print-int (printf-factory ::mem/int))
(def print-float (printf-factory ::mem/double))
(def print-two-ints (printf-factory ::mem/int ::mem/int))

(print-int "Value: %d\n" 42)
(print-float "Pi: %f\n" 3.14159)
(print-two-ints "Sum: %d + %d\n" 1 2)
```
