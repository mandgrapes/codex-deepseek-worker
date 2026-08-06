[CmdletBinding()]
param(
    [string]$Repository = "mandgrapes/codex-deepseek-worker",
    [string]$Ref = "main",
    [string]$InstallDirectory = (Join-Path $env:USERPROFILE ".codex\provider-switch"),
    [string]$ProfilePath = $PROFILE.CurrentUserAllHosts,
    [string]$LauncherSource,
    [switch]$SkipLegacyCleanup
)

$ErrorActionPreference = "Stop"
$RawBase = "https://raw.githubusercontent.com/$Repository/$Ref"
$LauncherUrl = "$RawBase/codex-provider-switch.ps1"
$InstallerUrl = "$RawBase/install.ps1"
$InstalledLauncher = Join-Path $InstallDirectory "codex-provider-switch.ps1"
$BlockStart = "# >>> dsbro shared-home launcher >>>"
$BlockEnd = "# <<< dsbro shared-home launcher <<<"

if ($null -eq (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI is not available. Install Codex before installing dsbro."
}

function Read-RemoteText {
    param([Parameter(Mandatory = $true)][string]$Url)

    $content = (Invoke-WebRequest -UseBasicParsing $Url).Content
    if ($content -is [byte[]]) {
        return [Text.Encoding]::UTF8.GetString($content)
    }
    return [string]$content
}

function Remove-LegacyConfigSections {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    if (-not (Test-Path -LiteralPath $ConfigPath)) { return }
    $lines = Get-Content -LiteralPath $ConfigPath -Encoding UTF8
    $output = New-Object 'System.Collections.Generic.List[string]'
    $skip = $false
    $removed = 0
    foreach ($line in $lines) {
        if ($line -match '^\[') {
            $target = ($line -eq '[marketplaces.codex-deepseek-worker]') -or
                ($line -match '^\[plugins\."codex-deepseek-worker@codex-deepseek-worker"(?:\.|\])')
            if ($target) {
                $skip = $true
                $removed++
                continue
            }
            $skip = $false
        }
        if (-not $skip) { $output.Add($line) }
    }
    if ($removed -eq 0) { return }

    $backup = "$ConfigPath.before-dsbro-shared-home.bak"
    Copy-Item -LiteralPath $ConfigPath -Destination $backup -Force
    [IO.File]::WriteAllLines($ConfigPath, $output, [Text.UTF8Encoding]::new($false))
    Write-Host "Removed legacy dsbro plugin registration from $ConfigPath" -ForegroundColor Yellow
}

if ([string]::IsNullOrWhiteSpace($LauncherSource)) {
    $localCandidate = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $null
    } else {
        Join-Path $PSScriptRoot "codex-provider-switch.ps1"
    }
    $launcherText = if ($localCandidate -and (Test-Path -LiteralPath $localCandidate)) {
        Get-Content -LiteralPath $localCandidate -Raw -Encoding UTF8
    } else {
        Read-RemoteText -Url $LauncherUrl
    }
} else {
    $launcherText = Get-Content -LiteralPath $LauncherSource -Raw -Encoding UTF8
}

if ($launcherText -notmatch 'deepseek-v4-flash' -or
    $launcherText -notmatch 'model_providers\.deepseek\.env_key') {
    throw "Downloaded launcher failed validation."
}

New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
[IO.File]::WriteAllText($InstalledLauncher, $launcherText, [Text.UTF8Encoding]::new($false))

$profileDirectory = Split-Path -Parent $ProfilePath
New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
$profileText = if (Test-Path -LiteralPath $ProfilePath) {
    Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8
} else {
    ""
}

$escapedLauncher = $InstalledLauncher.Replace("'", "''")
$profileBlock = @"
$BlockStart
function ds { & '$escapedLauncher' -Action deepseek @args }
function gpt { & '$escapedLauncher' -Action openai @args }
function set_ds_key { & '$escapedLauncher' -Action set-key }
function update_ds {
    irm '$InstallerUrl' | iex
    & '$escapedLauncher' -Action update
}
$BlockEnd
"@

$oldBlockPattern = '(?s)# >>> Codex DeepSeek provider switch >>>.*?# <<< Codex DeepSeek provider switch <<<'
$profileText = [regex]::Replace($profileText, $oldBlockPattern, '').TrimEnd()
$pattern = "(?s)" + [regex]::Escape($BlockStart) + ".*?" + [regex]::Escape($BlockEnd)
if ($profileText -match $pattern) {
    $profileText = [regex]::Replace($profileText, $pattern, $profileBlock)
} else {
    if ($profileText.Length -gt 0) { $profileText += "`r`n`r`n" }
    $profileText += $profileBlock
}
[IO.File]::WriteAllText($ProfilePath, $profileText + "`r`n", [Text.UTF8Encoding]::new($false))

if (-not $SkipLegacyCleanup) {
    $mainCodexHome = Join-Path $env:USERPROFILE ".codex"
    Remove-LegacyConfigSections -ConfigPath (Join-Path $mainCodexHome "config.toml")
    Remove-LegacyConfigSections -ConfigPath (Join-Path $env:USERPROFILE ".codex-deepseek\config.toml")

    $legacyInstall = Join-Path $env:LOCALAPPDATA "Codex\marketplaces\codex-deepseek-worker"
    if (Test-Path -LiteralPath $legacyInstall) {
        $resolvedLegacyInstall = (Resolve-Path -LiteralPath $legacyInstall).Path
        if ($resolvedLegacyInstall -ne $legacyInstall) {
            throw "Refusing to remove unexpected path: $resolvedLegacyInstall"
        }
        Remove-Item -LiteralPath $resolvedLegacyInstall -Recurse -Force
    }
    $legacyCatalog = Join-Path $mainCodexHome "dsbro-models.json"
    if (Test-Path -LiteralPath $legacyCatalog) {
        Remove-Item -LiteralPath $legacyCatalog -Force
    }
}

Write-Host "dsbro installed: ds, gpt, set_ds_key, update_ds" -ForegroundColor Green
Write-Host "Open a new PowerShell window, then run ds."
