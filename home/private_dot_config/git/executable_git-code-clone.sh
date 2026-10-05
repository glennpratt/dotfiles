#!/usr/bin/env bash
# git code-clone: clone a repo into ~/Code/<host>/<path> based on the remote URL
#
# Examples:
#   git code-clone git@gitlab.example.com:group/project.git
#     -> ~/Code/gitlab.example.com/group/project
#   git code-clone https://github.com/org/repo.git
#     -> ~/Code/github.com/org/repo
#   git code-clone ssh://git@git.example.com:7999/team/repo.git
#     -> ~/Code/git.example.com/team/repo

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
    set -x
fi

if [ -z "${1:-}" ]; then
    echo 'Usage: git code-clone <remote-url>'
    exit 1
fi

REMOTE_URL=$1

# Parse host and path from remote URL
# Handles:
#   git@host:org/repo.git       (SCP-style SSH)
#   ssh://[user@]host[:port]/path  (SSH with scheme)
#   https://host/org/repo.git   (HTTPS)
if [[ "$REMOTE_URL" =~ ^git@([^:]+):(.+)$ ]]; then
    HOST="${BASH_REMATCH[1]}"
    REPO_PATH="${BASH_REMATCH[2]}"
elif [[ "$REMOTE_URL" =~ ^ssh://([^@]+@)?([^:/]+)(:[0-9]+)?/(.+)$ ]]; then
    HOST="${BASH_REMATCH[2]}"
    REPO_PATH="${BASH_REMATCH[4]}"
elif [[ "$REMOTE_URL" =~ ^https?://([^/]+)/(.+)$ ]]; then
    HOST="${BASH_REMATCH[1]}"
    REPO_PATH="${BASH_REMATCH[2]}"
else
    echo "error: cannot parse remote URL: $REMOTE_URL" >&2
    exit 1
fi

# Strip .git suffix
REPO_PATH="${REPO_PATH%.git}"

CLONE_DIR="${HOME}/Code/${HOST}/${REPO_PATH}"

if [ -d "$CLONE_DIR" ]; then
    echo "Already exists: $CLONE_DIR"
    exit 1
fi

mkdir -p "$(dirname "$CLONE_DIR")"
git clone "$REMOTE_URL" "$CLONE_DIR"
