[CmdletBinding()]
param(
    [switch]$ConfigureApiKey,
    [switch]$SkipApiKeyPrompt,
    [string]$Repository = "mandgrapes/codex-deepseek-worker",
    [string]$BaseUrl = "https://api.deepseek.com/",
    [string]$InstallDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "Codex\marketplaces\codex-deepseek-worker")
)

$ErrorActionPreference = "Stop"
$Model = "deepseek-v4-flash"

function ConvertTo-EncodedPowerShellCommand {
    param([Parameter(Mandatory = $true)][string]$Command)
    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
}

function Set-DeepSeekApiKey {
    $secureKey = Read-Host "Enter DeepSeek API Key (input is hidden)" -AsSecureString
    $keyPointer = [IntPtr]::Zero
    $plainKey = $null
    try {
        $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
        if ([string]::IsNullOrWhiteSpace($plainKey)) {
            throw "API Key cannot be empty."
        }
        [Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", $plainKey, "User")
    }
    finally {
        if ($keyPointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
        }
        $plainKey = $null
        $secureKey = $null
    }
    Write-Host "DeepSeek API Key saved to the Windows user environment." -ForegroundColor Green
}

function Ensure-DeepSeekApiKey {
    $key = [Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "User")
    if (-not [string]::IsNullOrWhiteSpace($key)) {
        Write-Host "Existing DeepSeek API Key preserved." -ForegroundColor Green
        return
    }

    $legacyKey = [Environment]::GetEnvironmentVariable("DEEPSEEK_WORKER_API_KEY", "User")
    if (-not [string]::IsNullOrWhiteSpace($legacyKey)) {
        [Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", $legacyKey, "User")
        Write-Host "Existing dsbro API Key migrated without displaying it." -ForegroundColor Green
        $legacyKey = $null
        return
    }

    if ($SkipApiKeyPrompt) {
        Write-Warning "DEEPSEEK_API_KEY is not configured."
        return
    }

    $escapedScriptPath = $PSCommandPath.Replace("'", "''")
    $keyCommand = "& '$escapedScriptPath' -ConfigureApiKey"
    $encoded = ConvertTo-EncodedPowerShellCommand -Command $keyCommand
    $process = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encoded) `
        -Wait -PassThru
    if ($process.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "User"))) {
        throw "DeepSeek API Key configuration did not complete."
    }
}

function Enable-GitCommand {
    if ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) { return }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) { throw "Git is missing and winget is unavailable." }
    & $winget.Source install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "Git installation failed." }
    $gitDirectory = Join-Path $env:ProgramFiles "Git\cmd"
    $gitExecutable = Join-Path $gitDirectory "git.exe"
    if (-not (Test-Path -LiteralPath $gitExecutable)) { throw "Git was installed. Restart Windows and rerun this installer." }
    $env:Path = "$gitDirectory;$env:Path"
}

function Install-Repository {
    Enable-GitCommand
    [IO.Directory]::CreateDirectory((Split-Path -Parent $InstallDirectory)) | Out-Null
    $repositoryUrl = "https://github.com/$Repository.git"

    if (Test-Path -LiteralPath (Join-Path $InstallDirectory ".git")) {
        $origin = [string](& git -C $InstallDirectory remote get-url origin)
        if ($LASTEXITCODE -ne 0) { throw "The installed repository has no readable origin." }
        $normalized = $origin.Trim().TrimEnd('/').ToLowerInvariant()
        $allowed = @(
            $repositoryUrl.ToLowerInvariant(),
            $repositoryUrl.Substring(0, $repositoryUrl.Length - 4).ToLowerInvariant(),
            "git@github.com:$Repository.git".ToLowerInvariant()
        )
        if ($normalized -notin $allowed) { throw "Install directory belongs to another repository: $InstallDirectory" }
        & git -C $InstallDirectory pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "Updating dsbro failed." }
    }
    elseif (Test-Path -LiteralPath $InstallDirectory) {
        throw "Install directory exists but is not a Git repository: $InstallDirectory"
    }
    else {
        & git clone $repositoryUrl $InstallDirectory
        if ($LASTEXITCODE -ne 0) { throw "Downloading dsbro failed." }
    }
}

function Install-NativeCodexConfiguration {
    $codexDirectory = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex"
    } else {
        $env:CODEX_HOME
    }
    [IO.Directory]::CreateDirectory($codexDirectory) | Out-Null

    $assetDirectory = Join-Path $InstallDirectory "codex-deepseek-worker\assets"
    $catalogSource = Join-Path $assetDirectory "dsbro-models.json"
    if (-not (Test-Path -LiteralPath $catalogSource)) { throw "dsbro model catalog is missing: $catalogSource" }

    $catalogDestination = Join-Path $codexDirectory "dsbro-models.json"
    Copy-Item -LiteralPath $catalogSource -Destination $catalogDestination -Force
    Get-Content -LiteralPath $catalogDestination -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null

    $configPath = Join-Path $codexDirectory "config.toml"
    $config = if (Test-Path -LiteralPath $configPath) { Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 } else { "" }
    if ($null -eq $config) { $config = "" }

    $newConfig = [regex]::Replace($config, '(?ms)^\s*# dsbro-provider:start\s*$.*?^\s*# dsbro-provider:end\s*\r?\n?', '').TrimEnd() + "`r`n"

    if ((Test-Path -LiteralPath $configPath) -and $newConfig -ne $config) {
        $backupDirectory = Join-Path $codexDirectory "backup-dsbro"
        [IO.Directory]::CreateDirectory($backupDirectory) | Out-Null
        $backupName = "config-{0}.toml" -f (Get-Date -Format "yyyyMMdd-HHmmss")
        Copy-Item -LiteralPath $configPath -Destination (Join-Path $backupDirectory $backupName)
    }
    if ($newConfig -ne $config) {
        [IO.File]::WriteAllText($configPath, $newConfig, [Text.UTF8Encoding]::new($false))
    }
    Write-Host "DeepSeek worker metadata configured; the main Codex configuration was preserved." -ForegroundColor Green
}

function Install-CodexPlugin {
    $codex = Get-Command codex -ErrorAction SilentlyContinue
    if ($null -eq $codex) { throw "Codex CLI is not available." }
    $marketplaceName = "codex-deepseek-worker"
    $marketplaces = (& $codex.Source plugin marketplace list --json | ConvertFrom-Json).marketplaces
    if ($marketplaces | Where-Object { $_.name -eq $marketplaceName }) {
        & $codex.Source plugin marketplace remove $marketplaceName *> $null
        if ($LASTEXITCODE -ne 0) { throw "Removing the old dsbro marketplace failed." }
    }
    & $codex.Source plugin marketplace add $InstallDirectory --json | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Registering the dsbro marketplace failed." }
    & $codex.Source plugin add "codex-deepseek-worker@$marketplaceName" --json | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Installing dsbro failed." }
}

if ($ConfigureApiKey) {
    Set-DeepSeekApiKey
    exit 0
}
if (-not $IsWindows -and $env:OS -ne "Windows_NT") { throw "This installer currently supports Windows only." }

Write-Host "Installing dsbro native DeepSeek worker..." -ForegroundColor Cyan
Install-Repository
Ensure-DeepSeekApiKey
Install-NativeCodexConfiguration
Install-CodexPlugin
Write-Host "dsbro installed. Restart Codex, open the target project, and enter: dsbro" -ForegroundColor Green
