{ config, pkgs, lib, ... }:
{

  home.stateVersion = "25.05";
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
    initExtra = ''
      # don't put duplicate lines or lines starting with space in the history.
      # See bash(1) for more options
      HISTCONTROL=ignoreboth
      # check the window size after each command and, if necessary,
      # update the values of LINES and COLUMNS.
      shopt -s checkwinsize

      # If set, the pattern "**" used in a pathname expansion context will
      # match all files and zero or more directories and subdirectories.
      #shopt -s globstar

      # make less more friendly for non-text input files, see lesspipe(1)
      [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

      # set variable identifying the chroot you work in (used in the prompt below)
      if [ -z "''${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
          debian_chroot=$(cat /etc/debian_chroot)
      fi

      # set a fancy prompt (non-color, unless we know we "want" color)
      case "$TERM" in
          xterm-color|*-256color) color_prompt=yes;;
      esac

      # uncomment for a colored prompt, if the terminal has the capability; turned
      # off by default to not distract the user: the focus in a terminal window
      # should be on the output of commands, not on the prompt
      #force_color_prompt=yes

      if [ -n "$force_color_prompt" ]; then
          if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
      	# We have color support; assume it's compliant with Ecma-48
      	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
      	# a case would tend to support setf rather than setaf.)
      	color_prompt=yes
          else
      	color_prompt=
          fi
      fi

      if [ "$color_prompt" = yes ]; then
          PS1='''${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
      else
          PS1='''${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
      fi
      unset color_prompt force_color_prompt

      # If this is an xterm set the title to user@host:dir
      case "$TERM" in
      xterm*|rxvt*)
          PS1="\[\e]0;''${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
          ;;
      *)
          ;;
      esac

      # enable color support of ls and also add handy aliases
      if [ -x /usr/bin/dircolors ]; then
          test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
          alias ls='ls --color=auto'
          #alias dir='dir --color=auto'
          #alias vdir='vdir --color=auto'

          alias grep='grep --color=auto'
          alias fgrep='fgrep --color=auto'
          alias egrep='egrep --color=auto'
      fi

      # colored GCC warnings and errors
      #export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

      # some more ls aliases
      alias ll='ls -alF'
      alias la='ls -A'
      alias l='ls -CF'
      alias ..='cd ..'
      alias ...='cd ...'

      # Add an "alert" alias for long running commands.  Use like so:
      #   sleep 10; alert
      alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s * [ 0-9 ]\ + \s * //;s/ [;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
# bash theme - partly inspired by https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme
__bash_prompt() {
    local userpart='`export XIT=$? \
        && [ ! -z "''${GITHUB_USER:-}" ] && echo -n "\[\033[0;32m\]@''${GITHUB_USER:-} " || echo -n "\[\033[0;32m\]\u " \
        && [ "$XIT" -ne "0" ] && echo -n "\[\033[1;31m\]➜" || echo -n "\[\033[0m\]➜"`'
    local gitbranch='`\
        if [ "$(git config --get devcontainers-theme.hide-status 2>/dev/null)" != 1 ] && [ "$(git config --get codespaces-theme.hide-status 2>/dev/null)" != 1 ]; then \
            export BRANCH="$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null)"; \
            if [ "''${BRANCH:-}" != "" ]; then \
                echo -n "\[\033[0;36m\](\[\033[1;31m\]''${BRANCH:-}" \
                && if [ "$(git config --get devcontainers-theme.show-dirty 2>/dev/null)" = 1 ] && \
                    git --no-optional-locks ls-files --error-unmatch -m --directory --no-empty-directory -o --exclude-standard ":/*" > /dev/null 2>&1; then \
                        echo -n " \[\033[1;33m\]✗"; \
                fi \
                && echo -n "\[\033[0;36m\]) "; \
            fi; \
        fi`'
    local lightblue='\[\033[1;34m\]'
    local removecolor='\[\033[0m\]'
    PS1="''${userpart} ''${lightblue}\w ''${gitbranch}''${removecolor}\$ "
    unset -f __bash_prompt
}
__bash_prompt
export PROMPT_DIRTRIM=4

# Check if the terminal is xterm
if [[ "$TERM" == "xterm" ]]; then
    # Function to set the terminal title to the current command
    preexec() {
        local cmd="''${BASH_COMMAND}"
        echo -ne "\033]0;''${USER}@''${HOSTNAME}: ''${cmd}\007"
    }

    # Function to reset the terminal title to the shell type after the command is executed
    precmd() {
        echo -ne "\033]0;''${USER}@''${HOSTNAME}: ''${SHELL}\007"
    }

    # Trap DEBUG signal to call preexec before each command
    trap 'preexec' DEBUG

    # Append to PROMPT_COMMAND to call precmd before displaying the prompt
    PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND; }precmd"
fi

      '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      warn_timeout = "30s";
      whitelist.prefix = [
        "~/"
        "/workspaces"
        "/code"
      ];
    };
  };

    xdg.configFile."clojure/deps.edn" =
      let
        cljDepsUrl = "https://raw.githubusercontent.com/Ramblurr/nixcfg/refs/heads/main/modules/dev/clojure/configs/deps.edn";
        # impure fetch
        cljDeps = builtins.fetchurl { url = cljDepsUrl; };
      in
      {
        source = cljDeps;
      };

    home.packages = with pkgs; [
      git
      jq
      ripgrep
      tmux
      babashka
      clojure
      (pkgs.writeScriptBin "run-clojure-mcp" ''
        #!/usr/bin/env bash
          set -euo pipefail
          PORT_FILE=''${1:-.nrepl-port}
          PORT=''${1:-4888}
          if [ -f "$PORT_FILE" ]; then
          PORT=$(cat ''${PORT_FILE})
          fi
          ${clojure}/bin/clojure -X:mcp/clojure :port $PORT
      '')

      (pkgs.writeScriptBin "run-repl" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        PID_FILE="''${PID_FILE:-.nrepl-pid}"
        ("${pkgs.babashka}/bin/bb" dev "$@" >/dev/null 2>&1 & echo $! >"$PID_FILE")
        echo "nREPL started (pid $(cat "$PID_FILE"))"
      '')

      (pkgs.writeScriptBin "kill-repl" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        PID_FILE="''${PID_FILE:-.nrepl-pid}"
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
        PORT_FILE="''${PORT_FILE:-.nrepl-port}"
        PID_FILE="''${PID_FILE:-.nrepl-pid}"
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

