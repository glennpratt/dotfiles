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
`~/.local/share/chezmoi-<name>`, managed together by the `dotfiles` flake app
(`nix/dotfiles.sh`: apply, diff, status, pull, push, git). Its tools are pinned
by this flake; `~/.local/bin/dotfiles` is a shim that `nix run`s it from the
local checkout, and both repos' devshells provide it directly.
Each source applies on its own, in any order. No target is owned by two
sources (`dotfiles check`). Overlays contribute in two ways.

**Drop-in files** that the overlay deploys, picked up when the tool runs:

| Drop-in | Picked up by |
| --- | --- |
| `~/.config/shell/path.d/*.sh`, `rc.d/*.sh` | `~/.config/shell/rc` |
| `~/.config/git/config.d/work` | `[include]` in git config |
| `~/.config/direnv/lib/*.sh`, `projects/<host>/<org>/` | direnv |

**Fragments** for files with no include mechanism. They sit undeployed at the
overlay repo root and are read from its checkout when the base renders:

| Fragment | Merged into |
| --- | --- |
| `fragments/vscode/*.json` | VS Code `settings.json` (deep merge) |
| `fragments/finicky/*.js` (one JS array literal of handlers) | `~/.finicky.js` |

An overlay's flake can reuse this one:

```nix
inputs.personal.url = "github:glennpratt/dotfiles";
# ...
packages.default = personal.lib.mkProfile pkgs {
  name = "extra-packages";
  paths = personal.legacyPackages.${system}.sets.k8s ++ [ pkgs.foo ];
};
apps = personal.apps; # profile-sync, for the overlay's run_onchange script
```

Its install script then runs
`nix run <overlay>#profile-sync -- sync <overlay>` to add a second, disjoint
nix profile entry.
