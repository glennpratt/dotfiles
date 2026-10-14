# Packages defined in this repo, for consumers to add to their own nixpkgs.
final: prev: {
  diffx = final.callPackage ./pkgs/diffx.nix { };

  # Manage the base and overlay chezmoi sources together (see dotfiles.sh).
  dotfiles = final.writeShellApplication {
    name = "dotfiles";
    # Everything the script calls, pinned by the lock, except nix itself (bump)
    # which comes from PATH like it does for chezmoi's run scripts (nix, brew).
    runtimeInputs = with final; [ chezmoi coreutils git gnugrep jq openssh ];
    text = builtins.readFile ./dotfiles.sh;
  };
}
