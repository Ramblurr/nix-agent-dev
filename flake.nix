{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    flakelight.url = "github:nix-community/flakelight";
    flakelight.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { flakelight, home-manager, ... }@inputs:
    flakelight ./. ({ config, ... }: {
      inherit inputs;
      homeConfigurations.root = import ./users/root.nix inputs;
      homeConfigurations.vscode = import ./users/vscode.nix inputs;
      homeConfigurations.devbox = import ./users/devbox.nix inputs;
    });
}
