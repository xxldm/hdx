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
. (Join-Path $PSScriptRoot 'lib/release-common.ps1')

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
$tauriVersion = $Version.Substring(1) -replace '\+.*$', ''
Assert-Pattern -Name 'TauriVersion' -Value $tauriVersion -Pattern '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$' -Message '必须是 release tag 去掉前缀 v 和 build metadata 后的 Tauri 版本。'

function Format-CandidateNames {
    param([object[]]$Candidates)

    if ($Candidates.Count -lt 1) {
        return '无'
    }

    return ($Candidates | ForEach-Object { $_.Name }) -join ', '
}

function Select-SingleBundleFile {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$Filter,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "$Description 目录不存在：$Directory"
    }

    $matchedCandidates = @(Get-ChildItem -LiteralPath $Directory -Filter $Filter -File)
    if ($matchedCandidates.Count -ne 1) {
        $allCandidates = @(Get-ChildItem -LiteralPath $Directory -File)
        throw "无法唯一定位 $Description，匹配模式：$Filter；匹配候选：$(Format-CandidateNames -Candidates $matchedCandidates)；目录候选：$(Format-CandidateNames -Candidates $allCandidates)"
    }

    return $matchedCandidates[0]
}

if ($Platform -eq 'windows-x64') {
    $nsisDir = Join-Path $desktopRootFull 'src-tauri/target/release/bundle/nsis'
    $setupFile = Select-SingleBundleFile `
        -Directory $nsisDir `
        -Filter "$productName`_$tauriVersion`_x64-setup.exe" `
        -Description 'NSIS 安装包'

    $portableExePath = Join-Path $desktopRootFull "src-tauri/target/release/$binaryName.exe"
    if (-not (Test-Path -LiteralPath $portableExePath -PathType Leaf)) {
        throw "无法定位 Desktop 裸 EXE：$portableExePath"
    }

    $setupAssetName = "$productName`_$Platform`_$Version`_setup.exe"
    $portableAssetName = "$productName`_$Platform`_$Version`_portable.zip"
    Copy-Item -LiteralPath $setupFile.FullName -Destination (Join-Path $outputFull $setupAssetName) -Force

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
            throw 'Full Windows 绿色包必须提供 FullBackendResourcesDirectory，确保包含 backend-build.json 和已解压的 backend-full bin 目录。'
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
    $appImageFile = Select-SingleBundleFile `
        -Directory $appImageDir `
        -Filter "$productName`_$tauriVersion`_*.AppImage" `
        -Description 'AppImage'

    $appImageAssetName = "$productName`_$Platform`_$Version.AppImage"
    Copy-Item -LiteralPath $appImageFile.FullName -Destination (Join-Path $outputFull $appImageAssetName) -Force

    Write-Host "Desktop Linux asset：$appImageAssetName"
}
else {
    throw "未知 Desktop platform：$Platform"
}
