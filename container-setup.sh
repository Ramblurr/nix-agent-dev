#!/usr/bin/env bash
set -euo pipefail

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    ENV_BEFORE=$(export -p | sort)
fi

export HM_FLAKE_URI=github:Ramblurr/nix-agent-dev
export USER="${USER:-$(id -un)}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"

echo "export XDG_CACHE_HOME=$XDG_CACHE_HOME" >>~/.bashrc
echo "export XDG_CONFIG_HOME=$XDG_CONFIG_HOME" >>~/.bashrc

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export XDG_CACHE_HOME=$XDG_CACHE_HOME" >>"$CLAUDE_ENV_FILE"
    echo "export XDG_CONFIG_HOME=$XDG_CONFIG_HOME" >>"$CLAUDE_ENV_FILE"
fi

if [ -n "${CODEX_PROXY_CERT:-}" ]; then
    echo "CODEX_PROXY_CERT detected, configured JAVA_TOOL_OPTIONS and CLOJURE_CLI_JVM_OPTS for SSL trust store"
    JAVA_SSL_OPTS="-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=PKCS12"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }$JAVA_SSL_OPTS"
    export CLOJURE_CLI_JVM_OPTS="${CLOJURE_CLI_JVM_OPTS:+$CLOJURE_CLI_JVM_OPTS }$JAVA_SSL_OPTS"
fi

echo "=== Development Environment Setup ==="

# Install Nix using DeterminateSystems installer
echo "Installing Nix..."
if ! command -v nix &>/dev/null; then
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required but not installed." >&2
        exit 1
    fi
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

    # Source nix daemon for current session
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi

    # Verify Nix is working
    if ! command -v nix &>/dev/null; then
        echo "Nix installation complete, but requires shell restart."
        echo "Please restart your shell and run this script again to continue setup."
        exit 0
    fi

    determinate-nixd daemon &

    # Login to FlakeHub if token is available
    if [ -n "${FLAKEHUB_TOKEN:-}" ]; then
        echo "Logging in to FlakeHub..."
        TOKEN_FILE="/root/fh.token"
        echo "$FLAKEHUB_TOKEN" >"$TOKEN_FILE"
        determinate-nixd login token --token-file "$TOKEN_FILE"
        rm -f "$TOKEN_FILE"
        echo "FlakeHub login complete"
    fi
else
    echo "Nix is already installed"
fi

# Prepare home-manager installation
nix build --impure --no-write-lock-file --no-link --show-trace "${HM_FLAKE_URI}#homeConfigurations.${USER}.activationPackage"

# Install direnv
echo "Installing direnv..."
if ! command -v direnv &>/dev/null; then
    nix profile add nixpkgs#direnv
else
    echo "direnv is already installed"
fi

# Setup direnv config (whitelist)
echo "Configuring direnv..."
mkdir -p "$XDG_CONFIG_HOME/direnv"

DIRENV_TOML="$XDG_CONFIG_HOME/direnv/direnv.toml"
if [ ! -f "$DIRENV_TOML" ]; then
    cat >"$DIRENV_TOML" <<EOF
[whitelist]
prefix = [ "~/" ]
EOF
    echo "Created $DIRENV_TOML with whitelist for home directory"
else
    echo "$DIRENV_TOML already exists, skipping creation"
fi

# Setup direnv shell hook
echo "Setting up direnv shell hooks..."

# Detect shell and add appropriate hook
SHELL_NAME=$(basename "${SHELL:-sh}")
case "$SHELL_NAME" in
bash)
    SHELL_RC="$HOME/.bashrc"
    HOOK_CMD='eval "$(direnv hook bash)"'
    cat >>"$SHELL_RC" <<'EOF'
unset PROMPT_COMMAND
PS1='\u@\h\$ '
EOF
    ;;
zsh)
    SHELL_RC="$HOME/.zshrc"
    HOOK_CMD='eval "$(direnv hook zsh)"'
    cat >>"$SHELL_RC" <<'EOF'
unset PROMPT_COMMAND
PS1='%n@%m%# '
EOF
    ;;
*)
    echo "Warning: Unsupported shell '$SHELL_NAME'. Please manually add direnv hook."
    SHELL_RC=""
    ;;
esac

if [ -n "${SHELL_RC:-}" ]; then
    if ! grep -q "direnv hook" "$SHELL_RC" 2>/dev/null; then
        {
            echo ""
            echo "# Added by remote env container setup"
            echo "$HOOK_CMD"
        } >>"$SHELL_RC"
        echo "direnv hook added to $SHELL_RC"
    else
        echo "direnv hook already exists in $SHELL_RC"
    fi

    # Load direnv for current session
    eval "$HOOK_CMD"

    if [ -n "${CODEX_PROXY_CERT:-}" ]; then
        if ! grep -q "javax.net.ssl.trustStore" "$SHELL_RC" 2>/dev/null; then
            {
                echo ""
                echo "# Java SSL trust store configuration (added by container setup)"
                echo 'export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }'"$JAVA_SSL_OPTS"'"'
                echo 'export CLOJURE_CLI_JVM_OPTS="${CLOJURE_CLI_JVM_OPTS:+$CLOJURE_CLI_JVM_OPTS }'"$JAVA_SSL_OPTS"'"'
            } >>"$SHELL_RC"
            echo "JAVA_TOOL_OPTIONS and CLOJURE_CLI_JVM_OPTS added to $SHELL_RC"
        fi
    fi
fi

echo "Ensuring Maven local repository exists at: $XDG_CACHE_HOME/maven/repository"
mkdir -p "$XDG_CACHE_HOME/maven/repository"

# Fetch and install Clojure deps.edn
echo "Setting up Clojure deps.edn..."
CLOJURE_CONFIG_DIR="$XDG_CONFIG_HOME/clojure"
DEPS_PATH="$CLOJURE_CONFIG_DIR/deps.edn"
DEPS_URL="https://raw.githubusercontent.com/Ramblurr/nixcfg/refs/heads/main/modules/dev/clojure/configs/deps.edn"

mkdir -p "$CLOJURE_CONFIG_DIR"

tmpfile="$(mktemp)"
cleanup() { rm -f "$tmpfile"; }
trap cleanup EXIT

if ! command -v curl &>/dev/null; then
    echo "Error: curl is required to fetch deps.edn but not installed." >&2
    exit 1
fi

echo "Downloading deps.edn from: $DEPS_URL"
if ! curl -fsSL "$DEPS_URL" -o "$tmpfile"; then
    echo "Error: Failed to download deps.edn from $DEPS_URL" >&2
    exit 1
fi

# Replace /home/ramblurr with the actual HOME path (embed absolute path; clojure cli doesn't eval env vars)
HOME_ABS="$HOME"
sed 's|/home/ramblurr|'"$HOME_ABS"'|g' "$tmpfile" >"$DEPS_PATH"

echo "Installed deps.edn to $DEPS_PATH (with paths rewritten to $HOME_ABS)"

# Run direnv allow if .envrc exists
if [ -f ".envrc" ]; then
    echo "Running direnv allow..."
    direnv allow
else
    echo "No .envrc file found in current directory"
fi

# Create repl helper scripts
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"
echo 'export PATH=$HOME/.local/bin/:$PATH' >>~/.bashrc

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo 'export PATH=$HOME/.local/bin/:$PATH' >>"$CLAUDE_ENV_FILE"
fi

# run-repl: start bb dev in background and store PID
cat >"$BIN_DIR/run-repl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PID_FILE="${PID_FILE:-.nrepl-pid}"
(bb dev "$@" >/dev/null 2>&1 & echo $! >"$PID_FILE")
echo "nREPL started (pid $(cat "$PID_FILE"))"
EOF
chmod +x "$BIN_DIR/run-repl"

# kill-repl: stop process from PID file
cat >"$BIN_DIR/kill-repl" <<'EOF'
#!/usr/bin/env bash
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
  exit 0
fi
EOF
chmod +x "$BIN_DIR/kill-repl"

# restart-repl: reuse .nrepl-port if present, then relaunch
cat >"$BIN_DIR/restart-repl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PORT_FILE="${PORT_FILE:-.nrepl-port}"
PID_FILE="${PID_FILE:-.nrepl-pid}"
port=""
[[ -s "$PORT_FILE" ]] && port="$(cat "$PORT_FILE")"
kill-repl
if [[ -n "$port" ]]; then
  (bb dev --port "$port" >/dev/null 2>&1 & echo $! >"$PID_FILE")
  echo "nREPL restarted on port $port (pid $(cat "$PID_FILE"))"
else
  (bb dev >/dev/null 2>&1 & echo $! >"$PID_FILE")
  echo "nREPL restarted (auto port) (pid $(cat "$PID_FILE"))"
fi
EOF
chmod +x "$BIN_DIR/restart-repl"

echo ""
echo ""

set +u
set +e

# Home Manager helper scripts
cat >"$BIN_DIR/home-manager-update" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
cd "$XDG_CONFIG_HOME/home-manager"
git fetch origin
git reset --hard origin/main
if command -v home-manager &> /dev/null; then
  home-manager switch --impure -b backup
else
  nix run github:nix-community/home-manager -- switch --impure -b backup
fi
EOF
chmod +x "$BIN_DIR/home-manager-update"

cat >"$BIN_DIR/dev-env-start" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if command -v home-manager-update &> /dev/null; then
  home-manager-update
fi
if [ -n "${WORKSPACE_FOLDER:-}" ]; then
  cd "$WORKSPACE_FOLDER"
  nix develop --command -- echo "Start hook: Prepared env for $WORKSPACE_FOLDER"
fi
EOF
chmod +x "$BIN_DIR/dev-env-start"

cat >"$BIN_DIR/dev-env-poststart" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if command -v home-manager-update &> /dev/null; then
  home-manager-update
fi
if [ -n "${WORKSPACE_FOLDER:-}" ]; then
  cd "$WORKSPACE_FOLDER"
  nix develop --command -- echo "Post start hook: Prepared env for $WORKSPACE_FOLDER"
fi
EOF
chmod +x "$BIN_DIR/dev-env-poststart"

# Seed Nix cache by building the default devShell
WORKSPACE_ROOT="/workspace"

if [ -d "$WORKSPACE_ROOT" ]; then
    FLAKE_DIR="$(find "$WORKSPACE_ROOT" -maxdepth 2 -name flake.nix -print -quit | xargs -r dirname)"
    if [ -n "$FLAKE_DIR" ]; then
        SYSTEM="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
        echo "Seeding Nix cache from flake at $FLAKE_DIR for $SYSTEM"
        echo "(this could take awhile, please be patient)"
        (
            cd "$FLAKE_DIR"
            nix build ".#devShells.${SYSTEM}.default"
        )
        echo "Seeding Nix cache complete"
    fi
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    ENV_AFTER=$(export -p | sort)
    comm -13 <(echo "$ENV_BEFORE") <(echo "$ENV_AFTER") >>"$CLAUDE_ENV_FILE"
fi

# Auto-start repl if bb.edn exists
if [ -f "bb.edn" ]; then
    echo "bb.edn detected"
    if bb tasks 2>/dev/null | grep -q '^prep'; then
        echo "Running bb prep..."
        bb prep
    fi
    echo "Starting nREPL..."
    "$HOME/.local/bin/run-repl"
fi

echo "=== Setup Complete ==="
