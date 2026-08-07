#!/usr/bin/env bash
# claude-code-backends — installer (Linux/macOS)
# Repo: https://github.com/enginyilmaaz/claude-code-backends
#
# Adds two Claude Code backend launchers to your rc file (~/.bashrc and ~/.zshrc if present):
#   cckimi -> run Claude Code on the Kimi (Moonshot) backend   (+ cckimi-token)
#   ccglm  -> run Claude Code on the Z.AI GLM backend          (+ ccglm-token)
#
# Install AND load into your current shell (recommended — commands work right away):
#   source <(curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh)
# Plain install (open a new terminal, or `source ~/.bashrc`, to pick them up):
#   curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh | bash
# Uninstall:
#   curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh | bash -s -- --uninstall
#
# Safe to run either way. When EXECUTED (curl|bash, ./install.sh) it just writes the rc
# block. When SOURCED from an interactive shell (source <(curl …)) it ALSO loads the
# launchers into the running shell, so cckimi / ccglm work in the current terminal without
# opening a new one — a child process (curl|bash) can never inject into the parent shell,
# so sourcing is the only way to reach the terminal you are typing in.

# The backend launchers, delimited by markers so they can be replaced idempotently.
# Kept in a variable so a sourced install can eval it straight into the current shell.
CC_BACKENDS_BLOCK=$(cat <<'CC_BACKENDS_EOF'
# BEGIN cc-backends
# ccskip / cxskip -> run Claude Code on your NORMAL Anthropic login (no backend token),
# permissions skipped + effort max. ccskip pins Opus 4.8, cxskip pins Opus 5.
ccskip() { command claude --dangerously-skip-permissions --effort max --model claude-opus-4-8 "$@"; }
cxskip() { command claude --dangerously-skip-permissions --effort max --model claude-opus-5 "$@"; }

# cckimi -> runs Claude Code on the Kimi backend (token lives in ~/.kimi_token, chmod 600)
cckimi() {
    local token_file="$HOME/.kimi_token"
    local token
    token="$([ -r "$token_file" ] && tr -d '[:space:]' < "$token_file")"
    if [ -z "$token" ]; then
        printf 'cckimi: no API key found. Enter your Kimi API key and press Enter: ' >&2
        IFS= read -rs token < /dev/tty
        printf '\n' >&2
        token="$(printf '%s' "$token" | tr -d '[:space:]')"
        if [ -z "$token" ]; then
            printf 'cckimi: no key entered, aborting.\n' >&2
            return 1
        fi
        ( umask 177; printf '%s\n' "$token" > "$token_file" ) && chmod 600 "$token_file"
        printf 'cckimi: key saved to %s (mode 600).\n' "$token_file" >&2
    fi
    ANTHROPIC_BASE_URL="https://api.kimi.com/coding/" \
    ANTHROPIC_AUTH_TOKEN="$token" \
    ANTHROPIC_MODEL="kimi-k3[1m]" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="kimi-k3[1m]" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-k2.7-code" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="kimi-k2.7-code" \
    ANTHROPIC_DEFAULT_FABLE_MODEL="kimi-k2.7-code-highspeed" \
    CLAUDE_CODE_SUBAGENT_MODEL="kimi-k3[1m]" \
    ENABLE_TOOL_SEARCH="false" \
    CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576" \
    CLAUDE_CODE_EFFORT_LEVEL="max" \
    command claude --dangerously-skip-permissions --effort max "$@"
}

cckimi-token() { __cc_set_token cckimi "$HOME/.kimi_token" "$1"; }

# ccglm -> runs Claude Code on the Z.AI GLM backend (token lives in ~/.zai_token, chmod 600)
ccglm() {
    local token_file="$HOME/.zai_token"
    local token
    token="$([ -r "$token_file" ] && tr -d '[:space:]' < "$token_file")"
    if [ -z "$token" ]; then
        printf 'ccglm: no API key found. Enter your Z.AI API key and press Enter: ' >&2
        IFS= read -rs token < /dev/tty
        printf '\n' >&2
        token="$(printf '%s' "$token" | tr -d '[:space:]')"
        if [ -z "$token" ]; then
            printf 'ccglm: no key entered, aborting.\n' >&2
            return 1
        fi
        ( umask 177; printf '%s\n' "$token" > "$token_file" ) && chmod 600 "$token_file"
        printf 'ccglm: key saved to %s (mode 600).\n' "$token_file" >&2
    fi
    ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
    ANTHROPIC_AUTH_TOKEN="$token" \
    ANTHROPIC_MODEL="glm-5.2[1m]" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.6" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air" \
    ANTHROPIC_DEFAULT_FABLE_MODEL="glm-4.7-flashx" \
    CLAUDE_CODE_SUBAGENT_MODEL="glm-5.2[1m]" \
    CLAUDE_CODE_AUTO_COMPACT_WINDOW="1000000" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
    API_TIMEOUT_MS="3000000" \
    command claude --dangerously-skip-permissions "$@"
}

ccglm-token() { __cc_set_token ccglm "$HOME/.zai_token" "$1"; }

# __cc_set_token <label> <token_file> [key] -- shared writer for the cc*-token helpers
__cc_set_token() {
    local label="$1" token_file="$2" key="$3"
    if [ -z "$key" ]; then
        read -r -p "$label - paste API key: " key
    fi
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    if [ -z "$key" ]; then
        printf '%s: no key given, %s left unchanged\n' "$label" "$token_file" >&2
        return 1
    fi
    ( umask 177; printf '%s\n' "$key" > "$token_file" ) || return 1
    chmod 600 "$token_file"
    printf '%s: key written to %s (%d chars, mode %s). Verify with: %s -p "ok"\n' \
        "$label" "$token_file" "${#key}" \
        "$(stat -c '%a' "$token_file" 2>/dev/null || echo '600')" "$label"
}
# END cc-backends
CC_BACKENDS_EOF
)

# All file-mutating work runs in a SUBSHELL so `set -e` / `exit` can never leak into a
# shell that SOURCED this script (either would kill the user's terminal on error).
# Exit status back to the caller: 0 installed · 10 uninstalled · 11 help · anything else = error.
__cc_backends_run() (
  set -euo pipefail
  g(){ printf '\033[32m%s\033[0m' "$1"; }
  b(){ printf '\033[1m%s\033[0m' "$1"; }

  strip_block() {  # remove any existing block from $1
    [ -f "$1" ] || return 0
    sed -i '/^# BEGIN cc-backends$/,/^# END cc-backends$/d' "$1"
  }

  # Pick target rc files: those that exist; if none, create ~/.bashrc.
  targets=()
  [ -f "$HOME/.bashrc" ] && targets+=("$HOME/.bashrc")
  [ -f "$HOME/.zshrc" ]  && targets+=("$HOME/.zshrc")
  if [ "${#targets[@]}" -eq 0 ]; then touch "$HOME/.bashrc"; targets+=("$HOME/.bashrc"); fi

  # --yes / -y (or CC_ASSUME_YES=1) skips the install-time confirmation below.
  assume_yes="${CC_ASSUME_YES:-0}"
  for __a in "$@"; do case "$__a" in -y|--yes) assume_yes=1 ;; esac; done

  case "${1:-}" in
    --uninstall)
      for rc in "${targets[@]}"; do strip_block "$rc"; done
      echo "$(g '✓') cckimi / ccglm / ccskip / cxskip removed from: ${targets[*]}"
      echo "note: token files ~/.kimi_token and ~/.zai_token were left untouched."
      exit 10 ;;
    -h|--help)
      echo "usage: install.sh [--uninstall] [--yes]"; exit 11 ;;
  esac

  # These launchers run Claude Code with --dangerously-skip-permissions. Confirm once, at install.
  if [ "$assume_yes" != 1 ]; then
    printf '\n\033[33m⚠  DANGEROUS MODE\033[0m — cckimi / ccglm / ccskip / cxskip run Claude Code with\n' >&2
    printf '   \033[1m--dangerously-skip-permissions\033[0m: it runs commands and edits files WITHOUT asking.\n' >&2
    printf '   Use only in directories you trust.\n' >&2
    if [ -r /dev/tty ]; then
      printf '   Install these launchers anyway? [y/N] ' >&2
      read -r __ans < /dev/tty || __ans=""
      case "$__ans" in y|Y|yes|YES|Yes) ;; *) printf '   aborted — nothing was changed.\n' >&2; exit 20 ;; esac
    else
      printf '   no terminal to confirm; re-run with --yes (or CC_ASSUME_YES=1) to proceed.\n' >&2
      exit 20
    fi
  fi

  for rc in "${targets[@]}"; do
    strip_block "$rc"                    # idempotent: drop any previous block first
    printf '\n%s\n' "$CC_BACKENDS_BLOCK" >> "$rc"
  done

  echo
  echo "$(g '✓') claude-code-backends installed → ${targets[*]}"
  echo
  echo "commands: $(b cckimi) (+cckimi-token)   $(b ccglm) (+ccglm-token)   $(b ccskip)   $(b cxskip)"
  echo
  echo "first run of $(b cckimi)/$(b ccglm) asks for the backend API key and caches it in"
  echo "~/.kimi_token / ~/.zai_token (chmod 600); update later with cckimi-token / ccglm-token."
  echo
  echo "requires Claude Code installed."
  exit 0
)

__cc_backends_run "$@"
__cc_rc=$?

# Interactive shell? True only when this script was SOURCED at a prompt — the one situation
# where we can load the launchers straight into the shell you are typing in.
__cc_interactive=0
case "$-" in *i*) __cc_interactive=1 ;; esac

if [ "$__cc_rc" -eq 0 ]; then
  if [ "$__cc_interactive" -eq 1 ]; then
    eval "$CC_BACKENDS_BLOCK"            # load into the CURRENT shell — ready immediately
    printf '\n\033[32m✓\033[0m loaded into this shell — \033[1mcckimi\033[0m / \033[1mccglm\033[0m / \033[1mccskip\033[0m / \033[1mcxskip\033[0m are ready to use now.\n\n'
  else
    printf '\nreload your shell to use them now:\n'
    printf '  source ~/.bashrc            # or ~/.zshrc, or just open a new terminal\n'
    printf 'tip: install with  \033[1msource <(curl -fsSL …/install.sh)\033[0m  to load them into the current shell in one step.\n\n'
  fi
elif [ "$__cc_rc" -eq 10 ] && [ "$__cc_interactive" -eq 1 ]; then
  unset -f cckimi ccglm cckimi-token ccglm-token __cc_set_token 2>/dev/null || true
  printf '\033[32m✓\033[0m also removed from this shell.\n'
fi

# Reflect the outcome as $? WITHOUT ever calling exit/return (either would kill a sourced
# shell): 0/10/11 are success, anything else is a real error to propagate to curl|bash callers.
case "$__cc_rc" in
  0|10|11) ( exit 0 ) ;;
  *)       ( exit "$__cc_rc" ) ;;
esac
