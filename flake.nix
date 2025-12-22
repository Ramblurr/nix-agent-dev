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
    flakelight.url = "github:nix-community/flakelight";
    flakelight.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
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
  };
  outputs =
    {
      self,
      flakelight,
      home-manager,
      ...
    }@inputs:
    let
      # Creates a home-manager configuration for a user.
      # Returns homeManagerConfiguration args for flakelight.
      # Note: flakelight passes inputs to the home-manager configuration via extraSpecialArgs.
      mkUser =
        {
          username,
          system ? "x86_64-linux",
          homeDirectory ? (if username == "root" then "/root" else "/home/${username}"),
        }:
        _: {
          inherit system;
          modules = [
            (
              { ... }:
              {
                imports = [ ./config/home.nix ];
                home.username = username;
                home.homeDirectory = homeDirectory;
              }
            )
          ];
        };
    in
    flakelight ./. (
      { config, ... }:
      {
        inherit inputs;
        homeConfigurations.root = mkUser { username = "root"; };
        homeConfigurations.vscode = mkUser { username = "vscode"; };
        homeConfigurations.catnip = mkUser { username = "catnip"; };
        homeConfigurations.ramblurr = mkUser { username = "ramblurr"; };

        withOverlays = [
          self.overlays.default
        ];
        packages = {
          brepl = pkgs: pkgs.callPackage (import ./pkgs/brepl.nix) { };
          catnipContainer = pkgs: (import ./pkgs/catnip-container.nix) { inherit self inputs pkgs; };
          clojure-mcp-light = pkgs: pkgs.callPackage (import ./pkgs/clojure-mcp-light.nix) { };
          ramblurr-global-deps-edn = pkgs: pkgs.callPackage (import ./pkgs/deps-edn.nix) { };
        };
        flakelight.builtinFormatters = false;
        formatters = pkgs: {
          "*.nix" = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
        };
      }
    );
}
