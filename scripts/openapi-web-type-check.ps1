param(
    [string]$WebRoot = '',
    [string]$CompatibilityFile = ''
)

$ErrorActionPreference = 'Stop'

function U {
    param([Parameter(Mandatory = $true)][string]$Escaped)
    return [System.Text.RegularExpressions.Regex]::Unescape($Escaped)
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($WebRoot)) {
    $WebRoot = Join-Path $RepoRoot 'apps/web'
}

if ([string]::IsNullOrWhiteSpace($CompatibilityFile)) {
    $CompatibilityFile = Join-Path $RepoRoot 'packages/shared/contracts/openapi/web-type-compatibility.ts'
}

function Get-PnpmCommand {
    $pnpmCommand = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
    if ($null -ne $pnpmCommand) {
        return $pnpmCommand.Source
    }

    $pnpmCommand = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($null -ne $pnpmCommand) {
        return $pnpmCommand.Source
    }

    throw (U '未找到 pnpm。请先安装 pnpm，或确认 apps/web 的本地 Node 环境可用。')
}

if (-not (Test-Path -LiteralPath $WebRoot)) {
    throw "$(U '未找到 Web 目录：')$WebRoot"
}

if (-not (Test-Path -LiteralPath $CompatibilityFile)) {
    throw "$(U '缺少 Web 契约类型对齐文件：')$CompatibilityFile"
}

Push-Location $WebRoot
try {
    $relativeCompatibilityFile = (Resolve-Path -LiteralPath $CompatibilityFile -Relative).Replace('\', '/')
}
finally {
    Pop-Location
}
$pnpm = Get-PnpmCommand

Write-Host (U 'OpenAPI 与 Web 类型对齐检查')
Write-Host "$(U 'Web 目录：')$WebRoot"
Write-Host "$(U '对齐文件：')$CompatibilityFile"

Push-Location $WebRoot
try {
    & $pnpm exec vue-tsc `
        --noEmit `
        --strict `
        --skipLibCheck `
        --moduleResolution Bundler `
        --module ESNext `
        --target ESNext `
        --allowImportingTsExtensions `
        $relativeCompatibilityFile
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "$(U 'OpenAPI 与 Web 类型对齐检查失败，退出码：')$exitCode"
    }
}
finally {
    Pop-Location
}

Write-Host (U 'OpenAPI 与 Web 类型对齐检查通过。')
