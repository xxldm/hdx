param(
    [Parameter(Mandatory = $true)]
    [string]$HistoricalAssetRoot,

    [Parameter(Mandatory = $true)]
    [string]$RequiredAssetsJsonPath,

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

    [string]$OutputPath = 'target/release-resolve/backend-source-resolution.json'
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

function New-ReuseRequiredBuildError {
    param([Parameter(Mandatory = $true)][string]$Reason)
    return "无法复用历史 Release asset，需要重新运行后端 native workflow。原因：$Reason"
}

Assert-Pattern -Name 'Version' -Value $Version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-Pattern -Name 'RootRepository' -Value $RootRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'BackendRepository' -Value $BackendRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'RootCommit' -Value $RootCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'BackendCommit' -Value $BackendCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'OpenApiSnapshotHash' -Value $OpenApiSnapshotHash -Pattern '^[0-9a-f]{64}$' -Message '必须是 64 位小写 SHA-256。'
Assert-NoLatest -Name 'Version' -Value $Version
Assert-NoLatest -Name 'RootRef' -Value $RootRef

$historicalRootFull = Get-FullPath -Path $HistoricalAssetRoot
if (-not (Test-Path -LiteralPath $historicalRootFull -PathType Container)) {
    throw "HistoricalAssetRoot 不存在：$historicalRootFull"
}

$requiredAssetsFull = Get-FullPath -Path $RequiredAssetsJsonPath
$requiredPayload = Read-JsonFile -Path $requiredAssetsFull
$requiredProperty = $requiredPayload.PSObject.Properties['assets']
$requiredAssets = if ($null -ne $requiredProperty) { @($requiredProperty.Value) } else { @($requiredPayload) }
if ($requiredAssets.Count -lt 1) {
    throw 'RequiredAssetsJsonPath 至少需要一个 assets 条目。'
}

$historicalReleaseManifestPath = Join-Path $historicalRootFull 'release-manifest.json'
$historicalBackendManifestPath = Join-Path $historicalRootFull 'backend-native-manifest.json'
$historicalReleaseManifest = Read-JsonFile -Path $historicalReleaseManifestPath
$historicalBackendManifest = Read-JsonFile -Path $historicalBackendManifestPath
$historicalReleaseManifestSha256 = Get-Sha256 -Path $historicalReleaseManifestPath
$historicalBackendManifestSha256 = Get-Sha256 -Path $historicalBackendManifestPath

Assert-Equal -Name 'historicalRelease.manifestKind' -Actual $historicalReleaseManifest.manifestKind -Expected 'release'
Assert-Equal -Name 'historicalRelease.root.repository' -Actual $historicalReleaseManifest.root.repository -Expected $RootRepository
Assert-NoLatest -Name 'historicalRelease.version' -Value $historicalReleaseManifest.version
Assert-NoLatest -Name 'historicalRelease.root.ref' -Value $historicalReleaseManifest.root.ref
Assert-Equal -Name 'historicalRelease.backendNativeManifest.sha256' -Actual $historicalReleaseManifest.backendNativeManifest.sha256 -Expected $historicalBackendManifestSha256
Assert-Equal -Name 'historicalRelease.backendNativeManifest.backendCommit' -Actual $historicalReleaseManifest.backendNativeManifest.backendCommit -Expected $BackendCommit
Assert-Equal -Name 'historicalRelease.openapiSnapshotHash' -Actual $historicalReleaseManifest.openapiSnapshotHash -Expected $OpenApiSnapshotHash
Assert-Equal -Name 'historicalBackendManifest.backend.repository' -Actual $historicalBackendManifest.backend.repository -Expected $BackendRepository
Assert-Equal -Name 'historicalBackendManifest.backend.commit' -Actual $historicalBackendManifest.backend.commit -Expected $BackendCommit
Assert-Equal -Name 'historicalBackendManifest.openapiSnapshotHash' -Actual $historicalBackendManifest.openapiSnapshotHash -Expected $OpenApiSnapshotHash

$releaseManifestCheck = Join-Path $PSScriptRoot 'release-manifest-check.ps1'
& pwsh -NoLogo -NoProfile -File $releaseManifestCheck `
    -BackendNativeManifestPath $historicalBackendManifestPath `
    -ReleaseManifestPath $historicalReleaseManifestPath `
    -ScanPath $historicalRootFull
if ($LASTEXITCODE -ne 0) {
    throw (New-ReuseRequiredBuildError -Reason "历史 release manifest 或 backend native manifest 校验失败，退出码：$LASTEXITCODE")
}

$seenRequired = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$resolvedSources = @()

for ($index = 0; $index -lt $requiredAssets.Count; $index++) {
    $required = $requiredAssets[$index]
    $context = "assets[$index]"
    $kind = [string](Get-RequiredProperty -Object $required -Name 'kind' -Context $context)
    $platform = [string](Get-RequiredProperty -Object $required -Name 'platform' -Context $context)
    if ($kind -notin @('backend-full', 'backend-services')) {
        throw "$context.kind 无效：$kind"
    }
    if ($platform -notin @('linux-x64', 'windows-x64')) {
        throw "$context.platform 无效：$platform"
    }

    $key = "$kind/$platform"
    if (-not $seenRequired.Add($key)) {
        throw "重复的 required backend asset：$key"
    }

    $matchedAssets = @($historicalReleaseManifest.assets | Where-Object { $_.kind -eq $kind -and $_.platform -eq $platform })
    if ($matchedAssets.Count -ne 1) {
        throw (New-ReuseRequiredBuildError -Reason "历史 release 中无法唯一定位 $key，匹配数量：$($matchedAssets.Count)")
    }
    $matchedNativeArtifacts = @($historicalBackendManifest.artifacts | Where-Object { $_.kind -eq $kind -and $_.platform -eq $platform })
    if ($matchedNativeArtifacts.Count -ne 1) {
        throw (New-ReuseRequiredBuildError -Reason "历史 backend-native-manifest 中无法唯一定位 $key，匹配数量：$($matchedNativeArtifacts.Count)")
    }

    $asset = $matchedAssets[0]
    $nativeArtifact = $matchedNativeArtifacts[0]
    Assert-Equal -Name "$key.fileName" -Actual $asset.fileName -Expected $nativeArtifact.fileName
    Assert-Equal -Name "$key.sha256" -Actual $asset.sha256 -Expected $nativeArtifact.sha256
    Assert-Equal -Name "$key.sizeBytes" -Actual ([int64]$asset.sizeBytes) -Expected ([int64]$nativeArtifact.sizeBytes)

    $assetPath = Join-Path $historicalRootFull $asset.fileName
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw (New-ReuseRequiredBuildError -Reason "历史 Release asset 文件缺失：$($asset.fileName)")
    }
    Assert-Equal -Name "$key.fileSha256" -Actual (Get-Sha256 -Path $assetPath) -Expected $asset.sha256
    Assert-Equal -Name "$key.fileSizeBytes" -Actual ([int64](Get-Item -LiteralPath $assetPath).Length) -Expected ([int64]$asset.sizeBytes)

    $source = Get-RequiredProperty -Object $asset -Name 'source' -Context "$key.asset"
    $fingerprint = Get-RequiredProperty -Object $source -Name 'backendNativeFingerprint' -Context "$key.asset.source"
    Assert-Equal -Name "$key.fingerprint.algorithm" -Actual $fingerprint.algorithm -Expected 'hdx-backend-native-fingerprint-v1'
    Assert-Equal -Name "$key.fingerprint.backend.repository" -Actual $fingerprint.backend.repository -Expected $BackendRepository
    Assert-Equal -Name "$key.fingerprint.backend.commit" -Actual $fingerprint.backend.commit -Expected $BackendCommit
    Assert-Equal -Name "$key.fingerprint.openapiSnapshotHash" -Actual $fingerprint.openapiSnapshotHash -Expected $OpenApiSnapshotHash
    Assert-Equal -Name "$key.fingerprint.artifact.kind" -Actual $fingerprint.artifact.kind -Expected $kind
    Assert-Equal -Name "$key.fingerprint.artifact.platform" -Actual $fingerprint.artifact.platform -Expected $platform

    $resolvedSources += [ordered]@{
        type = 'historical-release-asset'
        backendRepository = $BackendRepository
        historicalReleaseRepository = $RootRepository
        historicalReleaseTag = $historicalReleaseManifest.version
        historicalBackendAssetName = $asset.fileName
        assetSha256 = $asset.sha256
        assetSizeBytes = [int64]$asset.sizeBytes
    }
}

$backendSourcesJson = [ordered]@{
    sources = $resolvedSources
}

$resolution = [ordered]@{
    schemaVersion = '1.0'
    resolutionKind = 'backend-source'
    version = $Version
    root = [ordered]@{
        repository = $RootRepository
        ref = $RootRef
        commit = $RootCommit
    }
    backend = [ordered]@{
        repository = $BackendRepository
        commit = $BackendCommit
    }
    openapiSnapshotHash = $OpenApiSnapshotHash
    backendSourceMode = 'historical-release-asset'
    backendSourcesJson = $backendSourcesJson
    backendSourcesJsonCompact = ($backendSourcesJson | ConvertTo-Json -Depth 100 -Compress)
    historicalRelease = [ordered]@{
        repository = $RootRepository
        tag = $historicalReleaseManifest.version
        releaseManifestSha256 = $historicalReleaseManifestSha256
        backendNativeManifestSha256 = $historicalBackendManifestSha256
    }
}

$outputFull = Get-FullPath -Path $OutputPath
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $outputFull
$outputParent = Split-Path -Parent $outputFull
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
    New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
}

$resolution | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outputFull

Write-Host '后端来源解析完成：可复用历史 Release asset。'
Write-Host "backend_source_mode：historical-release-asset"
Write-Host "historical_release：$RootRepository@$($historicalReleaseManifest.version)"
Write-Host "backend_sources_json：$($resolution.backendSourcesJsonCompact)"
Write-Host "输出文件：$outputFull"
