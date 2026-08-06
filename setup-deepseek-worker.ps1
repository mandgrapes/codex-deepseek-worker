[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$secureKey = Read-Host "Enter DeepSeek API Key (input is hidden)" -AsSecureString
$keyPointer = [IntPtr]::Zero
$plainKey = $null

try {
    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)

    if ([string]::IsNullOrWhiteSpace($plainKey)) {
        throw "API Key cannot be empty."
    }

    [Environment]::SetEnvironmentVariable(
        "DEEPSEEK_WORKER_API_KEY",
        $plainKey,
        [EnvironmentVariableTarget]::User
    )
    [Environment]::SetEnvironmentVariable(
        "DEEPSEEK_WORKER_BASE_URL",
        "https://api.deepseek.com",
        [EnvironmentVariableTarget]::User
    )
    [Environment]::SetEnvironmentVariable(
        "DEEPSEEK_WORKER_MODEL",
        "deepseek-v4-flash",
        [EnvironmentVariableTarget]::User
    )

    Write-Host "DeepSeek Worker settings were saved to Windows user environment variables." -ForegroundColor Green
    Write-Host "Restart Codex to load the new settings."
}
finally {
    if ($keyPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
    }

    $plainKey = $null
    $secureKey = $null
}
