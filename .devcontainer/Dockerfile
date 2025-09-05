# renovate: datasource=github-tags depName=devbox packageName=jetify-com/devbox
ARG DEVBOX_VERSION=0.16.0

# I use devbox to install nix in a non-root docker devcontainer environment,
# which the other installers (official and detsys) don't support
# I dont actually use any of the devbox features
FROM jetpackio/devbox:${DEVBOX_VERSION}
ENV HM_FLAKE_URI=github:Ramblurr/nix-agent-dev
WORKDIR /code

USER root:root

RUN mkdir -p /code && chown ${DEVBOX_USER}:${DEVBOX_USER} /code

USER ${DEVBOX_USER}:${DEVBOX_USER}

COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} devbox.json devbox.json
COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} devbox.lock devbox.lock

ENV USER=${DEVBOX_USER}
ENV NIX_CONFIG="experimental-features = nix-command flakes"
RUN devbox run -- echo "Installed Packages." \
  && nix-store --gc \
  && nix build --extra-experimental-features 'nix-command flakes' \
  --impure --no-write-lock-file --no-link --show-trace \
  "${HM_FLAKE_URI}#homeConfigurations.${DEVBOX_USER}.activationPackage"

RUN devbox shellenv --init-hook >> ~/.profile
