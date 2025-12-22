{
  runCommand,
  replaceVars,
  cacheDirectory ? "~/.cache/clojure",
  ...
}:
let
  depsEdn = replaceVars ../home-modules/deps.edn { inherit cacheDirectory; };
in
runCommand "ramblurr-global-deps-edn" { passthru = { inherit cacheDirectory; }; } ''
  mkdir -p $out/share/clojure
  cp ${depsEdn} $out/share/clojure/deps.edn
''
