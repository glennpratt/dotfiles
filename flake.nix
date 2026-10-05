{
  description = "Dotfiles: chezmoi source (home/), personal packages, and a dev shell";

  # Bootstrap on a fresh machine with only nix:
  #   nix develop github:glennpratt/dotfiles -c chezmoi init --apply glennpratt
  #
  # chezmoi (and the git it clones with) come from this flake's lock. Overlays
  # (e.g. a private work repo) are applied alongside with ~/.local/bin/dotfiles.
  #
  # packages.default (nix/sets.nix via lib.mkProfile) is installed into the nix
  # profile by home/run_onchange_after_install-nix-packages.sh.tmpl. The dev
  # shell shares its lock, so both resolve to the same store paths.
  #
  # Reusable outputs: overlays.default (diffx), lib.mkProfile, and
  # legacyPackages.<system>.sets (base/dev/k8s lists) for other flakes. An
  # overlay flake can install a second, disjoint profile entry, e.g.
  #   lib.mkProfile pkgs { name = "work-packages"; paths = sets.k8s ++ [ ... ]; }

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*.tar.gz";
    # Fork carrying nix_direnv_watch_content (rebuild only on content changes)
    # until it lands upstream.
    nix-direnv = {
      url = "github:glennpratt/nix-direnv/watch-content";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-direnv }:
    let
      supportedSystems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system (import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
          "1password-cli"
        ];
      }));
      setsFor = system: pkgs: import ./nix/sets.nix {
        inherit pkgs;
        nix-direnv = nix-direnv.packages.${system}.default;
      };
    in
    {
      overlays.default = import ./nix/overlay.nix;

      lib = import ./nix/lib.nix;

      # Not derivations, so they live under legacyPackages rather than packages.
      legacyPackages = forAllSystems (system: pkgs: {
        sets = setsFor system pkgs;
      });

      packages = forAllSystems (system: pkgs:
        let sets = setsFor system pkgs; in {
          default = self.lib.mkProfile pkgs {
            paths = sets.base ++ sets.dev;
          };
          inherit (pkgs) diffx;
          profile-sync = pkgs.writeShellApplication {
            name = "profile-sync";
            runtimeInputs = [ pkgs.gawk ]; # nix itself comes from PATH
            text = builtins.readFile ./nix/profile-sync.sh;
          };
        });

      # Used by the run_onchange scripts here and in overlays, so neither
      # depends on the other having been applied first.
      apps = forAllSystems (system: pkgs: {
        profile-sync = {
          type = "app";
          program = "${self.packages.${system}.profile-sync}/bin/profile-sync";
          meta.description = "Install or upgrade a dotfiles flake's nix profile entry";
        };
      });

      checks = forAllSystems (system: pkgs: {
        profile = self.packages.${system}.default;
      });

      formatter = forAllSystems (system: pkgs: pkgs.nixfmt);

      devShells = forAllSystems (system: pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            chezmoi
            git
            shellcheck
            shfmt
          ];
        };
      });
    };
}
