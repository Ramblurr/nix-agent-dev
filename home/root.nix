# This returns homeManagerConfiguration args for flakelight
# Note: flakelight passes inputs to the home-manager configuration via extraSpecialArgs
_: {
  system = "x86_64-linux";
  modules = [
    ({ pkgs, lib, inputs, ... }: {
      imports = [
        ./home.nix
      ];

      home.username = "root";
      home.homeDirectory = "/root";
      home.stateVersion = "25.05";
      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.allowUnfreePredicate = _: true;
      programs.home-manager.enable = true;
    })
  ];
}
