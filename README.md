# claude-code-backends

One-line installers — **Linux/macOS and Windows** — for three Claude Code **backend launchers**:
run Claude Code against the **Kimi (Moonshot)**, **Z.AI GLM** or **OpenRouter** backend with a single
command, with per-user token caching. Plus `ccskip` / `cxskip` — quick `--dangerously-skip-permissions`
launchers for your **normal Anthropic login** (Opus 5).

**Claude Code itself is installed for you** when it is missing, and the directories its installer uses
are added to PATH — so a fresh machine goes from nothing to a working launcher in one command.

**Version:** 1.2.0

## ✨ What you get

| Command | What it does |
|---------|--------------|
| `cckimi` | Runs **Claude Code on the Kimi (Moonshot) backend**. First run asks for your Kimi API key and caches it. |
| `cckimi-token` | Set/update the cached Kimi key. |
| `ccglm` | Runs **Claude Code on the Z.AI GLM backend**. First run asks for your Z.AI key and caches it. |
| `ccglm-token` | Set/update the cached Z.AI key. |
| `ccor` | Runs **Claude Code on the OpenRouter gateway** — any model OpenRouter serves. First run asks for your OpenRouter key and caches it. Defaults to `stealth/ox-alpha` until you pick another. |
| `ccor-token` | Set/update the cached OpenRouter key. |
| `ccor-model` | Set/update the model `ccor` runs on (cached in `~/.openrouter_model`). |
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
- The `ccor` model id is **not** a secret and lives beside them in `~/.openrouter_model` — set it with `ccor-model`.
- All launchers run Claude Code with `--dangerously-skip-permissions` (Claude runs commands and edits
  files **without asking**). The **installer** warns and asks you to confirm once before installing —
  pass `--yes` on Linux/macOS (`… | bash -s -- --yes`) or `-Yes` on Windows to skip that prompt in
  automation. The launchers themselves never re-prompt, so keep them to directories you trust.

## 🎛️ Models per tier

Each launcher maps Claude Code's model tiers to a fitting backend model — the heavy tiers
and the subagents get the flagship, while the lighter/background tiers get a cheaper model:

| Claude tier | `cckimi` (Kimi) | `ccglm` (Z.AI GLM) | `ccor` (OpenRouter) |
|-------------|-----------------|--------------------|---------------------|
| main / Opus | `kimi-k3` (1M ctx) | `glm-5.3` (1M ctx) | whatever `ccor-model` is set to |
| Sonnet | `kimi-k2.7-code` | `glm-4.6` | *(follows main)* |
| Haiku *(background: summaries, titles)* | `kimi-k2.7-code` | `glm-4.5-air` | *(follows main)* |
| Fable *(fast tier)* | `kimi-k2.7-code-highspeed` | `glm-4.7-flashx` | *(follows main)* |
| subagents | `kimi-k3` (1M ctx) | `glm-5.3` (1M ctx) | *(follows main)* |

For `cckimi` / `ccglm`, to use a different model for a tier edit the matching `ANTHROPIC_DEFAULT_*_MODEL`
(or `CLAUDE_CODE_SUBAGENT_MODEL`) line in the launcher block written to your rc file — model IDs come
from [Kimi](https://platform.kimi.ai/docs/models) / [Z.AI](https://docs.z.ai). Availability depends
on your plan; if a model is rejected, swap it for one your subscription includes.

### `ccor` — pick your own model

OpenRouter is a gateway to hundreds of models, so `ccor` lets you swap the model without touching any
script — just run **`ccor-model`**:

```bash
ccor-model                       # prompts for an id
ccor-model x-ai/grok-4.20        # or pass it straight in
```

The id is cached in `~/.openrouter_model` (`%USERPROFILE%\.openrouter_model` on Windows) and every
later `ccor` run picks it up. Browse ids at [openrouter.ai/models](https://openrouter.ai/models) —
either a pinned id (`anthropic/claude-opus-4.8`, `x-ai/grok-4.20`) or the tilde "latest" form
(`~anthropic/claude-opus-latest`).

**Until you set one, `ccor` falls back to `stealth/ox-alpha`** — a 1M-context reasoning model built
for coding and sustained agentic work, currently free on OpenRouter. It prints a one-line notice each
run so you know the fallback is in play.

The model resolves in this order, first hit wins:

1. a tier pinned inside the launcher itself (see below),
2. `~/.openrouter_model` — what `ccor-model` writes,
3. the built-in `stealth/ox-alpha` default.

Per-tier pinning is still there if you want cheaper background work: on **Linux/macOS** open the
`ccor()` block in your rc file, on **Windows** open `%USERPROFILE%\apps\aliases\ccor.cmd`, and fill in
the tier you care about — e.g. `or_haiku_model="z-ai/glm-4.7-flash"` (`set "OR_HAIKU_MODEL=…"` on
Windows). Any tier left blank follows the main model.

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
