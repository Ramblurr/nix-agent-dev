FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install dependencies for Nix
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends curl xz-utils sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the setup script
COPY terragon-setup.sh /tmp/terragon-setup.sh
RUN chmod +x /tmp/terragon-setup.sh

# Set environment variable to point to the correct repo for home manager config
ENV HM_FLAKE_URI=github:Ramblurr/nix-agent-dev

# Switch to vscode user and run setup
USER vscode
WORKDIR /home/vscode

# Run the setup script to install Nix and activate home manager
RUN /tmp/terragon-setup.sh

# Ensure nix is available in PATH for subsequent commands
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
