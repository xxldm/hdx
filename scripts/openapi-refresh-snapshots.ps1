param(
    [string]$AuthGeneratedSpecPath = '',
    [string]$GatewayGeneratedSpecPath = '',
    [string]$SnapshotsDir = ''
)

$ErrorActionPreference = 'Stop'

function U {
    param([Parameter(Mandatory = $true)][string]$Escaped)
    return [System.Text.RegularExpressions.Regex]::Unescape($Escaped)
}

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
        throw "$(U '\u7f3a\u5c11\u751f\u6210\u7684\u0020OpenAPI\u0020spec\uff1a')$ServiceName $Path$(U '\u3002\u8bf7\u5148\u8fd0\u884c\u540e\u7aef\u0020OpenAPI\u0020\u6d4b\u8bd5\u3002')"
    }

    try {
        Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json | Out-Null
    }
    catch {
        throw "$(U '\u004a\u0053\u004f\u004e\u0020\u683c\u5f0f\u65e0\u6548\uff1a')$ServiceName $Path"
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
    Write-Host "$(U '\u5df2\u5237\u65b0\u5feb\u7167\uff1a')$ServiceName $DestinationPath"
}

Write-Host (U '\u5237\u65b0\u0020OpenAPI\u0020\u5feb\u7167')
Write-Host "$(U '\u5feb\u7167\u76ee\u5f55\uff1a')$SnapshotsDir"

New-Item -ItemType Directory -Force -Path $SnapshotsDir | Out-Null

Copy-Snapshot `
    -ServiceName 'auth-service' `
    -SourcePath $AuthGeneratedSpecPath `
    -DestinationPath (Join-Path $SnapshotsDir 'auth-service.openapi.json')

Copy-Snapshot `
    -ServiceName 'gateway' `
    -SourcePath $GatewayGeneratedSpecPath `
    -DestinationPath (Join-Path $SnapshotsDir 'gateway.openapi.json')

Write-Host (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u5feb\u7167\u5237\u65b0\u5b8c\u6210\u3002')
