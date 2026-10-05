#!/usr/bin/env bash
# git wt: create a worktree for a new branch, carrying over uncommitted changes
# Usage: git wt -b <branch> [--no-carry] [<commit-ish>]

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
    set -x
fi

BRANCH=""
COMMIT_ISH=""
CARRY_CHANGES=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b)
            [[ -z "${2:-}" ]] && { echo "error: -b requires a branch name"; exit 1; }
            BRANCH="$2"
            shift 2
            ;;
        --no-carry)
            CARRY_CHANGES=false
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: git wt -b <branch> [--no-carry] [<commit-ish>]"
            exit 1
            ;;
        *)
            if [[ -z "$COMMIT_ISH" ]]; then
                COMMIT_ISH="$1"
            else
                echo "Unexpected argument: $1"
                echo "Usage: git wt -b <branch> [--no-carry] [<commit-ish>]"
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$BRANCH" ]]; then
    echo "Usage: git wt -b <branch> [--no-carry] [<commit-ish>]"
    exit 1
fi

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
WORKTREE_PATH=$(realpath "$(git rev-parse --show-toplevel)/../${REPO_NAME}-${BRANCH}")

git worktree add -b "${BRANCH}" "${WORKTREE_PATH}" ${COMMIT_ISH:+"${COMMIT_ISH}"}
echo "Worktree ready at ${WORKTREE_PATH}"

if [[ "$CARRY_CHANGES" == true ]]; then
    PATCH=$(mktemp /tmp/git-wt-XXXXXX.patch)
    trap 'rm -f "${PATCH}"' EXIT
    git diff HEAD > "${PATCH}"
    git -C "${WORKTREE_PATH}" apply --stat --allow-empty --apply "${PATCH}"
fi
