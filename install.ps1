[CmdletBinding()]
param(
    [switch]$ConfigureApiKey,

    [string]$Repository = "mandgrapes/codex-deepseek-worker",

    [string]$BaseUrl = "https://api.deepseek.com",

    [string]$Model = "deepseek-v4-flash",

    [string]$InstallDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "Codex\marketplaces\codex-deepseek-worker")
)

$ErrorActionPreference = "Stop"

function ConvertTo-EncodedPowerShellCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
}

function Get-GitHubCliPath {
    $command = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $commonPath = Join-Path $env:ProgramFiles "GitHub CLI\gh.exe"
    if (Test-Path -LiteralPath $commonPath) {
        return $commonPath
    }

    return $null
}

function Install-GitHubCli {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        throw "GitHub CLI is missing and winget is unavailable. Install GitHub CLI, then run this file again."
    }

    Write-Host "Installing GitHub CLI..." -ForegroundColor Cyan
    & $winget.Source install --id GitHub.cli --exact --source winget `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI installation failed."
    }

    $ghPath = Get-GitHubCliPath
    if ([string]::IsNullOrWhiteSpace($ghPath)) {
        throw "GitHub CLI was installed but gh.exe could not be found. Restart Windows and run this file again."
    }

    return $ghPath
}

function Enable-GitCommand {
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -ne $gitCommand) {
        return
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        throw "Git is missing and winget is unavailable. Install Git, then run this file again."
    }

    Write-Host "Installing Git..." -ForegroundColor Cyan
    & $winget.Source install --id Git.Git --exact --source winget `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "Git installation failed."
    }

    $gitCommandDirectory = Join-Path $env:ProgramFiles "Git\cmd"
    $gitExecutable = Join-Path $gitCommandDirectory "git.exe"
    if (-not (Test-Path -LiteralPath $gitExecutable)) {
        throw "Git was installed but git.exe could not be found. Restart Windows and run this file again."
    }

    $env:Path = "$gitCommandDirectory;$env:Path"
}

function Invoke-VisibleGitHubLogin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitHubCliPath
    )

    $escapedPath = $GitHubCliPath.Replace("'", "''")
    $loginCommand = @"
& '$escapedPath' auth login --hostname github.com --git-protocol https --web
if (`$LASTEXITCODE -ne 0) {
    Write-Host 'GitHub login failed.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
"@
    $encodedCommand = ConvertTo-EncodedPowerShellCommand -Command $loginCommand
    $process = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encodedCommand) `
        -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "GitHub login did not complete."
    }
}

function Set-DeepSeekUserSettings {
    $secureKey = Read-Host "Enter DeepSeek API Key (input is hidden)" -AsSecureString
    $keyPointer = [IntPtr]::Zero
    $plainKey = $null

    try {
        $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
        if ([string]::IsNullOrWhiteSpace($plainKey)) {
            throw "API Key cannot be empty. Run install.ps1 again."
        }

        [Environment]::SetEnvironmentVariable("DEEPSEEK_WORKER_API_KEY", $plainKey, "User")
        [Environment]::SetEnvironmentVariable("DEEPSEEK_WORKER_BASE_URL", $BaseUrl, "User")
        [Environment]::SetEnvironmentVariable("DEEPSEEK_WORKER_MODEL", $Model, "User")
    }
    finally {
        if ($keyPointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
        }
        $plainKey = $null
        $secureKey = $null
    }

    Write-Host "API settings saved securely to Windows user environment variables." -ForegroundColor Green
    Read-Host "Press Enter to close"
}

if ($ConfigureApiKey) {
    Set-DeepSeekUserSettings
    exit 0
}

if (-not $IsWindows -and $env:OS -ne "Windows_NT") {
    throw "This one-file installer currently supports Windows only."
}

Write-Host "Codex DeepSeek Worker installer" -ForegroundColor Cyan

$codex = Get-Command codex -ErrorAction SilentlyContinue
if ($null -eq $codex) {
    throw "Codex CLI is not available. Open this file with Codex on the target machine and ask Codex to run it."
}

$ghPath = Get-GitHubCliPath
if ([string]::IsNullOrWhiteSpace($ghPath)) {
    $ghPath = Install-GitHubCli
}

Enable-GitCommand

& $ghPath auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub login is required once because the plugin repository is private." -ForegroundColor Yellow
    Invoke-VisibleGitHubLogin -GitHubCliPath $ghPath
}

& $ghPath auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) {
    throw "GitHub login could not be verified."
}

$installParent = Split-Path -Parent $InstallDirectory
[IO.Directory]::CreateDirectory($installParent) | Out-Null

if (Test-Path -LiteralPath (Join-Path $InstallDirectory ".git")) {
    Write-Host "Updating plugin source..." -ForegroundColor Cyan
    & git -C $InstallDirectory pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        throw "Updating the existing plugin source failed."
    }
}
elseif (Test-Path -LiteralPath $InstallDirectory) {
    throw "Install directory already exists but is not a Git repository: $InstallDirectory"
}
else {
    Write-Host "Downloading plugin source..." -ForegroundColor Cyan
    & $ghPath repo clone $Repository $InstallDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Downloading the private plugin repository failed."
    }
}

$marketplaceName = "codex-deepseek-worker"
$marketplaces = (& $codex.Source plugin marketplace list --json | ConvertFrom-Json).marketplaces
$existingMarketplace = $marketplaces | Where-Object { $_.name -eq $marketplaceName }
if ($null -ne $existingMarketplace) {
    & $codex.Source plugin marketplace remove $marketplaceName *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Removing the previous marketplace registration failed."
    }
}

Write-Host "Registering marketplace and installing plugin..." -ForegroundColor Cyan
& $codex.Source plugin marketplace add $InstallDirectory --json | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Marketplace registration failed."
}

& $codex.Source plugin add "codex-deepseek-worker@$marketplaceName" --json | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Plugin installation failed."
}

$existingApiKey = [Environment]::GetEnvironmentVariable("DEEPSEEK_WORKER_API_KEY", "User")
if ([string]::IsNullOrWhiteSpace($existingApiKey)) {
    $escapedScriptPath = $PSCommandPath.Replace("'", "''")
    $escapedBaseUrl = $BaseUrl.Replace("'", "''")
    $escapedModel = $Model.Replace("'", "''")
    $keyCommand = "& '$escapedScriptPath' -ConfigureApiKey -BaseUrl '$escapedBaseUrl' -Model '$escapedModel'"
    $encodedKeyCommand = ConvertTo-EncodedPowerShellCommand -Command $keyCommand
    $keyProcess = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encodedKeyCommand) `
        -Wait -PassThru
    if ($keyProcess.ExitCode -ne 0) {
        throw "API Key configuration did not complete."
    }

    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("DEEPSEEK_WORKER_API_KEY", "User"))) {
        throw "API Key was not saved."
    }
}
else {
    Write-Host "Existing API Key preserved." -ForegroundColor Green
}
$existingApiKey = $null

Write-Host "Installation complete." -ForegroundColor Green
Write-Host "Restart Codex, open a new thread, and enter: dsbro"
