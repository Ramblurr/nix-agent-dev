{
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://install.determinate.systems"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };
  inputs = {
    #nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    nixpkgs.url = "git+https://github.com/ramblurr/nixpkgs?shallow=1&ref=consolidated";
    spdx-util.url = "https://flakehub.com/f/ramblurr/spdx-util/0.1.4";
    flakelight.url = "github:nix-community/flakelight";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "flakelight/nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1.*";
    # Using fork with skopeo fix for issue #185 (go mod vendor for skopeo >= 1.15)
    # TODO: revert to upstream when https://github.com/nlewo/nix2container/issues/185 is fixed
    nix2container.url = "github:cameronraysmith/nix2container/185-skopeo-fix";
    #nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix-src/*";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.2.0";
  };
  outputs =
    {
      self,
      flakelight,
      treefmt-nix,
      home-manager,
      spdx-util,
      ...
    }@inputs:
    flakelight ./. (
      { config, ... }:
      {
        inherit inputs;
        imports = [
          flakelight.flakelightModules.extendFlakelight
          ./flakelight-treefmt.nix
        ];
        flakelightModule =
          { lib, ... }:
          {
            imports = [ ./flakelight-treefmt.nix ];
            inputs.treefmt-nix = lib.mkDefault treefmt-nix;
          };
        treefmtConfig = {
          programs = {
            nixfmt.enable = true;
            mdformat.plugins =
              ps: with ps; [
                mdformat-gfm
                mdformat-gfm-alerts
              ];
          };
        };
        withOverlays = [
          self.overlays.default
        ];
        homeConfigurations = import ./home-modules/default.nix;
        packages = {
          brepl = pkgs: pkgs.callPackage (import ./pkgs/brepl.nix) { };
          catnipContainer = pkgs: (import ./pkgs/catnip-container.nix) { inherit self inputs pkgs; };
          clojure-mcp-light = pkgs: pkgs.callPackage (import ./pkgs/clojure-mcp-light.nix) { };
          ramblurr-global-deps-edn = pkgs: pkgs.callPackage (import ./pkgs/deps-edn.nix) { };
          spdx = pkgs: spdx-util.packages.${pkgs.system}.default;
        };
        templates = import ./templates;
        outputs = {
          capsules = import ./devshells;
          schemas = inputs.flake-schemas.schemas // {
            capsules = {
              version = 1;
              doc = ''
                The `capsules` flake output contains common devshell modules specified via numtide/devshell.
              '';
              inventory = inputs.flake-schemas.lib.derivationsInventory "Devshell Capsules" false;
            };
          };
        };
        flakelight.builtinFormatters = false;
      }
    );
}
