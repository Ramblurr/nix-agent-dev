# renovate: datasource=github-tags depName=devbox packageName=jetify-com/devbox
ARG DEVBOX_VERSION=0.16.0
FROM jetpackio/devbox:${DEVBOX_VERSION}
ENV DEVBOX_USER=vscode
ENV HM_FLAKE_URI=github:Ramblurr/nix-agent-dev
WORKDIR /home/${DEVBOX_USER}

# I use devbox to install nix in a non-root docker devcontainer environment,
# which the other installers (official and detsys) don't support
# I dont actually use any of the devbox features
COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} devbox.json devbox.json
COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} devbox.lock devbox.lock
RUN devbox install && nix-store --gc && nix build --extra-experimental-features 'nix-command flakes' --impure --no-write-lock-file "${HM_FLAKE_URI}#homeConfigurations.${DEVBOX_USER}.activationPackage" --no-link
