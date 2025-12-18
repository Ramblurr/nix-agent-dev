#!/bin/bash
set -e

# Start determinate-nixd daemon and login to FlakeHub if token is available
if [ -n "${FLAKEHUB_TOKEN:-}" ]; then
    echo "[nix-entrypoint] Starting determinate-nixd daemon..."
    nohup /usr/local/bin/determinate-nixd daemon > /var/log/determinate-nixd.log 2>&1 &

    # Wait for daemon to be ready
    echo "[nix-entrypoint] Waiting for determinate-nixd daemon..."
    for i in $(seq 1 30); do
        if determinate-nixd status >/dev/null 2>&1; then
            break
        fi
        sleep 0.2
    done

    if determinate-nixd status >/dev/null 2>&1; then
        echo "[nix-entrypoint] determinate-nixd daemon is ready"

        # Login to FlakeHub
        echo "[nix-entrypoint] Logging in to FlakeHub..."
        TOKEN_FILE="/tmp/flakehub.token"
        echo -n "$FLAKEHUB_TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"

        if determinate-nixd login token --token-file "$TOKEN_FILE"; then
            echo "[nix-entrypoint] FlakeHub login successful"
        else
            echo "[nix-entrypoint] FlakeHub login failed (continuing anyway)"
        fi

        rm -f "$TOKEN_FILE"

        # Export for nix to use the daemon
        export NIX_REMOTE=daemon
    else
        echo "[nix-entrypoint] Warning: determinate-nixd daemon failed to start"
    fi
else
    echo "[nix-entrypoint] FLAKEHUB_TOKEN not set, skipping FlakeHub login"
fi

# Execute the original catnip entrypoint
exec /entrypoint.sh "$@"
