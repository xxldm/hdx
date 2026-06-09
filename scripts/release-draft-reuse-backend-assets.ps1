param(
    [Parameter(Mandatory = $true)]
    [string]$HistoricalAssetRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$RootRepository,

    [Parameter(Mandatory = $true)]
    [string]$RootRef,

    [Parameter(Mandatory = $true)]
    [string]$RootCommit,

    [Parameter(Mandatory = $true)]
    [string]$BackendRepository,

    [Parameter(Mandatory = $true)]
    [string]$BackendCommit,

    [Parameter(Mandatory = $true)]
    [string]$OpenApiSnapshotHash,

    [Parameter(Mandatory = $true)]
    [string]$HistoricalReleaseRepository,

    [Parameter(Mandatory = $true)]
    [string]$HistoricalReleaseTag,

    [Parameter(Mandatory = $true)]
    [string]$HistoricalBackendAssetName,

    [string]$OutputBackendAssetName = '',

    [string]$OutputDirectory = 'target/release-draft-reuse-backend/assets',

    [string]$ExtractRoot = ''
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

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        $Actual,
        $Expected
    )

    if ($Actual -ne $Expected) {
        throw "$Name 不一致：期望 $Expected，实际 $Actual"
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

function Get-ContentType {
    param([Parameter(Mandatory = $true)][string]$FileName)

    $lower = $FileName.ToLowerInvariant()
    if ($lower.EndsWith('.tar.gz') -or $lower.EndsWith('.tgz')) {
        return 'application/gzip'
    }
    if ($lower.EndsWith('.zip')) {
        return 'application/zip'
    }
    if ($lower.EndsWith('.json')) {
        return 'application/json'
    }
    if ($lower -eq 'sha256sums') {
        return 'text/plain'
    }
    return 'application/octet-stream'
}

function Test-JsonPropertyExists {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]
}

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if (-not (Test-JsonPropertyExists -Object $Object -Name $Name)) {
        throw "$Context 缺少必填字段：$Name"
    }

    return $Object.PSObject.Properties[$Name].Value
}

Assert-Pattern -Name 'Version' -Value $Version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-Pattern -Name 'HistoricalReleaseTag' -Value $HistoricalReleaseTag -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-Pattern -Name 'RootRepository' -Value $RootRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'BackendRepository' -Value $BackendRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'HistoricalReleaseRepository' -Value $HistoricalReleaseRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'RootCommit' -Value $RootCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'BackendCommit' -Value $BackendCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'OpenApiSnapshotHash' -Value $OpenApiSnapshotHash -Pattern '^[0-9a-f]{64}$' -Message '必须是 64 位小写 SHA-256。'
Assert-Pattern -Name 'HistoricalBackendAssetName' -Value $HistoricalBackendAssetName -Pattern '^[A-Za-z0-9][A-Za-z0-9._+@=-]*$' -Message '必须是单个 Release asset 文件名，不能包含路径分隔符。'
Assert-NoLatest -Name 'Version' -Value $Version
Assert-NoLatest -Name 'RootRef' -Value $RootRef
Assert-NoLatest -Name 'HistoricalReleaseTag' -Value $HistoricalReleaseTag
Assert-NoLatest -Name 'HistoricalBackendAssetName' -Value $HistoricalBackendAssetName

if ([string]::IsNullOrWhiteSpace($OutputBackendAssetName)) {
    $OutputBackendAssetName = $HistoricalBackendAssetName
}
Assert-NoLatest -Name 'OutputBackendAssetName' -Value $OutputBackendAssetName
Assert-Pattern -Name 'OutputBackendAssetName' -Value $OutputBackendAssetName -Pattern '^[A-Za-z0-9][A-Za-z0-9._+@=-]*$' -Message '必须是单个 Release asset 文件名，不能包含路径分隔符。'
if ($OutputBackendAssetName -ne $HistoricalBackendAssetName) {
    throw '当前历史复用分支不支持重命名 backend native asset；backend-native-manifest.json 会记录历史文件名，需要重命名时必须先设计 manifest rewrite。'
}

$historicalAssetRootFull = Get-FullPath -Path $HistoricalAssetRoot
if (-not (Test-Path -LiteralPath $historicalAssetRootFull -PathType Container)) {
    throw "HistoricalAssetRoot 不存在：$historicalAssetRootFull"
}

$outputRootFull = Get-FullPath -Path $OutputDirectory
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $outputRootFull

if ([string]::IsNullOrWhiteSpace($ExtractRoot)) {
    $ExtractRoot = Join-Path $RepoRoot "target/release-draft-reuse-backend/extracted-$Version"
}
$extractRootFull = Get-FullPath -Path $ExtractRoot
Assert-PathWithin -Parent $targetRoot -Child $extractRootFull

$historicalReleaseManifestPath = Join-Path $historicalAssetRootFull 'release-manifest.json'
$historicalBackendManifestPath = Join-Path $historicalAssetRootFull 'backend-native-manifest.json'
$historicalBackendAssetPath = Join-Path $historicalAssetRootFull $HistoricalBackendAssetName

foreach ($requiredPath in @($historicalReleaseManifestPath, $historicalBackendManifestPath, $historicalBackendAssetPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "历史 Release asset 目录缺少必需文件：$requiredPath"
    }
}

$historicalReleaseManifest = Read-JsonFile -Path $historicalReleaseManifestPath
Assert-Equal -Name 'historicalRelease.manifestKind' -Actual $historicalReleaseManifest.manifestKind -Expected 'release'
Assert-Equal -Name 'historicalRelease.version' -Actual $historicalReleaseManifest.version -Expected $HistoricalReleaseTag
Assert-Equal -Name 'historicalRelease.root.repository' -Actual $historicalReleaseManifest.root.repository -Expected $HistoricalReleaseRepository

$historicalReleaseManifestSha256 = Get-Sha256 -Path $historicalReleaseManifestPath
$historicalBackendManifestSha256 = Get-Sha256 -Path $historicalBackendManifestPath
$historicalBackendManifestSizeBytes = (Get-Item -LiteralPath $historicalBackendManifestPath).Length
$historicalBackendAssetSha256 = Get-Sha256 -Path $historicalBackendAssetPath
$historicalBackendAssetSizeBytes = (Get-Item -LiteralPath $historicalBackendAssetPath).Length

Assert-Equal -Name 'historicalRelease.backendNativeManifest.sha256' -Actual $historicalReleaseManifest.backendNativeManifest.sha256 -Expected $historicalBackendManifestSha256
Assert-Equal -Name 'historicalRelease.backendNativeManifest.backendCommit' -Actual $historicalReleaseManifest.backendNativeManifest.backendCommit -Expected $BackendCommit
Assert-Equal -Name 'historicalRelease.openapiSnapshotHash' -Actual $historicalReleaseManifest.openapiSnapshotHash -Expected $OpenApiSnapshotHash

$matchedAssets = @($historicalReleaseManifest.assets | Where-Object { $_.fileName -eq $HistoricalBackendAssetName })
if ($matchedAssets.Count -ne 1) {
    $assetNames = @($historicalReleaseManifest.assets | ForEach-Object { $_.fileName }) -join ', '
    throw "无法在历史 release-manifest.json 中唯一定位后端 asset：$HistoricalBackendAssetName；历史 assets：$assetNames"
}

$historicalBackendAsset = $matchedAssets[0]
if ($historicalBackendAsset.kind -notin @('backend-full', 'backend-services')) {
    throw "历史 asset 必须是 backend-full 或 backend-services，实际：$($historicalBackendAsset.kind)"
}
if (-not (Test-JsonPropertyExists -Object $historicalBackendAsset -Name 'platform')) {
    throw '历史 backend native asset 缺少 platform。'
}
Assert-Equal -Name 'historicalAsset.sha256' -Actual $historicalBackendAsset.sha256 -Expected $historicalBackendAssetSha256
Assert-Equal -Name 'historicalAsset.sizeBytes' -Actual ([int64]$historicalBackendAsset.sizeBytes) -Expected $historicalBackendAssetSizeBytes

$source = Get-RequiredProperty -Object $historicalBackendAsset -Name 'source' -Context 'historicalAsset'
$fingerprint = Get-RequiredProperty -Object $source -Name 'backendNativeFingerprint' -Context 'historicalAsset.source'
Assert-Equal -Name 'fingerprint.algorithm' -Actual $fingerprint.algorithm -Expected 'hdx-backend-native-fingerprint-v1'
Assert-Equal -Name 'fingerprint.backend.repository' -Actual $fingerprint.backend.repository -Expected $BackendRepository
Assert-Equal -Name 'fingerprint.backend.commit' -Actual $fingerprint.backend.commit -Expected $BackendCommit
Assert-Equal -Name 'fingerprint.openapiSnapshotHash' -Actual $fingerprint.openapiSnapshotHash -Expected $OpenApiSnapshotHash
Assert-Equal -Name 'fingerprint.artifact.kind' -Actual $fingerprint.artifact.kind -Expected $historicalBackendAsset.kind
Assert-Equal -Name 'fingerprint.artifact.platform' -Actual $fingerprint.artifact.platform -Expected $historicalBackendAsset.platform

$historicalBuild = $null
if (Test-JsonPropertyExists -Object $source -Name 'historicalBuild') {
    $historicalBuild = $source.historicalBuild
}
else {
    $historicalBuild = [ordered]@{
        root = $historicalReleaseManifest.root
        backend = [ordered]@{
            repository = $BackendRepository
            commit = $BackendCommit
        }
        openapiSnapshotHash = $OpenApiSnapshotHash
        backendNativeManifestSha256 = $historicalBackendManifestSha256
    }
}

$releaseManifestCheck = Join-Path $PSScriptRoot 'release-manifest-check.ps1'
& pwsh -NoLogo -NoProfile -File $releaseManifestCheck `
    -BackendNativeManifestPath $historicalBackendManifestPath `
    -ReleaseManifestPath $historicalReleaseManifestPath `
    -ScanPath $historicalBackendAssetPath
if ($LASTEXITCODE -ne 0) {
    throw "历史 Release manifest 校验失败，退出码：$LASTEXITCODE"
}

if (Test-Path -LiteralPath $outputRootFull) {
    Remove-Item -LiteralPath $outputRootFull -Recurse -Force
}
New-Item -ItemType Directory -Path $outputRootFull | Out-Null

if (Test-Path -LiteralPath $extractRootFull) {
    Remove-Item -LiteralPath $extractRootFull -Recurse -Force
}
New-Item -ItemType Directory -Path $extractRootFull | Out-Null

$outputBackendManifestPath = Join-Path $outputRootFull 'backend-native-manifest.json'
$outputBackendAssetPath = Join-Path $outputRootFull $OutputBackendAssetName
Copy-Item -LiteralPath $historicalBackendManifestPath -Destination $outputBackendManifestPath
Copy-Item -LiteralPath $historicalBackendAssetPath -Destination $outputBackendAssetPath

$historicalReleaseForManifest = [ordered]@{
    repository = $HistoricalReleaseRepository
    tag = $HistoricalReleaseTag
    assetName = 'backend-native-manifest.json'
    assetSha256 = $historicalBackendManifestSha256
    assetSizeBytes = [int64]$historicalBackendManifestSizeBytes
    releaseManifestSha256 = $historicalReleaseManifestSha256
    backendNativeManifestSha256 = $historicalBackendManifestSha256
}

$historicalReleaseForAsset = [ordered]@{
    repository = $HistoricalReleaseRepository
    tag = $HistoricalReleaseTag
    assetName = $HistoricalBackendAssetName
    assetSha256 = $historicalBackendAssetSha256
    assetSizeBytes = [int64]$historicalBackendAssetSizeBytes
    releaseManifestSha256 = $historicalReleaseManifestSha256
    backendNativeManifestSha256 = $historicalBackendManifestSha256
}

$releaseManifest = [ordered]@{
    schemaVersion = '1.0'
    manifestKind = 'release'
    version = $Version
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    root = [ordered]@{
        repository = $RootRepository
        ref = $RootRef
        commit = $RootCommit
    }
    sources = [ordered]@{
        backend = [ordered]@{
            repository = $BackendRepository
            commit = $BackendCommit
        }
    }
    openapiSnapshotHash = $OpenApiSnapshotHash
    backendNativeManifest = [ordered]@{
        fileName = 'backend-native-manifest.json'
        sha256 = $historicalBackendManifestSha256
        backendCommit = $BackendCommit
        source = [ordered]@{
            type = 'historical-release-asset'
            historicalRelease = $historicalReleaseForManifest
            historicalBuild = $historicalBuild
        }
    }
    assets = @(
        [ordered]@{
            kind = $historicalBackendAsset.kind
            platform = $historicalBackendAsset.platform
            fileName = $OutputBackendAssetName
            contentType = Get-ContentType -FileName $OutputBackendAssetName
            sha256 = $historicalBackendAssetSha256
            sizeBytes = [int64]$historicalBackendAssetSizeBytes
            source = [ordered]@{
                type = 'historical-release-asset'
                commit = $BackendCommit
                historicalRelease = $historicalReleaseForAsset
                historicalBuild = $historicalBuild
                backendNativeFingerprint = $fingerprint
            }
        }
    )
}

$releaseManifestPath = Join-Path $outputRootFull 'release-manifest.json'
$releaseManifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $releaseManifestPath

$trackedFiles = Get-ChildItem -LiteralPath $outputRootFull -File | Sort-Object Name
$sha256SumsPath = Join-Path $outputRootFull 'SHA256SUMS'
$shaLines = foreach ($file in $trackedFiles) {
    if ($file.Name -eq 'SHA256SUMS') {
        continue
    }
    "$(Get-Sha256 -Path $file.FullName)  $($file.Name)"
}
$shaLines | Set-Content -LiteralPath $sha256SumsPath

& pwsh -NoLogo -NoProfile -File $releaseManifestCheck `
    -BackendNativeManifestPath $outputBackendManifestPath `
    -ReleaseManifestPath $releaseManifestPath `
    -AssetRoot $outputRootFull `
    -ScanPath $outputBackendAssetPath
if ($LASTEXITCODE -ne 0) {
    throw "复用 Release 资产校验失败，退出码：$LASTEXITCODE"
}

Write-Host '历史后端 native asset 复用资产已生成并通过本地校验。'
Write-Host "历史 Release：$HistoricalReleaseRepository@$HistoricalReleaseTag"
Write-Host "历史 asset：$HistoricalBackendAssetName"
Write-Host "输出 asset：$OutputBackendAssetName"
Write-Host "资产目录：$outputRootFull"
Get-ChildItem -LiteralPath $outputRootFull -File | Sort-Object Name | Select-Object Name, Length | Format-Table | Out-String | Write-Host
