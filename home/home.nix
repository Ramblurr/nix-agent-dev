{ config, pkgs, lib, ... }:
let
  user = builtins.getEnv "USER";
  homeDir = builtins.getEnv "HOME";
in
{
  # --- Identity & paths
  home.username = lib.mkDefault user;
  home.homeDirectory = lib.mkDefault homeDir;
  home.stateVersion = "24.05"; # adjust if your HM version differs

  # Enable XDG and set common session vars the script exported
  xdg.enable = true;
  home.sessionVariables = {
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
  };
  # Ensure ~/.local/bin is on PATH (used below for custom scripts)
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # --- Shells
  programs.bash = {
    enable = true;
    # HM will inject direnv hooks automatically (see programs.direnv below)
    initExtra = ''
      # Optional: auto-start a repl in dirs containing bb.edn when a toggle file exists
      if [ -f "${config.home.homeDirectory}/.auto-repl" ] && [ -f "bb.edn" ]; then
        "${config.home.homeDirectory}/.local/bin/run-repl" >/dev/null 2>&1 &
      fi
    '';
  };
  programs.zsh = {
    enable = true;
    initExtra = config.programs.bash.initExtra;
  };

  # --- Direnv + nix-direnv (replaces manual hook & config)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      warn_timeout = "10s"; # mirrors the simple direnv.toml created in the script
    };
  };

  # --- Packages the script likely ensured were present
  # Tune this list to match your original script's toolset.
  home.packages = with pkgs; [
    direnv
    nix-direnv
    git
    jq
    ripgrep
    fd
    tmux
    neovim
    babashka
    clojure
    clojure-lsp
  ];

  # --- Files written by the script
  # ~/.config/direnv/direnv.toml
  xdg.configFile."direnv/direnv.toml".text = ''
    [global]
    warn_timeout = "10s"
  '';

  # ~/.local/bin/run-repl (created & chmod +x by the script)
  home.file.".local/bin/run-repl" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Start a Clojure nREPL in the current project.
      # If a bb.edn is present, prefer babashka's nREPL for fast utility REPLs.
      if [ -f "bb.edn" ]; then
        exec ${pkgs.babashka}/bin/bb --nrepl-server 127.0.0.1:7888
      else
        exec ${pkgs.clojure}/bin/clojure \
          -Sdeps '{:deps {nrepl/nrepl {:mvn/version "1.1.1"}}}' \
          -M -m nrepl.cmdline --host 127.0.0.1 --port 7888
      fi
    '';
  };

  # ~/.local/bin/restart-repl (created & chmod +x by the script)
  home.file.".local/bin/restart-repl" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      pkill -f 'nrepl' || true
      sleep 0.2
      "${HOME}/.local/bin/run-repl"
    '';
  };
}

