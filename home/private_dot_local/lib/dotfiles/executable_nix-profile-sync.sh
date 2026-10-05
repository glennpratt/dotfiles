#!/bin/bash
# Keep one nix profile entry per dotfiles flake (base, overlays) in sync.
#
#   nix-profile-sync.sh sync <flake-dir>   install or upgrade <flake-dir>#default
#   nix-profile-sync.sh entries            "name<TAB>original flake URL" per entry
#
# nix names entries after the flake's directory, so entries are matched by URL.

set -euo pipefail

# Parsed with nix itself: jq may come from the package being replaced.
profile_entries() {
    # shellcheck disable=SC2016 # ${...} is nix interpolation, not bash
    PROFILE_JSON=$(nix profile list --json 2>/dev/null) nix eval --impure --raw --expr '
      let els = (builtins.fromJSON (builtins.getEnv "PROFILE_JSON")).elements;
      in builtins.concatStringsSep "" (map (n: "${n}\t${els.${n}.originalUrl or ""}\n") (builtins.attrNames els))'
}

sync() {
    local flake_path="$1" flake_url name
    flake_url="git+file://${flake_path}"
    name="$(profile_entries | awk -F'\t' -v url="${flake_url}" '$2 == url { print $1; exit }')"
    if [[ -n "${name}" ]]; then
        echo "Upgrading nix profile entry ${name} (${flake_path})..."
        nix profile upgrade "${name}"
    else
        echo "Installing nix profile entry from ${flake_path}..."
        nix profile add "${flake_path}#default"
    fi
}

case "${1:-}" in
    sync) sync "${2:?usage: $0 sync <flake-dir>}" ;;
    entries) profile_entries ;;
    *) echo "usage: $0 {sync <flake-dir>|entries}" >&2; exit 2 ;;
esac
