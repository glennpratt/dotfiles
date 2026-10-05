# Projects that use direnv

These apply only when the workspace, or a directory above it, has an `.envrc`.
Elsewhere, ignore this section.

## Working directory

The project's environment (toolchain, credentials) comes from its `.envrc` and
belongs to the workspace directory. Depending on how your shell runs, leaving
that directory either unloads the environment and reloads it on the way back,
which can take several seconds (Nix devshell, 1Password secrets), or carries the
workspace's environment into a directory it doesn't belong to.

- Don't `cd` out of the workspace. For commands that need another directory,
  use a subshell, `(cd /other/dir && cmd)`, or absolute paths.
- Moving between subdirectories of the same project is fine.

## Project environment

If command output contains `ENVIRONMENT NOT LOADED`, or `direnv` reports an
`.envrc` as blocked:

- Stop and ask the user to review and approve it. Say which `.envrc`.
- Never run `direnv allow` yourself; approving it is the user's review step.
- Don't work around it (installing tools, exporting variables by hand) — results
  without the project environment are misleading.
