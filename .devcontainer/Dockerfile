FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install dependencies for Nix
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends curl xz-utils sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

#VOLUME /nix

RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
  --extra-conf "sandbox = false" \
  --init none \
  --no-confirm

ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
ENV USER=vscode

# Basic Nix configuration (as root)
# Ensure /etc/nix exists before trying to write to nix.conf
RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "trusted-users = root ${USER} @wheel" >> /etc/nix/nix.conf

ENV HM_FLAKE_URI=github:Ramblurr/nix-agent-dev
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && \
  nix build --impure --no-write-lock-file "${HM_FLAKE_URI}#homeConfigurations.${USER}.activationPackage" --no-link

USER ${USER}
WORKDIR /home/${USER}
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
