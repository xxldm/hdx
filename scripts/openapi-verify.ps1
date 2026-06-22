param(
    [switch]$RefreshSnapshots,
    [switch]$GenerateTypes,
    [switch]$SkipWebTypeCheck
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PowerShellCommand = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($PowerShellCommand)) {
    $PowerShellCommand = 'pwsh'
}

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Format-CommandLine {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )
    return ((@($Command) + $Arguments) -join ' ')
}

function Invoke-OpenApiStep {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    Write-Section $Title
    $commandArguments = @('-NoLogo', '-NoProfile', '-File', $ScriptPath) + $Arguments
    Write-Host "命令：$(Format-CommandLine -Command $PowerShellCommand -Arguments $commandArguments)"

    & $PowerShellCommand @commandArguments
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "OpenAPI 验证步骤失败：$Title，退出码：$exitCode"
    }
}

Write-Section 'OpenAPI 聚合验证'
Write-Host "仓库：$RepoRoot"
Write-Host "RefreshSnapshots: $RefreshSnapshots"
Write-Host "GenerateTypes: $GenerateTypes"
Write-Host "SkipWebTypeCheck: $SkipWebTypeCheck"

if ($RefreshSnapshots) {
    Invoke-OpenApiStep `
        -Title '刷新 OpenAPI 快照' `
        -ScriptPath (Join-Path $RepoRoot 'scripts/openapi-refresh-snapshots.ps1')
}

if ($GenerateTypes) {
    Invoke-OpenApiStep `
        -Title '生成 OpenAPI TypeScript 类型' `
        -ScriptPath (Join-Path $RepoRoot 'scripts/openapi-generate-types.ps1')
}

Invoke-OpenApiStep `
    -Title 'OpenAPI 契约检查' `
    -ScriptPath (Join-Path $RepoRoot 'scripts/openapi-contract-check.ps1')

Invoke-OpenApiStep `
    -Title 'OpenAPI TypeScript 类型生成检查' `
    -ScriptPath (Join-Path $RepoRoot 'scripts/openapi-generate-types.ps1') `
    -Arguments @('-Check')

if (-not $SkipWebTypeCheck) {
    Invoke-OpenApiStep `
        -Title 'OpenAPI 与 Web 类型对齐检查' `
        -ScriptPath (Join-Path $RepoRoot 'scripts/openapi-web-type-check.ps1')
}

Write-Section 'OpenAPI 聚合验证完成'
Write-Host '全部检查通过。'
