param(
    [string]$WorkRoot = 'target/checks/desktop-release-asset-packaging'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib/release-common.ps1')

$PowerShellCommand = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($PowerShellCommand)) {
    $PowerShellCommand = 'pwsh'
}

$workRootFull = Get-FullPath -Path $WorkRoot
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $workRootFull

if (Test-Path -LiteralPath $workRootFull) {
    Remove-Item -LiteralPath $workRootFull -Recurse -Force
}

$desktopRoot = Join-Path $workRootFull 'desktop-root'
$outputRoot = Join-Path $workRootFull 'output'
$version = 'v0.0.0-public-assets-smoke.3'
$tauriVersion = '0.0.0-public-assets-smoke.3'
$oldTauriVersion = '0.0.0-public-assets-smoke.2'
$rootCommit = '1111111111111111111111111111111111111111'
$desktopCommit = '2222222222222222222222222222222222222222'

function New-FixtureFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Content
}

function Assert-FileExists {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "期望文件不存在：$Path"
    }
}

function Assert-FileContent {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    Assert-FileExists -Path $Path
    $actual = Get-Content -LiteralPath $Path -Raw
    if ($actual.Trim() -ne $Expected) {
        throw "文件内容不符合预期：$Path"
    }
}

function Invoke-PackagingScript {
    param(
        [Parameter(Mandatory = $true)][string]$Flavor,
        [Parameter(Mandatory = $true)][string]$Platform,
        [string]$FullBackendResourcesDirectory = ''
    )

    $arguments = @(
        '-NoLogo',
        '-NoProfile',
        '-File',
        (Join-Path $RepoRoot 'scripts/package-desktop-release-assets.ps1'),
        '-DesktopRoot',
        $desktopRoot,
        '-Version',
        $version,
        '-Flavor',
        $Flavor,
        '-Platform',
        $Platform,
        '-OutputDirectory',
        (Join-Path $outputRoot "$Flavor-$Platform"),
        '-RootCommit',
        $rootCommit,
        '-DesktopCommit',
        $desktopCommit
    )

    if (-not [string]::IsNullOrWhiteSpace($FullBackendResourcesDirectory)) {
        $arguments += @('-FullBackendResourcesDirectory', $FullBackendResourcesDirectory)
    }

    & $PowerShellCommand @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Desktop Release asset 打包 fixture 失败：$Flavor/$Platform"
    }
}

try {
    New-Item -ItemType Directory -Path $desktopRoot -Force | Out-Null
    New-FixtureFile -Path (Join-Path $desktopRoot 'README.md') -Content 'fixture readme'
    New-FixtureFile -Path (Join-Path $desktopRoot 'LICENSE') -Content 'fixture license'
    New-FixtureFile -Path (Join-Path $desktopRoot 'NOTICE') -Content 'fixture notice'

    $nsisDir = Join-Path $desktopRoot 'src-tauri/target/release/bundle/nsis'
    $appImageDir = Join-Path $desktopRoot 'src-tauri/target/release/bundle/appimage'

    New-FixtureFile -Path (Join-Path $desktopRoot 'src-tauri/target/release/HDX Desktop Online.exe') -Content 'online portable exe'
    New-FixtureFile -Path (Join-Path $desktopRoot 'src-tauri/target/release/HDX Desktop Full.exe') -Content 'full portable exe'

    New-FixtureFile -Path (Join-Path $nsisDir "HDX.Desktop.Online_$oldTauriVersion`_x64-setup.exe") -Content 'old online setup'
    New-FixtureFile -Path (Join-Path $nsisDir "HDX.Desktop.Online_$tauriVersion`_x64-setup.exe") -Content 'current online setup'
    New-FixtureFile -Path (Join-Path $nsisDir "HDX.Desktop.Full_$oldTauriVersion`_x64-setup.exe") -Content 'old full setup'
    New-FixtureFile -Path (Join-Path $nsisDir "HDX.Desktop.Full_$tauriVersion`_x64-setup.exe") -Content 'current full setup'

    New-FixtureFile -Path (Join-Path $appImageDir "HDX.Desktop.Online_$oldTauriVersion`_amd64.AppImage") -Content 'old online appimage'
    New-FixtureFile -Path (Join-Path $appImageDir "HDX.Desktop.Online_$tauriVersion`_amd64.AppImage") -Content 'current online appimage'
    New-FixtureFile -Path (Join-Path $appImageDir "HDX.Desktop.Full_$oldTauriVersion`_amd64.AppImage") -Content 'old full appimage'
    New-FixtureFile -Path (Join-Path $appImageDir "HDX.Desktop.Full_$tauriVersion`_amd64.AppImage") -Content 'current full appimage'

    $fullBackendResources = Join-Path $workRootFull 'full-backend-resources'
    New-FixtureFile -Path (Join-Path $fullBackendResources 'backend-build.json') -Content '{}'
    New-FixtureFile -Path (Join-Path $fullBackendResources 'bin/hdx-backend-full.exe') -Content 'backend exe'

    Invoke-PackagingScript -Flavor 'online' -Platform 'windows-x64'
    Assert-FileContent `
        -Path (Join-Path $outputRoot "online-windows-x64/HDX.Desktop.Online_windows-x64_${version}_setup.exe") `
        -Expected 'current online setup'
    Assert-FileExists -Path (Join-Path $outputRoot "online-windows-x64/HDX.Desktop.Online_windows-x64_${version}_portable.zip")

    Invoke-PackagingScript -Flavor 'online' -Platform 'linux-x64'
    Assert-FileContent `
        -Path (Join-Path $outputRoot "online-linux-x64/HDX.Desktop.Online_linux-x64_$version.AppImage") `
        -Expected 'current online appimage'

    Invoke-PackagingScript -Flavor 'full' -Platform 'windows-x64' -FullBackendResourcesDirectory $fullBackendResources
    Assert-FileContent `
        -Path (Join-Path $outputRoot "full-windows-x64/HDX.Desktop.Full_windows-x64_${version}_setup.exe") `
        -Expected 'current full setup'
    Assert-FileExists -Path (Join-Path $outputRoot "full-windows-x64/HDX.Desktop.Full_windows-x64_${version}_portable.zip")

    Invoke-PackagingScript -Flavor 'full' -Platform 'linux-x64'
    Assert-FileContent `
        -Path (Join-Path $outputRoot "full-linux-x64/HDX.Desktop.Full_linux-x64_$version.AppImage") `
        -Expected 'current full appimage'

    Write-Host 'Desktop Release asset 打包 fixture 检查通过：旧缓存产物不会干扰当前版本产物定位。'
}
finally {
    if (Test-Path -LiteralPath $workRootFull) {
        Remove-Item -LiteralPath $workRootFull -Recurse -Force
    }
}
