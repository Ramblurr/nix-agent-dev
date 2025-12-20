# nix-agent-dev

This project contains nix config for dev environments for coding agents.

I use nix flakes extensively (nearly exclusively) for defining my development environments. 

Most of the remote coding agent systems (codex, claude web, terragon) do not
allow you to bring your own container image.  So this repo serves as a bunch of
scripts that infect their repo with nix and home-manager. The home-manager
environment here is intentionally light, because most of the heavy devenv is in
a per-project flake devshell.

It supports multiple remote agent systems:

- terragon-setup.sh for [Terragon](https://terragonlabs.com )
- container-setup.sh for [ChatGPT Codex](https://chatgpt.com/codex)
- .devcontainer/Dockerfile - works with [gitpod/Ona](https://ona.com)
- Dockerfile.catnip for [catnip](https://github.com/wandb/catnip)

## Build

```bash
# enter devshell
nix develop

# build devcontainer
docker build -t nix-agent-dev:devcontainer -f .devcontainer/Dockerfile .
# build catnip container
docker build -t nix-agent-dev:catnip -f Dockerfile.catnip .
# also reference the .github/workflows/
```


## Inspiration

https://github.com/kasuboski/dotfiles/blob/c7f468d3013d5bd372a5c3a9610b63e3eec469dd/devcontainer.nix
