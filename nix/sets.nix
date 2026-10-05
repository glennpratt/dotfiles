# Package sets as plain lists so the same data can feed a buildEnv (nix
# profile), home-manager's home.packages, or a devShell.
# `pkgs` must include overlays.default (for diffx).
{ pkgs, nix-direnv }:
let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pip
    setuptools
    wheel
  ]);
in
{
  # Shell, git and everyday CLI tools.
  base = with pkgs; [
    atuin
    bashInteractive
    blesh
    chezmoi
    direnv
    gh
    git
    gnupg
    gron
    jq
    mtr
    ncdu
    nix-direnv
    nix-tree
    pstree
    readline
    ripgrep
    rsync
    sshping
    starship
    tree
    watch
    wget
    yadm
    yq-go
  ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    _1password-cli
  ];

  # Languages, linters and build tools.
  dev = with pkgs; [
    act
    checkmake
    diffx
    editorconfig-checker
    gnumake
    go
    golangci-lint
    graphviz
    pythonEnv
    ruff
    semgrep
    shellcheck
    shfmt
    uv
  ];

  # Kubernetes and container tooling.
  k8s = with pkgs; [
    diffoci
    dive
    dyff
    k9s
    kind
    krew
    kubectl
    kubernetes-helm
    kubernetes-helmPlugins.helm-unittest
    kustomize
  ];
}
