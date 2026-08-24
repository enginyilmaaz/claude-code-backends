#requires -Version 5
<#
  claude-code-backends - installer (Windows)
  Repo: https://github.com/enginyilmaaz/claude-code-backends

  Installs three Claude Code backend launchers as standalone .cmd commands under
  %USERPROFILE%\apps\aliases and adds that folder to the User PATH, so they work
  from ANY shell (cmd, PowerShell, Run):
    cckimi -> run Claude Code on the Kimi (Moonshot) backend   (+ cckimi-token)
    ccglm  -> run Claude Code on the Z.AI GLM backend          (+ ccglm-token)
    ccor   -> run Claude Code on the OpenRouter gateway        (+ ccor-token, ccor-model)
  Env vars are scoped via setlocal to each .cmd process, so they never leak into the caller.
  Claude Code itself is installed when missing, and its bin dirs are added to the User PATH.

  Quick install:
    irm https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.ps1 | iex
  Uninstall:
    & ([scriptblock]::Create((irm https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.ps1))) -Uninstall
#>
param([switch]$Uninstall, [switch]$Yes)

$ErrorActionPreference = 'Stop'
$aliasDir = Join-Path $env:USERPROFILE 'apps\aliases'
$names = @('cckimi','ccglm','ccor','cckimi-token','ccglm-token','ccor-token','ccor-model','ccskip','cxskip')
# Where the Claude Code installers put the binary - both go on PATH so 'claude' always resolves.
$claudeBinDirs = @((Join-Path $env:USERPROFILE '.local\bin'), (Join-Path $env:USERPROFILE '.claude\bin'))

function Remove-AliasDirFromUserPath([string]$dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path','User'); if (-not $userPath) { return }
    $parts = $userPath -split ';' | Where-Object { $_ -and $_ -ne $dir }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

# Persist $dir in the User PATH and make it usable in THIS session right away.
function Add-DirToPath([string]$dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); if (-not $userPath) { $userPath = '' }
    if (($userPath -split ';') -notcontains $dir) {
        $trimmed = $userPath.TrimEnd(';')
        $newPath = if ($trimmed) { $trimmed + ';' + $dir } else { $dir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    }
    $cur = [string]$env:Path
    if (($cur -split ';') -notcontains $dir) { $env:Path = ($cur.TrimEnd(';') + ';' + $dir).TrimStart(';') }
}

# Re-read the persisted PATH (an installer that just ran wrote to it) and add the Claude bin dirs.
function Update-ClaudeSessionPath {
    try {
        $merged = @([Environment]::GetEnvironmentVariable('Path','Machine'),
                    [Environment]::GetEnvironmentVariable('Path','User')) | Where-Object { $_ }
        if ($merged) { $env:Path = ($merged -join ';') }
    } catch { }
    foreach ($d in $claudeBinDirs) {
        if ((Test-Path -LiteralPath $d) -and (($env:Path -split ';') -notcontains $d)) { $env:Path = "$d;$env:Path" }
    }
}

function Test-ClaudeInstalled { [bool](Get-Command claude -ErrorAction SilentlyContinue) }

# Install Claude Code when it is missing: native installer first, npm as the fallback.
function Install-ClaudeCode {
    Update-ClaudeSessionPath
    if (Test-ClaudeInstalled) { return $true }
    Write-Host ""
    Write-Host "claude not found - installing Claude Code..." -ForegroundColor Cyan
    try { Invoke-Expression (Invoke-RestMethod -Uri 'https://claude.ai/install.ps1') }
    catch { Write-Host "Native Claude installer failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    Update-ClaudeSessionPath
    if (-not (Test-ClaudeInstalled) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "Falling back to npm..." -ForegroundColor Yellow
        npm install -g '@anthropic-ai/claude-code'
        Update-ClaudeSessionPath
    }
    # Persist whichever bin dir the installer actually used, so new shells find it too.
    foreach ($d in $claudeBinDirs) { if (Test-Path -LiteralPath $d) { Add-DirToPath $d } }
    return (Test-ClaudeInstalled)
}

if ($Uninstall) {
    foreach ($n in $names) {
        Remove-Item -LiteralPath (Join-Path $aliasDir "$n.cmd") -Force -ErrorAction SilentlyContinue
    }
    Remove-AliasDirFromUserPath $aliasDir
    Write-Host "OK  cckimi / ccglm / ccor / ccskip / cxskip removed from $aliasDir (and User PATH)." -ForegroundColor Green
    Write-Host "note: token files %USERPROFILE%\.kimi_token, .zai_token and .openrouter_token were left"
    Write-Host "      untouched, and Claude Code itself is not uninstalled."
    return
}

# These launchers run Claude Code with --dangerously-skip-permissions. Confirm once, at install.
if (-not $Yes) {
    if (-not [Environment]::UserInteractive) {
        Write-Host "Non-interactive session; re-run with -Yes to confirm the skip-permissions install." -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "WARNING (DANGEROUS MODE): cckimi / ccglm / ccor / ccskip / cxskip run Claude Code with" -ForegroundColor Yellow
    Write-Host "--dangerously-skip-permissions - it runs commands and edits files WITHOUT asking. Use only in trusted folders."
    $ans = Read-Host "Install these launchers anyway? [y/N]"
    if ($ans -notmatch '^\s*(y|yes)\s*$') { Write-Host "Aborted - nothing was changed."; return }
}

New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null

$cmds = [ordered]@{}
$cmds['ccskip'] = @'
@echo off
call claude --dangerously-skip-permissions --effort max --model claude-opus-5 %*
'@
$cmds['cxskip'] = @'
@echo off
call claude --dangerously-skip-permissions --effort max --model claude-opus-5 %*
'@
$cmds['cckimi'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.kimi_token"
set "token="
if exist "%TOKENFILE%" set /p token=<"%TOKENFILE%"
if not "%token%"=="" goto :run
set /p token=cckimi: no API key found. Enter your Kimi API key:
if "%token%"=="" (
    echo cckimi: no key entered, aborting.
    exit /b 1
)
>"%TOKENFILE%" echo %token%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo cckimi: key saved to %TOKENFILE% (current-user only).
:run
set "ANTHROPIC_BASE_URL=https://api.kimi.com/coding/"
set "ANTHROPIC_AUTH_TOKEN=%token%"
set "ANTHROPIC_MODEL=kimi-k3[1m]"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=kimi-k3[1m]"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=kimi-k2.7-code"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=kimi-k2.7-code"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=kimi-k2.7-code-highspeed"
set "CLAUDE_CODE_SUBAGENT_MODEL=kimi-k3[1m]"
set "ENABLE_TOOL_SEARCH=false"
set "CLAUDE_CODE_AUTO_COMPACT_WINDOW=1048576"
set "CLAUDE_CODE_EFFORT_LEVEL=max"
call claude --dangerously-skip-permissions --effort max %*
'@
$cmds['ccglm'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.zai_token"
set "token="
if exist "%TOKENFILE%" set /p token=<"%TOKENFILE%"
if not "%token%"=="" goto :run
set /p token=ccglm: no API key found. Enter your Z.AI API key:
if "%token%"=="" (
    echo ccglm: no key entered, aborting.
    exit /b 1
)
>"%TOKENFILE%" echo %token%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccglm: key saved to %TOKENFILE% (current-user only).
:run
set "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic"
set "ANTHROPIC_AUTH_TOKEN=%token%"
set "ANTHROPIC_MODEL=glm-5.3[1m]"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.3[1m]"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.6"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=glm-4.7-flashx"
set "CLAUDE_CODE_SUBAGENT_MODEL=glm-5.3[1m]"
set "CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
set "API_TIMEOUT_MS=3000000"
call claude --dangerously-skip-permissions %*
'@
$cmds['ccor'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.openrouter_token"
set "MODELFILE=%USERPROFILE%\.openrouter_model"
set "token="
if exist "%TOKENFILE%" set /p token=<"%TOKENFILE%"
if not "%token%"=="" goto :run
set /p token=ccor: no API key found. Enter your OpenRouter API key:
if "%token%"=="" (
    echo ccor: no key entered, aborting.
    exit /b 1
)
>"%TOKENFILE%" echo %token%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccor: key saved to %TOKENFILE% (current-user only).
:run
rem ---- Models: leave these EMPTY to follow ccor-model / the default below ----------
rem Fill one in only to pin that tier here, e.g. set "OR_HAIKU_MODEL=z-ai/glm-4.7-flash".
rem Model ids come from https://openrouter.ai/models
set "OR_MODEL="
set "OR_SONNET_MODEL="
set "OR_HAIKU_MODEL="
set "OR_FABLE_MODEL="
set "OR_SUBAGENT_MODEL="
set "OR_DEFAULT_MODEL=stealth/ox-alpha"
rem ---------------------------------------------------------------------------------
rem Resolution order for the main model: pinned above -> .openrouter_model -> default.
if "%OR_MODEL%"=="" if exist "%MODELFILE%" set /p OR_MODEL=<"%MODELFILE%"
if "%OR_MODEL%"=="" (
    set "OR_MODEL=%OR_DEFAULT_MODEL%"
    echo ccor: no model set, falling back to %OR_DEFAULT_MODEL% -- change it with: ccor-model your/model-id
)
if "%OR_SONNET_MODEL%"=="" set "OR_SONNET_MODEL=%OR_MODEL%"
if "%OR_HAIKU_MODEL%"=="" set "OR_HAIKU_MODEL=%OR_MODEL%"
if "%OR_FABLE_MODEL%"=="" set "OR_FABLE_MODEL=%OR_MODEL%"
if "%OR_SUBAGENT_MODEL%"=="" set "OR_SUBAGENT_MODEL=%OR_MODEL%"
set "ANTHROPIC_BASE_URL=https://openrouter.ai/api"
set "ANTHROPIC_AUTH_TOKEN=%token%"
rem ANTHROPIC_API_KEY must stay empty: Claude Code would send it as x-api-key, which
rem OpenRouter treats as a direct-Anthropic credential and the request fails to auth.
set "ANTHROPIC_API_KEY="
set "ANTHROPIC_MODEL=%OR_MODEL%"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=%OR_MODEL%"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=%OR_SONNET_MODEL%"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=%OR_HAIKU_MODEL%"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=%OR_FABLE_MODEL%"
set "CLAUDE_CODE_SUBAGENT_MODEL=%OR_SUBAGENT_MODEL%"
set "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1"
set "CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK=1"
set "API_TIMEOUT_MS=3000000"
call claude --dangerously-skip-permissions %*
'@
$cmds['cckimi-token'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.kimi_token"
set "key=%~1"
if "%key%"=="" set /p key=cckimi-token - paste API key:
if "%key%"=="" (
    echo cckimi-token: no key given.
    exit /b 1
)
>"%TOKENFILE%" echo %key%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo cckimi-token: key written to %TOKENFILE% (current-user only).
'@
$cmds['ccglm-token'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.zai_token"
set "key=%~1"
if "%key%"=="" set /p key=ccglm-token - paste API key:
if "%key%"=="" (
    echo ccglm-token: no key given.
    exit /b 1
)
>"%TOKENFILE%" echo %key%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccglm-token: key written to %TOKENFILE% (current-user only).
'@
$cmds['ccor-token'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.openrouter_token"
set "key=%~1"
if "%key%"=="" set /p key=ccor-token - paste API key:
if "%key%"=="" (
    echo ccor-token: no key given.
    exit /b 1
)
>"%TOKENFILE%" echo %key%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccor-token: key written to %TOKENFILE% (current-user only).
'@
$cmds['ccor-model'] = @'
@echo off
setlocal
set "MODELFILE=%USERPROFILE%\.openrouter_model"
set "id=%~1"
if "%id%"=="" set /p id=ccor-model - paste an OpenRouter model id, browse https://openrouter.ai/models :
if "%id%"=="" (
    echo ccor-model: no id given.
    exit /b 1
)
>"%MODELFILE%" echo %id%
echo ccor-model: model set to %id% (%MODELFILE%).
'@

foreach ($name in $cmds.Keys) {
    # force CRLF + ASCII (no BOM) so cmd.exe handles labels/goto correctly
    $body = ($cmds[$name] -replace "`r`n", "`n") -replace "`n", "`r`n"
    if (-not $body.EndsWith("`r`n")) { $body += "`r`n" }
    [System.IO.File]::WriteAllText((Join-Path $aliasDir "$name.cmd"), $body, [System.Text.Encoding]::ASCII)
}

# Add the aliases folder to the User PATH (persisted) + the current session.
Add-DirToPath $aliasDir

# Claude Code itself - every launcher shells out to it, so install it when it is missing.
$claudeOk = Install-ClaudeCode

Write-Host ""
Write-Host "OK  claude-code-backends installed -> $aliasDir (added to PATH)" -ForegroundColor Green
Write-Host ""
Write-Host "commands: cckimi (+cckimi-token)   ccglm (+ccglm-token)   ccor (+ccor-token, ccor-model)   ccskip   cxskip"
Write-Host ""
Write-Host "Ready in THIS PowerShell session now (the alias folder was added to the current PATH)." -ForegroundColor Green
Write-Host "Open a new window only for cmd.exe / other shells to pick up the persisted PATH."
Write-Host "First run of cckimi/ccglm/ccor asks for the backend API key and caches it in"
Write-Host "%USERPROFILE%\.kimi_token / .zai_token / .openrouter_token; update later with"
Write-Host "cckimi-token / ccglm-token / ccor-token."
Write-Host ""
Write-Host "ccor defaults to the free stealth/ox-alpha model (1M ctx, built for coding)." -ForegroundColor Yellow
Write-Host "Pick another any time with:  ccor-model <id>   - browse https://openrouter.ai/models"
Write-Host ""
if ($claudeOk) {
    Write-Host "OK  Claude Code: $((Get-Command claude).Source)" -ForegroundColor Green
} else {
    Write-Host "WARNING: Claude Code is still not on PATH - install it manually:" -ForegroundColor Yellow
    Write-Host "         https://claude.com/claude-code"
}
