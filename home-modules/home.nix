{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{

  home.stateVersion = "25.11";
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = _: true;
  programs.home-manager.enable = true;
  xdg.enable = true;
  home.sessionVariables = {
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
  };
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  programs.bash = {
    enable = true;
    initExtra = (builtins.readFile ./bashInit.rc);
  };
  home.file.".bashrc".force = true;
  home.file.".profile".force = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      warn_timeout = "30s";
      whitelist.prefix = [
        "~/"
        "/workspaces"
        "/workspace"
        "/code"
      ];
    };
  };

  xdg.configFile."clojure/deps.edn" = {
    source = "${
      pkgs.callPackage ../pkgs/deps-edn.nix {
        cacheDirectory = config.xdg.cacheHome;
      }
    }/share/clojure/deps.edn";
  };

  home.packages = [
    pkgs.dumbpipe
    pkgs.magic-wormhole-rs
    pkgs.git
    pkgs.jq
    pkgs.ripgrep
    pkgs.fd
    pkgs.jless
    pkgs.tmux
    (pkgs.writeScriptBin "run-clojure-mcp" ''
      #!/usr/bin/env bash
        set -euo pipefail
        PORT_FILE=''${1:-.nrepl-port}
        PORT=''${1:-4888}
        if [ -f "$PORT_FILE" ]; then
        PORT=$(cat ''${PORT_FILE})
        fi
        clojure -X:mcp/clojure :port $PORT
    '')
  ]
  ++ (with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    claude-code
    codex
    copilot-cli
    gemini-cli
  ]);
}
