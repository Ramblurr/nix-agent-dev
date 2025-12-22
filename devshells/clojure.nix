pkgs: {
  packages = pkgs: [
    pkgs.clojure
    pkgs.jdk25
    pkgs.brepl
    pkgs.clojure-mcp-light
    pkgs.clojure-lsp
    pkgs.clj-kondo
    pkgs.cljfmt
    pkgs.babashka
    pkgs.git
  ];
}
