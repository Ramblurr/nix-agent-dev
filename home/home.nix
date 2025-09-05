{ config, pkgs, lib, ... }:
{
  xdg.enable = true;
  home.sessionVariables = {
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
  };
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # --- Shells
  programs.bash = {
    enable = true;
    #initExtra = ''
    #  if [ -f "${config.home.homeDirectory}/.auto-repl" ] && [ -f "bb.edn" ]; then
    #    "${config.home.homeDirectory}/.local/bin/run-repl" >/dev/null 2>&1 &
    #  fi
    #'';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      warn_timeout = "30s";
      whitelist.prefix = [ "~/" ];
    };
  };

  home.packages = with pkgs; [
    git
    jq
    ripgrep
    fd
    tmux
    vim
    babashka
    clojure
    clojure-lsp
    # run-repl
    (pkgs.writeScriptBin "run-repl" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      PID_FILE="${PID_FILE:-.nrepl-pid}"
      ("${pkgs.babashka}/bin/bb" dev "$@" >/dev/null 2>&1 & echo $! >"$PID_FILE")
      echo "nREPL started (pid $(cat "$PID_FILE"))"
    '')

    (pkgs.writeScriptBin "kill-repl" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      PID_FILE="${PID_FILE:-.nrepl-pid}"
      [[ -s "$PID_FILE" ]] || { echo "No PID file: $PID_FILE"; exit 1; }
      pid="$(cat "$PID_FILE")"
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" || true
        for _ in {1..20}; do kill -0 "$pid" 2>/dev/null || { rm -f "$PID_FILE"; echo "Killed $pid"; exit 0; }; sleep 0.1; done
        echo "Process $pid did not exit"; exit 1
      else
        echo "Process $pid not running"; rm -f "$PID_FILE" || true
      fi
    '')
    (pkgs.writeScriptBin "restart-repl" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      PORT_FILE="${PORT_FILE:-.nrepl-port}"
      PID_FILE="${PID_FILE:-.nrepl-pid}"
      port=""
      [[ -s "$PORT_FILE" ]] && port="$(cat "$PORT_FILE")"
      kill-repl || true
      if [[ -n "$port" ]]; then
        ("${pkgs.babashka}/bin/bb" dev --port "$port" >/dev/null 2>&1 & echo $! >"$PID_FILE")
        echo "nREPL restarted on port $port (pid $(cat "$PID_FILE"))"
      else
        ("${pkgs.babashka}/bin/bb" dev >/dev/null 2>&1 & echo $! >"$PID_FILE")
        echo "nREPL restarted (auto port) (pid $(cat "$PID_FILE"))"
      fi
    '')
  ];
}

