# nix-devenv

Reusable Nix Flake [devshells] for my frequently used toolchains, and container/microvm environments sandboxed coding agents.

This flake also exposes it self as [a flakelight module][flakelight]. It extends your flakelight project to replace the builtin formatter with one powered by treefmt-nix.

## Devshell Capsules

I ship my devshells as "capsules" which are snippets of [numtide/devshell][devshell] configuration.

Available capsules:

| Capsule   |
|-----------|
| `clojure` |

<details>
<summary><b>Here is a minimal flake using the flakelight functionality and my clojure devshell capsule.</b></summary>

``` nix
{
  description = "my dev env";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    devshell.url = "github:numtide/devshell";
    devenv.url = "github:ramblurr/nix-devenv";
    devenv.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      self,
      flakelight,
      devenv,
      devshell,
      ...
    }:
    devenv.lib.mkFlake ./. {
      # inside here we are flakelight
      # refer to https://github.com/nix-community/flakelight/blob/master/API_GUIDE.md
      # for all attrs and functions
      withOverlays = [
        devshell.overlays.default
        devenv.overlays.default
      ];
      devShell =
        pkgs:
        pkgs.devshell.mkShell {
          # https://numtide.github.io/devshell
          imports = [
            devenv.capsules.clojure
          ];
          commands = [
            { package = pkgs.cowsay; }
          ];
          packages = [ ];
        };
    };
}
```
</details>

## Templates

Use `nix flake new` to create new projects.

| Template  | Description                                                                      |
|-----------|----------------------------------------------------------------------------------|
| `clojure` | A minimal clojure application template with a deps.edn, bb.edn and kaocha setup. |
| `generic` | A minimal generic nix flake template.                                            |

Example:

```bash
nix flake new my-project -t "github:ramblurr/nix-devenv#clojure"
```



## Sandboxed Agent Environments

This repo also contains nix config for dev environments for coding agents.

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

### Build

```bash
# enter devshell
nix develop

# build devcontainer
docker build -t nix-devenv:devcontainer -f .devcontainer/Dockerfile .
# build catnip container
docker build -t nix-devenv:catnip -f Dockerfile.catnip .
# also reference the .github/workflows/
```


[devshell]: https://github.com/numtide/devshell
[flakelight]: https://github.com/nix-community/flakelight
