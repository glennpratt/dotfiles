# Manage the personal chezmoi source plus any overlays (e.g. a private work
# repo) together, from any directory.
#
# Packaged as the flake app `dotfiles` (writeShellApplication adds the shebang
# and strict mode, and puts the pinned tools below first on PATH). The
# ~/.local/bin/dotfiles shim runs it with `nix run`.
#
# Overlays are extra chezmoi sources at ~/.local/share/chezmoi-<name>, with
# their own config and state in ~/.config/chezmoi-<name>/. They only add files
# into the base's drop-in dirs or fragments/ that base templates read from the
# overlay checkout; no target may be managed by two sources. Each source
# applies on its own, so order doesn't matter.
#
#   dotfiles apply [args]      apply base and every overlay
#   dotfiles diff [args]       chezmoi diff every source
#   dotfiles status            git and chezmoi status of every source
#   dotfiles pull              git pull --ff-only every repo
#   dotfiles push [args]       git push every repo (base guarded, see below)
#   dotfiles update            pull, then apply
#   dotfiles git <args>        run git in every repo, e.g. `dotfiles git log -3`
#   dotfiles check             fail if a target is managed by two sources
#   dotfiles <name> <args>     run chezmoi against one overlay, e.g.
#                              `dotfiles work add ~/.config/foo`
#
# The base repo is public. Before pushing it, `push` greps its tree and
# outgoing commit metadata for the patterns (extended regexes, `\b` allowed,
# one per line, case-insensitive) in each overlay's .dotfiles-denylist, so the patterns
# themselves never live in the base.
#
# Bootstrap an overlay:
#   git clone <url> ~/.local/share/chezmoi-<name> && dotfiles apply

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

overlays() {
    local d
    for d in "${DATA_DIR}"/chezmoi-*/; do
        [[ -e "${d}.git" ]] && basename "${d}"
    done
    return 0
}

overlay_chezmoi() {
    local dir="$1"
    shift
    chezmoi --source "${DATA_DIR}/${dir}" --config "${CONFIG_DIR}/${dir}/chezmoi.toml" "$@"
}

base_repo() {
    git -C "$(chezmoi source-path)" rev-parse --show-toplevel
}

# Base repo first, then overlays.
repos() {
    local dir
    base_repo
    for dir in $(overlays); do
        echo "${DATA_DIR}/${dir}"
    done
}

header() {
    printf '\n==> %s\n' "${1/#"${HOME}"/\~}"
}

# Run "$@" in every repo, with a header per repo.
each_repo() {
    local repo
    while read -r repo; do
        header "${repo}"
        git -C "${repo}" "$@"
    done < <(repos)
}

check() {
    local dir dupes
    local base_list
    base_list="$(chezmoi managed --include=files,symlinks | sort)"
    for dir in $(overlays); do
        dupes="$(comm -12 <(echo "${base_list}") <(overlay_chezmoi "${dir}" managed --include=files,symlinks | sort))"
        if [[ -n "${dupes}" ]]; then
            echo "dotfiles: targets managed by both base and ${dir}:" >&2
            echo "${dupes}" >&2
            return 1
        fi
    done
}

apply() {
    local dir
    check
    chezmoi apply "$@"
    for dir in $(overlays); do
        overlay_chezmoi "${dir}" apply "$@"
    done
}

status() {
    local dir
    header "$(base_repo)"
    git -C "$(base_repo)" status --short --branch
    chezmoi status
    for dir in $(overlays); do
        header "${DATA_DIR}/${dir}"
        git -C "${DATA_DIR}/${dir}" status --short --branch
        overlay_chezmoi "${dir}" status
    done
}

# Fail if the base repo's tree or unpushed commit metadata matches any overlay
# denylist pattern.
guard_public() {
    local repo patterns hits range
    repo="$(base_repo)"
    patterns="$(cat "${DATA_DIR}"/chezmoi-*/.dotfiles-denylist 2>/dev/null |
        grep -vE '^[[:space:]]*(#|$)' || true)"
    [[ -n "${patterns}" ]] || return 0

    hits="$(git -C "${repo}" grep -n -i -P -f <(echo "${patterns}") HEAD -- || true)"
    if git -C "${repo}" rev-parse -q --verify '@{u}' >/dev/null; then
        range='@{u}..HEAD'
    else
        range='HEAD'
    fi
    hits+="$(git -C "${repo}" log --format='%h %an <%ae> %s%n%b' "${range}" |
        grep -i -E -f <(echo "${patterns}") || true)"

    if [[ -n "${hits}" ]]; then
        echo "dotfiles: not pushing the public base repo; denylisted content:" >&2
        echo "${hits}" >&2
        return 1
    fi
}

push() {
    local repo
    guard_public
    while read -r repo; do
        header "${repo}"
        git -C "${repo}" push "$@"
    done < <(repos)
}

pull() {
    each_repo pull --ff-only
}

cmd="${1:-apply}"
[[ $# -gt 0 ]] && shift

case "${cmd}" in
    apply) apply "$@" ;;
    diff)
        chezmoi diff "$@"
        for dir in $(overlays); do overlay_chezmoi "${dir}" diff "$@"; done
        ;;
    status) status ;;
    pull) pull ;;
    push) push "$@" ;;
    update)
        pull
        apply
        ;;
    git) each_repo "$@" ;;
    check) check ;;
    *)
        if [[ -e "${DATA_DIR}/chezmoi-${cmd}/.git" ]]; then
            overlay_chezmoi "chezmoi-${cmd}" "$@"
        else
            echo "dotfiles: unknown command or overlay '${cmd}'" >&2
            exit 2
        fi
        ;;
esac
