{
  inputs = {
    #nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    nixpkgs.url = "git+https://github.com/ramblurr/nixpkgs?shallow=1&ref=consolidated";
    flakelight.url = "github:nix-community/flakelight";
    flakelight.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { self
    , flakelight
    , home-manager
    , ...
    }@inputs:
    flakelight ./. (
      { config, ... }:
      {
        inherit inputs;
        homeConfigurations.root = import ./users/root.nix inputs;
        homeConfigurations.vscode = import ./users/vscode.nix inputs;
        homeConfigurations.catnip = import ./users/catnip.nix inputs;

        withOverlays = [
          self.overlays.default
        ];
        packages = {
          ramblurr-global-deps-edn =
            { runCommand
            , replaceVars
            , cacheDirectory ? "~/.cache/clojure"
            , ...
            }:
            let
              depsEdn = replaceVars ./config/deps.edn { inherit cacheDirectory; };
            in
            runCommand "ramblurr-global-deps-edn" { passthru = { inherit cacheDirectory; }; } ''
              mkdir -p $out/share/clojure
              cp ${depsEdn} $out/share/clojure/deps.edn
            '';
        };
        flakelight.builtinFormatters = false;
        formatters = pkgs: {
          "*.nix" = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
        };
      }
    );
}
