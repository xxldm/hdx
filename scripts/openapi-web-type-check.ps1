param(
    [string]$WebRoot = '',
    [string]$CompatibilityFile = ''
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($WebRoot)) {
    $WebRoot = Join-Path $RepoRoot 'apps/web'
}

if ([string]::IsNullOrWhiteSpace($CompatibilityFile)) {
    $CompatibilityFile = Join-Path $RepoRoot 'packages/shared/contracts/openapi/web-type-compatibility.ts'
}

function Get-LocalVueTscCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebRoot
    )

    $binRoot = Join-Path $WebRoot 'node_modules/.bin'
    $candidates = if ($IsWindows) {
        @('vue-tsc.cmd', 'vue-tsc')
    }
    else {
        @('vue-tsc', 'vue-tsc.cmd')
    }

    foreach ($candidate in $candidates) {
        $candidatePath = Join-Path $binRoot $candidate
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidatePath).Path
        }
    }

    throw "未找到 Web 本地 vue-tsc：$binRoot。请先在 apps/web 安装依赖后再运行本检查。"
}

if (-not (Test-Path -LiteralPath $WebRoot)) {
    throw "未找到 Web 目录：$WebRoot"
}

if (-not (Test-Path -LiteralPath $CompatibilityFile)) {
    throw "缺少 Web 契约类型对齐文件：$CompatibilityFile"
}

Push-Location $WebRoot
try {
    $relativeCompatibilityFile = (Resolve-Path -LiteralPath $CompatibilityFile -Relative).Replace('\', '/')
}
finally {
    Pop-Location
}
$vueTsc = Get-LocalVueTscCommand -WebRoot $WebRoot

Write-Host 'OpenAPI 与 Web 类型对齐检查'
Write-Host "Web 目录：$WebRoot"
Write-Host "对齐文件：$CompatibilityFile"

Push-Location $WebRoot
try {
    & $vueTsc `
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
        throw "OpenAPI 与 Web 类型对齐检查失败，退出码：$exitCode"
    }
}
finally {
    Pop-Location
}

Write-Host 'OpenAPI 与 Web 类型对齐检查通过。'
