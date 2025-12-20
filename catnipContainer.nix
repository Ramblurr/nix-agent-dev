{ claude-code
, determinate-nixd
, detsys-nix
, lib
, nix2container
, pkgs
, self
,
}:

let
  upstream = nix2container.pullImage {
    imageName = "docker.io/wandb/catnip";
    imageDigest = "sha256:8c2a9c2dca1828fea6499f8bd32cc90a7a0bfdf40778407580b5208eaaf75760";
    arch = "amd64";
    sha256 = "sha256-FMTzK9fx2KW6MZ7SixbcSAX4V93TC6Kc/ANzinVxljU=";
  };

  claude = pkgs.writeShellScriptBin "claude" ''
    set -euo pipefail
    export NIX_CONFIG="experimental-features = nix-command flakes"
    REAL_CLAUDE="${claude-code}/bin/claude"

    if [[ ! -x "$REAL_CLAUDE" ]]; then
      echo "ERROR: REAL_CLAUDE not found or not executable: $REAL_CLAUDE" >&2
      exit 127
    fi

    exec catnip purr "$REAL_CLAUDE" "$@"
  '';
  entrypoint = pkgs.writeShellScriptBin "nix-entrypoint" ''
    export USER="$(id -un)"
    uid="$(id -u)"
    if [ "$uid" -eq 0 ]; then
        export HOME=/root
    else
        export HOME="/home/$(id -un)"
    fi
    echo "[nix-entrypoint] Starting nix daemon..."
    nohup ${determinate-nixd}/bin/determinate-nixd --nix-bin ${detsys-nix}/bin daemon >/var/log/determinate-nixd.log 2>&1 &
    sleep 0.5
    export NIX_REMOTE=daemon
    echo "[nix-entrypoint] Activating home-manager for root..."
    if ! ${self.homeConfigurations.root.activationPackage}/activate 2>&1; then 
        echo "[nix-entrypoint] home-manager activation for catnip failed (continuing anyway)"
    fi
    rm -f /opt/catnip/bin/claude
    ln -s ${claude}/bin/claude /opt/catnip/bin/claude
    if ! ${pkgs.gosu}/bin/gosu 1000:1000 ${pkgs.bash}/bin/bash -c '
      export USER=catnip
      export HOME=/home/catnip
      echo "[nix-entrypoint] Activating home-manager for catnip..."
      for f in ~/.bashrc ~/.profile ~/.bash_profile; do
        [ -f "$f" ] && [ ! -L "$f" ] && mv "$f" "$f.pre-home-manager"
      done
      ${self.homeConfigurations.catnip.activationPackage}/activate 2>&1 
    '; then
        echo "[nix-entrypoint] home-manager activation for catnip failed (continuing anyway)"
    fi
    export CATNIP_USERNAME=catnip
    exec /entrypoint.sh "$@"
  '';
  nixconf = ''
    experimental-features = nix-command flakes
    max-jobs = auto
    build-users-group = nixbld
    extra-nix-path = nixpkgs=flake:nixpkgs
    fsync-metadata = false
    trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    trusted-substituters = https://nix-community.cachix.org https://cache.nixos.org
    substituters = https://nix-community.cachix.org https://cache.nixos.org
    extra-substituters  = https://install.determinate.systems
    extra-trusted-public-keys = cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=
  '';
  globalPaths = [
    "/opt/catnip/nvm/versions/node/v22.17.0/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/catnip/bin"
    "/usr/local/sbin"
    "/usr/local/bin"
    "/usr/sbin"
    "/usr/bin"
    "/sbin"
    "/bin"
  ];
  globalPath = (lib.concatStringsSep ":" globalPaths);
  userPath = (
    lib.concatStringsSep ":" (
      [
        "/home/catnip/.local/bin"
        "/home/catnip/.nix-profile/bin"
      ]
      ++ globalPaths
    )
  );
  rootPath = (
    lib.concatStringsSep ":" (
      [
        "/root/.nix-profile/bin"
      ]
      ++ globalPaths
    )
  );

  baseSystem = (
    pkgs.runCommand "base"
      {
        allowSubstitutes = false;
        preferLocalBuild = true;
      }
      ''
        set -x
        mkdir $out
        mkdir $out/tmp
        mkdir $out/etc
        mkdir $out/etc/nix
        echo '${nixconf}' > $out/etc/nix/nix.conf
        mkdir -p $out/root/.local/state/nix/profiles
        mkdir -p $out/usr/local/bin
        echo 'export PATH=${rootPath}' > $out/root/.bashrc
        echo 'find ${self.homeConfigurations.root.activationPackage}' >>  $out/root/.bashrc
        echo '${passwd}' > $out/etc/passwd
        echo '${group}' > $out/etc/group;''
  );
  passwd = ''
    root:x:0:0::/root:/bin/bash
    catnip:x:1000:1000::/home/catnip:/bin/bash
    docker:x:1001:catnip
    ${lib.concatStringsSep "\n" (
      lib.genList (
        i:
        "nixbld${toString (i + 1)}:x:${toString (i + 30001)}:30000::/var/empty:/run/current-system/sw/bin/nologin"
      ) 32
    )}
  '';
  group = ''
    root:x:0:
    sudo:x:27:catnip
    nogroup:x:65534:
    nixbld:x:30000:${lib.concatStringsSep "," (lib.genList (i: "nixbld${toString (i + 1)}") 32)}
    catnip:x:1000:
    docker:x:1001:catnip
  '';
in

nix2container.buildImage {
  name = "catnip";
  tag = "main";
  initializeNixDatabase = true;
  fromImage = upstream;
  maxLayers = 150;
  config = {
    entrypoint = [
      "${entrypoint}/bin/nix-entrypoint"
    ];
    Env = [
      "USER=root"
      "PATH=${globalPath}"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "CATNIP_USERNAME=catnip"
      "DEBIAN_FRONTEND=noninteractive"
      "CATNIP_ROOT=/opt/catnip"
      "WORKSPACE=/workspace"
      "CATNIP_WORKSPACE_DIR=/workspace"
      "CATNIP_VOLUME_DIR=/volume"
      "CATNIP_LIVE_DIR=/live"
      "CATNIP_HOME_DIR=/home/catnip"
      "CATNIP_TEMP_DIR=/tmp"
      "CATNIP_TITLE_INTERCEPT=1"
      "CATNIP_TITLE_LOG=/home/catnip/.catnip/title_events.log"
      "NVM_DIR=/opt/catnip/nvm"
      "CARGO_HOME=/opt/catnip/cargo"
      "RUSTUP_HOME=/opt/catnip/rustup"
      "GOROOT=/opt/catnip/go"
      "GOPATH=/opt/catnip/go-workspace"
      "PIPX_BIN_DIR=/opt/catnip/bin"
      "PIPX_HOME=/opt/catnip/pipx"
      "COREPACK_ENABLE_DOWNLOAD_PROMPT=0"
      "COREPACK_DEFAULT_TO_LATEST=0"
      "COREPACK_ENABLE_AUTO_PIN=0"
      "COREPACK_ENABLE_STRICT=0"
    ];
    Cmd = [
      "catnip"
      "serve"
    ];
  };
  perms = [
    {
      path = baseSystem;
      regex = "(/var)?/tmp";
      mode = "1777";
    }
  ];
  copyToRoot = [
    baseSystem
    (pkgs.buildEnv {
      name = "root";
      paths = [
        pkgs.gosu
        pkgs.bashInteractive
        pkgs.coreutils
        pkgs.cacert
        pkgs.home-manager
        pkgs.git
        detsys-nix
      ];
      pathsToLink = [
        "/bin"
        "/etc/ssl"
      ];
    })

  ];
  layers = [
    (nix2container.buildLayer {
      deps = [
        detsys-nix
        pkgs.bashInteractive
        pkgs.cacert
        pkgs.coreutils
        pkgs.git
        pkgs.gosu
        pkgs.home-manager
        pkgs.runtimeShell
        pkgs.vim
      ];
    })
    (nix2container.buildLayer {
      deps = [
        self.homeConfigurations.root.activationPackage
      ];
    })
    (nix2container.buildLayer {
      deps = [
        self.homeConfigurations.catnip.activationPackage
      ];
    })
    (nix2container.buildLayer {
      deps = [
        entrypoint
      ];
    })

  ];
}
