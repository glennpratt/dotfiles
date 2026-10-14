# Manage the personal chezmoi source plus any overlays (e.g. a private work
# repo) together, from any directory.
#
# Packaged by nix/overlay.nix with writeShellApplication (which adds the shebang
# and strict mode, and puts pinned tools first on PATH). Installed via the base
# package set and provided by both repos' devshells.
#
# Repos are checked out like `git code-clone` does: ~/Code/<host>/<path>.
# Overlays are extra chezmoi sources registered in ~/.config/dotfiles/overlays
# ("<name> <dir>" per line), each with its own config and state in
# ~/.config/chezmoi-<name>/. They only add files into the base's drop-in dirs
# or fragments/ that base templates read from the overlay checkout; no target
# may be managed by two sources. Each source applies on its own, in any order.
#
#   dotfiles init [url]              clone the base (default: glennpratt/dotfiles),
#                                    chezmoi init --apply it
#   dotfiles overlay add <name> <url>  clone and register an overlay
#   dotfiles overlay list            registered overlays
#   dotfiles apply [--bump] [args]   apply base and every overlay; --bump (or
#                                    DOTFILES_BUMP=1) first runs `bump`
#   dotfiles bump                    update overlay flake inputs that pin the
#                                    base to the base's pushed HEAD, commit flake.lock
#   dotfiles diff [args]             chezmoi diff every source
#   dotfiles status                  git and chezmoi status of every source
#   dotfiles pull                    git pull --ff-only every repo
#   dotfiles push [args]             git push every repo (base guarded, see below)
#   dotfiles update                  pull, then apply
#   dotfiles git <args>              run git in every repo, e.g. `dotfiles git log -3`
#   dotfiles check                   fail if a target is managed by two sources
#   dotfiles <name> <args>           run chezmoi against one overlay, e.g.
#                                    `dotfiles work add ~/.config/foo`
#
# Bootstrap with nothing but nix:
#   nix run github:glennpratt/dotfiles#dotfiles -- init
#   dotfiles overlay add work <url> && dotfiles apply
#
# Overlay flakes usually take the base as an input (github:<owner>/<repo>).
# When that lock pins a different commit than the local base HEAD, `status`
# and `apply` say so; `bump` fixes it once the base is pushed.
#
# The base repo is public. Before pushing it, `push` greps its tree and
# outgoing commit metadata for the patterns (extended regexes, `\b` allowed,
# one per line, case-insensitive) in each overlay's .dotfiles-denylist, so the
# patterns themselves never live in the base.

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CODE_DIR="${DOTFILES_CODE_DIR:-$HOME/Code}"
REGISTRY="${CONFIG_DIR}/dotfiles/overlays"
BASE_URL="https://github.com/glennpratt/dotfiles.git"

die() {
    echo "dotfiles: $*" >&2
    exit 1
}

# ~/Code/<host>/<path> for a remote URL, as `git code-clone` lays it out.
code_path() {
    local url="$1" host path
    if [[ "${url}" =~ ^git@([^:]+):(.+)$ ]]; then
        host="${BASH_REMATCH[1]}" path="${BASH_REMATCH[2]}"
    elif [[ "${url}" =~ ^ssh://([^@]+@)?([^:/]+)(:[0-9]+)?/(.+)$ ]]; then
        host="${BASH_REMATCH[2]}" path="${BASH_REMATCH[4]}"
    elif [[ "${url}" =~ ^https?://([^/]+)/(.+)$ ]]; then
        host="${BASH_REMATCH[1]}" path="${BASH_REMATCH[2]}"
    else
        die "cannot parse remote URL: ${url}"
    fi
    echo "${CODE_DIR}/${host}/${path%.git}"
}

clone() {
    local url="$1" dir="$2"
    if [[ -e "${dir}/.git" ]]; then
        echo "Already cloned: ${dir}"
    else
        mkdir -p "$(dirname "${dir}")"
        git clone "${url}" "${dir}"
    fi
}

# "<name> <dir>" for each registered overlay.
registry() {
    [[ -r "${REGISTRY}" ]] || return 0
    grep -vE '^[[:space:]]*(#|$)' "${REGISTRY}" || true
}

overlays() {
    local name dir
    while read -r name dir; do
        if [[ -e "${dir}/.git" ]]; then
            echo "${name}"
        else
            echo "dotfiles: overlay ${name}: ${dir} is not a git checkout, skipping" >&2
        fi
    done < <(registry)
}

overlay_dir() {
    local name dir
    while read -r name dir; do
        if [[ "${name}" == "$1" ]]; then
            echo "${dir}"
            return 0
        fi
    done < <(registry)
    return 1
}

overlay_chezmoi() {
    local name="$1"
    shift
    chezmoi --source "$(overlay_dir "${name}")" --config "${CONFIG_DIR}/chezmoi-${name}/chezmoi.toml" "$@"
}

base_repo() {
    git -C "$(chezmoi source-path)" rev-parse --show-toplevel
}

# Base repo first, then overlays.
repos() {
    local name
    base_repo
    for name in $(overlays); do
        overlay_dir "${name}"
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

init() {
    local url="${1:-${BASE_URL}}" dir
    dir="$(code_path "${url}")"
    clone "${url}" "${dir}"
    # The base's .chezmoi.toml.tmpl records sourceDir, so plain `chezmoi` finds it.
    chezmoi init --source "${dir}" --apply
}

overlay_add() {
    local name="${1:?usage: dotfiles overlay add <name> <url>}" url="${2:?usage: dotfiles overlay add <name> <url>}" dir
    [[ "${name}" =~ ^[A-Za-z0-9_-]+$ ]] || die "overlay name must be [A-Za-z0-9_-]+: ${name}"
    overlay_dir "${name}" >/dev/null && die "overlay ${name} is already registered"
    dir="$(code_path "${url}")"
    clone "${url}" "${dir}"
    mkdir -p "$(dirname "${REGISTRY}")" "${CONFIG_DIR}/chezmoi-${name}"
    echo "${name} ${dir}" >> "${REGISTRY}"
    printf 'sourceDir = "%s"\n' "${dir}" > "${CONFIG_DIR}/chezmoi-${name}/chezmoi.toml"
    echo "Registered overlay ${name} at ${dir}; run \`dotfiles apply\`."
}

check() {
    local name dupes
    local base_list
    base_list="$(chezmoi managed --include=files,symlinks | sort)"
    for name in $(overlays); do
        dupes="$(comm -12 <(echo "${base_list}") <(overlay_chezmoi "${name}" managed --include=files,symlinks | sort))"
        if [[ -n "${dupes}" ]]; then
            echo "dotfiles: targets managed by both base and ${name}:" >&2
            echo "${dupes}" >&2
            return 1
        fi
    done
}

apply() {
    local name do_bump="${DOTFILES_BUMP:-}" args=()
    for arg in "$@"; do
        if [[ "${arg}" == "--bump" ]]; then
            do_bump=1
        else
            args+=("${arg}")
        fi
    done
    check
    if [[ -n "${do_bump}" ]]; then
        bump
    fi
    chezmoi apply "${args[@]}"
    for name in $(overlays); do
        overlay_chezmoi "${name}" apply "${args[@]}"
    done
    lock_notices
}

status() {
    local name
    header "$(base_repo)"
    git -C "$(base_repo)" status --short --branch
    chezmoi status
    for name in $(overlays); do
        header "$(overlay_dir "${name}")"
        git -C "$(overlay_dir "${name}")" status --short --branch
        overlay_chezmoi "${name}" status
    done
    lock_notices
}

# Fail if the base repo's tree or unpushed commit metadata matches any overlay
# denylist pattern.
guard_public() {
    local repo patterns="" hits range name
    repo="$(base_repo)"
    for name in $(overlays); do
        patterns+="$(cat "$(overlay_dir "${name}")/.dotfiles-denylist" 2>/dev/null || true)"$'\n'
    done
    patterns="$(echo "${patterns}" | grep -vE '^[[:space:]]*(#|$)' || true)"
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

# "<input> <locked rev>" for each of an overlay's flake inputs that locks the
# base repo from GitHub.
base_inputs() {
    local name="$1" lock origin owner repo
    lock="$(overlay_dir "${name}")/flake.lock"
    [[ -r "${lock}" ]] || return 0
    origin="$(git -C "$(base_repo)" remote get-url origin 2>/dev/null)" || return 0
    [[ "${origin}" =~ github\.com[:/]([^/]+)/([^/]+)$ ]] || return 0
    owner="${BASH_REMATCH[1],,}"
    repo="${BASH_REMATCH[2],,}"
    repo="${repo%.git}"
    jq -r --arg owner "${owner}" --arg repo "${repo}" '
      .nodes | to_entries[]
      | select(.value.original.type == "github"
               and (.value.original.owner | ascii_downcase) == $owner
               and (.value.original.repo | ascii_downcase) == $repo)
      | "\(.key) \(.value.locked.rev)"' "${lock}"
}

# How a locked base rev relates to the local base checkout:
# current | behind (local base is older; pull it) | unpushed | bumpable
lock_state() {
    local rev="$1" base head
    base="$(base_repo)"
    head="$(git -C "${base}" rev-parse HEAD)"
    if [[ "${rev}" == "${head}" ]]; then
        echo current
    elif git -C "${base}" merge-base --is-ancestor "${head}" "${rev}" 2>/dev/null; then
        echo behind
    elif ! git -C "${base}" merge-base --is-ancestor HEAD '@{u}' 2>/dev/null; then
        echo unpushed
    else
        echo bumpable
    fi
}

# Print a notice per overlay input whose base lock differs from the local base.
lock_notices() {
    local name input rev state head
    head="$(git -C "$(base_repo)" rev-parse --short HEAD)"
    for name in $(overlays); do
        while read -r input rev; do
            state="$(lock_state "${rev}")"
            case "${state}" in
                current) ;;
                behind) echo "dotfiles: ${name}: ${input} pins ${rev:0:7}, newer than the local base (${head}); run \`dotfiles pull\`" >&2 ;;
                unpushed) echo "dotfiles: ${name}: ${input} pins ${rev:0:7}, local base is at unpushed ${head}; run \`dotfiles push\`, then \`dotfiles bump\`" >&2 ;;
                bumpable) echo "dotfiles: ${name}: ${input} pins ${rev:0:7}, local base is at ${head}; run \`dotfiles bump\` (or \`dotfiles apply --bump\`)" >&2 ;;
            esac
        done < <(base_inputs "${name}")
    done
}

bump() {
    local name dir input rev state failed=0
    for name in $(overlays); do
        dir="$(overlay_dir "${name}")"
        while read -r input rev; do
            state="$(lock_state "${rev}")"
            case "${state}" in
                current) continue ;;
                behind)
                    echo "dotfiles: ${name}: not moving ${input} back to the older local base; run \`dotfiles pull\`" >&2
                    continue
                    ;;
                unpushed)
                    echo "dotfiles: ${name}: base has unpushed commits; run \`dotfiles push\` first" >&2
                    failed=1
                    continue
                    ;;
            esac
            if ! git -C "${dir}" diff --quiet HEAD -- flake.lock; then
                echo "dotfiles: ${name}: flake.lock has uncommitted changes; not bumping" >&2
                failed=1
                continue
            fi
            header "${dir}"
            (cd "${dir}" && nix flake update "${input}")
            if ! git -C "${dir}" diff --quiet HEAD -- flake.lock; then
                rev="$(jq -r --arg input "${input}" '.nodes[$input].locked.rev' "${dir}/flake.lock")"
                git -C "${dir}" commit -m "flake: bump ${input} to ${rev:0:7}" -- flake.lock
            fi
        done < <(base_inputs "${name}")
    done
    return "${failed}"
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
    init) init "$@" ;;
    overlay)
        sub="${1:-list}"
        [[ $# -gt 0 ]] && shift
        case "${sub}" in
            add) overlay_add "$@" ;;
            list) registry ;;
            *) die "usage: dotfiles overlay {add <name> <url>|list}" ;;
        esac
        ;;
    apply) apply "$@" ;;
    diff)
        chezmoi diff "$@"
        for name in $(overlays); do overlay_chezmoi "${name}" diff "$@"; done
        ;;
    status) status ;;
    pull) pull ;;
    push) push "$@" ;;
    update)
        pull
        apply "$@"
        ;;
    bump) bump ;;
    git) each_repo "$@" ;;
    check) check ;;
    *)
        if overlay_dir "${cmd}" >/dev/null; then
            overlay_chezmoi "${cmd}" "$@"
        else
            die "unknown command or overlay '${cmd}'"
        fi
        ;;
esac
