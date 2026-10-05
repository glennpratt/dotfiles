# Packages defined in this repo, for consumers to add to their own nixpkgs.
final: prev: {
  diffx = final.callPackage ./pkgs/diffx.nix { };
}
