let
  withCategory = category: attrset: attrset // { inherit category; };
in
{
  clojure = import ./devshells/clojure.nix { inherit withCategory; };
  base = import ./devshells/base.nix { inherit withCategory; };
}
