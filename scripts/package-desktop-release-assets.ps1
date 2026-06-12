param(
    [string]$DesktopRoot = 'apps/desktop',

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('online', 'full')]
    [string]$Flavor,

    [Parameter(Mandatory = $true)]
    [ValidateSet('windows-x64', 'linux-x64')]
    [string]$Platform,

    [string]$OutputDirectory = 'target/release/desktop-assets',

    [string]$RootCommit = '',

    [string]$DesktopCommit = '',

    [string]$FullBackendResourcesDirectory = ''
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

Assert-Pattern -Name 'Version' -Value $Version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
if ($Version -match '(?i)latest') {
    throw "Version 不能包含 latest：$Version"
}
if (-not [string]::IsNullOrWhiteSpace($RootCommit)) {
    Assert-Pattern -Name 'RootCommit' -Value $RootCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
}
if (-not [string]::IsNullOrWhiteSpace($DesktopCommit)) {
    Assert-Pattern -Name 'DesktopCommit' -Value $DesktopCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
}

$desktopRootFull = Get-FullPath -Path $DesktopRoot
$outputFull = Get-FullPath -Path $OutputDirectory
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $RepoRoot -Child $desktopRootFull
Assert-PathWithin -Parent $targetRoot -Child $outputFull

$fullBackendResourcesFull = ''
if (-not [string]::IsNullOrWhiteSpace($FullBackendResourcesDirectory)) {
    $fullBackendResourcesFull = Get-FullPath -Path $FullBackendResourcesDirectory
    Assert-PathWithin -Parent $targetRoot -Child $fullBackendResourcesFull
    if (-not (Test-Path -LiteralPath $fullBackendResourcesFull -PathType Container)) {
        throw "FullBackendResourcesDirectory 不存在：$fullBackendResourcesFull"
    }
}

if (-not (Test-Path -LiteralPath $desktopRootFull -PathType Container)) {
    throw "DesktopRoot 不存在：$desktopRootFull"
}
New-Item -ItemType Directory -Path $outputFull -Force | Out-Null

$flavorTitle = if ($Flavor -eq 'online') { 'Online' } else { 'Full' }
$productName = "HDX.Desktop.$flavorTitle"
$binaryName = "HDX Desktop $flavorTitle"

if ($Platform -eq 'windows-x64') {
    $nsisDir = Join-Path $desktopRootFull 'src-tauri/target/release/bundle/nsis'
    $setupCandidates = @(Get-ChildItem -LiteralPath $nsisDir -Filter '*setup.exe' -File)
    if ($setupCandidates.Count -ne 1) {
        $names = $setupCandidates | ForEach-Object { $_.Name } | Join-String -Separator ', '
        throw "无法唯一定位 NSIS 安装包，候选：$names"
    }

    $portableExePath = Join-Path $desktopRootFull "src-tauri/target/release/$binaryName.exe"
    if (-not (Test-Path -LiteralPath $portableExePath -PathType Leaf)) {
        throw "无法定位 Desktop 裸 EXE：$portableExePath"
    }

    $setupAssetName = "$productName`_$Platform`_$Version`_setup.exe"
    $portableAssetName = "$productName`_$Platform`_$Version`_portable.zip"
    Copy-Item -LiteralPath $setupCandidates[0].FullName -Destination (Join-Path $outputFull $setupAssetName) -Force

    $portableRoot = Join-Path $targetRoot "desktop-portable/$Flavor-$Platform"
    if (Test-Path -LiteralPath $portableRoot) {
        Remove-Item -LiteralPath $portableRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $portableRoot -Force | Out-Null
    Copy-Item -LiteralPath $portableExePath -Destination (Join-Path $portableRoot "$binaryName.exe") -Force

    foreach ($documentName in @('README.md', 'LICENSE', 'NOTICE')) {
        $documentPath = Join-Path $desktopRootFull $documentName
        if (Test-Path -LiteralPath $documentPath -PathType Leaf) {
            Copy-Item -LiteralPath $documentPath -Destination (Join-Path $portableRoot $documentName) -Force
        }
    }

    if ($Flavor -eq 'full') {
        if ([string]::IsNullOrWhiteSpace($fullBackendResourcesFull)) {
            throw 'Full Windows 绿色包必须提供 FullBackendResourcesDirectory，确保包含 backend-build.json 和同平台 backend-full archive。'
        }

        $portableBackendRoot = Join-Path $portableRoot 'backend'
        New-Item -ItemType Directory -Path $portableBackendRoot -Force | Out-Null
        foreach ($resource in Get-ChildItem -LiteralPath $fullBackendResourcesFull -Force) {
            Copy-Item -LiteralPath $resource.FullName -Destination $portableBackendRoot -Recurse -Force
        }
    }

    @(
        "HDX Desktop $flavorTitle 绿色包"
        ''
        "version：$Version"
        "platform：$Platform"
        "root_commit：$RootCommit"
        "desktop_commit：$DesktopCommit"
        ''
        '运行配置写入用户级应用配置位置。'
        '本绿色包不包含另一套默认配置模板。'
    ) | Set-Content -LiteralPath (Join-Path $portableRoot 'RELEASE.txt')

    $portableArchivePath = Join-Path $outputFull $portableAssetName
    if (Test-Path -LiteralPath $portableArchivePath) {
        Remove-Item -LiteralPath $portableArchivePath -Force
    }
    Compress-Archive -Path (Join-Path $portableRoot '*') -DestinationPath $portableArchivePath -CompressionLevel Optimal

    Write-Host "Desktop Windows assets：$setupAssetName, $portableAssetName"
}
elseif ($Platform -eq 'linux-x64') {
    $appImageDir = Join-Path $desktopRootFull 'src-tauri/target/release/bundle/appimage'
    $appImageCandidates = @(Get-ChildItem -LiteralPath $appImageDir -Filter '*.AppImage' -File)
    if ($appImageCandidates.Count -ne 1) {
        $names = $appImageCandidates | ForEach-Object { $_.Name } | Join-String -Separator ', '
        throw "无法唯一定位 AppImage，候选：$names"
    }

    $appImageAssetName = "$productName`_$Platform`_$Version.AppImage"
    Copy-Item -LiteralPath $appImageCandidates[0].FullName -Destination (Join-Path $outputFull $appImageAssetName) -Force

    Write-Host "Desktop Linux asset：$appImageAssetName"
}
else {
    throw "未知 Desktop platform：$Platform"
}
