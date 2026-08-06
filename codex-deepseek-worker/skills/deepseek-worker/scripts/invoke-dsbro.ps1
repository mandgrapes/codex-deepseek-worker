[CmdletBinding(DefaultParameterSetName = "TaskText")]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true, ParameterSetName = "TaskText")]
    [string]$Task,

    [Parameter(Mandatory = $true, ParameterSetName = "TaskFile")]
    [string]$TaskFile,

    [string]$SessionId,

    [ValidateSet("read-only", "workspace-write", "danger-full-access")]
    [string]$SandboxMode,

    [string]$OutputFile
)

$ErrorActionPreference = "Stop"

$resolvedProject = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not (Test-Path -LiteralPath $resolvedProject -PathType Container)) {
    throw "ProjectRoot must be an existing directory."
}

$apiKey = [Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "Process")
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = [Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "User")
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "DEEPSEEK_API_KEY is not configured. Run setup-deepseek-worker.ps1."
}
$env:DEEPSEEK_API_KEY = $apiKey
$apiKey = $null

$prompt = if ($PSCmdlet.ParameterSetName -eq "TaskFile") {
    Get-Content -LiteralPath $TaskFile -Raw -Encoding UTF8
} else {
    $Task
}
if ([string]::IsNullOrWhiteSpace($prompt)) { throw "The worker task cannot be empty." }

$codex = Get-Command codex -ErrorAction SilentlyContinue
if ($null -eq $codex) { throw "Codex CLI is not available." }

$codexDirectory = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex"
} else {
    $env:CODEX_HOME
}
$catalogPath = Join-Path $codexDirectory "dsbro-models.json"
if (-not (Test-Path -LiteralPath $catalogPath)) {
    throw "dsbro model catalog is missing. Run install.ps1."
}
$catalogTomlPath = $catalogPath.Replace("\", "/").Replace('"', '\"')

$workerPrompt = @"
Act as a Codex subagent for the parent agent. Work in the repository with the normal Codex tools and complete the following task. Return a concise handoff to the parent when this turn is done.

$prompt
"@

if ([string]::IsNullOrWhiteSpace($SessionId)) {
    $arguments = @(
        "exec",
        "--json",
        "-C", $resolvedProject,
        "-c", 'model_provider="deepseek"',
        "-c", "model_catalog_json=`"$catalogTomlPath`"",
        "-m", "deepseek-v4-flash"
    )
    if (-not [string]::IsNullOrWhiteSpace($SandboxMode)) {
        $arguments += @("--sandbox", $SandboxMode)
    }
} else {
    $arguments = @(
        "exec", "resume",
        "--json",
        "-c", 'model_provider="deepseek"',
        "-c", "model_catalog_json=`"$catalogTomlPath`"",
        "-m", "deepseek-v4-flash",
        $SessionId
    )
}
if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
    $arguments += @("-o", $OutputFile)
}
$arguments += @("--", $workerPrompt)

$capturedEvents = [Collections.Generic.List[string]]::new()
& $codex.Source @arguments | ForEach-Object {
    $line = [string]$_
    $capturedEvents.Add($line)
    Write-Output $line
}
$workerExitCode = $LASTEXITCODE
if ($workerExitCode -ne 0) { throw "DeepSeek Codex worker failed with exit code $workerExitCode." }

$threadId = $null
foreach ($line in @($capturedEvents)) {
    try {
        $event = $line | ConvertFrom-Json
        if ($event.type -eq "thread.started") {
            $threadId = $event.thread_id
            break
        }
    }
    catch {
        continue
    }
}
if (-not [string]::IsNullOrWhiteSpace($threadId)) {
    Write-Output "DSBRO_SESSION_ID=$threadId"
}
