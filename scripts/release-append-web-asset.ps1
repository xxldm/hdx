param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$WebArchivePath,

    [Parameter(Mandatory = $true)]
    [string]$WebRepository,

    [Parameter(Mandatory = $true)]
    [string]$WebCommit,

    [string]$AssetRoot = 'target/release/assets',

    [string]$WebPath = 'apps/web'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Assert-Pattern {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Value -notmatch $Pattern) {
        throw "$Name 无效：$Message"
    }
}

function Assert-NoLatest {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    if ($Value -match '(?i)latest') {
        throw "$Name 不能包含 latest：$Value"
    }
}

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Assert-PathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Child
    )

    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $parentWithSeparator = $parentFull + [System.IO.Path]::DirectorySeparatorChar

    if (
        $childFull -ne $parentFull -and
        -not $childFull.StartsWith($parentWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        throw "路径必须位于 $parentFull 之下：$childFull"
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "缺少 JSON 文件：$Path"
    }

    $jsonText = Get-Content -LiteralPath $Path -Raw
    $convertFromJson = Get-Command ConvertFrom-Json
    if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
        return $jsonText | ConvertFrom-Json -Depth 100 -DateKind String
    }
    return $jsonText | ConvertFrom-Json -Depth 100
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Copy-JsonObjectProperties {
    param([Parameter(Mandatory = $true)]$Object)

    $result = [ordered]@{}
    foreach ($property in $Object.PSObject.Properties) {
        $result[$property.Name] = $property.Value
    }
    return $result
}

Assert-Pattern -Name 'WebRepository' -Value $WebRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'WebCommit' -Value $WebCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-NoLatest -Name 'WebRepository' -Value $WebRepository

$assetRootFull = Get-FullPath -Path $AssetRoot
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $assetRootFull
if (-not (Test-Path -LiteralPath $assetRootFull -PathType Container)) {
    throw "AssetRoot 不存在：$assetRootFull"
}

$releaseManifestFull = Get-FullPath -Path $ReleaseManifestPath
$webArchiveFull = Get-FullPath -Path $WebArchivePath
Assert-PathWithin -Parent $assetRootFull -Child $releaseManifestFull
Assert-PathWithin -Parent $assetRootFull -Child $webArchiveFull

if (-not (Test-Path -LiteralPath $webArchiveFull -PathType Leaf)) {
    throw "Web archive 不存在：$webArchiveFull"
}

$manifest = Read-JsonFile -Path $releaseManifestFull
$version = [string]$manifest.version
Assert-Pattern -Name 'release manifest version' -Value $version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-NoLatest -Name 'release manifest version' -Value $version

$webArchiveName = Split-Path -Leaf $webArchiveFull
$expectedArchiveName = "hdx-web-node-server-$version.tar.gz"
if ($webArchiveName -ne $expectedArchiveName) {
    throw "Web archive 文件名不符合发布约定：期望 $expectedArchiveName，实际 $webArchiveName"
}

$sources = Copy-JsonObjectProperties -Object $manifest.sources
if ($sources.Contains('web')) {
    throw 'release-manifest.json 已包含 sources.web，拒绝重复追加 Web asset。'
}
$sources['web'] = [ordered]@{
    repository = $WebRepository
    commit = $WebCommit
    path = $WebPath
}

$assets = @($manifest.assets)
$duplicateAssets = @($assets | Where-Object { $_.fileName -eq $webArchiveName -or $_.kind -eq 'web-node-server' })
if ($duplicateAssets.Count -gt 0) {
    throw "release-manifest.json 已包含 Web node-server asset 或同名文件：$webArchiveName"
}

$webArchive = Get-Item -LiteralPath $webArchiveFull
$assets += [ordered]@{
    kind = 'web-node-server'
    packaging = 'tar.gz'
    fileName = $webArchiveName
    contentType = 'application/gzip'
    sha256 = Get-Sha256 -Path $webArchiveFull
    sizeBytes = [int64]$webArchive.Length
    source = [ordered]@{
        type = 'web'
        commit = $WebCommit
    }
}

$releaseManifest = [ordered]@{
    schemaVersion = $manifest.schemaVersion
    manifestKind = $manifest.manifestKind
    version = $manifest.version
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    root = $manifest.root
    sources = $sources
    openapiSnapshotHash = $manifest.openapiSnapshotHash
    backendNativeManifest = $manifest.backendNativeManifest
    assets = $assets
}

$releaseManifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $releaseManifestFull

$sha256SumsPath = Join-Path $assetRootFull 'SHA256SUMS'
$trackedFiles = Get-ChildItem -LiteralPath $assetRootFull -File | Sort-Object Name
$shaLines = foreach ($file in $trackedFiles) {
    if ($file.Name -eq 'SHA256SUMS') {
        continue
    }
    "$(Get-Sha256 -Path $file.FullName)  $($file.Name)"
}
$shaLines | Set-Content -LiteralPath $sha256SumsPath

$backendNativeManifestPath = Join-Path $assetRootFull 'backend-native-manifest.json'
$releaseManifestCheck = Join-Path $PSScriptRoot 'release-manifest-check.ps1'
& pwsh -NoLogo -NoProfile -File $releaseManifestCheck `
    -BackendNativeManifestPath $backendNativeManifestPath `
    -ReleaseManifestPath $releaseManifestFull `
    -AssetRoot $assetRootFull `
    -ScanPath $assetRootFull
if ($LASTEXITCODE -ne 0) {
    throw "追加 Web asset 后 Release manifest 校验失败，退出码：$LASTEXITCODE"
}

Write-Host 'Web node-server asset 已追加到 release-manifest.json，并通过校验。'
Write-Host "Web asset：$webArchiveName"
