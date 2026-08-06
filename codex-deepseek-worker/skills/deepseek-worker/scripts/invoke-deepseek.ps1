[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [ValidateRange(10, 1800)]
    [int]$TimeoutSec = 300
)

$ErrorActionPreference = "Stop"

function Get-WorkerSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$DefaultValue
    )

    $value = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::Process)
    if ([string]::IsNullOrWhiteSpace($value) -and $IsWindows -ne $false) {
        $value = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::User)
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }
    return $value
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

$resolvedInput = (Resolve-Path -LiteralPath $InputFile).Path
$resolvedOutput = [IO.Path]::GetFullPath($OutputFile)
$outputDirectory = [IO.Path]::GetDirectoryName($resolvedOutput)
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    [IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

$requestText = [IO.File]::ReadAllText($resolvedInput, [Text.Encoding]::UTF8)
try {
    $taskRequest = $requestText | ConvertFrom-Json
}
catch {
    throw "InputFile must contain valid JSON."
}

if ([string]::IsNullOrWhiteSpace([string]$taskRequest.task)) {
    throw "Input JSON must contain a non-empty task field."
}

$apiKey = Get-WorkerSetting -Name "DEEPSEEK_WORKER_API_KEY"
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "DEEPSEEK_WORKER_API_KEY is not configured."
}

$baseUrl = Get-WorkerSetting -Name "DEEPSEEK_WORKER_BASE_URL" -DefaultValue "https://api.deepseek.com"
$model = Get-WorkerSetting -Name "DEEPSEEK_WORKER_MODEL" -DefaultValue "deepseek-v4-flash"
$trimmedBaseUrl = $baseUrl.TrimEnd('/')
if ($trimmedBaseUrl.EndsWith('/chat/completions')) {
    $endpoint = $trimmedBaseUrl
}
else {
    $endpoint = "$trimmedBaseUrl/chat/completions"
}

$systemPrompt = @'
You are a coding implementation worker. Use only the task context supplied by the caller. Do not claim to inspect files or run commands. Return one JSON object with exactly these keys:
- summary: concise implementation summary string
- patch: unified diff string using repository-relative paths
- suggested_tests: array of test command strings
- risks: array of concise risk strings
Return valid JSON only. Do not wrap it in Markdown fences.
'@

$requestPayload = [ordered]@{
    model = $model
    messages = @(
        [ordered]@{ role = "system"; content = $systemPrompt }
        [ordered]@{ role = "user"; content = ($taskRequest | ConvertTo-Json -Depth 30 -Compress) }
    )
    response_format = [ordered]@{ type = "json_object" }
    stream = $false
}

$headers = @{ Authorization = "Bearer $apiKey" }
$body = $requestPayload | ConvertTo-Json -Depth 30 -Compress

try {
    $apiResponse = Invoke-RestMethod `
        -Method Post `
        -Uri $endpoint `
        -Headers $headers `
        -ContentType "application/json; charset=utf-8" `
        -Body ([Text.Encoding]::UTF8.GetBytes($body)) `
        -TimeoutSec $TimeoutSec
}
catch {
    $safeMessage = [string]$_.Exception.Message
    if (-not [string]::IsNullOrEmpty($apiKey)) {
        $safeMessage = $safeMessage.Replace($apiKey, "[REDACTED]")
    }
    throw "DeepSeek API request failed: $safeMessage"
}
finally {
    $headers.Authorization = "[REDACTED]"
    $apiKey = $null
}

$content = [string]$apiResponse.choices[0].message.content
if ([string]::IsNullOrWhiteSpace($content)) {
    throw "DeepSeek API returned no message content."
}

try {
    $workerResult = $content | ConvertFrom-Json
}
catch {
    throw "DeepSeek returned content that is not valid JSON."
}

foreach ($requiredField in @("summary", "patch", "suggested_tests", "risks")) {
    if ($null -eq $workerResult.$requiredField) {
        throw "DeepSeek result is missing required field: $requiredField"
    }
}

$normalizedResult = $workerResult | ConvertTo-Json -Depth 30
Write-Utf8NoBom -Path $resolvedOutput -Content $normalizedResult

Write-Output $resolvedOutput
