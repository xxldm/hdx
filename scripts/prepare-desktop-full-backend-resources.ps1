param(
    [Parameter(Mandatory = $true)]
    [string]$BackendAssetsDirectory,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('windows-x64', 'linux-x64')]
    [string]$Platform,

    [Parameter(Mandatory = $true)]
    [string]$RootRepository,

    [Parameter(Mandatory = $true)]
    [string]$RootRef,

    [Parameter(Mandatory = $true)]
    [string]$RootCommit,

    [Parameter(Mandatory = $true)]
    [string]$BackendCommit,

    [Parameter(Mandatory = $true)]
    [string]$DesktopCommit,

    [string]$OutputDirectory = 'target/release/desktop-full-backend'
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

Assert-Pattern -Name 'Version' -Value $Version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-NoLatest -Name 'Version' -Value $Version
Assert-NoLatest -Name 'RootRef' -Value $RootRef
Assert-Pattern -Name 'RootCommit' -Value $RootCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'BackendCommit' -Value $BackendCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'DesktopCommit' -Value $DesktopCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'RootRepository' -Value $RootRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'

$targetRoot = Join-Path $RepoRoot 'target'
$backendAssetsFull = Get-FullPath -Path $BackendAssetsDirectory
$outputFull = Get-FullPath -Path $OutputDirectory
Assert-PathWithin -Parent $targetRoot -Child $backendAssetsFull
Assert-PathWithin -Parent $targetRoot -Child $outputFull

if (-not (Test-Path -LiteralPath $backendAssetsFull -PathType Container)) {
    throw "BackendAssetsDirectory 不存在：$backendAssetsFull"
}

$backendNativeManifestPath = Join-Path $backendAssetsFull 'backend-native-manifest.json'
$releaseManifestPath = Join-Path $backendAssetsFull 'release-manifest.json'
$backendNativeManifest = Read-JsonFile -Path $backendNativeManifestPath
$releaseManifest = Read-JsonFile -Path $releaseManifestPath
$manifestSha256 = Get-Sha256 -Path $backendNativeManifestPath

if ($backendNativeManifest.manifestKind -ne 'backend-native') {
    throw "backend-native-manifest.json manifestKind 无效：$($backendNativeManifest.manifestKind)"
}
if ($releaseManifest.manifestKind -ne 'release') {
    throw "release-manifest.json manifestKind 无效：$($releaseManifest.manifestKind)"
}
if ($releaseManifest.version -ne $Version) {
    throw "release-manifest.json version 不一致：期望 $Version，实际 $($releaseManifest.version)"
}
if ($releaseManifest.root.repository -ne $RootRepository -or
    $releaseManifest.root.ref -ne $RootRef -or
    $releaseManifest.root.commit -ne $RootCommit) {
    throw 'release-manifest.json root 与当前发布事实源不一致。'
}
if ($backendNativeManifest.backend.commit -ne $BackendCommit) {
    throw "backend-native-manifest.json backend commit 不一致：期望 $BackendCommit，实际 $($backendNativeManifest.backend.commit)"
}
if ($releaseManifest.backendNativeManifest.sha256 -ne $manifestSha256) {
    throw "release-manifest.json 记录的 backend-native-manifest sha256 不一致：期望 $manifestSha256，实际 $($releaseManifest.backendNativeManifest.sha256)"
}
if ($releaseManifest.backendNativeManifest.backendCommit -ne $BackendCommit) {
    throw "release-manifest.json backendNativeManifest.backendCommit 不一致：期望 $BackendCommit，实际 $($releaseManifest.backendNativeManifest.backendCommit)"
}

$matchedArtifacts = @(
    $backendNativeManifest.artifacts | Where-Object {
        $_.kind -eq 'backend-full' -and $_.platform -eq $Platform
    }
)
if ($matchedArtifacts.Count -ne 1) {
    $available = @($backendNativeManifest.artifacts | ForEach-Object { "$($_.kind)/$($_.platform)/$($_.fileName)" }) -join ', '
    throw "无法唯一定位同平台 backend-full：$Platform；当前 artifacts：$available"
}

$backendArtifact = $matchedArtifacts[0]
$matchedReleaseAssets = @(
    $releaseManifest.assets | Where-Object {
        $_.kind -eq 'backend-full' -and $_.platform -eq $Platform -and $_.fileName -eq $backendArtifact.fileName
    }
)
if ($matchedReleaseAssets.Count -ne 1) {
    $available = @($releaseManifest.assets | ForEach-Object { "$($_.kind)/$($_.platform)/$($_.fileName)" }) -join ', '
    throw "无法在 release-manifest.json 中唯一定位同平台 backend-full：$Platform；当前 assets：$available"
}

$releaseAsset = $matchedReleaseAssets[0]
$archivePath = Join-Path $backendAssetsFull ([string]$backendArtifact.fileName)
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    throw "backend-full archive 不存在：$archivePath"
}

$archiveSha256 = Get-Sha256 -Path $archivePath
if ($archiveSha256 -ne [string]$backendArtifact.sha256) {
    throw "backend-full archive sha256 不一致：期望 $($backendArtifact.sha256)，实际 $archiveSha256"
}
if ($archiveSha256 -ne [string]$releaseAsset.sha256) {
    throw "release-manifest.json 记录的 backend-full archive sha256 不一致：期望 $archiveSha256，实际 $($releaseAsset.sha256)"
}

$archiveItem = Get-Item -LiteralPath $archivePath
if ([int64]$archiveItem.Length -ne [int64]$backendArtifact.sizeBytes) {
    throw "backend-full archive size 不一致：期望 $($backendArtifact.sizeBytes)，实际 $($archiveItem.Length)"
}
if ([int64]$archiveItem.Length -ne [int64]$releaseAsset.sizeBytes) {
    throw "release-manifest.json 记录的 backend-full archive size 不一致：期望 $($archiveItem.Length)，实际 $($releaseAsset.sizeBytes)"
}

$entrypoints = @($backendArtifact.entrypoints)
if ($entrypoints.Count -ne 1) {
    throw "backend-full 必须记录唯一 entrypoint，实际数量：$($entrypoints.Count)"
}
$entrypoint = [string]$entrypoints[0]
if ([string]::IsNullOrWhiteSpace($entrypoint)) {
    throw 'backend-full entrypoint 不能为空。'
}

$expectedArchivePattern = if ($Platform -eq 'windows-x64') {
    '^hdx-backend-full-windows-x64-v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\.zip$'
}
else {
    '^hdx-backend-full-linux-x64-v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\.tar\.gz$'
}
Assert-Pattern -Name 'backend-full archiveFileName' -Value ([string]$backendArtifact.fileName) -Pattern $expectedArchivePattern -Message '必须匹配平台和版本命名规则。'
Assert-NoLatest -Name 'backend-full archiveFileName' -Value ([string]$backendArtifact.fileName)

if (Test-Path -LiteralPath $outputFull) {
    Remove-Item -LiteralPath $outputFull -Recurse -Force
}
New-Item -ItemType Directory -Path $outputFull | Out-Null

$archiveDestinationPath = Join-Path $outputFull ([string]$backendArtifact.fileName)
Copy-Item -LiteralPath $archivePath -Destination $archiveDestinationPath -Force

$backendBuild = [ordered]@{
    schemaVersion = '1.0'
    manifestKind = 'backend-build'
    version = $Version
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    root = [ordered]@{
        repository = $RootRepository
        ref = $RootRef
        commit = $RootCommit
    }
    desktop = [ordered]@{
        commit = $DesktopCommit
        flavor = 'full'
        platform = $Platform
    }
    backend = [ordered]@{
        kind = 'backend-full'
        commit = $BackendCommit
        archiveFileName = [string]$backendArtifact.fileName
        archiveSha256 = $archiveSha256
        manifestSha256 = $manifestSha256
        executablePath = $entrypoint
    }
}

$backendBuildPath = Join-Path $outputFull 'backend-build.json'
$backendBuild | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $backendBuildPath

$releaseManifestCheck = Join-Path $PSScriptRoot 'release-manifest-check.ps1'
& pwsh -NoLogo -NoProfile -File $releaseManifestCheck `
    -SkipExamples `
    -BackendNativeManifestPath $backendNativeManifestPath `
    -ReleaseManifestPath $releaseManifestPath `
    -AssetRoot $backendAssetsFull `
    -ScanPath $archivePath
if ($LASTEXITCODE -ne 0) {
    throw "后端 Release 资产校验失败，退出码：$LASTEXITCODE"
}

& pwsh -NoLogo -NoProfile -File $releaseManifestCheck `
    -SkipExamples `
    -BackendBuildPath $backendBuildPath `
    -AssetRoot $outputFull `
    -ScanPath $archiveDestinationPath
if ($LASTEXITCODE -ne 0) {
    throw "Desktop Full 后端资源校验失败，退出码：$LASTEXITCODE"
}

Write-Host 'Desktop Full 后端资源已准备完成。'
Write-Host "平台：$Platform"
Write-Host "后端 archive：$($backendArtifact.fileName)"
Write-Host "backend-build.json：$backendBuildPath"
