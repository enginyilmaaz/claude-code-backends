#!/usr/bin/env bash
# claude-code-backends — installer (Linux/macOS)
# Repo: https://github.com/enginyilmaaz/claude-code-backends
#
# Adds three Claude Code backend launchers to your rc file (~/.bashrc and ~/.zshrc if present):
#   cckimi -> run Claude Code on the Kimi (Moonshot) backend   (+ cckimi-token)
#   ccglm  -> run Claude Code on the Z.AI GLM backend          (+ ccglm-token)
#   ccor   -> run Claude Code on the OpenRouter gateway        (+ ccor-token, ccor-model)
#   ccart  -> run Claude Code on the AgentRouter gateway       (+ ccart-token, ccart-model)
#
# Claude Code itself is installed automatically when it is missing, and the directories its
# installer uses (~/.local/bin, ~/.claude/bin) are added to PATH by the rc block.
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
# launchers into the running shell, so cckimi / ccglm / ccor / ccart work in the current terminal without
# opening a new one — a child process (curl|bash) can never inject into the parent shell,
# so sourcing is the only way to reach the terminal you are typing in.

# The backend launchers, delimited by markers so they can be replaced idempotently.
# Kept in a variable so a sourced install can eval it straight into the current shell.
CC_BACKENDS_BLOCK=$(cat <<'CC_BACKENDS_EOF'
# BEGIN cc-backends
# Neutralize any pre-existing aliases of these names first: an alias of the same name would
# both break the function definition below (parse error on '(') and shadow it at call time.
unalias cckimi ccglm ccor ccart ccskip cxskip cckimi-token ccglm-token ccor-token ccor-model \
        ccart-token ccart-model 2>/dev/null || true

# Claude Code's native installer drops its binary in ~/.local/bin (or ~/.claude/bin). Put both
# on PATH so `command claude` below resolves even in a shell that predates the install.
for __cc_bin in "$HOME/.local/bin" "$HOME/.claude/bin"; do
    if [ -d "$__cc_bin" ]; then
        case ":$PATH:" in *":$__cc_bin:"*) ;; *) PATH="$__cc_bin:$PATH" ;; esac
    fi
done
unset __cc_bin
export PATH

# ccskip / cxskip -> run Claude Code on your NORMAL Anthropic login (no backend token),
# permissions skipped + effort max. Both pin the latest Opus (claude-opus-5).
ccskip() { command claude --dangerously-skip-permissions --effort max --model claude-opus-5 "$@"; }
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

# ccor -> runs Claude Code on the OpenRouter gateway (key lives in ~/.openrouter_token, chmod 600)
# The model id lives in ~/.openrouter_model -- set or change it with: ccor-model <id>
ccor() {
    local token_file="$HOME/.openrouter_token"
    local model_file="$HOME/.openrouter_model"
    local token
    token="$([ -r "$token_file" ] && tr -d '[:space:]' < "$token_file")"
    if [ -z "$token" ]; then
        printf 'ccor: no API key found. Enter your OpenRouter API key and press Enter: ' >&2
        IFS= read -rs token < /dev/tty
        printf '\n' >&2
        token="$(printf '%s' "$token" | tr -d '[:space:]')"
        if [ -z "$token" ]; then
            printf 'ccor: no key entered, aborting.\n' >&2
            return 1
        fi
        ( umask 177; printf '%s\n' "$token" > "$token_file" ) && chmod 600 "$token_file"
        printf 'ccor: key saved to %s (mode 600).\n' "$token_file" >&2
    fi

    # ---- Models: leave these EMPTY to follow `ccor-model` / the default below --------
    # Fill a line in only to pin that tier here, e.g. or_haiku_model="z-ai/glm-4.7-flash".
    # Model ids come from https://openrouter.ai/models
    local or_model=""            # main + Opus tier
    local or_sonnet_model=""     # Sonnet tier
    local or_haiku_model=""      # Haiku tier -- background work (summaries, titles)
    local or_fable_model=""      # Fable tier -- fast
    local or_subagent_model=""   # subagents
    local or_default_model="stealth/ox-alpha"   # used when nothing else is set
    # ---------------------------------------------------------------------------------
    # Resolution order for the main model: pinned above -> ~/.openrouter_model -> default.
    if [ -z "$or_model" ] && [ -r "$model_file" ]; then
        or_model="$(tr -d '[:space:]' < "$model_file")"
    fi
    if [ -z "$or_model" ]; then
        or_model="$or_default_model"
        printf 'ccor: no model set, falling back to %s -- change it with: ccor-model <id>\n' "$or_model" >&2
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

ccor-token() { __cc_set_token ccor "$HOME/.openrouter_token" "$1"; }

# ccor-model [id] -- set the model ccor runs on (kept in .openrouter_model).
# With no argument it shows a numbered picker; option 0 takes any id from https://openrouter.ai/models
ccor-model() {
    local model_file="$HOME/.openrouter_model" id="$1"
    if [ -z "$id" ]; then
        __cc_pick_model ccor-model "$model_file" \
        stealth/ox-alpha \
        anthropic/claude-opus-4.8 \
        anthropic/claude-sonnet-5 \
        anthropic/claude-haiku-4.5 \
        x-ai/grok-4.20 \
        openai/gpt-5.6-sol \
        google/gemini-3.1-pro-preview \
        deepseek/deepseek-v4-pro \
        moonshotai/kimi-k3 \
        z-ai/glm-5
        return
    fi
    id="$(printf '%s' "$id" | tr -d '[:space:]')"
    printf '%s\n' "$id" > "$model_file" || return 1
    printf 'ccor-model: model set to %s (%s)\n' "$id" "$model_file" >&2
}

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
        ar_model="$ar_default_model"
        printf 'ccart: no model set, falling back to %s -- change it with: ccart-model <id>\n' "$ar_model" >&2
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
        claude-opus-5 \
        claude-opus-4-8 \
        gpt-5.6-sol \
        deepseek-v4f
        return
    fi
    id="$(printf '%s' "$id" | tr -d '[:space:]')"
    printf '%s\n' "$id" > "$model_file" || return 1
    printf 'ccart-model: model set to %s (%s)\n' "$id" "$model_file" >&2
}

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
      echo "$(g '✓') cckimi / ccglm / ccor / ccart / ccskip / cxskip removed from: ${targets[*]}"
      echo "note: the cached token/model files (~/.kimi_token, ~/.zai_token, ~/.openrouter_token,"
      echo "      ~/.agentrouter_token and the matching *_model files) were left untouched,"
      echo "      and Claude Code itself is not uninstalled."
      exit 10 ;;
    -h|--help)
      echo "usage: install.sh [--uninstall] [--yes]"; exit 11 ;;
  esac

  # These launchers run Claude Code with --dangerously-skip-permissions. Confirm once, at install.
  if [ "$assume_yes" != 1 ]; then
    printf '\n\033[33m⚠  DANGEROUS MODE\033[0m — cckimi / ccglm / ccor / ccart / ccskip / cxskip run Claude Code\n' >&2
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

  # Claude Code itself — every launcher shells out to it, so install it when it is missing.
  # Both install dirs are put on PATH for THIS run too; the rc block does the same per shell.
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
  if ! command -v claude >/dev/null 2>&1; then
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
  echo "$(g '✓') claude-code-backends installed → ${targets[*]}"
  echo
  echo "commands: $(b cckimi) (+cckimi-token)   $(b ccglm) (+ccglm-token)"
  echo "          $(b ccor) (+ccor-token, ccor-model)   $(b ccart) (+ccart-token, ccart-model)"
  echo "          $(b ccskip)   $(b cxskip)"
  echo
  echo "first run of a backend launcher asks for its API key and caches it in ~/.kimi_token /"
  echo "~/.zai_token / ~/.openrouter_token / ~/.agentrouter_token (chmod 600); update later with"
  echo "cckimi-token / ccglm-token / ccor-token / ccart-token."
  echo
  echo "$(b ccor) defaults to the free stealth/ox-alpha model, $(b ccart) to claude-opus-5."
  echo "run $(b ccor-model) / $(b ccart-model) with no argument to pick another from a numbered list."
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
  if [ "$__cc_interactive" -eq 1 ]; then
    eval "$CC_BACKENDS_BLOCK"            # load into the CURRENT shell — ready immediately
    printf '\n\033[32m✓\033[0m loaded into this shell — \033[1mcckimi\033[0m / \033[1mccglm\033[0m / \033[1mccor\033[0m / \033[1mccart\033[0m / \033[1mccskip\033[0m / \033[1mcxskip\033[0m are ready now.\n\n'
  else
    printf '\nreload your shell to use them now:\n'
    printf '  source ~/.bashrc            # or ~/.zshrc, or just open a new terminal\n'
    printf 'tip: install with  \033[1msource <(curl -fsSL …/install.sh)\033[0m  to load them into the current shell in one step.\n\n'
  fi
elif [ "$__cc_rc" -eq 10 ] && [ "$__cc_interactive" -eq 1 ]; then
  unset -f cckimi ccglm ccor ccart cckimi-token ccglm-token ccor-token ccor-model \
           ccart-token ccart-model __cc_set_token __cc_pick_model 2>/dev/null || true
  printf '\033[32m✓\033[0m also removed from this shell.\n'
fi

# Reflect the outcome as $? WITHOUT ever calling exit/return (either would kill a sourced
# shell): 0/10/11 are success, anything else is a real error to propagate to curl|bash callers.
case "$__cc_rc" in
  0|10|11) ( exit 0 ) ;;
  *)       ( exit "$__cc_rc" ) ;;
esac
