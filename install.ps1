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
    ccart  -> run Claude Code on the AgentRouter gateway       (+ ccart-token, ccart-model)
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
$names = @('cckimi','ccglm','ccor','ccart','cckimi-token','ccglm-token','ccor-token','ccor-model',
           'ccart-token','ccart-model','ccskip','cxskip')
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
    Write-Host "OK  cckimi / ccglm / ccor / ccart / ccskip / cxskip removed from $aliasDir (and User PATH)." -ForegroundColor Green
    Write-Host "note: the cached token/model files (.kimi_token, .zai_token, .openrouter_token,"
    Write-Host "      .agentrouter_token and the matching *_model files) were left untouched, and"
    Write-Host "      Claude Code itself is not uninstalled."
    return
}

# These launchers run Claude Code with --dangerously-skip-permissions. Confirm once, at install.
if (-not $Yes) {
    if (-not [Environment]::UserInteractive) {
        Write-Host "Non-interactive session; re-run with -Yes to confirm the skip-permissions install." -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "WARNING (DANGEROUS MODE): cckimi / ccglm / ccor / ccart / ccskip / cxskip run Claude Code with" -ForegroundColor Yellow
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
set "chosen="
if not "%~1"=="" set "chosen=%~1"
if not "%chosen%"=="" goto :save
set "current="
if exist "%MODELFILE%" set /p current=<"%MODELFILE%"
echo ccor-model - pick a model:
if "%current%"=="stealth/ox-alpha" (echo    1. stealth/ox-alpha   [current]) else (echo    1. stealth/ox-alpha)
if "%current%"=="anthropic/claude-opus-4.8" (echo    2. anthropic/claude-opus-4.8   [current]) else (echo    2. anthropic/claude-opus-4.8)
if "%current%"=="anthropic/claude-sonnet-5" (echo    3. anthropic/claude-sonnet-5   [current]) else (echo    3. anthropic/claude-sonnet-5)
if "%current%"=="anthropic/claude-haiku-4.5" (echo    4. anthropic/claude-haiku-4.5   [current]) else (echo    4. anthropic/claude-haiku-4.5)
if "%current%"=="x-ai/grok-4.20" (echo    5. x-ai/grok-4.20   [current]) else (echo    5. x-ai/grok-4.20)
if "%current%"=="openai/gpt-5.6-sol" (echo    6. openai/gpt-5.6-sol   [current]) else (echo    6. openai/gpt-5.6-sol)
if "%current%"=="google/gemini-3.1-pro-preview" (echo    7. google/gemini-3.1-pro-preview   [current]) else (echo    7. google/gemini-3.1-pro-preview)
if "%current%"=="deepseek/deepseek-v4-pro" (echo    8. deepseek/deepseek-v4-pro   [current]) else (echo    8. deepseek/deepseek-v4-pro)
if "%current%"=="moonshotai/kimi-k3" (echo    9. moonshotai/kimi-k3   [current]) else (echo    9. moonshotai/kimi-k3)
if "%current%"=="z-ai/glm-5" (echo    10. z-ai/glm-5   [current]) else (echo    10. z-ai/glm-5)
echo     0. type a different id by hand
set /p pick=choice [1-10, 0]: 
if "%pick%"=="1" set "chosen=stealth/ox-alpha"
if "%pick%"=="2" set "chosen=anthropic/claude-opus-4.8"
if "%pick%"=="3" set "chosen=anthropic/claude-sonnet-5"
if "%pick%"=="4" set "chosen=anthropic/claude-haiku-4.5"
if "%pick%"=="5" set "chosen=x-ai/grok-4.20"
if "%pick%"=="6" set "chosen=openai/gpt-5.6-sol"
if "%pick%"=="7" set "chosen=google/gemini-3.1-pro-preview"
if "%pick%"=="8" set "chosen=deepseek/deepseek-v4-pro"
if "%pick%"=="9" set "chosen=moonshotai/kimi-k3"
if "%pick%"=="10" set "chosen=z-ai/glm-5"
if "%pick%"=="0" set /p chosen=model id: 
:save
if "%chosen%"=="" (
    echo ccor-model: nothing picked, %MODELFILE% left unchanged.
    exit /b 1
)
>"%MODELFILE%" echo %chosen%
echo ccor-model: model set to %chosen% (%MODELFILE%).
echo echo More ids: https://openrouter.ai/models
'@
$cmds['ccart'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.agentrouter_token"
set "MODELFILE=%USERPROFILE%\.agentrouter_model"
set "token="
if exist "%TOKENFILE%" set /p token=<"%TOKENFILE%"
if not "%token%"=="" goto :run
set /p token=ccart: no API key found. Enter your AgentRouter API key:
if "%token%"=="" (
    echo ccart: no key entered, aborting.
    exit /b 1
)
>"%TOKENFILE%" echo %token%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccart: key saved to %TOKENFILE% (current-user only).
:run
rem ---- Models: leave these EMPTY to follow ccart-model / the default below ---------
rem AgentRouter serves a short list - claude-opus-5, claude-opus-4-8, gpt-5.6-sol,
rem deepseek-v4f. Fill one in only to pin that tier here.
set "AR_MODEL="
set "AR_SONNET_MODEL="
set "AR_HAIKU_MODEL="
set "AR_FABLE_MODEL="
set "AR_SUBAGENT_MODEL="
set "AR_DEFAULT_MODEL=claude-opus-5"
rem ---------------------------------------------------------------------------------
rem Resolution order for the main model: pinned above -> .agentrouter_model -> default.
if "%AR_MODEL%"=="" if exist "%MODELFILE%" set /p AR_MODEL=<"%MODELFILE%"
if "%AR_MODEL%"=="" (
    set "AR_MODEL=%AR_DEFAULT_MODEL%"
    echo ccart: no model set, falling back to %AR_DEFAULT_MODEL% -- change it with: ccart-model your-model-id
)
if "%AR_SONNET_MODEL%"=="" set "AR_SONNET_MODEL=%AR_MODEL%"
if "%AR_HAIKU_MODEL%"=="" set "AR_HAIKU_MODEL=%AR_MODEL%"
if "%AR_FABLE_MODEL%"=="" set "AR_FABLE_MODEL=%AR_MODEL%"
if "%AR_SUBAGENT_MODEL%"=="" set "AR_SUBAGENT_MODEL=%AR_MODEL%"
set "ANTHROPIC_BASE_URL=https://agentrouter.org"
set "ANTHROPIC_AUTH_TOKEN=%token%"
rem ANTHROPIC_API_KEY is blanked so the gateway only ever sees the Bearer token:
rem Claude Code sends ANTHROPIC_API_KEY as x-api-key, a direct-Anthropic credential.
set "ANTHROPIC_API_KEY="
set "ANTHROPIC_MODEL=%AR_MODEL%"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=%AR_MODEL%"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=%AR_SONNET_MODEL%"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=%AR_HAIKU_MODEL%"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=%AR_FABLE_MODEL%"
set "CLAUDE_CODE_SUBAGENT_MODEL=%AR_SUBAGENT_MODEL%"
set "API_TIMEOUT_MS=3000000"
call claude --dangerously-skip-permissions %*
'@
$cmds['ccart-token'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.agentrouter_token"
set "key=%~1"
if "%key%"=="" set /p key=ccart-token - paste API key:
if "%key%"=="" (
    echo ccart-token: no key given.
    exit /b 1
)
>"%TOKENFILE%" echo %key%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccart-token: key written to %TOKENFILE% (current-user only).
'@
$cmds['ccart-model'] = @'
@echo off
setlocal
set "MODELFILE=%USERPROFILE%\.agentrouter_model"
set "chosen="
if not "%~1"=="" set "chosen=%~1"
if not "%chosen%"=="" goto :save
set "current="
if exist "%MODELFILE%" set /p current=<"%MODELFILE%"
echo ccart-model - pick a model:
if "%current%"=="claude-opus-5" (echo    1. claude-opus-5   [current]) else (echo    1. claude-opus-5)
if "%current%"=="claude-opus-4-8" (echo    2. claude-opus-4-8   [current]) else (echo    2. claude-opus-4-8)
if "%current%"=="gpt-5.6-sol" (echo    3. gpt-5.6-sol   [current]) else (echo    3. gpt-5.6-sol)
if "%current%"=="deepseek-v4f" (echo    4. deepseek-v4f   [current]) else (echo    4. deepseek-v4f)
echo     0. type a different id by hand
set /p pick=choice [1-4, 0]: 
if "%pick%"=="1" set "chosen=claude-opus-5"
if "%pick%"=="2" set "chosen=claude-opus-4-8"
if "%pick%"=="3" set "chosen=gpt-5.6-sol"
if "%pick%"=="4" set "chosen=deepseek-v4f"
if "%pick%"=="0" set /p chosen=model id: 
:save
if "%chosen%"=="" (
    echo ccart-model: nothing picked, %MODELFILE% left unchanged.
    exit /b 1
)
>"%MODELFILE%" echo %chosen%
echo ccart-model: model set to %chosen% (%MODELFILE%).
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
Write-Host "commands: cckimi (+cckimi-token)   ccglm (+ccglm-token)"
Write-Host "          ccor (+ccor-token, ccor-model)   ccart (+ccart-token, ccart-model)"
Write-Host "          ccskip   cxskip"
Write-Host ""
Write-Host "Ready in THIS PowerShell session now (the alias folder was added to the current PATH)." -ForegroundColor Green
Write-Host "Open a new window only for cmd.exe / other shells to pick up the persisted PATH."
Write-Host "First run of a backend launcher asks for its API key and caches it in %USERPROFILE%\.kimi_token"
Write-Host "/ .zai_token / .openrouter_token / .agentrouter_token; update later with cckimi-token /"
Write-Host "ccglm-token / ccor-token / ccart-token."
Write-Host ""
Write-Host "ccor defaults to the free stealth/ox-alpha model, ccart to claude-opus-5." -ForegroundColor Yellow
Write-Host "Run ccor-model / ccart-model with no argument to pick another from a numbered list."
Write-Host ""
if ($claudeOk) {
    Write-Host "OK  Claude Code: $((Get-Command claude).Source)" -ForegroundColor Green
} else {
    Write-Host "WARNING: Claude Code is still not on PATH - install it manually:" -ForegroundColor Yellow
    Write-Host "         https://claude.com/claude-code"
}
