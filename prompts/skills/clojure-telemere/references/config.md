# Telemere Configuration

This reference covers filtering, handlers, and interop configuration.

## Filtering

See [architecture.md](./architecture.md) for the complete filtering flow.

### Minimum Level

Set globally or per signal kind:

```clojure
;; Global minimum
(tel/set-min-level! :warn)

;; Per signal kind
(tel/set-min-level! :log :debug)   ; Just log! signals
(tel/set-min-level! :event :info)  ; Just event! signals

;; Per namespace pattern
(tel/set-min-level! :log "my.app.db.*" :warn)

;; Dynamic override
(tel/with-min-level :trace
  (tel/log! {:level :debug} "Will be created"))
```

Levels (keyword or integer):
- `:trace` (0)
- `:debug` (1)
- `:info` (2) - default
- `:warn` (3)
- `:error` (4)
- `:fatal` (5)
- Or any integer

### Namespace Filters

Allow/disallow by namespace patterns:

```clojure
;; Disallow noisy namespaces
(tel/set-ns-filter! {:disallow "taoensso.*"})

;; Allow only specific namespaces
(tel/set-ns-filter! {:allow "my.app.*"})

;; Combine (allow takes precedence)
(tel/set-ns-filter!
  {:disallow "taoensso.*"
   :allow "taoensso.sente.*"})  ; Disallow all taoensso except sente

;; Dynamic override
(tel/with-ns-filter {:allow "*"}  ; Allow all
  (tel/log! "Will be created"))
```

Patterns support wildcards:
- `"my.app.*"` - matches `my.app.foo`, `my.app.bar.baz`
- `"my.app.foo"` - exact match only

SLF4J signals use logger name as namespace (typically source class).

### ID Filters

Allow/disallow by signal ID patterns:

```clojure
;; Allow only specific IDs
(tel/set-id-filter! {:allow #{::important-event "my.app/*"}})

;; Disallow specific IDs
(tel/set-id-filter! {:disallow #{::noisy-event}})

;; Combine
(tel/set-id-filter!
  {:allow "my.app/*"
   :disallow #{::skip-this}})

;; Dynamic override
(tel/with-id-filter {:allow "*"}
  (tel/event! ::my-id))
```

### Sampling

Random sampling at call or handler level:

```clojure
;; Per-signal sampling (50%)
(tel/log! {:sample 0.5} "Sampled message")

;; Per-handler sampling
(tel/add-handler! :my-handler handler-fn
  {:sample 0.25})  ; Handle 25% of received signals

;; Multiplicative: signal 50% * handler 25% = 12.5% handled
```

Signal's `:sample` value reflects combined multiplicative rate for cardinality estimation.

### Rate Limiting

Limit by time windows:

```clojure
;; Per-signal rate limit
(tel/log!
  {:limit {"1/sec" [1 1000]      ; Max 1 per second
           "10/min" [10 60000]}} ; Max 10 per minute
  "Rate limited message")

;; Custom scope (per user, IP, etc.)
(tel/log!
  {:limit {"1/sec" [1 1000]}
   :limit-by user-id}  ; Separate limits per user-id
  "User action")

;; Per-handler rate limit
(tel/add-handler! :my-handler handler-fn
  {:limit {"1/sec" [1 1000]}})
```

Windows are sliding. Limits are per-scope (default scope is the callsite).

### Conditional Execution

```clojure
;; Signal created only when predicate true
(tel/log!
  {:when (feature-enabled? :verbose-logging)}
  "Verbose details")

;; Per-handler when function
(tel/add-handler! :my-handler handler-fn
  {:when-fn (fn [signal] (prod-environment?))})
```

`:when` is compile-time + runtime.
`:when-fn` is runtime only (for handlers).

### Transforms

Modify or filter signals with arbitrary logic:

```clojure
;; Call-level transform (shared across all handlers)
(tel/set-xfn!
  (fn [signal]
    (if (-> signal :data :skip?)
      nil  ; Filter out
      (assoc signal :enriched-at (java.time.Instant/now)))))

;; Handler-level transform
(tel/add-handler! :my-handler handler-fn
  {:xform (fn [signal]
            (if (-> signal :level (= :trace))
              nil  ; This handler ignores :trace
              (update signal :msg str/upper-case)))})

;; Dynamic context
(tel/with-xfn
  (fn [signal] (assoc signal :request-id request-id))
  (handle-request))  ; All signals get :request-id
```

Transforms returning nil filter the signal (prevent handling).

### View Current Filters

```clojure
;; See all call filters in context
(tel/get-filters)
;; => {:min-level :info, :ns-filter {...}, ...}

;; Temporarily disable all filters
(tel/without-filters
  (tel/log! {:level :trace} "Will be created"))
```

### Debugging Filters

```clojure
;; See last signal created
(tel/with-signal
  (tel/log! "Test"))
;; => {:ns "...", :level :info, ...} or nil if filtered

;; See all signals created
(tel/with-signals
  (tel/log! "One")
  (tel/log! "Two"))
;; => [{:msg "One" ...} {:msg "Two" ...}]

;; Handler stats show filtering effects
(tel/get-handlers-stats)
;; => {:my-handler {:counts {:handled 100, :dropped 50, ...}}}
```

## Handler Configuration

### Adding Handlers

```clojure
;; Simple handler
(tel/add-handler! :my-handler
  (fn [signal] (println (:msg signal))))

;; With cleanup
(tel/add-handler! :my-handler
  (fn
    ([signal] (save-to-db signal))
    ([] (close-db!))))  ; Called on stop-handlers!

;; With dispatch options
(tel/add-handler! :my-handler handler-fn
  {:async {:mode :dropping
           :buffer-size 1024
           :n-threads 1}
   :priority 100
   :min-level :warn
   :sample 0.5
   :ns-filter {:disallow "noisy.*"}
   :limit {"1/sec" [1 1000]}
   :xform (fn [signal] ...)
   :drain-msecs 6000
   :stats? true})
```

See `tel/help:handler-dispatch-options` for all options.

### Handler Priority

Controls handler call order (higher = earlier):

```clojure
(tel/add-handler! :first handler-fn {:priority 200})
(tel/add-handler! :second handler-fn {:priority 100})
(tel/add-handler! :third handler-fn {:priority 50})
;; Called in order: :first, :second, :third
```

### Async Dispatch

Configure per-handler async behavior:

```clojure
{:async
 {:mode :dropping           ; :dropping, :sliding, :blocking
  :buffer-size 1024         ; Signal queue size
  :n-threads 1}}            ; Worker threads

;; :dropping - Drop new signals when buffer full
;; :sliding  - Drop old signals when buffer full
;; :blocking - Block signal creator when buffer full (can slow app!)
```

Sync dispatch (no queue):
```clojure
{:async nil}  ; or omit :async key
```

### Managing Handlers

```clojure
;; View handlers
(tel/get-handlers)
;; => {:my-handler {:handler-fn ..., :dispatch-opts {...}, ...}}

;; Remove handler
(tel/remove-handler! :my-handler)

;; Stop all handlers (IMPORTANT on shutdown!)
(tel/stop-handlers!)

;; Shutdown hook
(tel/call-on-shutdown!
  (fn [] (tel/stop-handlers!)))
```

`stop-handlers!` blocks to flush async queues (default max 6 sec per handler via `:drain-msecs`).

### Handler Stats

```clojure
(tel/get-handlers-stats)
;; =>
{:my-handler
 {:counts {:handled 1000, :dropped 10, :errors 2, ...}
  :times  {:min-nsecs 100, :max-nsecs 5000, :mean-nsecs 250, ...}}}
```

Disable stats collection:
```clojure
{:stats? false}
```

## Interop

### tools.logging

Redirect tools.logging to Telemere:

```clojure
;; 1. Add dependency
;; org.clojure/tools.logging {:mvn/version "..."}

;; 2. Enable interop
(require '[taoensso.telemere.tools-logging])
(taoensso.telemere.tools-logging/tools-logging->telemere!)

;; Or via environmental config (see below)

;; 3. Verify
(tel/check-interop)
;; => {:tools-logging {:sending->telemere? true
;;                     :telemere-receiving? true}}
```

tools.logging calls become Telemere signals.

### SLF4J (Java Logging)

Redirect SLF4J v2+ to Telemere:

```clojure
;; 1. Add dependencies
;; org.slf4j/slf4j-api {:mvn/version "2.0.0"}  ; v2+ required!
;; com.taoensso/telemere-slf4j {:mvn/version "..."}

;; 2. telemere-slf4j auto-enables if it's the only SLF4J backend

;; 3. Verify
(tel/check-interop)
;; => {:slf4j {:sending->telemere? true
;;             :telemere-receiving? true}}
```

SLF4J signals will have `:ns` set to logger name (typically source class).

For other Java logging (Log4j, JUL, JCL):
1. Use appropriate [SLF4J bridge](https://www.slf4j.org/legacy.html)
2. Configure SLF4J as above
3. Logging flows: Log4j/JUL/JCL → SLF4J → Telemere

### System Streams

Redirect `System/out` and `System/err`:

```clojure
(tel/streams->telemere!)

;; Verify
(tel/check-interop)
;; => {:system/out {:sending->telemere? true, :telemere-receiving? true}
;;     :system/err {:sending->telemere? true, :telemere-receiving? true}}
```

Note: Clojure's `*out*`, `*err*` are NOT automatically affected.

### OpenTelemetry

Send Telemere signals to OpenTelemetry exporters as LogRecords with correlated tracing:

```clojure
;; 1. Add dependency
;; io.opentelemetry/opentelemetry-api {:mvn/version "..."}

;; 2. Configure OpenTelemetry exporters (not Telemere-specific)
;; See https://opentelemetry.io/docs/languages/java/configuration/

;; 3. Add Telemere OpenTelemetry handler
(require '[taoensso.telemere.open-telemetry :as otel])

(tel/add-handler! :open-telemetry
  (otel/handler:open-telemetry
    {;; Optional OpenTelemetry-specific opts
     }))

;; 4. Enable tracing interop (if desired)
(tel/set-otel-tracing?! true)

;; 5. Verify
(tel/check-interop)
;; => {:open-telemetry {:present? true
;;                      :use-tracer? true
;;                      :viable-tracer? true}}
```

Telemere's OpenTelemetry interop is experimental. No need to use OpenTelemetry Java API directly - just use Telemere normally and the handler emits detailed log and trace data.

### Tufte

Include Tufte performance data in signals:

```clojure
(require '[taoensso.tufte :as tufte])

(let [[_ perf-data] (tufte/profiled {...} (my-code))]
  (tel/log! {:id ::perf, :data {:perf perf-data}}
    "Performance data"))
```

Telemere and Tufte are complementary. Upcoming Tufte v3 will share Telemere's core and identical API for filters/handlers.

### Truss

Capture Truss assertion failures:

```clojure
(require '[taoensso.truss :as truss])

(tel/catch->error! ::validation
  (truss/have string? user-input))  ; Logs error if assertion fails
```

## Environmental Config

Configure via JVM properties, environment variables, or classpath resources.

Use `tel/get-env` to read environmental config with fallbacks:

```clojure
(tel/get-env
  {:as :bool  ; :bool, :str, :edn, :keyword
   :id :my-config
   :default false
   :resource "config.edn"  ; Check classpath resource
   :env-var "MY_CONFIG"    ; Check environment variable
   :sys-prop "my.config"}) ; Check JVM system property
;; Checks in order: sys-prop, env-var, resource, default
```

Example - conditionally add handler based on env:

```clojure
(when (tel/get-env {:as :bool, :id :enable-file-logging
                    :env-var "ENABLE_FILE_LOGGING"
                    :default false})
  (tel/add-handler! :file
    (tel/handler:file {:path "./logs/app.log"})))
```

See `tel/help:environmental-config` for complete details.

## Handler-Specific Configuration

Each included handler has its own options. See [handlers.md](./handlers.md) for details.

Console handler example:
```clojure
(tel/handler:console
  {:output-fn (tel/format-signal-fn
                {:format-opts {:incl-newline? true
                               :incl-hostname? false}})})
```

File handler example:
```clojure
(tel/handler:file
  {:path "./logs/app.log"
   :output-fn (tel/pr-signal-fn {:pr-fn :edn})
   :append? true})
```

## For More Details

- Complete filtering reference: `tel/help:filters`
- Handler dispatch options: `tel/help:handler-dispatch-options`
- Environmental config: `tel/help:environmental-config`
- Full wiki: https://github.com/taoensso/telemere/wiki/3-Config
