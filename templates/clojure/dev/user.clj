(ns user
  (:require
   [portal.api :as p]
   [clj-reload.core :as clj-reload]
   [ol.dev.portal :as my-portal]))

((requiring-resolve 'hashp.install/install!))

(set! *warn-on-reflection* true)
(set! *print-namespace-maps* false)

;; Configure the paths containing clojure sources we want clj-reload to reload
(clj-reload/init {:dirs      ["src" "dev" "test"]
                  :no-reload #{'user 'dev 'ol.dev.portal}})

(defonce ps (my-portal/open-portals))

(comment
  (clj-reload/reload)
  (clj-reload/reload {:only :all}) ;; rcf
  (reset! my-portal/portal-state nil)
  (clojure.repl.deps/sync-deps)
  ;;;
  )
