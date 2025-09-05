#!/usr/bin/env bash
set -euo pipefail
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"


### Minimal Nix + Home Manager bootstrap for Ubuntu 24.04

# --- Config you may override via env ---
: "${HM_FLAKE_URI:=github:Ramblurr/nix-agent-dev}"

# Detect shell rc to append sourcing line (only if missing)
detect_shell_rc() {
  if [ -n "${ZSH_VERSION:-}" ]; then echo "$HOME/.zshrc"
  elif [ -n "${BASH_VERSION:-}" ]; then echo "$HOME/.bashrc"
  else echo "$HOME/.profile"
  fi
}

# Ensure experimental features for this user (no sudo needed)
ensure_nix_user_config() {
  local user_conf_dir="$HOME/.config/nix"
  local user_conf="$user_conf_dir/nix.conf"
  mkdir -p "$user_conf_dir"
  if [ ! -f "$user_conf" ] || ! grep -q '^experimental-features *=.*flakes' "$user_conf"; then
    {
      echo "experimental-features = nix-command flakes"
    } >> "$user_conf"
  fi
}

# Source nix profile into current session if present
source_nix_profile() {
  # Nix (daemon) profile path:
  local prof="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  if [ -e "$prof" ]; then
    # shellcheck disable=SC1090
    . "$prof"
  fi
}

# Append sourcing line to user rc if missing
persist_nix_profile_in_shell_rc() {
  local rc; rc="$(detect_shell_rc)"
  local prof_line='. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  if [ -f "$rc" ]; then
    if ! grep -qF "$prof_line" "$rc"; then
      printf "\n# Load Nix daemon profile\n%s\n" "$prof_line" >> "$rc"
    fi
  else
    printf "# Load Nix daemon profile\n%s\n" "$prof_line" > "$rc"
  fi
}

# Install Nix (daemon) if missing
install_nix_if_needed() {
  if ! command -v nix >/dev/null 2>&1; then
    echo ">> Installing Nix ..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  else
    echo ">> Nix already installed."
  fi
}

# Run home-manager to switch to the flake’s home configuration
activate_home_config() {
  local user host selector
  user="${USER}"
  host="$(hostname)"
  selector="${user}@${host}"

  echo ">> Activating Home Manager configuration: ${HM_FLAKE_URI}#${selector}"

  # Use the HM flake runner (no prior HM install needed)
  nix run --extra-experimental-features 'nix-command flakes' \
    github:nix-community/home-manager -- switch \
    --flake "${HM_FLAKE_URI}#${selector}"
}

main() {
  echo "=== Minimal Nix + Home Manager bootstrap ==="

  # 1) Install Nix (daemon) if needed
  install_nix_if_needed

  # 2) Make nix available in this shell + future shells
  source_nix_profile
  persist_nix_profile_in_shell_rc

  # 3) Ensure user-level flakes are enabled
  ensure_nix_user_config

  # Safety: confirm nix works now
  if ! command -v nix >/dev/null 2>&1; then
    echo "!! nix command not found after install. Please re-login and rerun this script."
    exit 1
  fi

  # 4) Fetch and activate Ramblurr/agent-remote-dev home configuration
  activate_home_config

  echo "=== Done. If this was your first Nix install, log out/in for shells to pick up Nix by default. ==="
}

main "$@"

