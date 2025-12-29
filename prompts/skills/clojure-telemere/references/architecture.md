# Telemere Architecture

## Overview

Telemere's key function is to:
1. **Capture information** in running programs
2. **Facilitate processing** of that information to support insight

Basic tools:
1. **Signal creators** - conditionally create signal maps at code points
2. **Signal handlers** - conditionally handle those maps (analyze, write to console/file/DB, etc.)

## Signal Flow

The complete signal flow from creation to handling:

```
Signal Creator Call
        |
        v
[Compile-time Filters]
  - sample, kind, ns, id
  - level, when, rate limit
        |
        v
[Runtime Filters]
  - sample, kind, ns, id
  - level, when, rate limit
        |
        v
[Call Transform]
  fn[signal] => ?signal'
        |
        v
   [Cache Result] <----- Shared between handlers
        |
        v
For each Handler:
        |
        v
[Handler Filters]
  - sample, kind, ns, id
  - level, when fn, rate limit
        |
        v
[Handler Transform]
  fn[signal] => ?signal'
        |
        v
[A/sync Queue] <----- Configurable per handler
        |
        v
[Handler Function]
  - Write to console/file/DB
  - Send to service
  - Analyze/aggregate
```

Key points:

1. **Compile-time filters** - Can completely elide signal creation (zero overhead)
2. **Runtime filters** - O(1) filtering before signal map creation
3. **Call transform** - Shared cache makes expensive transforms efficient
4. **Handler filters** - Per-handler filtering (additive with call filters)
5. **Handler transform** - Per-handler signal modification
6. **A/sync queue** - Configurable async dispatch with backpressure control

## Filtering Stages

A signal reaches a handler only if ALL these pass:

### 1. Signal Call Filters

#### a. Compile-time (can elide code):
- Sample rate
- Signal kind
- Namespace pattern
- ID pattern
- Level
- When form
- Rate limit

#### b. Runtime (after elision check):
- Sample rate
- Signal kind
- Namespace pattern
- ID pattern
- Level
- When form
- Rate limit

### 2. Signal Handler Filters

Only runtime (no compile-time equivalent):
- Sample rate
- Signal kind
- Namespace pattern
- ID pattern
- Level
- When fn
- Rate limit

### 3. Transforms

- **Call transform**: `(fn [signal]) => ?signal'`
  - Returns nil to filter
  - Result cached and shared across handlers
  - Good for expensive operations

- **Handler transform**: `(fn [signal]) => ?signal'`
  - Returns nil to filter
  - Per-handler modification
  - Good for handler-specific formatting

## Filter Characteristics

- **Additive**: Handlers can be MORE restrictive than call filters, not less
- **Performance**: All filters O(1) except rate limits (O(n-windows))
- **Flexibility**: Transforms provide arbitrary signal data/content conditions

This makes sense because:
- Call filters decide if a signal CAN be created
- Handler filters decide if a PARTICULAR handler handles a created signal

## Handler Dispatch Options

Handlers can specify detailed dispatch behavior:

```clojure
{:async {:mode :dropping      ; or :blocking, :sliding
         :buffer-size 1024
         :n-threads 1}

 :priority 100                 ; Handler call order
 :sample 0.5                   ; Handler-level sampling
 :min-level :info              ; Handler-level min level
 :ns-filter {...}              ; Handler-level ns filter
 :limit {...}                  ; Handler-level rate limit
 :rate-limit-by ...            ; Rate limit scope

 ;; Advanced
 :xform (fn [signal] ...)      ; Handler transform
 :drain-msecs 6000             ; Max time to wait on stop
 :stats? true}                 ; Collect handler stats
```

### Async Modes

- `:dropping` - Drop signals when buffer full (prevents blocking)
- `:sliding` - Drop oldest signals when buffer full
- `:blocking` - Block signal creator when buffer full

Choose based on your requirements:
- `:dropping` - Best for high-throughput, tolerate loss
- `:sliding` - Keep most recent signals
- `:blocking` - Guarantee all signals handled (can slow app)

## Signal Content

Every signal is a map with these standard keys:

```clojure
{:inst   #inst "..."     ; Creation timestamp
 :ns     "my.ns"         ; Namespace
 :line   42              ; Line number
 :column 5               ; Column number
 :file   "my_ns.clj"     ; Source file

 :level  :info           ; Signal level
 :id     ::my-id         ; Signal identifier
 :kind   :log            ; Signal kind (:log, :event, :trace, etc.)

 :msg    "..."           ; Message string (if provided)
 :data   {...}           ; Structured data (if provided)
 :error  #error ...      ; Error/exception (if provided)

 :parent {...}           ; Parent trace info
 :ctx    {...}           ; Dynamic context
 :kvs    {...}           ; App-level keys collected

 :run-nsecs  1234        ; Runtime (trace!/spy! only)
 :run-value  ...         ; Return value (trace!/spy! only)

 ;; Sample rate (combined multiplicative rate)
 :sample 0.25

 ;; App-level keys also at root level
 :my-custom-key "..."}
```

The exact keys present depend on:
- Which signal creator was used
- What options were provided
- What transforms were applied

## Transform Cache

The call transform result is cached and shared between ALL handlers.

This is important for:
- **Expensive operations**: Do once, use many times
- **Side effects**: Sync with external service once per signal
- **Consistency**: All handlers see same transform result

Example use case:
```clojure
;; Sync with external trace service to get correlation ID
(tel/set-xfn!
  (fn [signal]
    (assoc signal :correlation-id
      (get-correlation-id-from-service))))  ; Called once per signal

;; All handlers see the same :correlation-id
```

## Handler Stats

Handlers maintain comprehensive stats by default:

```clojure
(tel/get-handlers-stats)
;; =>
{:my-handler
 {:counts
  {:handled 1000
   :dropped 50
   :errors  2}

  :times
  {:min-nsecs 100
   :max-nsecs 5000
   :mean-nsecs 250}}}
```

Use for:
- Debugging handler behavior
- Understanding performance
- Monitoring backpressure
- Capacity planning

## Flow Example

Here's a concrete example of signal flow:

```clojure
;; 1. Signal created
(tel/log! {:level :info
           :id ::user-action
           :data {:user-id 42}}
  "User clicked button")

;; 2. Passes compile-time filters (if any)
;; 3. Passes runtime call filters
;;    - Level :info >= min-level :info ✓
;;    - No namespace filter blocking ✓

;; 4. Signal map created
{:inst #inst "...", :level :info, :id ::user-action,
 :data {:user-id 42}, :msg "User clicked button", ...}

;; 5. Call transform applied (cached)
;; => {:correlation-id "abc123", ...}

;; 6. For each handler:
;;    a. Handler filters checked
;;    b. Handler transform applied
;;    c. Queued async (if configured)
;;    d. Handler function called

;; Handler 1: Console
;;   Formats and prints to stdout

;; Handler 2: File
;;   Formats and appends to log file

;; Handler 3: Metrics
;;   Extracts :user-id, updates counter
```

## Performance Implications

Understanding the flow helps optimize:

1. **Compile-time elision** - Zero overhead for filtered signals
2. **Early runtime filtering** - Fast rejection before map creation
3. **Lazy evaluation** - `:let`, `:data`, `:msg`, `:do` only if needed
4. **Transform caching** - Expensive work done once
5. **Async dispatch** - Non-blocking handler execution

See [tips.md](./tips.md) for performance best practices.

## For More Details

- Full architecture visualization: [Wiki Architecture](https://github.com/taoensso/telemere/wiki/2-Architecture)
- Signal flow: See the flowchart in the wiki
- Handler dispatch: See `tel/help:handler-dispatch-options`
- Filtering: See `tel/help:filters`
