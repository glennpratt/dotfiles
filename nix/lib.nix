# System-independent helpers, exported as `lib` from the flake.
{
  # A single nix-profile entry from a list of packages.
  mkProfile = pkgs: { name ? "my-packages", paths }:
    pkgs.buildEnv {
      inherit name paths;
      extraOutputsToInstall = [ "man" "doc" "info" ];
    };
}
