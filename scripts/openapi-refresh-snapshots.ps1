param(
    [string]$AuthGeneratedSpecPath = '',
    [string]$GatewayGeneratedSpecPath = '',
    [string]$SnapshotsDir = ''
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($AuthGeneratedSpecPath)) {
    $AuthGeneratedSpecPath = Join-Path $RepoRoot 'services/backend/backend-auth-service/target/openapi/auth-service.openapi.json'
}

if ([string]::IsNullOrWhiteSpace($GatewayGeneratedSpecPath)) {
    $GatewayGeneratedSpecPath = Join-Path $RepoRoot 'services/backend/backend-gateway/target/openapi/gateway.openapi.json'
}

if ([string]::IsNullOrWhiteSpace($SnapshotsDir)) {
    $SnapshotsDir = Join-Path $RepoRoot 'packages/shared/contracts/openapi/snapshots'
}

function Assert-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "缺少生成的 OpenAPI spec：$ServiceName $Path。请先运行后端 OpenAPI 测试。"
    }

    try {
        Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json | Out-Null
    }
    catch {
        throw "JSON 格式无效：$ServiceName $Path"
    }
}

function Copy-Snapshot {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    Assert-JsonFile -ServiceName $ServiceName -Path $SourcePath
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    Write-Host "已刷新快照：$ServiceName $DestinationPath"
}

Write-Host '刷新 OpenAPI 快照'
Write-Host "快照目录：$SnapshotsDir"

New-Item -ItemType Directory -Force -Path $SnapshotsDir | Out-Null

Copy-Snapshot `
    -ServiceName 'auth-service' `
    -SourcePath $AuthGeneratedSpecPath `
    -DestinationPath (Join-Path $SnapshotsDir 'auth-service.openapi.json')

Copy-Snapshot `
    -ServiceName 'gateway' `
    -SourcePath $GatewayGeneratedSpecPath `
    -DestinationPath (Join-Path $SnapshotsDir 'gateway.openapi.json')

Write-Host 'OpenAPI 快照刷新完成。'
