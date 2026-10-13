#!/usr/bin/env bash
# Sync README.md + install.sh + install.ps1 into the public Gist (create on first run,
# update afterwards). Uses the logged-in `gh` account (needs the `gist` scope).
#
#   ./publish.sh              # stamp gist id, sanity-check, create/update the gist
#   ./publish.sh --check-only # only stamp + syntax-check, touch no network
set -euo pipefail
cd "$(dirname "$0")"

GIST_ID="2b903923ea111f741ca50a878ee9d2f8"
FILES=(README.md install.sh install.ps1)
DESC="claude-code-backends — one-line installers (Linux/macOS + Windows) for the Kimi, Z.AI GLM, OpenRouter & AgentRouter Claude Code backend launchers (cckimi/ccglm/ccort/ccart), installing Claude Code itself when missing"

# Stamp the real gist id into the self-reference URLs (idempotent once replaced).
if [ -n "$GIST_ID" ] && [ "$GIST_ID" != "__GIST_ID__" ]; then
  sed -i "s/GIST_ID_PLACEHOLDER/$GIST_ID/g" install.sh install.ps1 README.md
fi

# Sanity: both installers must be valid.
bash -n install.sh && echo "install.sh: syntax ok"
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command '$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./install.ps1),[ref]$null,[ref]$e); if($e){$e|%{$_.Message}; exit 1} else {"install.ps1: syntax ok"}'
else
  echo "install.ps1: (pwsh not present — skipped syntax check)"
fi

[ "${1:-}" = "--check-only" ] && exit 0

if [ -z "$GIST_ID" ] || [ "$GIST_ID" = "__GIST_ID__" ]; then
  echo "creating gist..."
  url=$(gh gist create README.md install.sh install.ps1 --public --desc "$DESC")
  echo "GIST_URL=$url"
  echo "→ put the gist id into publish.sh GIST_ID + README.md, then run ./publish.sh again."
else
  # Publish what is committed, never the working tree: uncommitted edits must not reach
  # users, and on Windows the checkout is CRLF (core.autocrlf) while the gist is LF --
  # a CRLF install.sh breaks the moment someone curl-pipes it into bash.
  if ! git diff --quiet HEAD -- "${FILES[@]}"; then
    echo "uncommitted changes in ${FILES[*]} — commit them first, then publish."
    exit 1
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  for f in "${FILES[@]}"; do git show "HEAD:$f" > "$tmp/$f"; done
  # No leading slash on the endpoint: Git Bash rewrites "/gists/..." into a Windows path.
  jq -n --arg d "$DESC" \
     --rawfile r "$tmp/README.md" --rawfile s "$tmp/install.sh" --rawfile p "$tmp/install.ps1" \
     '{description:$d, files:{"README.md":{content:$r},"install.sh":{content:$s},"install.ps1":{content:$p}}}' \
    | gh api -X PATCH "gists/$GIST_ID" --input - >/dev/null
  echo "gist updated: https://gist.github.com/enginyilmaaz/$GIST_ID"
fi
