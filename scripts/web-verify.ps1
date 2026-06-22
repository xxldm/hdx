param(
    [string]$WebRoot = '',
    [switch]$Build,
    [switch]$SkipWhitespace,
    [switch]$SkipTest,
    [switch]$SkipTypecheck,
    [switch]$SkipLint
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($WebRoot)) {
    $WebRoot = Join-Path $RepoRoot 'apps/web'
}

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

. (Join-Path $RepoRoot 'scripts/lib/quality-gate-common.ps1')

if (-not (Test-Path -LiteralPath $WebRoot)) {
    throw "未找到 Web 目录：$WebRoot"
}

$pnpm = Get-PnpmCommand

Write-Section 'Web 聚合验证'
Write-Host "Web 目录：$WebRoot"
Write-Host "Build: $Build"
Write-Host "SkipWhitespace: $SkipWhitespace"
Write-Host "SkipTest: $SkipTest"
Write-Host "SkipTypecheck: $SkipTypecheck"
Write-Host "SkipLint: $SkipLint"

if (-not $SkipWhitespace) {
    Invoke-Step `
        -Title 'Web 空白检查' `
        -WorkingDirectory $WebRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')
}

if (-not $SkipTest) {
    Invoke-Step `
        -Title 'Web 单元测试' `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('test')
}

if (-not $SkipTypecheck) {
    Invoke-Step `
        -Title 'Web 类型检查' `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('typecheck')
}

if (-not $SkipLint) {
    Invoke-Step `
        -Title 'Web lint' `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('lint')
}

if ($Build) {
    Invoke-Step `
        -Title 'Web build' `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('build')
}
else {
    Write-Host '跳过：未传 -Build，已跳过 Web build。'
}

Write-Section 'Web 聚合验证完成'
Write-Host '全部检查通过。'
