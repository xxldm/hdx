param(
    [string]$BackendRoot = '',
    [string]$JavaHome = 'D:\JetBrains\.jdks\graalvm-jdk-25.0.3+9.1',
    [string]$MavenPath = 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd',
    [switch]$NoBuild,
    [switch]$AotSmoke,
    [switch]$SkipWhitespace,
    [switch]$SkipBoot4Jackson,
    [switch]$SkipTest
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PowerShellCommand = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($PowerShellCommand)) {
    $PowerShellCommand = 'pwsh'
}

if ([string]::IsNullOrWhiteSpace($BackendRoot)) {
    $BackendRoot = Join-Path $RepoRoot 'services/backend'
}

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

. (Join-Path $RepoRoot 'scripts/lib/quality-gate-common.ps1')

$javaPath = Join-Path $JavaHome 'bin/java.exe'
if (-not (Test-Path -LiteralPath $javaPath)) {
    throw "未找到 GraalVM JDK 25：$JavaHome"
}
if (-not (Test-Path -LiteralPath $MavenPath)) {
    throw "未找到 Maven：$MavenPath"
}
if (-not (Test-Path -LiteralPath $BackendRoot)) {
    throw "未找到后端目录：$BackendRoot"
}

$toolEnv = @{
    JAVA_HOME = $JavaHome
    PATH = "$JavaHome\bin;$(Split-Path -Parent $MavenPath);$env:PATH"
}

Write-Section '后端聚合验证'
Write-Host "后端目录：$BackendRoot"
Write-Host "JavaHome: $JavaHome"
Write-Host "MavenPath: $MavenPath"
Write-Host "NoBuild: $NoBuild"
Write-Host "AotSmoke: $AotSmoke"
Write-Host "SkipWhitespace: $SkipWhitespace"
Write-Host "SkipBoot4Jackson: $SkipBoot4Jackson"
Write-Host "SkipTest: $SkipTest"

if (-not $SkipWhitespace) {
    Invoke-Step `
        -Title '后端空白检查' `
        -WorkingDirectory $BackendRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')
}

if (-not $SkipBoot4Jackson) {
    Invoke-Step `
        -Title '后端 Boot 4 Jackson 兼容检查' `
        -WorkingDirectory $BackendRoot `
        -Command $PowerShellCommand `
        -Arguments @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            (Join-Path $BackendRoot 'scripts/check-boot4-jackson.ps1')
        )
}

if ($NoBuild) {
    Invoke-Step `
        -Title '后端 Maven 环境检查' `
        -WorkingDirectory $BackendRoot `
        -Command $MavenPath `
        -Arguments @('-version') `
        -Environment $toolEnv

    Write-Section '后端聚合验证完成'
    Write-Host '全部检查通过。'
    exit 0
}

if (-not $SkipTest) {
    Invoke-Step `
        -Title '后端测试' `
        -WorkingDirectory $BackendRoot `
        -Command $MavenPath `
        -Arguments @('test') `
        -Environment $toolEnv
}

if ($AotSmoke) {
    Invoke-Step `
        -Title '后端 all-in-one AOT 打包 smoke' `
        -WorkingDirectory $BackendRoot `
        -Command $MavenPath `
        -Arguments @('-pl', ':backend-all-in-one', '-am', '-Pnative', 'package', '-DskipTests', '-Dnative.skip=true') `
        -Environment $toolEnv
}
else {
    Write-Host '跳过：未传 -AotSmoke，已跳过后端 all-in-one AOT 打包 smoke。'
}

Write-Section '后端聚合验证完成'
Write-Host '全部检查通过。'
