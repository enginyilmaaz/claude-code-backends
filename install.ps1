#requires -Version 5
<#
  claude-code-backends - installer (Windows)
  Repo: https://github.com/enginyilmaaz/claude-code-backends

  Installs three Claude Code backend launchers as standalone .cmd commands under
  %USERPROFILE%\apps\aliases and adds that folder to the User PATH, so they work
  from ANY shell (cmd, PowerShell, Run):
    cckimi -> run Claude Code on the Kimi (Moonshot) backend   (+ cckimi-token)
    ccglm  -> run Claude Code on the Z.AI GLM backend          (+ ccglm-token)
    ccort   -> run Claude Code on the OpenRouter gateway        (+ ccort-token, ccort-model)
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
$names = @('cckimi','ccglm','ccort','ccart','cckimi-token','ccglm-token','ccort-token','ccort-model',
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


# ------------------------------------------------------------------ catalogue ---
# Order shown in the picker; Cmds is everything the entry installs.
$catalogue = @(
    @{ Key='ccskip'; Label='ccskip / cxskip   your Anthropic login, skip-permissions'; Cmds=@('ccskip','cxskip') }
    @{ Key='cckimi'; Label='cckimi            Kimi (Moonshot) backend';                Cmds=@('cckimi','cckimi-token') }
    @{ Key='ccglm';  Label='ccglm             Z.AI GLM backend';                       Cmds=@('ccglm','ccglm-token') }
    @{ Key='ccort';  Label='ccort             OpenRouter gateway (stealth/ox-alpha)';  Cmds=@('ccort','ccort-token','ccort-model') }
    @{ Key='ccart';  Label='ccart             AgentRouter gateway (claude-opus-5)';    Cmds=@('ccart','ccart-token','ccart-model') }
)
# Shims from earlier versions, deleted on every confirmed run without asking: the ccor
# family was renamed to ccort, claude-skip/codex-skip are long gone.
$deprecated = @('ccor','ccor-token','ccor-model','claude-skip','codex-skip')

function Test-CmdInstalled([string]$name) { Test-Path -LiteralPath (Join-Path $aliasDir "$name.cmd") }

# Numbered checkbox picker: SPACE toggles, arrows move, ENTER confirms, q cancels.
# Returns the chosen keys, or $null when cancelled.
function Show-LauncherPicker {
    $sel = @{}; foreach ($e in $catalogue) { $sel[$e.Key] = $true }
    $cur = 0; $first = $true; $n = $catalogue.Count
    while ($true) {
        if ($first) { $first = $false }
        else {
            $top = [Console]::CursorTop - ($n + 3)
            if ($top -lt 0) { $top = 0 }
            [Console]::SetCursorPosition(0, $top)
        }
        Write-Host "  Select the launchers to install:                                        "
        for ($i = 0; $i -lt $n; $i++) {
            $e = $catalogue[$i]
            $box = if ($sel[$e.Key]) { '[x]' } else { '[ ]' }
            $ptr = if ($i -eq $cur) { '>' } else { ' ' }
            $mark = if (Test-CmdInstalled $e.Key) { '  installed' } else { '' }
            Write-Host (" {0} {1} {2}{3}          " -f $ptr, $box, $e.Label, $mark)
        }
        Write-Host "                                                                          "
        Write-Host "  SPACE toggle - up/down move - a all - n none - ENTER confirm - q cancel  "
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'Spacebar'   { $sel[$catalogue[$cur].Key] = -not $sel[$catalogue[$cur].Key] }
            'UpArrow'    { if ($cur -gt 0) { $cur-- } else { $cur = $n - 1 } }
            'DownArrow'  { $cur = ($cur + 1) % $n }
            'Enter'      { return @($catalogue | Where-Object { $sel[$_.Key] } | ForEach-Object { $_.Key }) }
            default {
                switch ($k.KeyChar) {
                    'a' { foreach ($e in $catalogue) { $sel[$e.Key] = $true } }
                    'n' { foreach ($e in $catalogue) { $sel[$e.Key] = $false } }
                    'q' { return $null }
                }
            }
        }
    }
}

if ($Uninstall) {
    foreach ($n in ($names + $deprecated)) {
        Remove-Item -LiteralPath (Join-Path $aliasDir "$n.cmd") -Force -ErrorAction SilentlyContinue
    }
    Remove-AliasDirFromUserPath $aliasDir
    Write-Host "OK  cckimi / ccglm / ccort / ccart / ccskip / cxskip removed from $aliasDir (and User PATH)." -ForegroundColor Green
    Write-Host "note: the cached token/model files (.kimi_token, .zai_token, .openrouter_token,"
    Write-Host "      .agentrouter_token and the matching *_model files) were left untouched, and"
    Write-Host "      Claude Code itself is not uninstalled."
    return
}

# Pick the launchers, then review what will be written, overwritten and removed.
$chosen = @($catalogue | ForEach-Object { $_.Key })
$staleFound = @($deprecated | Where-Object { Test-CmdInstalled $_ })

if (-not $Yes) {
    if (-not [Environment]::UserInteractive) {
        Write-Host "Non-interactive session; re-run with -Yes to install everything without the picker." -ForegroundColor Yellow
        return
    }
    Write-Host ""
    $chosen = Show-LauncherPicker
    if ($null -eq $chosen) { Write-Host "`nCancelled - nothing was changed."; return }

    $over = @($chosen | Where-Object { Test-CmdInstalled $_ })
    Write-Host ""
    Write-Host "  Review" -ForegroundColor Cyan
    if ($chosen.Count -gt 0) {
        Write-Host ("    install    : " + ($chosen -join ' '))
        foreach ($k in $chosen) {
            Write-Host ("                 " + (($catalogue | Where-Object { $_.Key -eq $k }).Cmds -join ' '))
        }
    } else {
        Write-Host "    install    : (nothing selected)"
    }
    if ($over.Count -gt 0)       { Write-Host ("    overwrite  : " + ($over -join ' ') + "  (already installed)") -ForegroundColor Yellow }
    if ($staleFound.Count -gt 0) { Write-Host ("    remove     : " + ($staleFound -join ' ') + "  (deprecated)") -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "    these launchers run Claude Code with --dangerously-skip-permissions -" -ForegroundColor Yellow
    Write-Host "    it runs commands and edits files WITHOUT asking. Use only in trusted folders."
    Write-Host ""
    Write-Host "      1) Confirm"
    Write-Host "      2) Cancel"
    $ans = Read-Host "    choice [1/2]"
    if ($ans -notmatch '^\s*(1|y|yes)\s*$') { Write-Host "    Cancelled - nothing was changed."; return }
}

if ($chosen.Count -eq 0) { Write-Host "Nothing selected - nothing was changed."; return }

New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null

# Deprecated shims go without asking, now that the run is confirmed.
foreach ($d in $deprecated) {
    Remove-Item -LiteralPath (Join-Path $aliasDir "$d.cmd") -Force -ErrorAction SilentlyContinue
}

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
$cmds['ccort'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.openrouter_token"
set "MODELFILE=%USERPROFILE%\.openrouter_model"
set "token="
if exist "%TOKENFILE%" set /p token=<"%TOKENFILE%"
if not "%token%"=="" goto :run
set /p token=ccort: no API key found. Enter your OpenRouter API key:
if "%token%"=="" (
    echo ccort: no key entered, aborting.
    exit /b 1
)
>"%TOKENFILE%" echo %token%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccort: key saved to %TOKENFILE% (current-user only).
:run
rem ---- Models: leave these EMPTY to follow ccort-model / the default below ----------
rem Fill one in only to pin that tier here, e.g. set "OR_HAIKU_MODEL=z-ai/glm-4.7-flash".
rem Model ids come from https://openrouter.ai/models. Append [1m] to an id whose
rem context window is 1M - without it Claude Code assumes 200k and compacts early.
set "OR_MODEL="
set "OR_SONNET_MODEL="
set "OR_HAIKU_MODEL="
set "OR_FABLE_MODEL="
set "OR_SUBAGENT_MODEL="
set "OR_DEFAULT_MODEL=stealth/ox-alpha[1m]"
rem ---------------------------------------------------------------------------------
rem Resolution order for the main model: pinned above -> .openrouter_model -> default.
if "%OR_MODEL%"=="" if exist "%MODELFILE%" set /p OR_MODEL=<"%MODELFILE%"
if "%OR_MODEL%"=="" (
    rem Adopt the default once and record it, so this notice shows on the FIRST run only.
    set "OR_MODEL=%OR_DEFAULT_MODEL%"
    >"%MODELFILE%" echo %OR_DEFAULT_MODEL%
    echo ccort: no model set -- adopting the default %OR_DEFAULT_MODEL%, saved to %MODELFILE%.
    echo        pick another any time with: ccort-model
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
$cmds['ccort-token'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.openrouter_token"
set "key=%~1"
if "%key%"=="" set /p key=ccort-token - paste API key:
if "%key%"=="" (
    echo ccort-token: no key given.
    exit /b 1
)
>"%TOKENFILE%" echo %key%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccort-token: key written to %TOKENFILE% (current-user only).
'@
$cmds['ccort-model'] = @'
@echo off
setlocal
set "MODELFILE=%USERPROFILE%\.openrouter_model"
set "chosen="
if not "%~1"=="" set "chosen=%~1"
if not "%chosen%"=="" goto :save
set "current="
if exist "%MODELFILE%" set /p current=<"%MODELFILE%"
echo ccort-model - pick a model:
if "%current%"=="stealth/ox-alpha[1m]" (echo    1. stealth/ox-alpha[1m]   [current]) else (echo    1. stealth/ox-alpha[1m])
if "%current%"=="anthropic/claude-opus-4.8[1m]" (echo    2. anthropic/claude-opus-4.8[1m]   [current]) else (echo    2. anthropic/claude-opus-4.8[1m])
if "%current%"=="anthropic/claude-sonnet-5[1m]" (echo    3. anthropic/claude-sonnet-5[1m]   [current]) else (echo    3. anthropic/claude-sonnet-5[1m])
if "%current%"=="anthropic/claude-haiku-4.5" (echo    4. anthropic/claude-haiku-4.5   [current]) else (echo    4. anthropic/claude-haiku-4.5)
if "%current%"=="x-ai/grok-4.20[1m]" (echo    5. x-ai/grok-4.20[1m]   [current]) else (echo    5. x-ai/grok-4.20[1m])
if "%current%"=="openai/gpt-5.6-sol[1m]" (echo    6. openai/gpt-5.6-sol[1m]   [current]) else (echo    6. openai/gpt-5.6-sol[1m])
if "%current%"=="google/gemini-3.1-pro-preview[1m]" (echo    7. google/gemini-3.1-pro-preview[1m]   [current]) else (echo    7. google/gemini-3.1-pro-preview[1m])
if "%current%"=="deepseek/deepseek-v4-pro[1m]" (echo    8. deepseek/deepseek-v4-pro[1m]   [current]) else (echo    8. deepseek/deepseek-v4-pro[1m])
if "%current%"=="moonshotai/kimi-k3[1m]" (echo    9. moonshotai/kimi-k3[1m]   [current]) else (echo    9. moonshotai/kimi-k3[1m])
if "%current%"=="z-ai/glm-5" (echo    10. z-ai/glm-5   [current]) else (echo    10. z-ai/glm-5)
echo     0. type a different id by hand
set /p pick=choice [1-10, 0]: 
if "%pick%"=="1" set "chosen=stealth/ox-alpha[1m]"
if "%pick%"=="2" set "chosen=anthropic/claude-opus-4.8[1m]"
if "%pick%"=="3" set "chosen=anthropic/claude-sonnet-5[1m]"
if "%pick%"=="4" set "chosen=anthropic/claude-haiku-4.5"
if "%pick%"=="5" set "chosen=x-ai/grok-4.20[1m]"
if "%pick%"=="6" set "chosen=openai/gpt-5.6-sol[1m]"
if "%pick%"=="7" set "chosen=google/gemini-3.1-pro-preview[1m]"
if "%pick%"=="8" set "chosen=deepseek/deepseek-v4-pro[1m]"
if "%pick%"=="9" set "chosen=moonshotai/kimi-k3[1m]"
if "%pick%"=="10" set "chosen=z-ai/glm-5"
if "%pick%"=="0" set /p chosen=model id: 
:save
if "%chosen%"=="" (
    echo ccort-model: nothing picked, %MODELFILE% left unchanged.
    exit /b 1
)
>"%MODELFILE%" echo %chosen%
echo ccort-model: model set to %chosen% (%MODELFILE%).
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
    rem Adopt the default once and record it, so this notice shows on the FIRST run only.
    set "AR_MODEL=%AR_DEFAULT_MODEL%"
    >"%MODELFILE%" echo %AR_DEFAULT_MODEL%
    echo ccart: no model set -- adopting the default %AR_DEFAULT_MODEL%, saved to %MODELFILE%.
    echo        pick another any time with: ccart-model
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
if "%current%"=="gpt-5.6-sol[1m]" (echo    3. gpt-5.6-sol[1m]   [current]) else (echo    3. gpt-5.6-sol[1m])
if "%current%"=="deepseek-v4f[1m]" (echo    4. deepseek-v4f[1m]   [current]) else (echo    4. deepseek-v4f[1m])
echo     0. type a different id by hand
set /p pick=choice [1-4, 0]: 
if "%pick%"=="1" set "chosen=claude-opus-5"
if "%pick%"=="2" set "chosen=claude-opus-4-8"
if "%pick%"=="3" set "chosen=gpt-5.6-sol[1m]"
if "%pick%"=="4" set "chosen=deepseek-v4f[1m]"
if "%pick%"=="0" set /p chosen=model id: 
:save
if "%chosen%"=="" (
    echo ccart-model: nothing picked, %MODELFILE% left unchanged.
    exit /b 1
)
>"%MODELFILE%" echo %chosen%
echo ccart-model: model set to %chosen% (%MODELFILE%).
'@

$wanted = @()
foreach ($k in $chosen) { $wanted += ($catalogue | Where-Object { $_.Key -eq $k }).Cmds }
foreach ($name in $cmds.Keys) {
    if ($wanted -notcontains $name) { continue }
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
Write-Host "installed:"
foreach ($k in $chosen) {
    Write-Host ("  " + (($catalogue | Where-Object { $_.Key -eq $k }).Cmds -join '   '))
}
if ($staleFound.Count -gt 0) { Write-Host ""; Write-Host ("removed (deprecated): " + ($staleFound -join ' ')) }
Write-Host ""
Write-Host "Ready in THIS PowerShell session now (the alias folder was added to the current PATH)." -ForegroundColor Green
Write-Host "Open a new window only for cmd.exe / other shells to pick up the persisted PATH."
Write-Host "First run of a backend launcher asks for its API key and caches it in %USERPROFILE%\.kimi_token"
Write-Host "/ .zai_token / .openrouter_token / .agentrouter_token; update later with cckimi-token /"
Write-Host "ccglm-token / ccort-token / ccart-token."
Write-Host ""
Write-Host "ccort defaults to the free stealth/ox-alpha model, ccart to claude-opus-5." -ForegroundColor Yellow
Write-Host "Run ccort-model / ccart-model with no argument to pick another from a numbered list."
Write-Host ""
if ($claudeOk) {
    Write-Host "OK  Claude Code: $((Get-Command claude).Source)" -ForegroundColor Green
} else {
    Write-Host "WARNING: Claude Code is still not on PATH - install it manually:" -ForegroundColor Yellow
    Write-Host "         https://claude.com/claude-code"
}
