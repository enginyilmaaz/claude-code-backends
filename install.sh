#!/usr/bin/env bash
# claude-code-backends — installer (Linux/macOS)
# Repo: https://github.com/enginyilmaaz/claude-code-backends
#
# Adds two Claude Code backend launchers to your rc file (~/.bashrc and ~/.zshrc if present):
#   cckimi -> run Claude Code on the Kimi (Moonshot) backend   (+ cckimi-token)
#   ccglm  -> run Claude Code on the Z.AI GLM backend          (+ ccglm-token)
#
# Quick install:
#   curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh | bash
# Uninstall:
#   curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh | bash -s -- --uninstall
set -euo pipefail

g(){ printf '\033[32m%s\033[0m' "$1"; }
b(){ printf '\033[1m%s\033[0m' "$1"; }

# The backend launchers, delimited by markers so they can be replaced idempotently.
BLOCK=$(cat <<'CC_BACKENDS_EOF'
# BEGIN cc-backends
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
    ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-k3[1m]" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="kimi-k3[1m]" \
    ANTHROPIC_DEFAULT_FABLE_MODEL="kimi-k3[1m]" \
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
    ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.2[1m]" \
    ANTHROPIC_DEFAULT_FABLE_MODEL="glm-5.2[1m]" \
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

strip_block() {  # remove any existing block from $1
  [ -f "$1" ] || return 0
  sed -i '/^# BEGIN cc-backends$/,/^# END cc-backends$/d' "$1"
}

# Pick target rc files: those that exist; if none, create ~/.bashrc.
targets=()
[ -f "$HOME/.bashrc" ] && targets+=("$HOME/.bashrc")
[ -f "$HOME/.zshrc" ]  && targets+=("$HOME/.zshrc")
if [ "${#targets[@]}" -eq 0 ]; then touch "$HOME/.bashrc"; targets+=("$HOME/.bashrc"); fi

case "${1:-}" in
  --uninstall)
    for rc in "${targets[@]}"; do strip_block "$rc"; done
    echo "$(g '✓') cckimi / ccglm removed from: ${targets[*]}"
    echo "note: token files ~/.kimi_token and ~/.zai_token were left untouched."
    exit 0 ;;
  -h|--help)
    echo "usage: install.sh [--uninstall]"; exit 0 ;;
esac

for rc in "${targets[@]}"; do
  strip_block "$rc"                    # idempotent: drop any previous block first
  printf '\n%s\n' "$BLOCK" >> "$rc"
done

echo
echo "$(g '✓') claude-code-backends installed → ${targets[*]}"
echo
echo "commands: $(b cckimi) (+cckimi-token)   $(b ccglm) (+ccglm-token)"
echo
echo "reload your shell to use them:"
echo "  source ${targets[0]}    # or just open a new terminal"
echo
echo "first run of $(b cckimi)/$(b ccglm) asks for the backend API key and caches it in"
echo "~/.kimi_token / ~/.zai_token (chmod 600); update later with cckimi-token / ccglm-token."
echo
echo "requires Claude Code installed."
