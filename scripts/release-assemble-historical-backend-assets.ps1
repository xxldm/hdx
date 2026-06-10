param(
    [Parameter(Mandatory = $true)]
    [string]$SourcesJsonPath,

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

    [string]$OutputDirectory = 'target/release/assets'
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

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Context 缺少字段：$Name"
    }

    return $property.Value
}

Assert-Pattern -Name 'Version' -Value $Version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-NoLatest -Name 'Version' -Value $Version
Assert-NoLatest -Name 'RootRef' -Value $RootRef
Assert-Pattern -Name 'RootCommit' -Value $RootCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'BackendCommit' -Value $BackendCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'OpenApiSnapshotHash' -Value $OpenApiSnapshotHash -Pattern '^[0-9a-f]{64}$' -Message '必须是 64 位小写 SHA-256。'
Assert-Pattern -Name 'BackendRepository' -Value $BackendRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'RootRepository' -Value $RootRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'

$sourcesJsonFull = Get-FullPath -Path $SourcesJsonPath
$sourcesPayload = Read-JsonFile -Path $sourcesJsonFull
$sourcesProperty = $sourcesPayload.PSObject.Properties['sources']
$sources = if ($null -ne $sourcesProperty) { @($sourcesProperty.Value) } else { @($sourcesPayload) }
if ($sources.Count -lt 1) {
    throw 'SourcesJsonPath 至少需要一个 sources 条目。'
}

$outputRootFull = Get-FullPath -Path $OutputDirectory
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $outputRootFull

if (Test-Path -LiteralPath $outputRootFull) {
    Remove-Item -LiteralPath $outputRootFull -Recurse -Force
}
New-Item -ItemType Directory -Path $outputRootFull | Out-Null

$releaseManifestCheck = Join-Path $PSScriptRoot 'release-manifest-check.ps1'
$releaseAssets = @()
$backendNativeManifestSource = $null
$backendNativeManifestSha256 = ''
$backendNativeManifestPath = ''
$historicalReleaseManifestSha256 = ''
$historicalBackendNativeManifest = $null
$historicalBuild = $null
$historicalReleaseRepository = ''
$historicalReleaseTag = ''
$seenAssetNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$seenKindPlatforms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

for ($index = 0; $index -lt $sources.Count; $index++) {
    $source = $sources[$index]
    $context = "sources[$index]"

    $sourceType = [string](Get-RequiredProperty -Object $source -Name 'type' -Context $context)
    Assert-Equal -Name "$context.type" -Actual $sourceType -Expected 'historical-release-asset'

    $sourceBackendRepository = [string](Get-RequiredProperty -Object $source -Name 'backendRepository' -Context $context)
    Assert-Equal -Name "$context.backendRepository" -Actual $sourceBackendRepository -Expected $BackendRepository

    $sourceHistoricalReleaseRepository = [string](Get-RequiredProperty -Object $source -Name 'historicalReleaseRepository' -Context $context)
    $sourceHistoricalReleaseTag = [string](Get-RequiredProperty -Object $source -Name 'historicalReleaseTag' -Context $context)
    $historicalBackendAssetName = [string](Get-RequiredProperty -Object $source -Name 'historicalBackendAssetName' -Context $context)
    $expectedAssetSha256 = [string](Get-RequiredProperty -Object $source -Name 'assetSha256' -Context $context)
    $expectedAssetSizeBytesText = [string](Get-RequiredProperty -Object $source -Name 'assetSizeBytes' -Context $context)
    $historicalAssetRoot = [string](Get-RequiredProperty -Object $source -Name 'historicalAssetRoot' -Context $context)

    Assert-Pattern -Name "$context.historicalReleaseRepository" -Value $sourceHistoricalReleaseRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
    Assert-Pattern -Name "$context.historicalReleaseTag" -Value $sourceHistoricalReleaseTag -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
    Assert-Pattern -Name "$context.historicalBackendAssetName" -Value $historicalBackendAssetName -Pattern '^[A-Za-z0-9][A-Za-z0-9._+@=-]*$' -Message '必须是单个 Release asset 文件名，不能包含路径分隔符。'
    Assert-Pattern -Name "$context.assetSha256" -Value $expectedAssetSha256 -Pattern '^[0-9a-f]{64}$' -Message '必须是 64 位小写 SHA-256。'
    Assert-Pattern -Name "$context.assetSizeBytes" -Value $expectedAssetSizeBytesText -Pattern '^[1-9][0-9]*$' -Message '必须是大于 0 的整数。'
    Assert-NoLatest -Name "$context.historicalReleaseRepository" -Value $sourceHistoricalReleaseRepository
    Assert-NoLatest -Name "$context.historicalReleaseTag" -Value $sourceHistoricalReleaseTag
    Assert-NoLatest -Name "$context.historicalBackendAssetName" -Value $historicalBackendAssetName

    if ($sourceHistoricalReleaseRepository -ne $RootRepository) {
        throw "$context.historicalReleaseRepository 必须是当前主仓库：期望 $RootRepository，实际 $sourceHistoricalReleaseRepository"
    }

    if ([string]::IsNullOrWhiteSpace($historicalReleaseRepository)) {
        $historicalReleaseRepository = $sourceHistoricalReleaseRepository
        $historicalReleaseTag = $sourceHistoricalReleaseTag
    }
    else {
        Assert-Equal -Name "$context.historicalReleaseRepository" -Actual $sourceHistoricalReleaseRepository -Expected $historicalReleaseRepository
        Assert-Equal -Name "$context.historicalReleaseTag" -Actual $sourceHistoricalReleaseTag -Expected $historicalReleaseTag
    }

    if (-not $seenAssetNames.Add($historicalBackendAssetName)) {
        throw "重复的历史 Release asset：$historicalBackendAssetName"
    }

    $historicalAssetRootFull = Get-FullPath -Path $historicalAssetRoot
    if (-not (Test-Path -LiteralPath $historicalAssetRootFull -PathType Container)) {
        throw "$context.historicalAssetRoot 不存在：$historicalAssetRootFull"
    }

    $historicalReleaseManifestPath = Join-Path $historicalAssetRootFull 'release-manifest.json'
    $historicalBackendManifestPath = Join-Path $historicalAssetRootFull 'backend-native-manifest.json'
    $historicalBackendAssetPath = Join-Path $historicalAssetRootFull $historicalBackendAssetName
    foreach ($requiredPath in @($historicalReleaseManifestPath, $historicalBackendManifestPath, $historicalBackendAssetPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "$context 历史 Release asset 目录缺少必需文件：$requiredPath"
        }
    }

    $historicalReleaseManifest = Read-JsonFile -Path $historicalReleaseManifestPath
    $sourceBackendNativeManifest = Read-JsonFile -Path $historicalBackendManifestPath
    $sourceReleaseManifestSha256 = Get-Sha256 -Path $historicalReleaseManifestPath
    $sourceBackendNativeManifestSha256 = Get-Sha256 -Path $historicalBackendManifestPath
    $sourceBackendNativeManifestSizeBytes = (Get-Item -LiteralPath $historicalBackendManifestPath).Length
    $historicalBackendAssetSha256 = Get-Sha256 -Path $historicalBackendAssetPath
    $historicalBackendAssetSizeBytes = (Get-Item -LiteralPath $historicalBackendAssetPath).Length

    Assert-Equal -Name "$context.historicalRelease.manifestKind" -Actual $historicalReleaseManifest.manifestKind -Expected 'release'
    Assert-Equal -Name "$context.historicalRelease.version" -Actual $historicalReleaseManifest.version -Expected $sourceHistoricalReleaseTag
    Assert-Equal -Name "$context.historicalRelease.root.repository" -Actual $historicalReleaseManifest.root.repository -Expected $sourceHistoricalReleaseRepository
    Assert-Equal -Name "$context.historicalRelease.backendNativeManifest.sha256" -Actual $historicalReleaseManifest.backendNativeManifest.sha256 -Expected $sourceBackendNativeManifestSha256
    Assert-Equal -Name "$context.historicalRelease.backendNativeManifest.backendCommit" -Actual $historicalReleaseManifest.backendNativeManifest.backendCommit -Expected $BackendCommit
    Assert-Equal -Name "$context.historicalRelease.openapiSnapshotHash" -Actual $historicalReleaseManifest.openapiSnapshotHash -Expected $OpenApiSnapshotHash
    Assert-Equal -Name "$context.backendNativeManifest.backend.repository" -Actual $sourceBackendNativeManifest.backend.repository -Expected $BackendRepository
    Assert-Equal -Name "$context.backendNativeManifest.backend.commit" -Actual $sourceBackendNativeManifest.backend.commit -Expected $BackendCommit
    Assert-Equal -Name "$context.backendNativeManifest.openapiSnapshotHash" -Actual $sourceBackendNativeManifest.openapiSnapshotHash -Expected $OpenApiSnapshotHash
    Assert-Equal -Name "$context.input.assetSha256" -Actual $expectedAssetSha256 -Expected $historicalBackendAssetSha256
    Assert-Equal -Name "$context.input.assetSizeBytes" -Actual ([int64]$expectedAssetSizeBytesText) -Expected $historicalBackendAssetSizeBytes

    & pwsh -NoLogo -NoProfile -File $releaseManifestCheck `
        -BackendNativeManifestPath $historicalBackendManifestPath `
        -ReleaseManifestPath $historicalReleaseManifestPath `
        -ScanPath $historicalBackendAssetPath
    if ($LASTEXITCODE -ne 0) {
        throw "$context 历史 Release manifest 校验失败，退出码：$LASTEXITCODE"
    }

    if ([string]::IsNullOrWhiteSpace($backendNativeManifestSha256)) {
        $backendNativeManifestSha256 = $sourceBackendNativeManifestSha256
        $historicalReleaseManifestSha256 = $sourceReleaseManifestSha256
        $historicalBackendNativeManifest = $sourceBackendNativeManifest
        $historicalBuild = [ordered]@{
            root = $historicalReleaseManifest.root
            backend = [ordered]@{
                repository = $BackendRepository
                commit = $BackendCommit
            }
            openapiSnapshotHash = $OpenApiSnapshotHash
            backendNativeManifestSha256 = $sourceBackendNativeManifestSha256
        }
        $backendNativeManifestSource = [ordered]@{
            type = 'historical-release-asset'
            historicalRelease = [ordered]@{
                repository = $sourceHistoricalReleaseRepository
                tag = $sourceHistoricalReleaseTag
                assetName = 'backend-native-manifest.json'
                assetSha256 = $sourceBackendNativeManifestSha256
                assetSizeBytes = [int64]$sourceBackendNativeManifestSizeBytes
                releaseManifestSha256 = $sourceReleaseManifestSha256
                backendNativeManifestSha256 = $sourceBackendNativeManifestSha256
            }
            historicalBuild = $historicalBuild
        }
        $backendNativeManifestPath = Join-Path $outputRootFull 'backend-native-manifest.json'
        Copy-Item -LiteralPath $historicalBackendManifestPath -Destination $backendNativeManifestPath
    }
    else {
        Assert-Equal -Name "$context.backendNativeManifest.sha256" -Actual $sourceBackendNativeManifestSha256 -Expected $backendNativeManifestSha256
        Assert-Equal -Name "$context.releaseManifest.sha256" -Actual $sourceReleaseManifestSha256 -Expected $historicalReleaseManifestSha256
    }

    $matchedAssets = @($historicalReleaseManifest.assets | Where-Object { $_.fileName -eq $historicalBackendAssetName })
    if ($matchedAssets.Count -ne 1) {
        $assetNames = @($historicalReleaseManifest.assets | ForEach-Object { $_.fileName }) -join ', '
        throw "$context 无法在历史 release-manifest.json 中唯一定位后端 asset：$historicalBackendAssetName；历史 assets：$assetNames"
    }

    $historicalBackendAsset = $matchedAssets[0]
    if ($historicalBackendAsset.kind -notin @('backend-full', 'backend-services')) {
        throw "$context 历史 asset 必须是 backend-full 或 backend-services，实际：$($historicalBackendAsset.kind)"
    }
    Assert-Equal -Name "$context.asset.sha256" -Actual $historicalBackendAsset.sha256 -Expected $historicalBackendAssetSha256
    Assert-Equal -Name "$context.asset.sizeBytes" -Actual ([int64]$historicalBackendAsset.sizeBytes) -Expected $historicalBackendAssetSizeBytes

    $matchedNativeArtifacts = @($sourceBackendNativeManifest.artifacts | Where-Object { $_.fileName -eq $historicalBackendAssetName })
    if ($matchedNativeArtifacts.Count -ne 1) {
        $nativeNames = @($sourceBackendNativeManifest.artifacts | ForEach-Object { $_.fileName }) -join ', '
        throw "$context 无法在历史 backend-native-manifest.json 中唯一定位后端 asset：$historicalBackendAssetName；历史 native assets：$nativeNames"
    }
    $nativeArtifact = $matchedNativeArtifacts[0]
    Assert-Equal -Name "$context.nativeArtifact.kind" -Actual $nativeArtifact.kind -Expected $historicalBackendAsset.kind
    Assert-Equal -Name "$context.nativeArtifact.platform" -Actual $nativeArtifact.platform -Expected $historicalBackendAsset.platform
    Assert-Equal -Name "$context.nativeArtifact.sha256" -Actual $nativeArtifact.sha256 -Expected $historicalBackendAssetSha256
    Assert-Equal -Name "$context.nativeArtifact.sizeBytes" -Actual ([int64]$nativeArtifact.sizeBytes) -Expected $historicalBackendAssetSizeBytes

    $historicalAssetSource = Get-RequiredProperty -Object $historicalBackendAsset -Name 'source' -Context "$context.asset"
    $fingerprint = Get-RequiredProperty -Object $historicalAssetSource -Name 'backendNativeFingerprint' -Context "$context.asset.source"
    Assert-Equal -Name "$context.fingerprint.algorithm" -Actual $fingerprint.algorithm -Expected 'hdx-backend-native-fingerprint-v1'
    Assert-Equal -Name "$context.fingerprint.backend.repository" -Actual $fingerprint.backend.repository -Expected $BackendRepository
    Assert-Equal -Name "$context.fingerprint.backend.commit" -Actual $fingerprint.backend.commit -Expected $BackendCommit
    Assert-Equal -Name "$context.fingerprint.openapiSnapshotHash" -Actual $fingerprint.openapiSnapshotHash -Expected $OpenApiSnapshotHash
    Assert-Equal -Name "$context.fingerprint.artifact.kind" -Actual $fingerprint.artifact.kind -Expected $historicalBackendAsset.kind
    Assert-Equal -Name "$context.fingerprint.artifact.platform" -Actual $fingerprint.artifact.platform -Expected $historicalBackendAsset.platform

    $assetHistoricalBuild = $historicalBuild
    $historicalBuildProperty = $historicalAssetSource.PSObject.Properties['historicalBuild']
    if ($null -ne $historicalBuildProperty -and $null -ne $historicalBuildProperty.Value) {
        $assetHistoricalBuild = $historicalBuildProperty.Value
    }

    $kindPlatform = "$($historicalBackendAsset.kind)/$($historicalBackendAsset.platform)"
    if (-not $seenKindPlatforms.Add($kindPlatform)) {
        throw "重复的历史后端 native asset kind/platform：$kindPlatform"
    }

    $targetAssetPath = Join-Path $outputRootFull $historicalBackendAssetName
    Copy-Item -LiteralPath $historicalBackendAssetPath -Destination $targetAssetPath

    $releaseAssets += [ordered]@{
        kind = $historicalBackendAsset.kind
        platform = $historicalBackendAsset.platform
        fileName = $historicalBackendAssetName
        contentType = Get-ContentType -FileName $historicalBackendAssetName
        sha256 = $historicalBackendAssetSha256
        sizeBytes = [int64]$historicalBackendAssetSizeBytes
        source = [ordered]@{
            type = 'historical-release-asset'
            commit = $BackendCommit
            historicalRelease = [ordered]@{
                repository = $sourceHistoricalReleaseRepository
                tag = $sourceHistoricalReleaseTag
                assetName = $historicalBackendAssetName
                assetSha256 = $historicalBackendAssetSha256
                assetSizeBytes = [int64]$historicalBackendAssetSizeBytes
                releaseManifestSha256 = $sourceReleaseManifestSha256
                backendNativeManifestSha256 = $sourceBackendNativeManifestSha256
            }
            historicalBuild = $assetHistoricalBuild
            backendNativeFingerprint = $fingerprint
        }
    }
}

foreach ($nativeArtifact in @($historicalBackendNativeManifest.artifacts)) {
    if (-not $seenAssetNames.Contains([string]$nativeArtifact.fileName)) {
        throw "historical-release-asset 多来源必须覆盖 backend-native-manifest.json 中的全部资产；缺少：$($nativeArtifact.fileName)"
    }
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
        sha256 = $backendNativeManifestSha256
        backendCommit = $BackendCommit
        source = $backendNativeManifestSource
    }
    assets = $releaseAssets
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
    -BackendNativeManifestPath $backendNativeManifestPath `
    -ReleaseManifestPath $releaseManifestPath `
    -AssetRoot $outputRootFull `
    -ScanPath $outputRootFull
if ($LASTEXITCODE -ne 0) {
    throw "Release 历史多后端资产校验失败，退出码：$LASTEXITCODE"
}

Write-Host 'Release 历史后端 native assets 已生成并通过本地校验。'
Write-Host "历史 Release：$historicalReleaseRepository@$historicalReleaseTag"
Write-Host "资产目录：$outputRootFull"
Get-ChildItem -LiteralPath $outputRootFull -File | Sort-Object Name | Select-Object Name, Length | Format-Table | Out-String | Write-Host
