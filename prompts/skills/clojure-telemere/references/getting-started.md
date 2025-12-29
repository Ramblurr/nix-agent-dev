# Getting Started with Telemere

Telemere is a structured telemetry library that helps you create observable Clojure/Script systems.

## What is Structured Telemetry?

Traditional logging outputs strings (messages). Structured logging outputs data - retaining rich data types and nested structures throughout the pipeline from callsite to handlers.

A data-oriented pipeline enables:
- Easier filtering and transformation
- Better analysis and querying
- Usually faster (pay for serialization only when needed)
- Well-suited to Clojure/Script idioms

## Signals

The basic unit in Telemere is the signal - a plain Clojure/Script map with attributes.

Signals include:
- Traditional log messages
- Structured log messages
- Events
- Traces
- Performance measurements

All signals:
- Occur at a particular location (namespace, line, column)
- Occur within a particular program state/context
- Convey something valuable about that state/context

Signals may be independently valuable, valuable in aggregate (statistically), or valuable in association with other signals (e.g., tracing).

## Basic Tools

1. **Signal creators** - conditionally create signal maps at points in your code
2. **Signal handlers** - conditionally handle those signals (write to console/file/DB, etc.)

## Setup

```clojure
;; deps.edn
com.taoensso/telemere {:mvn/version "1.2.1"}

;; Leiningen
[com.taoensso/telemere "1.2.1"]
```

```clojure
(ns my-app
  (:require [taoensso.telemere :as tel]))
```

## Default Configuration

Telemere works out-of-the-box with sensible defaults:

- **Default min level**: `:info` (signals below this level noop)
- **Default handlers**:
  - Clj: Console handler printing to `*out*` or `*err*`
  - Cljs: Console handler printing to browser console

- **Default interop** (Clj only):
  - SLF4J logging (if SLF4J API + telemere-slf4j backend present)
  - tools.logging (if present and `tools-logging->telemere!` called)
  - System streams (if `streams->telemere!` called)

## Creating Signals

The low-level `signal!` macro creates all signals. Wrapper macros provide ergonomic shortcuts:

```clojure
;; Traditional logging
(tel/log! "Something happened")
(tel/log! :warn "Warning message")

;; Structured logging
(tel/event! ::user-login {:level :info, :data {:user-id 42}})

;; Mixed approach
(tel/log! {:level :info
           :id ::user-login
           :data {:user-id 42}}
  "User logged in")

;; Tracing (captures runtime, return value, parent chain)
(tel/trace! {:id ::processing}
  (expensive-operation))

;; All wrappers can use full opts map
(tel/log!
  {:level :debug
   :id ::my-id
   :let [x (expensive-calc)]
   :data {:result x}
   :sample 0.5
   :when (feature-enabled?)}
  ["Result:" x])
```

## Signal Options Quick Reference

Common options (all optional):
- `:level` - `:trace`, `:debug`, `:info`, `:warn`, `:error`, `:fatal`, or integer
- `:id` - qualified keyword identifying this signal type
- `:data` - structured data map
- `:msg` - message string or vector
- `:let` - bindings available to `:data` and `:msg`
- `:sample` - random sampling (0.0 to 1.0)
- `:when` - conditional predicate
- `:limit` - rate limit map
- `:do` - side effects

See `tel/help:signal-options` for complete details.

## Checking Signals

Use `with-signal` for debugging:

```clojure
(tel/with-signal
  (tel/log! {:let [x "x"], :data {:x x}} ["Message:" x]))
;; => {:ns "my-ns", :level :info, :id nil, :data {:x "x"}, ...}
```

- `with-signal` - returns last signal created
- `with-signals` - returns all signals created

## Basic Filtering

Filtering is O(1) and happens before signal creation:

```clojure
;; Set minimum level
(tel/set-min-level! :info)
(tel/with-signal (tel/log! {:level :info} "..."))  ; => {...}
(tel/with-signal (tel/log! {:level :debug} "...")) ; => nil (filtered)

;; Dynamic override
(tel/with-min-level :trace
  (tel/with-signal (tel/log! {:level :debug} "..."))) ; => {...}

;; Namespace filters
(tel/set-ns-filter! {:disallow "noisy.namespace.*"})

;; ID filters
(tel/set-id-filter! {:allow #{::important "my-app/*"}})

;; Per-namespace levels
(tel/set-min-level! :log "taoensso.sente.*" :warn)
```

Filters are additive - signals must pass ALL filters to be created.

See [config.md](./config.md) and `tel/help:filters` for complete filtering capabilities.

## Signal Handlers

Handlers are functions that process created signals:

```clojure
;; Simple handler
(tel/add-handler! :my-handler
  (fn [signal]
    (println "Signal ID:" (:id signal))))

;; Handler with shutdown cleanup
(tel/add-handler! :my-handler
  (fn
    ([signal] (save-to-db signal))
    ([] (close-db))))  ; Called on stop-handlers!

;; Handler with filtering and async
(tel/add-handler! :my-handler my-handler-fn
  {:async {:mode :dropping
           :buffer-size 1024}
   :min-level :warn
   :sample 0.5})
```

Built-in handlers:
```clojure
;; Console (human-readable)
(tel/handler:console {:output-fn (tel/format-signal-fn {})})

;; Console (EDN)
(tel/handler:console {:output-fn (tel/pr-signal-fn {:pr-fn :edn})})

;; File (Clj only)
(tel/handler:file {:path "./logs/app.log"})
```

See [handlers.md](./handlers.md) for details on all included handlers.

## Shutdown

Always stop handlers on application shutdown:

```clojure
(defn -main [& args]
  ;; ... app code ...
  (tel/stop-handlers!))  ; Flush buffers, close resources

;; Or use shutdown hook
(tel/call-on-shutdown!
  (fn [] (tel/stop-handlers!)))
```

`stop-handlers!` blocks to finish async handling (default max 6 seconds per handler).

## Checking Interop

Verify external integrations with:

```clojure
(tel/check-interop)
;; =>
{:tools-logging  {:present? false}
 :slf4j          {:present? true, :telemere-receiving? true}
 :open-telemetry {:present? true, :use-tracer? false}
 :system/out     {:telemere-receiving? false}
 :system/err     {:telemere-receiving? false}}
```

## Internal Help

All help available from your REPL:

```clojure
tel/help:signal-creators         ; Creating signals
tel/help:signal-options          ; Signal options
tel/help:signal-content          ; Signal map keys
tel/help:filters                 ; Filtering & transforms
tel/help:handlers                ; Handler management
tel/help:handler-dispatch-options ; Handler config
tel/help:environmental-config    ; JVM/env config
```

## Next Steps

- See [architecture.md](./architecture.md) for signal flow visualization
- See [config.md](./config.md) for advanced filtering and interop
- See [handlers.md](./handlers.md) for handler details
- See [tips.md](./tips.md) for best practices

For complete details, visit the [Telemere Wiki](https://github.com/taoensso/telemere/wiki).
