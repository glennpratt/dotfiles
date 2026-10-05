---
name: diffx-start-review
description: Start a diffx review session so the user can review the current git changes in a browser UI and leave inline comments. Use when the user asks to review changes in diffx, wants a PR-style review of the working tree, or invokes /diffx-start-review.
---

# Start a diffx review

`diffx` serves a GitHub-PR-like diff view of the current repository where the
user leaves inline comments. Afterwards, `/diffx-finish-review` applies them.

## 1. Launch diffx in the background

Run from the repository root, as a background process (whatever your tool
calls it: a background shell, `run_in_background`, an async terminal). It is a
long-running server; a foreground call blocks until it times out.

```bash
diffx                   # working tree: staged + unstaged + untracked
diffx -- --staged       # staged only
diffx -- main..HEAD     # this branch vs main
diffx -- HEAD~3         # last 3 commits
```

Anything after `--` goes to `git diff`. Pick the range that matches what the
user wants to review; if you just made commits on a branch, `main..HEAD` (or the
repo's default branch) is usually right.

- **Never pass `-p/--port`.** diffx binds a random free port on 127.0.0.1, so
  parallel sessions (other agents, other worktrees) never collide. A fixed port
  is what causes cross-session confusion.
- Don't pass `--host`.
- diffx opens the browser itself (`open` on macOS, `xdg-open`/`$BROWSER` on
  Linux; in VS Code Remote that opens locally through a forwarded port). A
  failed open doesn't stop the server.

## 2. Get the URL

Wait for the startup line in the process output:

```
diffx server running at http://127.0.0.1:<port>
```

If it exits instead (e.g. `not inside a git repository`), report the error.

## 3. Hand it to the user

Reply with the exact URL, so it stays in this conversation for
`/diffx-finish-review` and the user can open it if no browser appeared:

> diffx is running at http://127.0.0.1:<port>. Leave inline comments there, then
> run `/diffx-finish-review`.

Keep it brief. Don't stop the server; the finish step uses it.
