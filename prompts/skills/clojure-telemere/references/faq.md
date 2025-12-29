# Telemere FAQ

## Does Telemere replace Timbre?

Yes, Telemere's functionality is a superset of Timbre and offers many improvements.

However:
- Timbre will continue to be maintained and supported
- There is no pressure to migrate
- Timbre will receive some backwards-compatible improvements back-ported from Telemere

See [Migration Guide](https://github.com/taoensso/telemere/wiki/5-Migrating#from-timbre) for migration information.

## Why not just update Timbre?

Timbre's fundamental design is 12+ years old. Telemere is a ground-up rewrite free of historical constraints.

Telemere advantages over Timbre:
- Easier to use
- Faster performance
- More robust
- Significantly more flexible
- Better platform for future development

Timbre users who are happy can stay on Timbre. Those who migrate will find improvements in every area.

## Does Telemere replace Tufte?

No. Telemere and Tufte are complementary:

- Telemere: Basic performance measurement (single form runtime)
- Tufte: Rich performance monitoring (arbitrary nested forms with detailed stats)

They work great together. Upcoming Tufte v3 will share Telemere's core and identical filter/handler API.

Example using both:
```clojure
(let [[_ perf-data] (tufte/profiled {...} (my-code))]
  (tel/log! {:id ::perf, :data {:perf perf-data}}
    "Performance data"))
```

## How does Telemere compare to μ/log?

[μ/log](https://github.com/BrunoBonacci/mulog) is an excellent structured logging library with many shared capabilities.

### Similarities

- Both emphasize structured data over string messages
- Both offer tracing and nested context
- Both are fast with async handling
- Both provide variety of handlers

### μ/log Strengths

- More established/mature
- Wider range of handlers (Kafka, Kinesis, Prometheus, Zipkin, etc.)
- More community resources
- Smaller code base

### Telemere Strengths

- Both Clj and Cljs support (μ/log is Clj only)
- Rich filtering (see `tel/help:filters`) including compile-time elision
- Rich dispatch control (see `tel/help:handler-dispatch-options`)
- Environmental config for all platforms
- Detailed handler stats
- Single unified API for all telemetry needs
- Lazy `:let`, `:data`, `:msg`, `:do` evaluated after filtering
- Extensive in-IDE documentation

### When to Choose

Choose μ/log if:
- You need its specific handlers (Kafka, Prometheus, etc.)
- You prefer its mature ecosystem
- You only need Clj support

Choose Telemere if:
- You need Cljs support
- You have complex filtering needs
- You want tight integration with Tufte
- You're migrating from Timbre
- You prefer Telemere's API/ergonomics

Both are excellent choices. Try both and see which fits your needs better.

## Does Telemere work with GraalVM?

Yes. Telemere works with GraalVM native compilation.

## Does Telemere work with Babashka?

Not currently. Support is possible but requires removing dependency on Encore (which uses classes unavailable in Babashka).

If interested, upvote: https://github.com/taoensso/roadmap/issues/22

## Why no format-style messages?

Telemere's message API is more flexible than format-style builders and uses pure Clojure/Script (no arcane pattern syntax).

Messages are always lazy - you only pay for building if the signal is created (after filtering).

Examples:
```clojure
;; Fixed message
(tel/log! "A fixed message")

;; Joined vector
(tel/log! ["User" username "logged in"])

;; With preprocessing
(tel/log!
  {:let [username (str/upper-case user-arg)
         balance  (parse-double balance-str)]
   :data {:username username
          :balance balance}}
  ["User" username "has balance:" (format "$%.2f" balance)])

;; Use format if you want
(tel/log! (format "User %s has balance $%.2f" username balance))

;; Use any formatter
(tel/log! (str "Built " "with " "str"))
```

You have full Clojure/Script at your disposal. Use `format`, `str`, or any other tools you prefer.

## How to use Telemere from a library?

See [Library Authors Guide](https://github.com/taoensso/telemere/wiki/9-Authors).

Short version: Use [Trove](https://www.taoensso.com/trove) for library logging. It's designed specifically for library authors and integrates seamlessly with Telemere.

## Why the unusual arg order for `event!`?

Every signal creator except `event!` takes opts map as first arg in 2-arg arity.

`event!` takes `[id ?level]` because:

1. Event IDs are typically very short (just a keyword)
2. Event IDs never depend on `:let` bindings
3. Event opts typically include long/multi-line `:data`

This makes `(event! ::user-login {:data {...}})` read better than `(event! {:data {...}} ::user-login)`.

The pattern: typically-larger argument goes last.

Alternatives:
- Use `signal!` for full control of arg order
- A future `ev!` might provide alternative arg order

Most IDEs help with arg order, and the initial surprise typically wears off with use.

## Can I use Telemere with OpenTelemetry?

Yes. Telemere has experimental OpenTelemetry support.

See [config.md](./config.md#opentelemetry) for setup details.

Telemere can send signals as LogRecords with correlated tracing to OpenTelemetry exporters. You don't need to use the OpenTelemetry Java API directly.

Feedback welcome: https://www.taoensso.com/telemere/slack

## How do I migrate from Timbre?

Telemere includes a Timbre shim for easy migration:

```clojure
;; Change this:
(require '[taoensso.timbre :as log])

;; To this:
(require '[taoensso.telemere.timbre :as log])
```

Most Timbre code works unchanged. See [Migration Guide](https://github.com/taoensso/telemere/wiki/5-Migrating#from-timbre) for details.

## How do I integrate with SLF4J?

Add dependencies:
1. `org.slf4j/slf4j-api` v2+
2. `com.taoensso/telemere-slf4j`

SLF4J auto-detects telemere-slf4j as backend. All SLF4J logging becomes Telemere signals.

Verify: `(tel/check-interop)` => `{:slf4j {:telemere-receiving? true}}`

See [config.md](./config.md#slf4j-java-logging) for more details.

## How do I integrate with tools.logging?

Add `org.clojure/tools.logging` dependency and call:

```clojure
(require '[taoensso.telemere.tools-logging])
(taoensso.telemere.tools-logging/tools-logging->telemere!)
```

Or set via environmental config (see `tel/help:environmental-config`).

Verify: `(tel/check-interop)` => `{:tools-logging {:telemere-receiving? true}}`

## What's the difference between `:data` and `:msg`?

- `:data` - Structured data (map) preserved as-is, queryable, analyzable
- `:msg` - Human-readable message string or vector

Use `:data` for:
- Values you want to query/filter/analyze
- Structured information
- Machine-readable data

Use `:msg` for:
- Human-readable descriptions
- Context/explanation
- Debugging messages

You can use both:
```clojure
(tel/log! {:id ::user-action
           :data {:user-id 42 :action "login"}
           :msg "User logged in"})
```

## How do I filter by custom criteria?

Use transforms:

```clojure
;; Call-level transform (shared across handlers)
(tel/set-xfn!
  (fn [signal]
    (if (custom-criteria? signal)
      signal  ; Keep it
      nil)))  ; Filter it

;; Handler-level transform
(tel/add-handler! :my-handler handler-fn
  {:xform (fn [signal]
            (if (handler-specific-criteria? signal)
              (modify-signal signal)
              nil))})
```

Transforms can:
- Filter signals (return nil)
- Modify signals (return modified map)
- Access any signal data

## How do I correlate signals across requests?

Use dynamic context:

```clojure
(defn handle-request [request]
  (tel/with-ctx {:request-id (generate-id)
                 :user-id (:user-id request)}
    (tel/log! "Started processing")
    (process-request request)
    (tel/log! "Finished processing")))

;; All signals in scope have :request-id and :user-id in :ctx
```

Or use call transforms:
```clojure
(tel/with-xfn
  (fn [signal] (assoc signal :request-id current-request-id))
  (handle-request))
```

## How do I prevent sensitive data from being logged?

Several approaches:

1. Filter at signal creation:
```clojure
(tel/log! {:data (dissoc user-data :password :ssn)} "User created")
```

2. Use call transform:
```clojure
(tel/set-xfn!
  (fn [signal]
    (update signal :data
      #(-> % (dissoc :password) (dissoc :ssn)))))
```

3. Use handler transform:
```clojure
(tel/add-handler! :my-handler handler-fn
  {:xform (fn [signal]
            (update signal :data redact-sensitive-keys))})
```

4. Custom output function:
```clojure
(defn safe-output-fn [signal]
  (-> signal
      (update :data redact-sensitive-keys)
      (tel/pr-signal-fn {:pr-fn :edn})))
```

## Other questions?

- Open a [GitHub issue](https://github.com/taoensso/telemere/issues)
- Ask on [Slack](https://www.taoensso.com/telemere/slack)
- Check the [Wiki](https://github.com/taoensso/telemere/wiki)

The FAQ is regularly updated with common questions.
