let
  withCategory = category: attrset: attrset // { inherit category; };
in
{
  clojure = import ./clojure.nix { inherit withCategory; };
  base = import ./base.nix { inherit withCategory; };
}
