# Packages defined in this repo, for consumers to add to their own nixpkgs.
final: prev: {
  diffx = final.callPackage ./pkgs/diffx.nix { };

  # Manage the base and overlay chezmoi sources together (see dotfiles.sh).
  dotfiles = final.writeShellApplication {
    name = "dotfiles";
    # Everything the script calls, pinned by the lock, except host integration
    # that must match the machine: nix itself (bump), and ssh (used by git),
    # which has to honor the host's /etc/ssh/ssh_config (managed hosts use
    # options a nixpkgs openssh rejects, e.g. GSSAPI). Both come from PATH,
    # like they do for chezmoi's run scripts.
    runtimeInputs = with final; [ chezmoi coreutils git gnugrep jq ];
    text = builtins.readFile ./dotfiles.sh;
  };
}
