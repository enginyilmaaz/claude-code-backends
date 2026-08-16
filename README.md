# claude-code-backends

One-line installers — **Linux/macOS and Windows** — for two Claude Code **backend launchers**:
run Claude Code against the **Kimi (Moonshot)** or **Z.AI GLM** backend with a single command,
with per-user token caching. Plus `ccskip` / `cxskip` — quick `--dangerously-skip-permissions`
launchers for your **normal Anthropic login** (Opus 5).

**Version:** 1.0.0

## ✨ What you get

| Command | What it does |
|---------|--------------|
| `cckimi` | Runs **Claude Code on the Kimi (Moonshot) backend**. First run asks for your Kimi API key and caches it. |
| `cckimi-token` | Set/update the cached Kimi key. |
| `ccglm` | Runs **Claude Code on the Z.AI GLM backend**. First run asks for your Z.AI key and caches it. |
| `ccglm-token` | Set/update the cached Z.AI key. |
| `ccskip` | Runs Claude Code on your **normal Anthropic login** (no backend token) — permissions skipped, effort max, pinned to the latest **Opus 5**. |
| `cxskip` | Same as `ccskip` — an alternate name, also **Opus 5**. |

`cckimi`/`ccglm` just point Claude Code at a different `ANTHROPIC_BASE_URL` + model via scoped env vars —
your normal `claude` login is untouched, and the backend env never leaks into your shell.

## 🚀 Quick install

**Linux / macOS** (bash/zsh — writes the launchers into `~/.bashrc` and `~/.zshrc` if present).
Use the `source <(…)` form so the commands also load into your **current** shell right away:

```bash
source <(curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh)
```

Or the plain pipe (installs to your rc files; open a new terminal or `source ~/.bashrc` to use them):

```bash
curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh | bash
```

**Windows** (PowerShell — installs `.cmd` shims into `%USERPROFILE%\apps\aliases` and adds it to PATH,
so they work from cmd, PowerShell and Run):

```powershell
irm https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.ps1 | iex
```

With the `source <(…)` form (Linux/macOS) the commands work in the current shell immediately.
The plain pipe writes to your rc files instead — open a new terminal or `source ~/.bashrc` to pick them up.
On Windows they are ready in the **current PowerShell** session at once (a new window is only needed for `cmd.exe`).

### Uninstall

```bash
# Linux / macOS
curl -fsSL https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.sh | bash -s -- --uninstall
```

```powershell
# Windows
& ([scriptblock]::Create((irm https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.ps1))) -Uninstall
```

Uninstalling removes the launchers only — your cached token files are left untouched.

## 🔗 Links

| | URL |
|------|-----|
| **Gist** (quick install) | https://gist.github.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8 |
| **Repository** (source) | https://github.com/enginyilmaaz/claude-code-backends |
| **Gist ID** | `2b903923ea111f741ca50a878ee9d2f8` |

## 🔐 Tokens & security

- Keys are read once, then cached per-user: `~/.kimi_token` / `~/.zai_token` on Linux/macOS (`chmod 600`),
  `%USERPROFILE%\.kimi_token` / `.zai_token` on Windows (`icacls`, current-user only).
- Nothing is committed or transmitted anywhere except the backend you call.
- Rotate a key any time with `cckimi-token` / `ccglm-token` (or pass it as the first argument).
- All launchers run Claude Code with `--dangerously-skip-permissions` (Claude runs commands and edits
  files **without asking**). The **installer** warns and asks you to confirm once before installing —
  pass `--yes` on Linux/macOS (`… | bash -s -- --yes`) or `-Yes` on Windows to skip that prompt in
  automation. The launchers themselves never re-prompt, so keep them to directories you trust.

## 🎛️ Models per tier

Each launcher maps Claude Code's model tiers to a fitting backend model — the heavy tiers
and the subagents get the flagship, while the lighter/background tiers get a cheaper model:

| Claude tier | `cckimi` (Kimi) | `ccglm` (Z.AI GLM) |
|-------------|-----------------|--------------------|
| main / Opus | `kimi-k3` (1M ctx) | `glm-5.3` (1M ctx) |
| Sonnet | `kimi-k2.7-code` | `glm-4.6` |
| Haiku *(background: summaries, titles)* | `kimi-k2.7-code` | `glm-4.5-air` |
| Fable *(fast tier)* | `kimi-k2.7-code-highspeed` | `glm-4.7-flashx` |
| subagents | `kimi-k3` (1M ctx) | `glm-5.3` (1M ctx) |

To use a different model for a tier, edit the matching `ANTHROPIC_DEFAULT_*_MODEL` (or
`CLAUDE_CODE_SUBAGENT_MODEL`) line in the launcher block written to your rc file — model IDs come
from [Kimi](https://platform.kimi.ai/docs/models) / [Z.AI](https://docs.z.ai). Availability depends
on your plan; if a model is rejected, swap it for one your subscription includes.

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

## 📋 Requirements

- [Claude Code](https://claude.com/claude-code) installed.
- Linux/macOS: `bash` (zsh also supported). Windows: PowerShell 5+.
- A Kimi key (https://platform.moonshot.ai) for `cckimi`, a Z.AI key (https://z.ai/subscribe) for `ccglm`.

## 🛠️ Maintainer

Edit `install.sh` / `install.ps1`, then run `./publish.sh` to sync both installers + this README into
the Gist (uses the logged-in `gh` account with the `gist` scope).

## License

MIT
