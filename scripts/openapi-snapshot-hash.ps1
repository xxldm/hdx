param(
    [string]$SnapshotsDir = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($SnapshotsDir)) {
    $SnapshotsDir = Join-Path $RepoRoot 'packages/shared/contracts/openapi/snapshots'
}

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSha256 {
    param([Parameter(Mandatory = $true)][string]$Value)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
}

$snapshotsFull = Get-FullPath -Path $SnapshotsDir
if (-not (Test-Path -LiteralPath $snapshotsFull -PathType Container)) {
    throw "OpenAPI 快照目录不存在：$snapshotsFull"
}

$files = @(Get-ChildItem -LiteralPath $snapshotsFull -File -Recurse | Sort-Object FullName)
if ($files.Count -lt 1) {
    throw "OpenAPI 快照目录为空：$snapshotsFull"
}

$lines = foreach ($file in $files) {
    $relativePath = [System.IO.Path]::GetRelativePath($snapshotsFull, $file.FullName).Replace('\', '/')
    $fileSha256 = Get-Sha256 -Path $file.FullName
    "$relativePath`t$($file.Length)`t$fileSha256"
}

$canonicalPayload = ($lines -join "`n") + "`n"
$snapshotHash = Get-StringSha256 -Value $canonicalPayload

if (-not $Quiet) {
    Write-Host 'OpenAPI snapshot hash'
    Write-Host "快照目录：$snapshotsFull"
    Write-Host '参与文件：'
    foreach ($line in $lines) {
        Write-Host $line
    }
    Write-Host "hash：$snapshotHash"
}

Write-Output $snapshotHash
