# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/), plus a Nix
flake for packages. macOS and Linux (including WSL); native Windows gets the
cross-platform subset.

## Bootstrap

```sh
nix develop github:glennpratt/dotfiles -c chezmoi init --apply glennpratt
```

`chezmoi init` prompts for a name and git email. Packages from
`packages.default` are installed into the nix profile by
`home/run_onchange_after_install-nix-packages.sh.tmpl`.

## Layout

- `home/`: chezmoi source (`.chezmoiroot`)
- `nix/sets.nix`: package sets (`base`, `dev`, `k8s`) as plain lists
- `nix/lib.nix`: `mkProfile`, a `buildEnv` for one nix profile entry
- `nix/overlay.nix`, `nix/pkgs/`: packages not in nixpkgs (diffx)

## Overlays

Machine- or employer-specific config lives in separate chezmoi sources at
`~/.local/share/chezmoi-<name>`, applied together by `~/.local/bin/dotfiles`.
Overlays only add files to these drop-in points; no target is owned by two
sources (`dotfiles check`).

| Drop-in | Picked up by |
| --- | --- |
| `~/.config/shell/path.d/*.sh`, `rc.d/*.sh` | `~/.config/shell/rc` |
| `~/.config/git/config.d/work` | `[include]` in git config |
| `~/.config/direnv/lib/*.sh`, `projects/<host>/<org>/` | direnv |
| `~/.config/finicky/rules.d/*.js` | `~/.finicky.js` (imported) |
| `~/.config/Code/User/settings.d/*.json` | VS Code `settings.json` (deep-merged) |

An overlay's flake can reuse this one:

```nix
inputs.personal.url = "github:glennpratt/dotfiles";
# ...
personal.lib.mkProfile pkgs {
  name = "extra-packages";
  paths = personal.legacyPackages.${system}.sets.k8s ++ [ pkgs.foo ];
}
```
