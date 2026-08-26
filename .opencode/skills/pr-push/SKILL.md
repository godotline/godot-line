---
name: pr-push
description: Push the current branch, open a GitHub PR, and after merge fast-forward local main. Use when the user says gh pr push, create PR, merge后pull, or pull after merge.
---

# pr-push

`gh pr push` is not a command. Do: commit (if asked) → `git push` → `gh pr create` → after merge, checkout `main` and pull.

## 1. Inspect

```bash
git status
git branch --show-current
git log --oneline origin/main..HEAD
git diff --stat
```

If there are uncommitted files, **ask** (Question tool) before committing: commit them / push as-is / abort. Default base branch is `main` unless the user names another.

## 2. Push + PR

```bash
# only if the user chose to commit
git add -A
git commit -m "<concise summary of the working-tree change>"

git push -u origin HEAD
gh pr create --base main --title "<title>" --body "$(cat <<'EOF'
## Summary
- <1–3 bullets>

## Test plan
- <how to verify>
EOF
)"
```

Print the PR URL. Do not merge unless the user asks.

## 3. After merge → pull main

When the user says merge后pull / pull (and the PR is merged):

```bash
git fetch origin
git checkout main
git pull origin main
```

If still on the feature branch, leave it; do not delete it unless asked.

## GitHub TLS / proxy (this machine)

Direct HTTPS to GitHub works. An HTTP proxy at `127.0.0.1:7897` (verge-mihomo) does **not**:

- `CONNECT github.com:443` returns 200
- then TLS ClientHello dies: `error:0A000126:SSL routines::unexpected eof while reading`

**Do not set** `git config http.proxy` / `https.proxy` for GitHub. If they are set, unset:

```bash
git config --global --unset http.proxy
git config --global --unset https.proxy
```

Retry `git fetch` / `git push` / `gh` with no proxy. If the user later insists on a proxy, it is still broken for GitHub TLS — say so, keep going direct.
