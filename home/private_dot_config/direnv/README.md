# Direnv Configuration

This directory contains a custom direnv setup that:
1. Loads per-project configurations based on git origin URL
2. Supports environment variants (prod/staging/etc) with easy switching
3. Uses 1Password CLI to inject secrets at runtime (no secrets on disk)

## How It Works

When you `cd` into a git repository with direnv enabled, the system:
1. Detects the git origin URL (e.g., `git@github.com:example/project.git`)
2. Converts to directory path: `github.com/example/project/`
3. Loads config from `~/.config/direnv/projects/github.com/example/project/config.sh`
4. If using `load_env_variant`, loads the appropriate env file (prod.env, staging.env, etc.)
5. Uses 1Password CLI (`op run`) to inject secrets from `op://` references at runtime

## Directory Structure

Projects are organized by host/org/repo:
```
~/.config/direnv/projects/
└── github.com/
    └── example/
        └── project/
            ├── config.sh        # Project-specific direnv config
            ├── prod.env         # Production environment variables
            └── staging.env      # Staging environment variables
```

## Environment Variants

### Setup for a New Project

1. Create the project directory structure in `~/.config/direnv/projects/`:
   ```bash
   mkdir -p ~/.config/direnv/projects/<host>/<org>/<repo>
   ```

2. Create variant env files with 1Password secret references:
   ```bash
   # ~/.config/direnv/projects/<host>/<org>/<repo>/prod.env
   export API_TOKEN="op://Private/api-token/password"
   export DATABASE_URL="op://Private/db-creds/url"
   ```

3. Create a config.sh that loads the variant:
   ```bash
   #!/usr/bin/env bash
   load_env_variant prod
   ```

4. In your project repo, create `.env-variant` file (managed by chezmoi):
   ```bash
   prod
   ```

5. Create a `.envrc` file in your project repo:
   ```bash
   # Enable direnv (config is loaded automatically)
   ```

6. Allow direnv in the project:
   ```bash
   direnv allow
   ```

### Switching Variants

Use the `switch_env_variant` helper function:

```bash
# Switch to staging
switch_env_variant staging

# Switch to prod
switch_env_variant prod

# Reload direnv to apply changes
direnv reload
# or just cd out and back into the directory
```

The variant is stored in `.env-variant` file (in your project repo) and defaults to "prod" if not present.
`DIRENV_ENV_VARIANT` in the environment overrides both.

### Current Variant

The current variant is exported as `$ENV_VARIANT`:

```bash
echo $ENV_VARIANT  # Shows current variant (prod/staging/etc)
```

## 1Password Integration

Environment files use 1Password secret references with the `op://` syntax:
```bash
export API_TOKEN="op://Private/my-api-token/password"
export SSH_KEY="op://Private/my-ssh-key/private key"
```

When direnv loads the environment:
1. If `op` CLI is available, it uses `op run --env-file=<file>` to inject secrets at runtime
2. Secrets are never written to disk
3. You must be signed in to 1Password CLI (`op signin`)

If `op` is not available, it falls back to sourcing the file directly (secrets won't be resolved).


## Files

- `direnvrc` - Main direnv configuration (managed by chezmoi)
- `lib/*.sh` - Loaded by direnv before `direnvrc`; overlays drop helpers here
- `projects/` - Per-project configuration files (organized by host/org/repo)
- `projects/example.sh` - Example project config showing all features
- `README.md` - This file
