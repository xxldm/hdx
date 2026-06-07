param(
    [string]$ExpectedPathsPath = '',
    [string]$AuthSpecPath = '',
    [string]$GatewaySpecPath = ''
)

$ErrorActionPreference = 'Stop'

function U {
    param([Parameter(Mandatory = $true)][string]$Escaped)
    return [System.Text.RegularExpressions.Regex]::Unescape($Escaped)
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($ExpectedPathsPath)) {
    $ExpectedPathsPath = Join-Path $RepoRoot 'packages/shared/contracts/openapi/expected-paths.json'
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$(U '\u7f3a\u5c11\u6587\u4ef6\uff1a')$Path"
    }

    try {
        return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        throw "$(U '\u004a\u0053\u004f\u004e\u0020\u683c\u5f0f\u65e0\u6548\uff1a')$Path"
    }
}

function Get-JsonPropertyNames {
    param([Parameter(Mandatory = $true)]$Object)
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Assert-ExpectedPaths {
    param([Parameter(Mandatory = $true)]$Expected)

    foreach ($serviceName in Get-JsonPropertyNames -Object $Expected) {
        $paths = @($Expected.$serviceName)
        if ($paths.Count -eq 0) {
            throw "$(U '\u7f3a\u5c11\u671f\u671b\u8def\u5f84\uff1a')$serviceName"
        }

        $seen = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($path in $paths) {
            if ($path -isnot [string] -or -not $path.StartsWith('/')) {
                throw "$(U '\u671f\u671b\u8def\u5f84\u5fc5\u987b\u4ee5\u0020/\u0020\u5f00\u5934\uff1a')$serviceName"
            }
            if (-not $seen.Add($path)) {
                throw "$(U '\u671f\u671b\u8def\u5f84\u91cd\u590d\uff1a')$serviceName $path"
            }
        }
    }
}

function Assert-SpecContainsExpectedPaths {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SpecPath,
        [Parameter(Mandatory = $true)][string[]]$ExpectedPaths
    )

    $spec = Read-JsonFile -Path $SpecPath
    if ($null -eq $spec.paths) {
        throw "$(U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u6587\u6863\u7f3a\u5c11\u0020paths\uff1a')$SpecPath"
    }

    $actualPaths = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($path in Get-JsonPropertyNames -Object $spec.paths) {
        [void]$actualPaths.Add($path)
    }

    foreach ($expectedPath in $ExpectedPaths) {
        if (-not $actualPaths.Contains($expectedPath)) {
            throw "$(U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u6587\u6863\u7f3a\u5c11\u8def\u5f84\uff1a')$ServiceName $expectedPath"
        }
    }
}

Write-Host (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u5951\u7ea6\u68c0\u67e5')
Write-Host "$(U '\u671f\u671b\u8def\u5f84\uff1a')$ExpectedPathsPath"

$expected = Read-JsonFile -Path $ExpectedPathsPath
Assert-ExpectedPaths -Expected $expected

$specInputs = @{
    'auth-service' = $AuthSpecPath
    'gateway' = $GatewaySpecPath
}

foreach ($serviceName in Get-JsonPropertyNames -Object $expected) {
    $specPath = $specInputs[$serviceName]
    if ([string]::IsNullOrWhiteSpace($specPath)) {
        Write-Host "$(U '\u8df3\u8fc7\u0020spec\u0020\u8def\u5f84\u6821\u9a8c\uff1a')$serviceName"
        continue
    }

    Assert-SpecContainsExpectedPaths `
        -ServiceName $serviceName `
        -SpecPath $specPath `
        -ExpectedPaths @($expected.$serviceName)
    Write-Host "$(U '\u901a\u8fc7\u0020spec\u0020\u8def\u5f84\u6821\u9a8c\uff1a')$serviceName"
}

Write-Host (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u5951\u7ea6\u68c0\u67e5\u901a\u8fc7\u3002')
