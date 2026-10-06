# Packages defined in this repo, for consumers to add to their own nixpkgs.
final: prev: {
  diffx = final.callPackage ./pkgs/diffx.nix { };

  # Manage the base and overlay chezmoi sources together (see dotfiles.sh).
  dotfiles = final.writeShellApplication {
    name = "dotfiles";
    # Everything the script calls, pinned by the lock. Run scripts that
    # chezmoi starts still see the rest of PATH (nix, brew).
    runtimeInputs = with final; [ chezmoi coreutils git gnugrep openssh ];
    text = builtins.readFile ./dotfiles.sh;
  };
}
