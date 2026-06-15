param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$DesktopAssetsDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DesktopRepository,

    [Parameter(Mandatory = $true)]
    [string]$DesktopCommit,

    [ValidateSet('stable', 'preview', 'nightly', 'manual')]
    [string]$ReleaseChannel = 'stable',

    [string]$AssetRoot = 'target/release/assets',

    [string]$DesktopPath = 'apps/desktop'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib/release-common.ps1')

function Get-JsonStringProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return ''
    }
    return [string]$property.Value
}

Assert-Pattern -Name 'DesktopRepository' -Value $DesktopRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'DesktopCommit' -Value $DesktopCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-NoLatest -Name 'DesktopRepository' -Value $DesktopRepository
Assert-NoLatest -Name 'ReleaseChannel' -Value $ReleaseChannel

$targetRoot = Join-Path $RepoRoot 'target'
$assetRootFull = Get-FullPath -Path $AssetRoot
$desktopAssetsFull = Get-FullPath -Path $DesktopAssetsDirectory
$releaseManifestFull = Get-FullPath -Path $ReleaseManifestPath

Assert-PathWithin -Parent $targetRoot -Child $assetRootFull
Assert-PathWithin -Parent $targetRoot -Child $desktopAssetsFull
Assert-PathWithin -Parent $assetRootFull -Child $releaseManifestFull

if (-not (Test-Path -LiteralPath $assetRootFull -PathType Container)) {
    throw "AssetRoot 不存在：$assetRootFull"
}
if (-not (Test-Path -LiteralPath $desktopAssetsFull -PathType Container)) {
    throw "DesktopAssetsDirectory 不存在：$desktopAssetsFull"
}

$manifest = Read-JsonFile -Path $releaseManifestFull
$version = [string]$manifest.version
Assert-Pattern -Name 'release manifest version' -Value $version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-NoLatest -Name 'release manifest version' -Value $version

$definitions = @(
    [ordered]@{
        fileName = "HDX.Desktop.Online_windows-x64_${version}_setup.exe"
        kind = 'desktop-installer'
        platform = 'windows-x64'
        flavor = 'online'
        packaging = 'nsis'
        contentType = 'application/vnd.microsoft.portable-executable'
    },
    [ordered]@{
        fileName = "HDX.Desktop.Online_windows-x64_${version}_portable.zip"
        kind = 'desktop-portable'
        platform = 'windows-x64'
        flavor = 'online'
        packaging = 'zip'
        contentType = 'application/zip'
    },
    [ordered]@{
        fileName = "HDX.Desktop.Online_linux-x64_${version}.AppImage"
        kind = 'desktop-appimage'
        platform = 'linux-x64'
        flavor = 'online'
        packaging = 'appimage'
        contentType = 'application/vnd.appimage'
    },
    [ordered]@{
        fileName = "HDX.Desktop.Full_windows-x64_${version}_setup.exe"
        kind = 'desktop-installer'
        platform = 'windows-x64'
        flavor = 'full'
        packaging = 'nsis'
        contentType = 'application/vnd.microsoft.portable-executable'
    },
    [ordered]@{
        fileName = "HDX.Desktop.Full_windows-x64_${version}_portable.zip"
        kind = 'desktop-portable'
        platform = 'windows-x64'
        flavor = 'full'
        packaging = 'zip'
        contentType = 'application/zip'
    },
    [ordered]@{
        fileName = "HDX.Desktop.Full_linux-x64_${version}.AppImage"
        kind = 'desktop-appimage'
        platform = 'linux-x64'
        flavor = 'full'
        packaging = 'appimage'
        contentType = 'application/vnd.appimage'
    }
)

$sources = Copy-JsonObjectProperties -Object $manifest.sources
if ($sources.Contains('desktop')) {
    $existingDesktop = $sources['desktop']
    $existingRepository = Get-JsonStringProperty -Object $existingDesktop -Name 'repository'
    $existingCommit = Get-JsonStringProperty -Object $existingDesktop -Name 'commit'
    $existingPath = Get-JsonStringProperty -Object $existingDesktop -Name 'path'
    if ($existingRepository -ne $DesktopRepository -or $existingCommit -ne $DesktopCommit -or $existingPath -ne $DesktopPath) {
        throw "release-manifest.json 已包含不同的 sources.desktop：$existingRepository@$existingCommit path=$existingPath"
    }
}
else {
    $sources['desktop'] = [ordered]@{
        repository = $DesktopRepository
        commit = $DesktopCommit
        path = $DesktopPath
    }
}

$assets = @($manifest.assets)
$addedAssets = @()
foreach ($definition in $definitions) {
    $sourcePath = Join-Path $desktopAssetsFull $definition.fileName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        continue
    }

    $destinationPath = Join-Path $assetRootFull $definition.fileName
    $sourceFull = [System.IO.Path]::GetFullPath($sourcePath)
    $destinationFull = [System.IO.Path]::GetFullPath($destinationPath)
    Assert-PathWithin -Parent $assetRootFull -Child $destinationFull

    $duplicateAssets = @(
        $assets | Where-Object {
            $_.fileName -eq $definition.fileName -or
            (
                $_.kind -eq $definition.kind -and
                $_.platform -eq $definition.platform -and
                $_.flavor -eq $definition.flavor -and
                $_.packaging -eq $definition.packaging
            )
        }
    )
    if ($duplicateAssets.Count -gt 0) {
        throw "release-manifest.json 已包含 Desktop asset 或同名文件：$($definition.fileName)"
    }

    if ($sourceFull -ne $destinationFull) {
        Copy-Item -LiteralPath $sourceFull -Destination $destinationFull -Force
    }

    $assetFile = Get-Item -LiteralPath $destinationFull
    $assets += [ordered]@{
        kind = $definition.kind
        platform = $definition.platform
        flavor = $definition.flavor
        packaging = $definition.packaging
        channel = $ReleaseChannel
        fileName = $definition.fileName
        contentType = $definition.contentType
        sha256 = Get-Sha256 -Path $destinationFull
        sizeBytes = [int64]$assetFile.Length
        source = [ordered]@{
            type = 'desktop'
            commit = $DesktopCommit
        }
    }
    $addedAssets += $definition.fileName
}

if ($addedAssets.Count -lt 1) {
    throw "未找到可追加的 Desktop Release asset。目录：$desktopAssetsFull"
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
    throw "追加 Desktop asset 后 Release manifest 校验失败，退出码：$LASTEXITCODE"
}

Write-Host 'Desktop asset 已追加到 release-manifest.json，并通过校验。'
foreach ($assetName in $addedAssets) {
    Write-Host "Desktop asset：$assetName"
}
