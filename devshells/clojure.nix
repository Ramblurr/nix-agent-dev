{ withCategory, ... }:
{ pkgs, ... }:
{
  commands = map (withCategory "clojure") [
    {
      package = pkgs.babashka;
      name = "bb";
      help = "task runner for clojure see `bb help`";
    }
    { package = pkgs.brepl; }
  ];
  packages = [
    pkgs.clojure
    pkgs.jdk25
    pkgs.brepl
    pkgs.clojure-mcp-light
    pkgs.clojure-lsp
    pkgs.clj-kondo
    pkgs.cljfmt
    pkgs.babashka
  ];
}
