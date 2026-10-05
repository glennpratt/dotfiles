#!/usr/bin/env bash
# Example project-specific direnv configuration
#
# This file shows the format for project-specific configs.
# Filename format: <sanitized-git-origin-url>.sh
#
# Example URLs and their corresponding filenames:
# - https://github.com/user/repo.git → github.com_user_repo.sh
# - git@github.com:user/repo.git     → github.com_user_repo.sh
# - https://gitlab.com/user/repo     → gitlab.com_user_repo.sh

# Example: Load environment variant (prod/staging/etc)
# Reads from .env-variant file, defaults to "prod"
# Loads .gprattignore.{variant}.env file
# load_env_variant prod

# Example: Switch between variants using the helper function
# Run in your project: switch_env_variant staging
# Then reload direnv to apply changes

# Example: Load a specific Python version
# use python 3.11

# Example: Set environment variables
# export DEBUG=true
# export API_KEY="dev-key"

# Example: Load .env file if it exists
# dotenv_if_exists .env.local

# Example: Add to PATH
# PATH_add bin
