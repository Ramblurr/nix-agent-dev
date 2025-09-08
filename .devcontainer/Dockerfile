FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends curl xz-utils sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER root
ENV DEVBOX_USER=vscode
RUN usermod -aG sudo $DEVBOX_USER
RUN echo "${DEVBOX_USER} ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$DEVBOX_USER
USER $DEVBOX_USER

RUN wget --output-document=/dev/stdout https://nixos.org/nix/install | sh -s -- --no-daemon
RUN . ~/.nix-profile/etc/profile.d/nix.sh
ENV PATH="/home/${DEVBOX_USER}/.local/bin:/home/${DEVBOX_USER}/.nix-profile/bin:$PATH"
ENV HM_FLAKE_URI=github:Ramblurr/nix-agent-dev
WORKDIR /code
USER root:root
RUN mkdir -p /code && chown ${DEVBOX_USER}:${DEVBOX_USER} /code
USER ${DEVBOX_USER}:${DEVBOX_USER}
ENV USER=${DEVBOX_USER}
ENV NIX_CONFIG="experimental-features = nix-command flakes"
COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} . /home/${DEVBOX_USER}/.config/home-manager
ENV PATH="/home/${DEVBOX_USER}/.local/bin:/home/${DEVBOX_USER}/.nix-profile/bin:$PATH"
RUN mkdir -p /home/${DEVBOX_USER}/.local/bin/ && cat > /home/${DEVBOX_USER}/.local/bin/home-manager-update << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd ~/.config/home-manager
git fetch origin
git reset --hard origin/main
if command -v home-manager &> /dev/null; then
  home-manager switch --impure -b backup
else
  nix run github:nix-community/home-manager -- switch --impure -b backup
fi
EOF

RUN cat > /home/${DEVBOX_USER}/.local/bin/dev-env-start << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
home-manager-update
if [ -n "${WORKSPACE_FOLDER:-}" ]; then
  cd "$WORKSPACE_FOLDER"
  nix develop --command -- echo "Start hook: Prepared env for $WORKSPACE_FOLDER"
fi
EOF

RUN cat > /home/${DEVBOX_USER}/.local/bin/dev-env-poststart << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
home-manager-update
if [ -n "${WORKSPACE_FOLDER:-}" ]; then
  cd "$WORKSPACE_FOLDER"
  nix develop --command -- echo "Post start hook: Prepared env for $WORKSPACE_FOLDER"
fi
EOF

RUN mkdir -p /home/${DEVBOX_USER}/.local/bin \
  && chmod +x /home/${DEVBOX_USER}/.local/bin/home-manager-update \
  && chmod +x /home/${DEVBOX_USER}/.local/bin/dev-env-start \
  && chmod +x /home/${DEVBOX_USER}/.local/bin/dev-env-poststart \
  && chown -R ${DEVBOX_USER}:${DEVBOX_USER} /home/${DEVBOX_USER}/.local

RUN set -x && ls -alh /home/${DEVBOX_USER}/.config/home-manager && mkdir -p /home/${DEVBOX_USER}/.config/nix \
  && echo "experimental-features = nix-command flakes" > /home/${DEVBOX_USER}/.config/nix/nix.conf \
  && nix-store --gc \
  && cd /home/${DEVBOX_USER}/.config/home-manager \
  && nix build --extra-experimental-features 'nix-command flakes' \
  --impure --no-write-lock-file --no-link --show-trace \
  "#homeConfigurations.${DEVBOX_USER}.activationPackage"
