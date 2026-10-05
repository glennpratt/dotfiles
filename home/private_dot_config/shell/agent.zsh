# Sourced from ~/.config/shell/rc in zsh when AI_AGENT is set. Agents set it in
# their shells (VS Code Copilot: github_copilot_vscode_agent; Claude Code:
# claude-code_<version>_agent), but the hooks below only run in an interactive
# shell like Copilot's agent terminal; Claude Code's command shell runs none.
#
# The agent only sees output between VS Code's command-start and command-end
# markers, so direnv's prompt-time "is blocked" error never reaches it and it
# carries on without the project environment. Repeat the error inside each
# command's output instead.

__agent_direnv_guard() {
  local out rc
  out=$(direnv status 2>/dev/null) || return 0
  # "Found RC allowed": 0 = allowed, 1 = not allowed, 2 = denied
  [[ $out == *$'\nFound RC allowed '[12]* ]] || return 0
  rc=${${(M)${(f)out}:#Found RC path *}#Found RC path }
  print -u2 "ENVIRONMENT NOT LOADED: $rc is not approved in direnv, so this" \
    "project's tools and variables are missing. Stop and ask the user to review" \
    "and approve it; do not run 'direnv allow' yourself."
}

# Register on the first prompt rather than now: VS Code's shell integration adds
# its preexec hook (which marks the command as started) after this file runs,
# and the guard has to run after that to land in the captured output.
__agent_direnv_register() {
  preexec_functions+=(__agent_direnv_guard)
  precmd_functions=(${precmd_functions:#__agent_direnv_register})
}
precmd_functions+=(__agent_direnv_register)
