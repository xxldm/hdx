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

    throw (U '\u672a\u627e\u5230\u0020pnpm\u3002\u8bf7\u5148\u5b89\u88c5\u0020pnpm\uff0c\u6216\u786e\u8ba4\u0020apps/web\u0020\u7684\u672c\u5730\u0020Node\u0020\u73af\u5883\u53ef\u7528\u3002')
}

if (-not (Test-Path -LiteralPath $WebRoot)) {
    throw "$(U '\u672a\u627e\u5230\u0020Web\u0020\u76ee\u5f55\uff1a')$WebRoot"
}

if (-not (Test-Path -LiteralPath $CompatibilityFile)) {
    throw "$(U '\u7f3a\u5c11\u0020Web\u0020\u5951\u7ea6\u7c7b\u578b\u5bf9\u9f50\u6587\u4ef6\uff1a')$CompatibilityFile"
}

Push-Location $WebRoot
try {
    $relativeCompatibilityFile = (Resolve-Path -LiteralPath $CompatibilityFile -Relative).Replace('\', '/')
}
finally {
    Pop-Location
}
$pnpm = Get-PnpmCommand

Write-Host (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u4e0e\u0020Web\u0020\u7c7b\u578b\u5bf9\u9f50\u68c0\u67e5')
Write-Host "$(U '\u0057\u0065\u0062\u0020\u76ee\u5f55\uff1a')$WebRoot"
Write-Host "$(U '\u5bf9\u9f50\u6587\u4ef6\uff1a')$CompatibilityFile"

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
        throw "$(U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u4e0e\u0020Web\u0020\u7c7b\u578b\u5bf9\u9f50\u68c0\u67e5\u5931\u8d25\uff0c\u9000\u51fa\u7801\uff1a')$exitCode"
    }
}
finally {
    Pop-Location
}

Write-Host (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u4e0e\u0020Web\u0020\u7c7b\u578b\u5bf9\u9f50\u68c0\u67e5\u901a\u8fc7\u3002')
