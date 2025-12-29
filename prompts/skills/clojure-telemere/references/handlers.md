# Telemere Signal Handlers

Signal handlers are plain functions that process signals (write to console, file, DB, send to service, etc.).

## Handler Basics

Minimal handler:
```clojure
(fn [signal] (println signal))
```

Handler with shutdown cleanup:
```clojure
(fn my-handler
  ([signal] (save-to-db signal))      ; Handle signal
  ([] (close-db-connection)))         ; Called on stop-handlers!
```

Handlers receive signal maps. See `tel/help:signal-content` for map structure.

## Included Handlers

### Console Handler

Writes to `*out*`/`*err*` (Clj) or browser console (Cljs).

Human-readable format (default):
```clojure
(tel/add-handler! :console
  (tel/handler:console
    {:output-fn (tel/format-signal-fn {})}))

;; Output:
;; 2024-04-11T10:54:57.202869Z INFO LOG MyHost examples(56,1) ::my-id - My message
;;     data: {:x1 :x2}
```

EDN format:
```clojure
(tel/add-handler! :console-edn
  (tel/handler:console
    {:output-fn (tel/pr-signal-fn {:pr-fn :edn})}))

;; Output:
;; {:inst #inst "2024-04-11T10:54:57.202869Z", :msg "My message", ...}
```

JSON format (Clj requires JSON library):
```clojure
(require '[jsonista.core :as json])

(tel/add-handler! :console-json
  (tel/handler:console
    {:output-fn (tel/pr-signal-fn
                  {:pr-fn json/write-value-as-string})}))

;; Output:
;; {"inst":"2024-04-11T10:54:57.202869Z","msg":"My message",...}
```

Options:
```clojure
{:output-fn (fn [signal] "string to print")
 :stream    :out  ; :out or :err (Clj only)
 }
```

See API docs: [handler:console](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere#handler:console)

### Console Raw Handler (Cljs only)

Writes raw signal maps to browser console (works great with cljs-devtools):

```clojure
(tel/add-handler! :console-raw
  (tel/handler:console-raw {}))
```

See API docs: [handler:console-raw](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere#handler:console-raw)

### File Handler (Clj only)

Writes to file/s with rotation support:

```clojure
(tel/add-handler! :file
  (tel/handler:file
    {:path "./logs/app.log"
     :output-fn (tel/format-signal-fn {})
     :append? true}))
```

Options:
```clojure
{:path      "./logs/app.log"  ; File path or fn returning path
 :output-fn (tel/format-signal-fn {})
 :append?   true              ; Append vs overwrite
 :encoding  "UTF-8"}
```

Path can be a function for rotation:
```clojure
{:path
 (fn [_signal]
   (str "logs/app-"
        (.format (java.time.LocalDate/now)
                (java.time.format.DateTimeFormatter/ofPattern "yyyy-MM-dd"))
        ".log"))}
```

See API docs: [handler:file](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere#handler:file)

### Email Handler (Clj only)

Sends emails via [Postal](https://github.com/drewr/postal):

```clojure
(require '[taoensso.telemere.postal :as postal])

(tel/add-handler! :postal
  (postal/handler:postal
    {:conn {:host "smtp.gmail.com"
            :user "me@gmail.com"
            :pass "my-password"}
     :msg-fn
     (fn [signal]
       {:to      "alerts@myapp.com"
        :subject (str "[Alert] " (:id signal))
        :body    (tel/format-signal signal {})})}))
```

Needs `com.draines/postal` dependency.

See API docs: [handler:postal](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere.postal#handler:postal)

### Slack Handler (Clj only)

Sends to Slack webhooks:

```clojure
(require '[taoensso.telemere.slack :as slack])

(tel/add-handler! :slack
  (slack/handler:slack
    {:webhook-url "https://hooks.slack.com/services/..."
     :msg-fn
     (fn [signal]
       {:text (str (:level signal) " - " (:msg signal))
        :blocks [...]})}))
```

See API docs: [handler:slack](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere.slack#handler:slack)

### TCP/UDP Socket Handlers (Clj only)

Send to network sockets:

```clojure
(require '[taoensso.telemere.sockets :as sockets])

;; TCP
(tel/add-handler! :tcp
  (sockets/handler:tcp-socket
    {:host "localhost"
     :port 5000
     :output-fn (tel/pr-signal-fn {:pr-fn :edn})}))

;; UDP
(tel/add-handler! :udp
  (sockets/handler:udp-socket
    {:host "localhost"
     :port 5000
     :output-fn (tel/pr-signal-fn {:pr-fn :edn})}))
```

See API docs:
- [handler:tcp-socket](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere.sockets#handler:tcp-socket)
- [handler:udp-socket](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere.sockets#handler:udp-socket)

### OpenTelemetry Handler (Clj only)

Sends to OpenTelemetry exporters:

```clojure
(require '[taoensso.telemere.open-telemetry :as otel])

(tel/add-handler! :open-telemetry
  (otel/handler:open-telemetry
    {;; Optional OpenTelemetry-specific options
     }))
```

See [config.md](./config.md#opentelemetry) for setup details.

See API docs: [handler:open-telemetry](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere.open-telemetry#handler:open-telemetry)

## Output Functions

Many handlers accept `:output-fn` to format signals.

### Formatted Text

Human-readable formatted output:

```clojure
(tel/format-signal-fn
  {:format-opts
   {:incl-newline?  true
    :incl-hostname? true
    :preamble-fn    (fn [signal] ...)  ; Custom preamble
    :msg-fn         (fn [signal] ...)  ; Custom message formatting
    }})
```

### Serialized Data

EDN or JSON output:

```clojure
;; EDN
(tel/pr-signal-fn {:pr-fn :edn})

;; JSON (Cljs uses js/JSON.stringify)
(tel/pr-signal-fn {:pr-fn json/write-value-as-string})

;; Custom printer
(tel/pr-signal-fn
  {:pr-fn (fn [x] ...)
   :incl-keys #{...}    ; Include only these keys
   :excl-keys #{...}})  ; Exclude these keys
```

### Custom Output Functions

Write your own:

```clojure
(defn my-output-fn [signal]
  (str (:level signal) " | " (:msg signal)))

(tel/handler:console {:output-fn my-output-fn})
```

## Writing Custom Handlers

Handlers are just functions with 2 arities:

```clojure
(defn my-handler
  ([signal]
   ;; Process signal
   (println "Level:" (:level signal))
   (println "Message:" (:msg signal)))

  ([]
   ;; Called on stop-handlers!
   (println "Handler shutting down")))
```

### Handler Constructor Pattern

For reusable handlers, use constructor pattern:

```clojure
(defn handler:my-custom-handler
  "Returns a signal handler that writes to my-service.

  Options:
    :api-key  - API key for my-service
    :endpoint - Service endpoint URL

  Tips:
    - Configure rate limiting to avoid overwhelming service
    - Use async dispatch for better performance"

  ([] (handler:my-custom-handler nil))
  ([{:keys [api-key endpoint] :as opts}]

   ;; Validate options and setup
   (when-not api-key
     (throw (ex-info "Missing :api-key" {})))

   (let [client (create-client api-key endpoint)]

     ;; Return handler fn
     (fn a-handler:my-custom-handler
       ([signal]
        ;; Handle signal
        (send-to-service client signal))

       ([]
        ;; Cleanup
        (close-client client))))))
```

Use constructor naming convention: `handler:my-custom-handler`.

### Handler Metadata

Provide default dispatch options via metadata:

```clojure
(with-meta handler-fn
  {:dispatch-opts
   {:min-level :info
    :async {:mode :dropping
            :buffer-size 1024}
    :limit [[1 1000]      ; Max 1/sec
            [10 60000]]}}) ; Max 10/min
```

Users can override when calling `add-handler!`.

## Handler Utilities

See [utils namespace](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere.utils) for:
- `signal-preamble-fn` - Build formatted preambles
- `signal-msg-fn` - Build formatted messages
- `pr-signal-fn` - Serialize signals
- `format-signal-fn` - Format signals as text
- And more...

## Handler-Specific Per-Signal Keys

Include app-level data for custom handlers:

```clojure
(tel/log!
  {:my-handler-key "value-for-my-handler"
   :another-key    {:some :data}}
  "Message")

;; In handler:
(fn [signal]
  (let [custom-value (:my-handler-key signal)]
    ...))
```

App-level keys are:
- Included at signal root level
- Collected under `:kvs` key
- Typically NOT included in default handler output

Great for passing data/opts to custom transforms/handlers without cluttering output.

## Managing Handlers

```clojure
;; Add handler
(tel/add-handler! :my-id handler-fn
  {:async {...}
   :min-level :warn
   ...})

;; View handlers
(tel/get-handlers)
;; => {:my-id {:handler-fn ..., :dispatch-opts {...}, :stats_ ...}}

;; Remove handler
(tel/remove-handler! :my-id)

;; Stop all handlers (flush buffers, close resources)
(tel/stop-handlers!)

;; Shutdown hook
(tel/call-on-shutdown!
  (fn [] (tel/stop-handlers!)))
```

## Handler Statistics

View handler performance and behavior:

```clojure
(tel/get-handlers-stats)
;; =>
{:console
 {:handling-nsecs nil  ; Only for sync handlers
  :counts
  {:handled 1523
   :dropped 12
   :errors  0
   :backp-dropping 12
   :backp-sliding  0
   :backp-blocking 0}

  :times
  {:min-nsecs  45231
   :max-nsecs  892345
   :p50-nsecs  123456
   :p90-nsecs  234567
   :p99-nsecs  345678
   :mean-nsecs 156789
   :mad-nsecs  23456}}}
```

Stats are collected by default. Disable per-handler:
```clojure
{:stats? false}
```

Use stats for:
- Debugging handler behavior
- Understanding performance characteristics
- Monitoring backpressure
- Capacity planning

## Handler Dispatch Options

Full dispatch options (see `tel/help:handler-dispatch-options`):

```clojure
{:async
 {:mode        :dropping  ; :dropping, :sliding, :blocking
  :buffer-size 1024       ; Queue size
  :n-threads   1}         ; Worker threads

 :priority     100        ; Call order (higher = earlier)
 :sample       0.5        ; Random sampling
 :min-level    :info      ; Minimum level
 :kind-filter  #{...}     ; Allow/deny kinds
 :ns-filter    {...}      ; Allow/deny namespaces
 :id-filter    {...}      ; Allow/deny IDs
 :middleware   [...]      ; (Advanced) middleware chain
 :xform        (fn ...)   ; Transform fn
 :rate-limit   {...}      ; Rate limiting
 :rate-limit-by ...       ; Rate limit scope
 :when-fn      (fn ...)   ; Conditional fn
 :drain-msecs  6000       ; Max wait on stop
 :stats?       true}      ; Collect stats
```

## Stopping Handlers Properly

ALWAYS call `stop-handlers!` on shutdown:

```clojure
(defn -main [& args]
  ;; App initialization
  (tel/add-handler! :file (tel/handler:file {...}))

  ;; App logic
  (run-app)

  ;; IMPORTANT: Stop handlers before exit
  (tel/stop-handlers!))
```

Or use shutdown hook:
```clojure
(tel/call-on-shutdown!
  (fn []
    (println "Shutting down handlers...")
    (tel/stop-handlers!)))
```

`stop-handlers!`:
- Calls 0-arity handler functions
- Blocks to finish async queues
- Max wait per handler: `:drain-msecs` (default 6 sec)
- Flushes buffers, closes files/connections

## Community Handlers

See [Community Resources](https://github.com/taoensso/telemere/wiki/8-Community) for:
- Third-party handlers
- Handler examples
- Integration guides

Vote for future handlers: https://github.com/taoensso/roadmap/issues/12

## For More Details

- Handler management: `tel/help:handlers`
- Dispatch options: `tel/help:handler-dispatch-options`
- Signal content: `tel/help:signal-content`
- Utils namespace: [API docs](https://cljdoc.org/d/com.taoensso/telemere/CURRENT/api/taoensso.telemere.utils)
- Full wiki: https://github.com/taoensso/telemere/wiki/4-Handlers
