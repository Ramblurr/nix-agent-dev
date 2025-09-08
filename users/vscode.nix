# This returns homeManagerConfiguration args for flakelight
# Note: flakelight passes inputs to the home-manager configuration via extraSpecialArgs
_: {
  system = "x86_64-linux";
  modules = [
    ({ pkgs, lib, inputs, ... }: {
      imports = [
        ../config/home.nix
      ];

      home.username = "vscode";
      home.homeDirectory = "/home/vscode";
    })
  ];
}
