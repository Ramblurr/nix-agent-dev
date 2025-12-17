#!/usr/bin/env bash
set -euo pipefail

export HM_FLAKE_URI=github:Ramblurr/nix-agent-dev
export USER="${USER:-$(id -un)}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"

echo "export XDG_CACHE_HOME=$XDG_CACHE_HOME" >>~/.bashrc
echo "export XDG_CONFIG_HOME=$XDG_CONFIG_HOME" >>~/.bashrc

if [ -n "${CODEX_PROXY_CERT:-}" ]; then
    echo "CODEX_PROXY_CERT detected, configured JAVA_TOOL_OPTIONS and CLOJURE_CLI_JVM_OPTS for SSL trust store"
    JAVA_SSL_OPTS="-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=PKCS12"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }$JAVA_SSL_OPTS"
    export CLOJURE_CLI_JVM_OPTS="${CLOJURE_CLI_JVM_OPTS:+$CLOJURE_CLI_JVM_OPTS }$JAVA_SSL_OPTS"
fi

echo "=== Development Environment Setup ==="

# Install Nix using DeterminateSystems installer
if ! command -v nix &>/dev/null && [[ ! -f /nix/receipt.json ]]; then
    echo "Installing Nix..."
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required but not installed." >&2
        exit 1
    fi
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
else
    echo "Nix is already installed"
fi

if [ -n "${FLAKEHUB_TOKEN:-}" ]; then
    echo "Starting determinate-nixd daemon"
    nohup /usr/local/bin/determinate-nixd daemon &
    while ! determinate-nixd status &>/dev/null; do
        sleep 0.1
    done
    export NIX_REMOTE=daemon
    export PATH="$PATH:$HOME/.nix-profile/bin/"
    echo "Logging in to FlakeHub..."
    TOKEN_FILE="$HOME/fh.token"
    echo -n "$FLAKEHUB_TOKEN" >"$TOKEN_FILE"
    determinate-nixd login token --token-file "$TOKEN_FILE"
    rm -f "$TOKEN_FILE"
    echo "FlakeHub login complete"
else
    echo "Skipping Flakehub Login, FLAKEHUB_TOKEN is not defined"
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

fi

# Prepare home-manager installation
nix build --impure --no-write-lock-file --no-link --show-trace "${HM_FLAKE_URI}#homeConfigurations.${USER}.activationPackage"

BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"
echo 'export PATH=$HOME/.local/bin/:$PATH' >>~/.bashrc

echo ""
set +u
set +e

set -x

mv $HOME/.bashrc $HOME/.bashrc.orig
mv /$HOME/.profile $HOME/.profile.orig
rm -rf $HOME/.config/clojure
rm -rf /$HOME/.config/direnv
nix profile list
nix profile remove direnv

# Home Manager helper scripts
cat >"$BIN_DIR/home-manager-update" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
target="$XDG_CONFIG_HOME/home-manager"
if [[ ! -d "$target" ]]; then
    git clone https://github.com/Ramblurr/nix-agent-dev "$target"
    cd "$target"
else
    cd "$target"
    git fetch
    git reset --hard origin/main
fi
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

echo "=== Setup Complete ==="
echo
echo "Running $BIN_DIR/dev-env-start to activate the nix environment"
echo

$BIN_DIR/dev-env-start
