# Telemere Best Practices and Tips

Building observable systems requires planning. This guide offers practical advice for using Telemere effectively.

## General Guidance

### Consider What Information You Need

Be as concrete as possible about what information is (or will be) most valuable. Get agreement on examples.

Information may be needed for:
- Debugging
- Business intelligence
- Testing/staging/validation
- Customer support
- Quality management

Be clear on:
- WHO needs what information
- WHEN they need it (time frame)
- In WHAT FORM (raw data, aggregate, formatted)
- For WHAT PURPOSE (how will it be actionable)

Always involve the final consumer of information in your design process.

Always map examples of expected information to expected actionable decisions, and document these mappings.

The clearer the expected decisions, the clearer the information's value.

### Consider Data Dependencies

Not all data is inherently useful. Be clear on which data is:

- Useful independently
- Useful in the aggregate (statistically)
- Useful in association with other data (e.g., tracing)

Question assertions of usefulness! Useful for what precise purpose and by whom? Can a clear example map information to decisions?

When aggregates or associations are needed, plan for producing them from raw data. Forethought (appropriate identifiers, indexes) avoids headaches.

### Consider Cardinality

Too much low-value data is actively harmful: expensive to process, store, and query. Noise interferes with better data.

Consider the quantities of data that suit your needs:

- 100% - Critical events, errors
- 10-50% - Important business events
- 1-10% - Regular operations, debugging
- 0.1-1% - Detailed tracing, verbose logs
- 0% - Filter out entirely

Telemere offers extensive filtering to express conditions and quantities. Use these both for their effects and as documentation.

### Consider Evolution

Data and needs evolve over time.

Consider:
- What is likely to change
- How changes impact observability needs
- Downstream effects on data services/storage

Use schemas when appropriate. Use version identifiers when reasonable.

Consider the differences between accretion (adding) and breakage (changing/removing).

## Telemere-Specific Tips

### Always Provide Signal IDs

```clojure
;; BAD - no ID
(tel/log! "User logged in")

;; GOOD - qualified keyword ID
(tel/log! {:id ::user-login} "User logged in")
(tel/event! ::user-login {:data {:user-id 42}})
```

Benefits:
- Downstream behavior can match on IDs (more reliable than messages)
- IDs are less likely to change than messages
- IDs enable better filtering and analysis

### Keep a Signal ID Index

Maintain a documented index of all signal IDs under version control:

```clojure
;; signals.edn
{:user-events
 #{::user-login
   ::user-logout
   ::user-signup}

 :payment-events
 #{::payment-initiated
   ::payment-completed
   ::payment-failed}

 :system-events
 #{::service-started
   ::service-stopped
   ::health-check}}
```

Benefits:
- See all IDs in one place
- Track when IDs were added/removed/changed
- Coordinate with downstream consumers
- Document signal taxonomy

### Use `log!` and `event!` as General-Purpose Creators

Both are good for most use cases:
- `log!` - When message is primary
- `event!` - When ID/data is primary

```clojure
;; log! - message-focused
(tel/log! {:id ::processing
           :data {:count 42}}
  "Processing 42 items")

;; event! - data-focused
(tel/event! ::item-processed
  {:data {:item-id "abc123"
          :duration-ms 123}})
```

### Leverage Call Transforms

Call transforms are cached and shared between handlers:

```clojure
;; Expensive operation done once per signal
(tel/set-xfn!
  (fn [signal]
    (assoc signal
      :correlation-id (get-from-external-service)  ; Expensive!
      :hostname (get-hostname))))                   ; Cached

;; All handlers see the same enriched signal
```

Good for:
- Expensive enrichment
- Side effects (sync with external service)
- Ensuring consistency across handlers

### Understand Multiplicative Sampling

Signal and handler sampling multiply:

```clojure
;; Signal: 20% sampling
(tel/log! {:sample 0.2} "Message")

;; Handler: 50% sampling
(tel/add-handler! :my-handler handler-fn {:sample 0.5})

;; Result: 10% of possible signals handled (0.2 * 0.5 = 0.1)
```

The signal's `:sample` value reflects the combined rate, useful for estimating unsampled cardinalities:

```clojure
;; For n randomly sampled signals:
;; Estimated total = Σ(1.0 / sample-rate-i)
```

### Use Transforms for Signal Splitting

Transforms can create new signals:

```clojure
(tel/set-xfn!
  (fn [signal]
    (when (error-signal? signal)
      ;; Create alert signal
      (tel/event! ::error-alert
        {:data {:original-id (:id signal)}}))
    signal))  ; Return original to continue handling
```

Or filter source and create replacement:

```clojure
(tel/set-xfn!
  (fn [signal]
    (when (special-case? signal)
      (tel/event! ::special-event {:data (extract-data signal)})
      nil)))  ; Filter original
```

Note: New signals re-enter handler queues and may experience delay/backpressure.

### Levels Can Be Integers

Standard keywords map to integers:

```clojure
tel/level-aliases
;; => {:trace 0, :debug 1, :info 2, :warn 3, :error 4, :fatal 5}

;; Use custom levels between standard ones
(tel/log! {:level 25} "Between :info and :warn")
```

### Error Value ≠ Error Level

Signals can have error values at any level:

```clojure
;; Error value, info level (expected error, informational)
(tel/log! {:level :info
           :error (ex-info "User not found" {})}
  "Attempted login for non-existent user")

;; No error value, error level (error condition without exception)
(tel/log! {:level :error}
  "Database connection pool exhausted")
```

Be clear on what constitutes an "error signal" for your use case. Use `tel/error-signal?` utility if needed.

### App-Level Keys for Custom Handlers

Include arbitrary data for custom transforms/handlers:

```clojure
(tel/log!
  {:my-custom-key "value"
   :alert-channel :slack}
  "Message")

;; In handler:
(fn [signal]
  (when (= :slack (:alert-channel signal))
    (send-to-slack signal)))
```

App-level keys:
- Available at signal root
- Collected under `:kvs`
- Typically NOT in default handler output

Good for handler-specific routing/config without cluttering output.

### Use Signal `kind` for Custom Taxonomies

Every signal has a `:kind` (`:log`, `:event`, `:trace`, etc.):

```clojure
;; Custom kind for business events
(tel/signal! {:kind :business-metric
              :id ::revenue
              :data {:amount 1000}})

;; Filter by kind
(tel/set-kind-filter! {:allow #{:business-metric}})

;; Set min level by kind
(tel/set-min-level! :business-metric :info)
```

Advanced use case - allows signal taxonomy separate from IDs/namespaces.

### Cache Validators/Decoders

Don't create validators/decoders per signal:

```clojure
;; BAD - creates validator every call
(defn process [data]
  (when (tel/with-signal (tel/log! ...))
    ...))

;; GOOD - create once
(def my-validator (tel/validator ...))
(defn process [data]
  (when (my-validator data)
    ...))
```

Applies to any Telemere utilities that return functions.

### Always Stop Handlers on Shutdown

```clojure
(defn -main [& args]
  ;; App code
  ...

  ;; CRITICAL - stop handlers before exit
  (tel/stop-handlers!))

;; Or use shutdown hook
(tel/call-on-shutdown!
  (fn []
    (tel/stop-handlers!)))
```

Ensures:
- Buffers are flushed
- Files are closed
- Resources are released
- Pending signals are handled

`stop-handlers!` blocks to finish async handling (max `:drain-msecs` per handler, default 6 sec).

### Use Async Handlers for Better Performance

```clojure
(tel/add-handler! :my-handler handler-fn
  {:async {:mode :dropping
           :buffer-size 1024
           :n-threads 1}})
```

Benefits:
- Non-blocking signal creation
- Better throughput
- Automatic backpressure handling

Choose mode based on requirements:
- `:dropping` - Best throughput, can lose signals under load
- `:sliding` - Keep most recent signals
- `:blocking` - Guarantee handling, can slow app

### Monitor Handler Stats

```clojure
(tel/get-handlers-stats)
```

Use to:
- Understand handler performance
- Detect backpressure (`:dropped`, `:backp-*` counts)
- Tune buffer sizes and thread counts
- Plan capacity

### Structured Data Over Messages

```clojure
;; LESS USEFUL - string message
(tel/log! (str "User " user-id " purchased " item-id))

;; MORE USEFUL - structured data
(tel/log! {:id ::purchase
           :data {:user-id user-id
                  :item-id item-id
                  :amount amount}}
  "User purchased item")
```

Structured data enables:
- Easy filtering/querying
- Aggregation/analysis
- Type preservation
- Better tooling

### Use Dynamic Context for Request Correlation

```clojure
(defn handle-request [req]
  (let [req-id (generate-request-id)]
    (tel/with-ctx {:request-id req-id
                   :user-id (:user-id req)}
      ;; All signals in scope have context
      (tel/log! "Processing request")
      (do-work req)
      (tel/log! "Request complete"))))
```

All signals get `:ctx` with correlation info.

### Prefer Compile-Time Filtering for Hot Paths

```clojure
;; Set compile-time minimum level
(tel/set-min-level! :info)

;; In production, :debug/:trace signals are completely elided (zero cost)
(tel/log! {:level :debug} "Expensive debug info")  ; No-op in production
```

Hot paths benefit most from elision.

### Use Sampling for High-Volume Signals

```clojure
;; Instead of logging every request (millions)
(tel/log! {:sample 0.01} "Request processed")  ; Log 1%

;; Adjust based on volume and value
(tel/log!
  {:sample (if prod? 0.001 1.0)}  ; 0.1% in prod, 100% in dev
  "High-volume event")
```

### Use Rate Limiting for Expensive Operations

```clojure
;; Prevent alert spam
(tel/log!
  {:id ::database-error
   :limit {"1/min" [1 60000]}     ; Max 1 per minute
   :do (send-alert!)}              ; Expensive side effect
  "Database connection failed")
```

### Layer Your Filters

Use multiple filtering stages:

1. Compile-time: Elide verbose signals in production
2. Runtime call filters: Filter by level/namespace/id
3. Call transforms: Filter/enrich based on signal content
4. Handler filters: Per-handler filtering
5. Handler transforms: Handler-specific filtering/formatting

Each stage has different strengths. Use appropriate stage for each need.

### Plan for Log Rotation

For file handlers:

```clojure
(tel/handler:file
  {:path
   (fn [_signal]
     (str "logs/app-"
          (.format (java.time.LocalDate/now)
                   (java.time.format.DateTimeFormatter/ofPattern "yyyy-MM-dd"))
          ".log"))})
```

Or use external log rotation (logrotate, etc.).

### Test Your Observability

Write tests for critical signals:

```clojure
(deftest user-login-creates-signal
  (let [signals (tel/with-signals
                  (handle-login user))]
    (is (= 1 (count signals)))
    (is (= ::user-login (:id (first signals))))
    (is (= user-id (get-in (first signals) [:data :user-id])))))
```

Ensures important telemetry isn't accidentally removed/broken.

### Document Your Signal Taxonomy

Create documentation:

```markdown
# Application Signals

## User Events
- `::user-login` - User successfully logged in
  - Data: `{:user-id int, :ip string}`
  - Level: :info
  - Handlers: file, metrics

- `::user-logout` - User logged out
  - Data: `{:user-id int, :session-duration-ms int}`
  - Level: :info

## Error Signals
- `::database-error` - Database operation failed
  - Data: `{:operation keyword, :table string, :error error}`
  - Level: :error
  - Rate limit: 1/min
  - Alerts: email, slack
```

Benefits:
- Team alignment
- Downstream consumer coordination
- Easier debugging
- Better maintenance

## Performance Tips

1. Use compile-time filtering for hot paths
2. Use sampling for high-volume signals
3. Use async handlers for better throughput
4. Cache validators/transformers
5. Use call transforms for expensive operations (shared across handlers)
6. Monitor handler stats to detect bottlenecks
7. Tune handler buffer sizes and thread counts based on stats
8. Use rate limiting to prevent expensive operations from overwhelming handlers

## Common Patterns

### Request/Response Logging

```clojure
(defn wrap-telemetry [handler]
  (fn [request]
    (let [start (System/nanoTime)
          req-id (generate-id)]
      (tel/with-ctx {:request-id req-id}
        (tel/log! {:id ::request-start
                   :data {:method (:request-method request)
                          :uri (:uri request)}}
          "Request started")
        (let [response (handler request)
              duration-ms (/ (- (System/nanoTime) start) 1000000.0)]
          (tel/log! {:id ::request-complete
                     :data {:status (:status response)
                            :duration-ms duration-ms}}
            "Request complete")
          response)))))
```

### Error Boundary

```clojure
(defn with-error-logging [f]
  (tel/catch->error! ::unexpected-error
    {:catch-val ::error
     :let [result (f)]}
    result))
```

### Feature Flags

```clojure
(tel/log!
  {:when (feature-enabled? :verbose-logging)}
  "Verbose details")
```

### Multi-Environment Config

```clojure
(case environment
  :dev
  (tel/set-min-level! :trace)

  :staging
  (do (tel/set-min-level! :debug)
      (tel/add-handler! :file (tel/handler:file {...})))

  :production
  (do (tel/set-min-level! :info)
      (tel/add-handler! :file (tel/handler:file {...}))
      (tel/add-handler! :slack (tel/handler:slack {...}))))
```

## For More Details

- Full tips: https://github.com/taoensso/telemere/wiki/7-Tips
- Architecture: [architecture.md](./architecture.md)
- Configuration: [config.md](./config.md)
- Handlers: [handlers.md](./handlers.md)
