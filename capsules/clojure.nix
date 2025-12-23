{ withCategory, ... }:
{ pkgs, ... }:
let
  javaVersion = "25";
  jdk = pkgs."jdk${javaVersion}";
  clojure = pkgs.clojure.override { inherit jdk; };
in
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
    jdk
    clojure
    pkgs.brepl
    pkgs.clojure-mcp-light
    pkgs.clojure-lsp
    pkgs.clj-kondo
    pkgs.cljfmt
    pkgs.babashka
  ];
}
