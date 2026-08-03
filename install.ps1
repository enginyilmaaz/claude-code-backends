#requires -Version 5
<#
  claude-code-backends - installer (Windows)
  Repo: https://github.com/enginyilmaaz/claude-code-backends

  Installs two Claude Code backend launchers as standalone .cmd commands under
  %USERPROFILE%\apps\aliases and adds that folder to the User PATH, so they work
  from ANY shell (cmd, PowerShell, Run):
    cckimi -> run Claude Code on the Kimi (Moonshot) backend   (+ cckimi-token)
    ccglm  -> run Claude Code on the Z.AI GLM backend          (+ ccglm-token)
  Env vars are scoped via setlocal to each .cmd process, so they never leak into the caller.

  Quick install:
    irm https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.ps1 | iex
  Uninstall:
    & ([scriptblock]::Create((irm https://gist.githubusercontent.com/enginyilmaaz/2b903923ea111f741ca50a878ee9d2f8/raw/install.ps1))) -Uninstall
#>
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$aliasDir = Join-Path $env:USERPROFILE 'apps\aliases'
$names = @('cckimi','ccglm','cckimi-token','ccglm-token')

function Remove-AliasDirFromUserPath([string]$dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path','User'); if (-not $userPath) { return }
    $parts = $userPath -split ';' | Where-Object { $_ -and $_ -ne $dir }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

if ($Uninstall) {
    foreach ($n in $names) {
        Remove-Item -LiteralPath (Join-Path $aliasDir "$n.cmd") -Force -ErrorAction SilentlyContinue
    }
    Remove-AliasDirFromUserPath $aliasDir
    Write-Host "OK  cckimi / ccglm removed from $aliasDir (and User PATH)." -ForegroundColor Green
    Write-Host "note: token files %USERPROFILE%\.kimi_token and %USERPROFILE%\.zai_token were left untouched."
    return
}

New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null

$cmds = [ordered]@{}
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
set "ANTHROPIC_MODEL=glm-5.2[1m]"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.2[1m]"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.6"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=glm-4.7-flashx"
set "CLAUDE_CODE_SUBAGENT_MODEL=glm-5.2[1m]"
set "CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
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

foreach ($name in $cmds.Keys) {
    # force CRLF + ASCII (no BOM) so cmd.exe handles labels/goto correctly
    $body = ($cmds[$name] -replace "`r`n", "`n") -replace "`n", "`r`n"
    if (-not $body.EndsWith("`r`n")) { $body += "`r`n" }
    [System.IO.File]::WriteAllText((Join-Path $aliasDir "$name.cmd"), $body, [System.Text.Encoding]::ASCII)
}

# Add the aliases folder to the User PATH (persisted) + the current session.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); if (-not $userPath) { $userPath = '' }
if (($userPath -split ';') -notcontains $aliasDir) {
    $trimmed = $userPath.TrimEnd(';')
    $newPath = if ($trimmed) { $trimmed + ';' + $aliasDir } else { $aliasDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}
$cur = [string]$env:Path
if (($cur -split ';') -notcontains $aliasDir) { $env:Path = ($cur.TrimEnd(';') + ';' + $aliasDir).TrimStart(';') }

Write-Host ""
Write-Host "OK  claude-code-backends installed -> $aliasDir (added to PATH)" -ForegroundColor Green
Write-Host ""
Write-Host "commands: cckimi (+cckimi-token)   ccglm (+ccglm-token)"
Write-Host ""
Write-Host "Ready in THIS PowerShell session now (the alias folder was added to the current PATH)." -ForegroundColor Green
Write-Host "Open a new window only for cmd.exe / other shells to pick up the persisted PATH."
Write-Host "First run of cckimi/ccglm asks for the backend API key and caches it in"
Write-Host "%USERPROFILE%\.kimi_token / .zai_token; update later with cckimi-token / ccglm-token."
Write-Host "Requires Claude Code installed."
