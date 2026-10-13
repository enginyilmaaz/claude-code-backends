#!/usr/bin/env bash
# claude-code-backends — installer (Linux/macOS)
# Repo: https://github.com/enginyilmaaz/claude-code-backends
#
# Interactive picker for the Claude Code backend launchers, written into your rc file
# (~/.bashrc and ~/.zshrc if present):
#   ccskip / cxskip -> your NORMAL Anthropic login, permissions skipped (Opus 5)
#   ccapi  -> Anthropic Console API key, no subscription  (+ ccapi-token)
#   cckimi -> Kimi (Moonshot) backend        (+ cckimi-token)
#   ccglm  -> Z.AI GLM backend               (+ ccglm-token)
#   ccort  -> OpenRouter gateway             (+ ccort-token, ccort-model)
#   ccart  -> AgentRouter gateway            (+ ccart-token, ccart-model)
#
# SPACE toggles, arrows move, ENTER confirms; a summary then asks you to confirm or cancel.
# Anything already installed is listed as an overwrite; DEPRECATED commands (e.g. the old
# ccor family, renamed to ccort) are removed on confirm without asking.
#
# Claude Code itself is installed when missing, and the directories its installer uses
# (~/.local/bin, ~/.claude/bin) are added to PATH by the rc block.
#
# Install AND load into your current shell (recommended — commands work right away):
#   source <(curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh)
# Plain install (open a new terminal, or `source ~/.bashrc`, to pick them up):
#   curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh | bash
# Non-interactive (installs everything, no picker):
#   curl -fsSL … /install.sh | bash -s -- --yes
# Uninstall:
#   curl -fsSL … /install.sh | bash -s -- --uninstall
#
# Safe to run either way. When EXECUTED it just writes the rc block. When SOURCED from an
# interactive shell it ALSO loads the launchers into the running shell, so they work in the
# current terminal without opening a new one.

# ------------------------------------------------------------------ catalogue ---
# Order shown in the picker. Each key maps to a label, the extra commands it brings
# along, and the rc snippet emitted by __cc_part.
CC_KEYS="ccskip ccapi cckimi ccglm ccort ccart"

# Commands from earlier versions that are wiped on every confirmed run, no questions
# asked: the ccor family was renamed to ccort, claude-skip/codex-skip are long gone.
CC_DEPRECATED="ccor ccor-token ccor-model claude-skip codex-skip"

__cc_label() {
    case "$1" in
        ccskip) printf 'ccskip / cxskip   your Anthropic login, skip-permissions (Opus 5)' ;;
        ccapi)  printf 'ccapi             Anthropic Console API key (claude-opus-5-5)' ;;
        cckimi) printf 'cckimi            Kimi (Moonshot) backend' ;;
        ccglm)  printf 'ccglm             Z.AI GLM backend' ;;
        ccort)  printf 'ccort             OpenRouter gateway (stealth/ox-alpha)' ;;
        ccart)  printf 'ccart             AgentRouter gateway (claude-opus-5)' ;;
    esac
}

# Every command a key installs — used for the "already installed" check and the summary.
__cc_cmds() {
    case "$1" in
        ccskip) printf 'ccskip cxskip' ;;
        ccapi)  printf 'ccapi ccapi-token' ;;
        cckimi) printf 'cckimi cckimi-token' ;;
        ccglm)  printf 'ccglm ccglm-token' ;;
        ccort)  printf 'ccort ccort-token ccort-model' ;;
        ccart)  printf 'ccart ccart-token ccart-model' ;;
    esac
}

# The rc snippet for one catalogue key.
__cc_part() {
    case "$1" in
    ccskip) cat <<'CC_PART_EOF'
# ccskip / cxskip -> run Claude Code on your NORMAL Anthropic login (no backend token),
# permissions skipped + effort max. Both pin the latest Opus (claude-opus-5).
ccskip() { command claude --dangerously-skip-permissions --effort max --model claude-opus-5 "$@"; }
cxskip() { command claude --dangerously-skip-permissions --effort max --model claude-opus-5 "$@"; }
CC_PART_EOF
    ;;
    ccapi) cat <<'CC_PART_EOF'
# ccapi -> runs Claude Code on the Anthropic Console API (key lives in ~/.anthropic_token,
# chmod 600). Billed per token to that key's Console credit, NOT to a Claude subscription:
# ANTHROPIC_API_KEY outranks the /login credential, so it bills the key while you stay
# logged in -- and ccskip, on the same machine, keeps using the subscription.
ccapi() {
    local token_file="$HOME/.anthropic_token"
    local token
    token="$([ -r "$token_file" ] && tr -d '[:space:]' < "$token_file")"
    if [ -z "$token" ]; then
        printf 'ccapi: no API key found. Enter your Anthropic Console API key and press Enter: ' >&2
        IFS= read -rs token < /dev/tty
        printf '\n' >&2
        token="$(printf '%s' "$token" | tr -d '[:space:]')"
        if [ -z "$token" ]; then
            printf 'ccapi: no key entered, aborting.\n' >&2
            return 1
        fi
        ( umask 177; printf '%s\n' "$token" > "$token_file" ) && chmod 600 "$token_file"
        printf 'ccapi: key saved to %s (mode 600).\n' "$token_file" >&2
    fi
    # ANTHROPIC_AUTH_TOKEN ranks ABOVE the API key, so blank it in case a gateway left one
    # in the environment; the base URL is pinned to first-party for the same reason.
    # The first interactive run asks once to approve the key before it overrides the
    # subscription -- say yes (reversible later via /config "Use custom API key").
    ANTHROPIC_API_KEY="$token" \
    ANTHROPIC_AUTH_TOKEN="" \
    ANTHROPIC_BASE_URL="https://api.anthropic.com" \
    command claude --dangerously-skip-permissions --model claude-opus-5-5 "$@"
}

ccapi-token() { __cc_set_token ccapi "$HOME/.anthropic_token" "$1"; }
CC_PART_EOF
    ;;
    cckimi) cat <<'CC_PART_EOF'
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
CC_PART_EOF
    ;;
    ccglm) cat <<'CC_PART_EOF'
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
    ANTHROPIC_MODEL="glm-5.3[1m]" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.3[1m]" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.6" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air" \
    ANTHROPIC_DEFAULT_FABLE_MODEL="glm-4.7-flashx" \
    CLAUDE_CODE_SUBAGENT_MODEL="glm-5.3[1m]" \
    CLAUDE_CODE_AUTO_COMPACT_WINDOW="1000000" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
    API_TIMEOUT_MS="3000000" \
    command claude --dangerously-skip-permissions "$@"
}

ccglm-token() { __cc_set_token ccglm "$HOME/.zai_token" "$1"; }
CC_PART_EOF
    ;;
    ccort) cat <<'CC_PART_EOF'
# ccort -> runs Claude Code on the OpenRouter gateway (key lives in ~/.openrouter_token, chmod 600)
# The model id lives in ~/.openrouter_model -- set or change it with: ccort-model <id>
ccort() {
    local token_file="$HOME/.openrouter_token"
    local model_file="$HOME/.openrouter_model"
    local token
    token="$([ -r "$token_file" ] && tr -d '[:space:]' < "$token_file")"
    if [ -z "$token" ]; then
        printf 'ccort: no API key found. Enter your OpenRouter API key and press Enter: ' >&2
        IFS= read -rs token < /dev/tty
        printf '\n' >&2
        token="$(printf '%s' "$token" | tr -d '[:space:]')"
        if [ -z "$token" ]; then
            printf 'ccort: no key entered, aborting.\n' >&2
            return 1
        fi
        ( umask 177; printf '%s\n' "$token" > "$token_file" ) && chmod 600 "$token_file"
        printf 'ccort: key saved to %s (mode 600).\n' "$token_file" >&2
    fi

    # ---- Models: leave these EMPTY to follow `ccort-model` / the default below --------
    # Fill a line in only to pin that tier here, e.g. or_haiku_model="z-ai/glm-4.7-flash".
    # Model ids come from https://openrouter.ai/models. Append [1m] to an id whose context
    # window is 1M -- without it Claude Code does not recognise the gateway model, assumes
    # 200k and starts auto-compacting far too early.
    local or_model=""            # main + Opus tier
    local or_sonnet_model=""     # Sonnet tier
    local or_haiku_model=""      # Haiku tier -- background work (summaries, titles)
    local or_fable_model=""      # Fable tier -- fast
    local or_subagent_model=""   # subagents
    local or_default_model="stealth/ox-alpha[1m]"   # used when nothing else is set
    # ---------------------------------------------------------------------------------
    # Resolution order for the main model: pinned above -> ~/.openrouter_model -> default.
    if [ -z "$or_model" ] && [ -r "$model_file" ]; then
        or_model="$(tr -d '[:space:]' < "$model_file")"
    fi
    if [ -z "$or_model" ]; then
        # Adopt the default once and record it, so this notice shows on the FIRST run only.
        or_model="$or_default_model"
        printf '%s\n' "$or_model" > "$model_file" 2>/dev/null || true
        printf 'ccort: no model set -- adopting the default %s (saved to %s).\n' "$or_model" "$model_file" >&2
        printf '       pick another any time with: ccort-model\n' >&2
    fi
    : "${or_sonnet_model:=$or_model}"
    : "${or_haiku_model:=$or_model}"
    : "${or_fable_model:=$or_model}"
    : "${or_subagent_model:=$or_model}"

    # ANTHROPIC_API_KEY must be blanked: Claude Code would send it as x-api-key, which
    # OpenRouter treats as a direct-Anthropic credential and the request fails to auth.
    ANTHROPIC_BASE_URL="https://openrouter.ai/api" \
    ANTHROPIC_AUTH_TOKEN="$token" \
    ANTHROPIC_API_KEY="" \
    ANTHROPIC_MODEL="$or_model" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$or_model" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$or_sonnet_model" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$or_haiku_model" \
    ANTHROPIC_DEFAULT_FABLE_MODEL="$or_fable_model" \
    CLAUDE_CODE_SUBAGENT_MODEL="$or_subagent_model" \
    CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1" \
    CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK="1" \
    API_TIMEOUT_MS="3000000" \
    command claude --dangerously-skip-permissions "$@"
}

ccort-token() { __cc_set_token ccort "$HOME/.openrouter_token" "$1"; }

# ccort-model [id] -- set the model ccort runs on (kept in .openrouter_model).
# With no argument it shows a numbered picker; option 0 takes any id from https://openrouter.ai/models
ccort-model() {
    local model_file="$HOME/.openrouter_model" id="$1"
    if [ -z "$id" ]; then
        __cc_pick_model ccort-model "$model_file" \
        'stealth/ox-alpha[1m]' \
        'anthropic/claude-opus-4.8[1m]' \
        'anthropic/claude-sonnet-5[1m]' \
        'anthropic/claude-haiku-4.5' \
        'x-ai/grok-4.20[1m]' \
        'openai/gpt-5.6-sol[1m]' \
        'google/gemini-3.1-pro-preview[1m]' \
        'deepseek/deepseek-v4-pro[1m]' \
        'moonshotai/kimi-k3[1m]' \
        'z-ai/glm-5'
        return
    fi
    id="$(printf '%s' "$id" | tr -d '[:space:]')"
    printf '%s\n' "$id" > "$model_file" || return 1
    printf 'ccort-model: model set to %s (%s)\n' "$id" "$model_file" >&2
}
CC_PART_EOF
    ;;
    ccart) cat <<'CC_PART_EOF'
# ccart -> runs Claude Code on the AgentRouter gateway (key lives in ~/.agentrouter_token, chmod 600)
# The model id lives in ~/.agentrouter_model -- set or change it with: ccart-model <id>
ccart() {
    local token_file="$HOME/.agentrouter_token"
    local model_file="$HOME/.agentrouter_model"
    local token
    token="$([ -r "$token_file" ] && tr -d '[:space:]' < "$token_file")"
    if [ -z "$token" ]; then
        printf 'ccart: no API key found. Enter your AgentRouter API key and press Enter: ' >&2
        IFS= read -rs token < /dev/tty
        printf '\n' >&2
        token="$(printf '%s' "$token" | tr -d '[:space:]')"
        if [ -z "$token" ]; then
            printf 'ccart: no key entered, aborting.\n' >&2
            return 1
        fi
        ( umask 177; printf '%s\n' "$token" > "$token_file" ) && chmod 600 "$token_file"
        printf 'ccart: key saved to %s (mode 600).\n' "$token_file" >&2
    fi

    # ---- Models: leave these EMPTY to follow `ccart-model` / the default below -------
    # AgentRouter serves a short list -- claude-opus-5, claude-opus-4-8, gpt-5.6-sol,
    # deepseek-v4f. Fill a line in only to pin that tier here.
    local ar_model=""            # main + Opus tier
    local ar_sonnet_model=""     # Sonnet tier
    local ar_haiku_model=""      # Haiku tier -- background work (summaries, titles)
    local ar_fable_model=""      # Fable tier -- fast
    local ar_subagent_model=""   # subagents
    local ar_default_model="claude-opus-5"   # used when nothing else is set
    # ---------------------------------------------------------------------------------
    # Resolution order for the main model: pinned above -> ~/.agentrouter_model -> default.
    if [ -z "$ar_model" ] && [ -r "$model_file" ]; then
        ar_model="$(tr -d '[:space:]' < "$model_file")"
    fi
    if [ -z "$ar_model" ]; then
        # Adopt the default once and record it, so this notice shows on the FIRST run only.
        ar_model="$ar_default_model"
        printf '%s\n' "$ar_model" > "$model_file" 2>/dev/null || true
        printf 'ccart: no model set -- adopting the default %s (saved to %s).\n' "$ar_model" "$model_file" >&2
        printf '       pick another any time with: ccart-model\n' >&2
    fi
    : "${ar_sonnet_model:=$ar_model}"
    : "${ar_haiku_model:=$ar_model}"
    : "${ar_fable_model:=$ar_model}"
    : "${ar_subagent_model:=$ar_model}"

    # ANTHROPIC_API_KEY is blanked so the gateway only ever sees the Bearer token:
    # Claude Code sends ANTHROPIC_API_KEY as x-api-key, a direct-Anthropic credential.
    ANTHROPIC_BASE_URL="https://agentrouter.org" \
    ANTHROPIC_AUTH_TOKEN="$token" \
    ANTHROPIC_API_KEY="" \
    ANTHROPIC_MODEL="$ar_model" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$ar_model" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$ar_sonnet_model" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$ar_haiku_model" \
    ANTHROPIC_DEFAULT_FABLE_MODEL="$ar_fable_model" \
    CLAUDE_CODE_SUBAGENT_MODEL="$ar_subagent_model" \
    API_TIMEOUT_MS="3000000" \
    command claude --dangerously-skip-permissions "$@"
}

ccart-token() { __cc_set_token ccart "$HOME/.agentrouter_token" "$1"; }

# ccart-model [id] -- set the model ccart runs on (kept in .agentrouter_model).
# With no argument it shows a numbered picker; the list is AgentRouter's full catalogue.
ccart-model() {
    local model_file="$HOME/.agentrouter_model" id="$1"
    if [ -z "$id" ]; then
        __cc_pick_model ccart-model "$model_file" \
        'claude-opus-5' \
        'claude-opus-4-8' \
        'gpt-5.6-sol[1m]' \
        'deepseek-v4f[1m]'
        return
    fi
    id="$(printf '%s' "$id" | tr -d '[:space:]')"
    printf '%s\n' "$id" > "$model_file" || return 1
    printf 'ccart-model: model set to %s (%s)\n' "$id" "$model_file" >&2
}
CC_PART_EOF
    ;;
    __path) cat <<'CC_PART_EOF'
# Claude Code's native installer drops its binary in ~/.local/bin (or ~/.claude/bin). Put both
# on PATH so `command claude` below resolves even in a shell that predates the install.
for __cc_bin in "$HOME/.local/bin" "$HOME/.claude/bin"; do
    if [ -d "$__cc_bin" ]; then
        case ":$PATH:" in *":$__cc_bin:"*) ;; *) PATH="$__cc_bin:$PATH" ;; esac
    fi
done
unset __cc_bin
export PATH
CC_PART_EOF
    ;;
    __set_token) cat <<'CC_PART_EOF'
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
CC_PART_EOF
    ;;
    __pick_model) cat <<'CC_PART_EOF'
# __cc_pick_model <label> <model_file> <id...> -- numbered picker shared by the cc*-model
# helpers. Prints to stderr, reads from /dev/tty, writes the chosen id to <model_file>.
__cc_pick_model() {
    local label="$1" model_file="$2"; shift 2
    local current="" m pick chosen="" n=1 total=0
    [ -r "$model_file" ] && current="$(tr -d '[:space:]' < "$model_file")"
    printf '%s - pick a model:\n' "$label" >&2
    for m in "$@"; do
        if [ "$m" = "$current" ]; then
            printf '  %2d. %s   <- current\n' "$n" "$m" >&2
        else
            printf '  %2d. %s\n' "$n" "$m" >&2
        fi
        n=$((n + 1)); total=$((total + 1))
    done
    printf '   0. type a different id by hand\n' >&2
    printf 'choice [1-%d, 0]: ' "$total" >&2
    IFS= read -r pick < /dev/tty
    pick="$(printf '%s' "$pick" | tr -d '[:space:]')"
    if [ "$pick" = "0" ]; then
        printf 'model id: ' >&2
        IFS= read -r chosen < /dev/tty
    else
        n=1
        for m in "$@"; do
            [ "$pick" = "$n" ] && chosen="$m"
            n=$((n + 1))
        done
    fi
    chosen="$(printf '%s' "$chosen" | tr -d '[:space:]')"
    if [ -z "$chosen" ]; then
        printf '%s: nothing picked, %s left unchanged\n' "$label" "$model_file" >&2
        return 1
    fi
    printf '%s\n' "$chosen" > "$model_file" || return 1
    printf '%s: model set to %s (%s)\n' "$label" "$chosen" "$model_file" >&2
}
CC_PART_EOF
    ;;
    esac
}

# ------------------------------------------------------------------------ TUI ---
# Runs in a `bash -c` child so it works even when this script was SOURCED from zsh
# (which has no `read -rsn1`). Reads "key|label|marker" lines on stdin, draws on
# /dev/tty, prints the chosen keys — or __CANCEL__ — on stdout.
CC_TUI=$(cat <<'CC_TUI_EOF'
rows=(); while IFS= read -r l; do rows+=("$l"); done
n=${#rows[@]}; [ "$n" -eq 0 ] && exit 0
sel=(); for ((i=0;i<n;i++)); do sel[i]=1; done
cur=0; first=1
draw() {
    if [ "$first" = 1 ]; then first=0; else printf '\033[%dA' "$((n+3))" >/dev/tty; fi
    {
        printf '\r\033[K  \033[1mSelect the launchers to install:\033[0m\n'
        for ((i=0;i<n;i++)); do
            key=${rows[i]%%|*}; rest=${rows[i]#*|}; label=${rest%%|*}; mark=${rest#*|}
            box='[ ]'; [ "${sel[i]}" = 1 ] && box='[x]'
            ptr=' '; [ "$i" = "$cur" ] && ptr='>'
            printf '\r\033[K %s %s %s' "$ptr" "$box" "$label"
            [ -n "$mark" ] && printf '  \033[33m%s\033[0m' "$mark"
            printf '\n'
        done
        printf '\r\033[K\n'
        printf '\r\033[K  \033[2mSPACE toggle · up/down move · a all · n none · ENTER confirm · q cancel\033[0m\n'
    } >/dev/tty
}
while :; do
    draw
    IFS= read -rsn1 k </dev/tty || k=''
    case "$k" in
        '') break ;;
        ' ') if [ "${sel[cur]}" = 1 ]; then sel[cur]=0; else sel[cur]=1; fi ;;
        a|A) for ((i=0;i<n;i++)); do sel[i]=1; done ;;
        n|N) for ((i=0;i<n;i++)); do sel[i]=0; done ;;
        q|Q) printf '__CANCEL__'; exit 0 ;;
        j) cur=$(( (cur+1) % n )) ;;
        k) if [ "$cur" -gt 0 ]; then cur=$((cur-1)); else cur=$((n-1)); fi ;;
        $'\033')
            IFS= read -rsn2 -t 1 r </dev/tty || r=''
            case "$r" in
                '[A') if [ "$cur" -gt 0 ]; then cur=$((cur-1)); else cur=$((n-1)); fi ;;
                '[B') cur=$(( (cur+1) % n )) ;;
            esac ;;
    esac
done
out=''
for ((i=0;i<n;i++)); do [ "${sel[i]}" = 1 ] && out="$out ${rows[i]%%|*}"; done
printf '%s' "${out# }"
CC_TUI_EOF
)

# --------------------------------------------------------------------- runner ---
# All file-mutating work runs in a SUBSHELL so `set -e` / `exit` can never leak into a
# shell that SOURCED this script. Exit status: 0 installed · 10 uninstalled · 11 help ·
# 20 cancelled · anything else = error. The block to eval into a sourced shell is handed
# back through a temp file, since a subshell cannot export a variable to its parent.
CC_TMP_BLOCK="${TMPDIR:-/tmp}/.cc-backends-block.$$"

__cc_backends_run() (
  set -uo pipefail
  g(){ printf '\033[32m%s\033[0m' "$1"; }
  b(){ printf '\033[1m%s\033[0m' "$1"; }
  y(){ printf '\033[33m%s\033[0m' "$1"; }

  strip_block() {                       # remove our marker block from $1
    [ -f "$1" ] || return 0
    sed -i '/^# BEGIN cc-backends$/,/^# END cc-backends$/d' "$1"
  }

  # Delete a deprecated command wherever it sits in the rc file (function, one-liner
  # function, or alias) plus the comment line above it. Runs on every confirmed install.
  purge_deprecated() {
    local rc="$1" name
    [ -f "$rc" ] || return 0
    for name in $CC_DEPRECATED; do
      sed -i -e "/^${name}[[:space:]]*()[[:space:]]*{.*}[[:space:]]*\$/d" \
             -e "/^${name}[[:space:]]*()[[:space:]]*{[[:space:]]*\$/,/^}\$/d" \
             -e "/^alias ${name}=/d" \
             -e "/^# ${name} ->/d" -e "/^# ${name} \[id\]/d" "$rc"
    done
  }

  present() {                           # is command $1 defined in any target rc?
    local name="$1" rc
    for rc in "${targets[@]}"; do
      grep -qE "^${name}[[:space:]]*\(\)" "$rc" 2>/dev/null && return 0
      grep -q "^alias ${name}=" "$rc" 2>/dev/null && return 0
    done
    return 1
  }

  case "${1:-}" in
    -h|--help)
      echo "usage: install.sh [--uninstall] [--yes]"
      echo "  --yes  install every launcher without the picker (for automation)"
      exit 11 ;;
  esac

  targets=()
  [ -f "$HOME/.bashrc" ] && targets+=("$HOME/.bashrc")
  [ -f "$HOME/.zshrc" ]  && targets+=("$HOME/.zshrc")
  if [ "${#targets[@]}" -eq 0 ]; then touch "$HOME/.bashrc"; targets+=("$HOME/.bashrc"); fi

  assume_yes="${CC_ASSUME_YES:-0}"
  for __a in "$@"; do case "$__a" in -y|--yes) assume_yes=1 ;; esac; done

  case "${1:-}" in
    --uninstall)
      for rc in "${targets[@]}"; do strip_block "$rc"; purge_deprecated "$rc"; done
      echo "$(g '✓') launchers removed from: ${targets[*]}"
      echo "note: the cached token/model files (~/.anthropic_token, ~/.kimi_token, ~/.zai_token,"
      echo "      ~/.openrouter_token, ~/.agentrouter_token and the matching *_model files) were"
      echo "      left untouched, and Claude Code itself is not uninstalled."
      exit 10 ;;
  esac

  # What is already there, and what is stale?
  installed_keys=""; dep_found=""
  for key in $CC_KEYS; do
    first_cmd="${key}"
    present "$first_cmd" && installed_keys="$installed_keys $key"
  done
  for name in $CC_DEPRECATED; do
    present "$name" && dep_found="$dep_found $name"
  done

  # Pick the launchers: interactive unless --yes or there is no terminal.
  if [ "$assume_yes" = 1 ] || [ ! -r /dev/tty ]; then
    chosen="$CC_KEYS"
  else
    menu=""
    for key in $CC_KEYS; do
      mark=""
      case " $installed_keys " in *" $key "*) mark="installed" ;; esac
      menu="$menu$key|$(__cc_label "$key")|$mark
"
    done
    chosen="$(printf '%s' "$menu" | bash -c "$CC_TUI")"
    if [ "$chosen" = "__CANCEL__" ]; then
      printf '\ncancelled — nothing was changed.\n' >&2
      exit 20
    fi
  fi

  # Summary + confirm/cancel.
  if [ "$assume_yes" != 1 ] && [ -r /dev/tty ]; then
    over=""
    for key in $chosen; do case " $installed_keys " in *" $key "*) over="$over $key" ;; esac; done
    printf '\n  %s\n' "$(b 'Review')"
    if [ -n "$chosen" ]; then
      printf '    install    :'
      for key in $chosen; do printf ' %s' "$key"; done
      printf '\n'
      for key in $chosen; do printf '                 %s\n' "$(__cc_cmds "$key")"; done
    else
      printf '    install    : (nothing selected — the block will be removed)\n'
    fi
    [ -n "$over" ]      && printf '    overwrite  : %s  %s\n' "$(y "${over# }")" "(already installed)"
    [ -n "$dep_found" ] && printf '    remove     : %s  %s\n' "$(y "${dep_found# }")" "(deprecated)"
    printf '\n    these launchers run Claude Code with \033[1m--dangerously-skip-permissions\033[0m —\n'
    printf '    it runs commands and edits files WITHOUT asking. Use only in trusted directories.\n'
    printf '\n      1) Confirm\n      2) Cancel\n'
    printf '    choice [1/2]: '
    read -r ans < /dev/tty || ans=2
    case "$ans" in
      1|y|Y|yes|YES|Yes) ;;
      *) printf '    cancelled — nothing was changed.\n'; exit 20 ;;
    esac
  fi

  # Assemble the rc block out of the chosen parts only.
  need_token=0; need_pick=0
  for key in $chosen; do
    case "$key" in ccapi|cckimi|ccglm|ccort|ccart) need_token=1 ;; esac
    case "$key" in ccort|ccart) need_pick=1 ;; esac
  done
  all_cmds=""
  for key in $CC_KEYS; do all_cmds="$all_cmds $(__cc_cmds "$key")"; done

  block="$(
    printf '# BEGIN cc-backends\n'
    printf '# Neutralize any pre-existing aliases of these names first: an alias of the same name\n'
    printf '# would break the function definitions below and shadow them at call time.\n'
    printf 'unalias%s 2>/dev/null || true\n\n' "$all_cmds"
    __cc_part __path
    for key in $chosen; do printf '\n'; __cc_part "$key"; done
    if [ "$need_token" = 1 ]; then printf '\n'; __cc_part __set_token; fi
    if [ "$need_pick" = 1 ]; then printf '\n'; __cc_part __pick_model; fi
    printf '# END cc-backends\n'
  )"

  for rc in "${targets[@]}"; do
    strip_block "$rc"                    # idempotent: drop any previous block first
    purge_deprecated "$rc"               # stale commands go without asking
    if [ -n "$chosen" ]; then printf '\n%s\n' "$block" >> "$rc"; fi
  done
  printf '%s\n' "$block" > "$CC_TMP_BLOCK" 2>/dev/null || true

  # Claude Code itself — every launcher shells out to it, so install it when missing.
  add_claude_bins_to_path() {
    local d
    for d in "$HOME/.local/bin" "$HOME/.claude/bin"; do
      [ -d "$d" ] || continue
      case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    done
    export PATH
    hash -r 2>/dev/null || true
  }
  add_claude_bins_to_path
  if [ -n "$chosen" ] && ! command -v claude >/dev/null 2>&1; then
    echo
    echo "claude not found — installing Claude Code…"
    if ! curl -fsSL https://claude.ai/install.sh | bash; then
      if command -v npm >/dev/null 2>&1; then
        echo "native installer failed — falling back to npm…"
        npm install -g @anthropic-ai/claude-code || true
      fi
    fi
    add_claude_bins_to_path
  fi

  echo
  if [ -z "$chosen" ]; then
    echo "$(g '✓') nothing selected — the cc-backends block was removed from: ${targets[*]}"
    exit 0
  fi
  echo "$(g '✓') claude-code-backends installed → ${targets[*]}"
  echo
  echo "installed:"
  for key in $chosen; do echo "  $(b "$(__cc_cmds "$key")")"; done
  if [ -n "$dep_found" ]; then
    echo
    echo "removed (deprecated): ${dep_found# }"
  fi
  echo
  echo "first run of a backend launcher asks for its API key and caches it in ~/.anthropic_token /"
  echo "~/.kimi_token / ~/.zai_token / ~/.openrouter_token / ~/.agentrouter_token (chmod 600);"
  echo "update later with the matching *-token command."
  case " $chosen " in *" ccapi "*)
    echo
    echo "$(b ccapi) runs on an Anthropic Console API key (platform.claude.com/settings/keys) and"
    echo "bills that key per token -- no subscription involved. Claude Code asks once, on the"
    echo "first interactive run, to approve the key over your login; answer yes." ;;
  esac
  case " $chosen " in *" ccort "*|*" ccart "*)
    echo
    echo "$(b ccort) defaults to the free stealth/ox-alpha model, $(b ccart) to claude-opus-5."
    echo "run $(b ccort-model) / $(b ccart-model) with no argument to pick another from a list." ;;
  esac
  echo
  if command -v claude >/dev/null 2>&1; then
    echo "$(g '✓') Claude Code: $(command -v claude)"
  else
    echo "⚠  Claude Code is still not on PATH — install it manually: https://claude.com/claude-code"
  fi
  exit 0
)

__cc_backends_run "$@"
__cc_rc=$?

# Interactive shell? True only when this script was SOURCED at a prompt — the one situation
# where we can load the launchers straight into the shell you are typing in.
__cc_interactive=0
case "$-" in *i*) __cc_interactive=1 ;; esac

if [ "$__cc_rc" -eq 0 ]; then
  if [ "$__cc_interactive" -eq 1 ] && [ -r "$CC_TMP_BLOCK" ]; then
    eval "$(cat "$CC_TMP_BLOCK")"        # load into the CURRENT shell — ready immediately
    printf '\n\033[32m✓\033[0m loaded into this shell — ready to use now.\n\n'
  elif [ "$__cc_interactive" -eq 0 ]; then
    printf '\nreload your shell to use them now:\n'
    printf '  source ~/.bashrc            # or ~/.zshrc, or just open a new terminal\n'
    printf 'tip: install with  \033[1msource <(curl -fsSL …/install.sh)\033[0m  to load them into the current shell in one step.\n\n'
  fi
elif [ "$__cc_rc" -eq 10 ] && [ "$__cc_interactive" -eq 1 ]; then
  unset -f ccapi cckimi ccglm ccort ccart ccapi-token cckimi-token ccglm-token ccort-token \
           ccort-model ccart-token ccart-model __cc_set_token __cc_pick_model 2>/dev/null || true
  printf '\033[32m✓\033[0m also removed from this shell.\n'
fi
rm -f "$CC_TMP_BLOCK" 2>/dev/null || true

# Reflect the outcome as $? WITHOUT ever calling exit/return (either would kill a sourced
# shell): 0/10/11/20 are expected outcomes, anything else is a real error.
case "$__cc_rc" in
  0|10|11|20) ( exit 0 ) ;;
  *)          ( exit "$__cc_rc" ) ;;
esac
