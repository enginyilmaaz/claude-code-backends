# claude-code-backends

One-line installers — **Linux/macOS and Windows** — for three Claude Code **backend launchers**:
run Claude Code against the **Kimi (Moonshot)**, **Z.AI GLM** or **OpenRouter** backend with a single
command, with per-user token caching. Plus `ccskip` / `cxskip` — quick `--dangerously-skip-permissions`
launchers for your **normal Anthropic login** (Opus 5).

**Claude Code itself is installed for you** when it is missing, and the directories its installer uses
are added to PATH — so a fresh machine goes from nothing to a working launcher in one command.

**Version:** 1.1.0

## ✨ What you get

| Command | What it does |
|---------|--------------|
| `cckimi` | Runs **Claude Code on the Kimi (Moonshot) backend**. First run asks for your Kimi API key and caches it. |
| `cckimi-token` | Set/update the cached Kimi key. |
| `ccglm` | Runs **Claude Code on the Z.AI GLM backend**. First run asks for your Z.AI key and caches it. |
| `ccglm-token` | Set/update the cached Z.AI key. |
| `ccor` | Runs **Claude Code on the OpenRouter gateway** — any model OpenRouter serves. First run asks for your OpenRouter key and caches it. **Ships with no model set — you fill one in** (see [Models per tier](#-models-per-tier)). |
| `ccor-token` | Set/update the cached OpenRouter key. |
| `ccskip` | Runs Claude Code on your **normal Anthropic login** (no backend token) — permissions skipped, effort max, pinned to the latest **Opus 5**. |
| `cxskip` | Same as `ccskip` — an alternate name, also **Opus 5**. |

`cckimi`/`ccglm`/`ccor` just point Claude Code at a different `ANTHROPIC_BASE_URL` + model via scoped env
vars — your normal `claude` login is untouched, and the backend env never leaks into your shell.

## 🚀 Quick install

**Linux / macOS** (bash/zsh — writes the launchers into `~/.bashrc` and `~/.zshrc` if present).
Use the `source <(…)` form so the commands also load into your **current** shell right away:

```bash
source <(curl -fsSL https://bit.ly/465SVW2)
```

Or the plain pipe (installs to your rc files; open a new terminal or `source ~/.bashrc` to use them):

```bash
curl -fsSL https://bit.ly/465SVW2 | bash
```

**Windows** (PowerShell — installs `.cmd` shims into `%USERPROFILE%\apps\aliases` and adds it to PATH,
so they work from cmd, PowerShell and Run):

```powershell
irm https://bit.ly/cc-backend-win | iex
```

With the `source <(…)` form (Linux/macOS) the commands work in the current shell immediately.
The plain pipe writes to your rc files instead — open a new terminal or `source ~/.bashrc` to pick them up.
On Windows they are ready in the **current PowerShell** session at once (a new window is only needed for `cmd.exe`).

### Uninstall

```bash
# Linux / macOS
curl -fsSL https://bit.ly/465SVW2 | bash -s -- --uninstall
```

```powershell
# Windows
& ([scriptblock]::Create((irm https://bit.ly/cc-backend-win))) -Uninstall
```

Uninstalling removes the launchers only — your cached token files are left untouched.

## 🔗 Links

| | URL |
|------|-----|
| **Install** (Linux/macOS) | https://bit.ly/465SVW2 |
| **Install** (Windows) | https://bit.ly/cc-backend-win |
| **Gist** (mirror of the installers) | https://gist.github.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8 |
| **Repository** (source) | https://github.com/enginyilmaaz/claude-code-backends |
| **Gist ID** | `2b903923ea111f741ca50a878ee9d2f8` |

## 🔐 Tokens & security

- Keys are read once, then cached per-user: `~/.kimi_token` / `~/.zai_token` / `~/.openrouter_token` on
  Linux/macOS (`chmod 600`), `%USERPROFILE%\.kimi_token` / `.zai_token` / `.openrouter_token` on Windows
  (`icacls`, current-user only). The OpenRouter key is cached in that file like every other backend key —
  it is **not** read from an `OPENROUTER_API_KEY` environment variable.
- Nothing is committed or transmitted anywhere except the backend you call.
- Rotate a key any time with `cckimi-token` / `ccglm-token` / `ccor-token` (or pass it as the first argument).
- All launchers run Claude Code with `--dangerously-skip-permissions` (Claude runs commands and edits
  files **without asking**). The **installer** warns and asks you to confirm once before installing —
  pass `--yes` on Linux/macOS (`… | bash -s -- --yes`) or `-Yes` on Windows to skip that prompt in
  automation. The launchers themselves never re-prompt, so keep them to directories you trust.

## 🎛️ Models per tier

Each launcher maps Claude Code's model tiers to a fitting backend model — the heavy tiers
and the subagents get the flagship, while the lighter/background tiers get a cheaper model:

| Claude tier | `cckimi` (Kimi) | `ccglm` (Z.AI GLM) | `ccor` (OpenRouter) |
|-------------|-----------------|--------------------|---------------------|
| main / Opus | `kimi-k3` (1M ctx) | `glm-5.3` (1M ctx) | *(blank — you fill it in)* |
| Sonnet | `kimi-k2.7-code` | `glm-4.6` | *(blank → falls back to main)* |
| Haiku *(background: summaries, titles)* | `kimi-k2.7-code` | `glm-4.5-air` | *(blank → falls back to main)* |
| Fable *(fast tier)* | `kimi-k2.7-code-highspeed` | `glm-4.7-flashx` | *(blank → falls back to main)* |
| subagents | `kimi-k3` (1M ctx) | `glm-5.3` (1M ctx) | *(blank → falls back to main)* |

For `cckimi` / `ccglm`, to use a different model for a tier edit the matching `ANTHROPIC_DEFAULT_*_MODEL`
(or `CLAUDE_CODE_SUBAGENT_MODEL`) line in the launcher block written to your rc file — model IDs come
from [Kimi](https://platform.kimi.ai/docs/models) / [Z.AI](https://docs.z.ai). Availability depends
on your plan; if a model is rejected, swap it for one your subscription includes.

### `ccor` — pick your own model

OpenRouter is a gateway to hundreds of models, so `ccor` intentionally ships with **every model slot
empty** and refuses to start until you fill one in. Model ids come from
[openrouter.ai/models](https://openrouter.ai/models) — either a pinned id (`anthropic/claude-opus-4.5`,
`x-ai/grok-4`) or the tilde "latest" form (`~anthropic/claude-opus-latest`).

**Linux/macOS** — open `~/.bashrc` (or `~/.zshrc`), find the `ccor()` block and edit these lines:

```bash
local or_model=""            # main + Opus tier   <- required
local or_sonnet_model=""     # Sonnet tier
local or_haiku_model=""      # Haiku tier -- background work (summaries, titles)
local or_fable_model=""      # Fable tier -- fast
local or_subagent_model=""   # subagents
```

**Windows** — open `%USERPROFILE%\apps\aliases\ccor.cmd` and edit the matching
`set "OR_MODEL="` / `set "OR_SONNET_MODEL="` / … lines.

Only the main model is required: any tier you leave blank falls back to it, so a single id is enough
to get going. Set a cheaper model for Haiku/Fable if you want the background work to cost less.

`ccor` also blanks `ANTHROPIC_API_KEY` — Claude Code would otherwise send it as `x-api-key`, which
OpenRouter treats as a direct-Anthropic credential and the request fails to authenticate. See the
[OpenRouter × Claude Code guide](https://openrouter.ai/docs/cookbook/coding-agents/claude-code-integration).

## 🧠 How it works

- **Linux/macOS:** the installer writes a single, marker-delimited block
  (`# BEGIN cc-backends` … `# END cc-backends`) into your rc file. Re-running replaces the block
  in place (idempotent); `--uninstall` removes exactly that block and nothing else.
  The script is safe to **source** — `source <(curl … install.sh)` writes the rc block *and* loads the
  launchers into the shell you're in (a child `curl | bash` process can't reach the parent shell, so
  sourcing is the only way to make them live in the current terminal). All rc-mutating work runs in a
  subshell, so `set -e`/`exit` never leak into — or kill — a shell that sourced it.
- **Windows:** each command is a self-contained `.cmd` under `%USERPROFILE%\apps\aliases` (on PATH).
  Env vars are scoped with `setlocal`, so a backend launcher never pollutes your session.
- **Claude Code bootstrap:** at the end of the install, if `claude` is not on PATH the official
  installer is run for you (`https://claude.ai/install.sh` / `install.ps1`, with `npm i -g
  @anthropic-ai/claude-code` as the fallback). Its bin directories — `~/.local/bin` and `~/.claude/bin`
  (`%USERPROFILE%\.local\bin` / `.claude\bin` on Windows) — are then added to PATH: the rc block does it
  for every new shell on Linux/macOS, and the Windows installer persists them to the User PATH.

## 📋 Requirements

- [Claude Code](https://claude.com/claude-code) — installed automatically if it is missing.
- Linux/macOS: `bash` (zsh also supported), plus `curl`. Windows: PowerShell 5+.
- A Kimi key (https://platform.moonshot.ai) for `cckimi`, a Z.AI key (https://z.ai/subscribe) for `ccglm`,
  an OpenRouter key (https://openrouter.ai/keys) for `ccor`.

## 🛠️ Maintainer

Edit `install.sh` / `install.ps1`, then run `./publish.sh` to sync both installers + this README into
the Gist (uses the logged-in `gh` account with the `gist` scope).

## License

MIT
