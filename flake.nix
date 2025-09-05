{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    flakelight.url = "github:nix-community/flakelight";
    flakelight.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    home-manger.url = "github:nix-community/home-manager";
    home-manager.nixpkgs.follows = "nixpkgs";
  };
  outputs = { flakelight, home-manager, ... }@inputs:
    flakelight ./. ({ config, ... }: {
      inherit inputs;
      homeConfigurations.username = {
        system = "x86_64-linux";
        modules = [{ home.stateVersion = "25.05"; }];
      };
    });
}
