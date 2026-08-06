[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("deepseek", "openai", "set-key", "update")]
    [string]$Action,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CodexArguments
)

$ErrorActionPreference = "Stop"
$OfficialScriptUrl = "https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.ps1"
$MainCodexHome = Join-Path $env:USERPROFILE ".codex"
$LegacyDeepSeekHome = Join-Path $env:USERPROFILE ".codex-deepseek"
$LegacyDeepSeekConfig = Join-Path $LegacyDeepSeekHome "config.toml"
$DeepSeekCatalog = Join-Path $MainCodexHome "deepseek-models.json"

function Set-DeepSeekApiKey {
    $secureKey = Read-Host "Enter DeepSeek API Key (hidden)" -AsSecureString
    $pointer = [IntPtr]::Zero
    $plainKey = $null
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        if ([string]::IsNullOrWhiteSpace($plainKey) -or $plainKey -cnotlike "sk-*") {
            throw "The DeepSeek API Key must start with sk-."
        }
        [Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", $plainKey, "User")
        $env:DEEPSEEK_API_KEY = $plainKey
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
        $plainKey = $null
        $secureKey = $null
    }
    Write-Host "DeepSeek API Key saved for this Windows user." -ForegroundColor Green
}

function Get-DeepSeekApiKey {
    $key = [Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "User")
    if ([string]::IsNullOrWhiteSpace($key) -and (Test-Path -LiteralPath $LegacyDeepSeekConfig)) {
        $legacyConfig = Get-Content -LiteralPath $LegacyDeepSeekConfig -Raw -Encoding UTF8
        $legacyMatch = [regex]::Match(
            $legacyConfig,
            '(?m)^experimental_bearer_token\s*=\s*"(sk-[^"]+)"'
        )
        if ($legacyMatch.Success) {
            $key = $legacyMatch.Groups[1].Value
            [Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", $key, "User")
            Write-Host "Existing DeepSeek API Key migrated to the Windows user environment." -ForegroundColor Green
        }
    }
    if ([string]::IsNullOrWhiteSpace($key)) {
        Set-DeepSeekApiKey
        $key = [Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "User")
    }
    if (-not [string]::IsNullOrWhiteSpace($key)) {
        $env:DEEPSEEK_API_KEY = $key
    }
}

function Ensure-DeepSeekCatalog {
    param([switch]$Refresh)

    if (-not $Refresh -and (Test-Path -LiteralPath $DeepSeekCatalog)) {
        return
    }

    New-Item -ItemType Directory -Path $MainCodexHome -Force | Out-Null
    $bootstrapDirectory = Join-Path ([IO.Path]::GetTempPath()) ("dsbro-official-" + [guid]::NewGuid().ToString("N"))
    $bootstrapCatalog = Join-Path $bootstrapDirectory "models.json"
    New-Item -ItemType Directory -Path $bootstrapDirectory | Out-Null
    $previousCodexHome = $env:CODEX_HOME
    try {
        $env:CODEX_HOME = $bootstrapDirectory
        Invoke-OfficialSetup -InputLines @("1")
        if (-not (Test-Path -LiteralPath $bootstrapCatalog)) {
            throw "The official DeepSeek setup did not create models.json."
        }
        Copy-Item -LiteralPath $bootstrapCatalog -Destination $DeepSeekCatalog -Force
    }
    finally {
        if ($null -eq $previousCodexHome) {
            Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
        } else {
            $env:CODEX_HOME = $previousCodexHome
        }
        $resolvedBootstrap = (Resolve-Path -LiteralPath $bootstrapDirectory).Path
        $resolvedTemp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd('\')
        if ($resolvedBootstrap.StartsWith($resolvedTemp + '\', [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedBootstrap -Recurse -Force
        }
    }
}

function Invoke-OfficialSetup {
    param([string[]]$InputLines)

    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(
        "irm '$OfficialScriptUrl' | iex"
    ))
    $setupOutput = @(
        $InputLines | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand *>&1
    )
    if ($LASTEXITCODE -ne 0) {
        $details = ($setupOutput | ForEach-Object { "$_" }) -join "`n"
        throw "The official DeepSeek Codex setup script failed with exit code $LASTEXITCODE.`n$details"
    }
}

switch ($Action) {
    "set-key" {
        Set-DeepSeekApiKey
    }
    "update" {
        Get-DeepSeekApiKey
        Ensure-DeepSeekCatalog -Refresh
        Write-Host "DeepSeek official model catalog updated." -ForegroundColor Green
    }
    "deepseek" {
        Get-DeepSeekApiKey
        Ensure-DeepSeekCatalog

        $previousCodexHome = $env:CODEX_HOME
        try {
            Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
            $catalogValue = $DeepSeekCatalog -replace '\\', '/'
            $providerOverrides = @(
                '-c', 'model="deepseek-v4-flash"',
                '-c', 'model_provider="deepseek"',
                '-c', 'model_reasoning_effort="high"',
                '-c', ('model_catalog_json="' + $catalogValue + '"'),
                '-c', 'model_providers.deepseek.name="deepseek"',
                '-c', 'model_providers.deepseek.base_url="https://api.deepseek.com/"',
                '-c', 'model_providers.deepseek.wire_api="responses"',
                '-c', 'model_providers.deepseek.env_key="DEEPSEEK_API_KEY"'
            )
            & codex @providerOverrides @CodexArguments
        }
        finally {
            if ($null -ne $previousCodexHome) {
                $env:CODEX_HOME = $previousCodexHome
            }
        }
    }
    "openai" {
        $previousHome = $env:CODEX_HOME
        try {
            Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
            & codex @CodexArguments
        }
        finally {
            if ($null -ne $previousHome) {
                $env:CODEX_HOME = $previousHome
            }
        }
    }
}
