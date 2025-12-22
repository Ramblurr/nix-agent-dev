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
            imports = [ ./home.nix ];
            home.username = username;
            home.homeDirectory = homeDirectory;
          }
        )
      ];
    };
in
{

  root = mkUser { username = "root"; };
  vscode = mkUser { username = "vscode"; };
  catnip = mkUser { username = "catnip"; };
  ramblurr = mkUser { username = "ramblurr"; };
}
