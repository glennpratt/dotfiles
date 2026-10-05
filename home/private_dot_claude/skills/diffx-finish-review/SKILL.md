---
name: diffx-finish-review
description: Finish a diffx review session by fetching the user's inline comments from the running diffx server, applying requested changes, answering questions, and resolving comments. Use when the user says they finished reviewing in diffx or invokes /diffx-finish-review.
---

# Finish a diffx review

## 1. Find this session's server

Use the `http://127.0.0.1:<port>` URL that `/diffx-start-review` reported
earlier in **this** conversation (below, `$URL`).

- Do **not** go looking for "a diffx server" with `ps`, `lsof`, or by trying
  ports. Other agent sessions and worktrees run their own diffx servers, and
  picking one of those would apply someone else's review to this checkout.
- If the URL isn't in this conversation, ask the user for it.

Sanity-check that it serves this checkout:

```bash
curl -fsS "$URL/api/diff" | jq '{repoName, branch}'
```

`repoName` and `branch` should match the current repository and branch. If they
don't, or the connection fails, stop and tell the user.

## 2. Fetch comments

```bash
curl -fsS "$URL/api/comments"
```

Returns a JSON array:

```json
[{
  "id": "uuid",
  "filePath": "src/utils/parser.ts",
  "side": "additions",
  "lineNumber": 42,
  "lineContent": "const x = tokenize(input)",
  "body": "Rename x to parsedToken for clarity",
  "status": "open",
  "replies": []
}]
```

`side` is `additions` (new line) or `deletions` (removed line). Only process
comments with `"status": "open"`. Read existing `replies`; an open comment may
be a follow-up to an earlier reply.

## 3. Process each open comment

Decide if it is a **change request** or a **question**.

**Change request** ("rename x", "extract a helper"): read `filePath`, locate the
code by `lineContent` (line numbers drift as you edit), make the change, reply
saying what you did, then resolve it.

**Question** ("why not a Map?"): reply with the answer. Don't change code and
don't resolve it; the user follows up.

**Ambiguous**: reply asking for clarification; leave it open.

Handle related comments together (e.g. one rename touching several places).

Build JSON bodies with `jq` so quotes and newlines in the text are escaped:

```bash
# Reply
jq -n --arg body "Done. Renamed x to parsedToken." '{body: $body}' |
  curl -fsS -X POST "$URL/api/comments/<id>/replies" \
    -H 'Content-Type: application/json' -d @-

# Resolve
curl -fsS -X PUT "$URL/api/comments/<id>" \
  -H 'Content-Type: application/json' -d '{"status": "resolved"}'
```

The browser updates live as you reply and resolve.

## 4. Summarize

Briefly: changes applied, questions answered, anything left open. If there were
no open comments, say so.

Leave the server running so the user can check the result and add another round
of comments. Stop it when the user is done with the review.
