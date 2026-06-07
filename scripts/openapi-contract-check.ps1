param(
    [string]$ExpectedPathsPath = '',
    [string]$AuthSpecPath = '',
    [string]$GatewaySpecPath = '',
    [string]$AuthGeneratedSpecPath = '',
    [string]$GatewayGeneratedSpecPath = '',
    [string]$SnapshotsDir = '',
    [switch]$AllowMissingSpec
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

if ([string]::IsNullOrWhiteSpace($SnapshotsDir)) {
    $SnapshotsDir = Join-Path $RepoRoot 'packages/shared/contracts/openapi/snapshots'
}

if ([string]::IsNullOrWhiteSpace($AuthSpecPath)) {
    $AuthSpecPath = Join-Path $SnapshotsDir 'auth-service.openapi.json'
}

if ([string]::IsNullOrWhiteSpace($GatewaySpecPath)) {
    $GatewaySpecPath = Join-Path $SnapshotsDir 'gateway.openapi.json'
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

function Get-JsonPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Assert-ExpectedPaths {
    param([Parameter(Mandatory = $true)]$Expected)

    foreach ($serviceName in Get-JsonPropertyNames -Object $Expected) {
        $paths = @(Get-JsonPropertyValue -Object $Expected -Name $serviceName)
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

function Assert-TextFilesMatch {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SnapshotPath,
        [Parameter(Mandatory = $true)][string]$GeneratedPath
    )

    if (-not (Test-Path -LiteralPath $GeneratedPath)) {
        throw "$(U '\u7f3a\u5c11\u751f\u6210\u7684\u0020OpenAPI\u0020spec\uff1a')$ServiceName $GeneratedPath"
    }

    $snapshotContent = Get-Content -LiteralPath $SnapshotPath -Encoding UTF8 -Raw
    $generatedContent = Get-Content -LiteralPath $GeneratedPath -Encoding UTF8 -Raw
    if ($snapshotContent -ne $generatedContent) {
        throw "$(U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u5feb\u7167\u5df2\u6f02\u79fb\uff1a')$ServiceName$(U '\u3002\u5982\u679c\u8be5\u53d8\u66f4\u7b26\u5408\u9884\u671f\uff0c\u8bf7\u5148\u8fd0\u884c\u0020scripts/openapi-refresh-snapshots.ps1\u0020\u5e76\u63d0\u4ea4\u5feb\u7167\u3002')"
    }
}

Write-Host (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u5951\u7ea6\u68c0\u67e5')
Write-Host "$(U '\u671f\u671b\u8def\u5f84\uff1a')$ExpectedPathsPath"
Write-Host "$(U '\u5feb\u7167\u76ee\u5f55\uff1a')$SnapshotsDir"

$expected = Read-JsonFile -Path $ExpectedPathsPath
Assert-ExpectedPaths -Expected $expected

$specInputs = @{
    'auth-service' = @{
        Snapshot = $AuthSpecPath
        Generated = $AuthGeneratedSpecPath
    }
    'gateway' = @{
        Snapshot = $GatewaySpecPath
        Generated = $GatewayGeneratedSpecPath
    }
}

foreach ($serviceName in Get-JsonPropertyNames -Object $expected) {
    if (-not $specInputs.ContainsKey($serviceName)) {
        throw "$(U '\u7f3a\u5c11\u0020spec\u0020\u914d\u7f6e\uff1a')$serviceName"
    }

    $expectedPaths = @(Get-JsonPropertyValue -Object $expected -Name $serviceName)
    $specPath = $specInputs[$serviceName]['Snapshot']
    if (-not (Test-Path -LiteralPath $specPath)) {
        if (-not $AllowMissingSpec) {
            throw "$(U '\u7f3a\u5c11\u0020OpenAPI\u0020spec\u0020\u5feb\u7167\uff1a')$serviceName $specPath$(U '\u3002\u8bf7\u5148\u8fd0\u884c\u540e\u7aef\u0020OpenAPI\u0020\u6d4b\u8bd5\uff0c\u518d\u8fd0\u884c\u0020scripts/openapi-refresh-snapshots.ps1\u3002')"
        }
        Write-Host "$(U '\u8df3\u8fc7\u0020spec\u0020\u8def\u5f84\u6821\u9a8c\uff1a')$serviceName"
        continue
    }

    Assert-SpecContainsExpectedPaths `
        -ServiceName $serviceName `
        -SpecPath $specPath `
        -ExpectedPaths $expectedPaths
    Write-Host "$(U '\u901a\u8fc7\u0020spec\u0020\u8def\u5f84\u6821\u9a8c\uff1a')$serviceName"

    $generatedSpecPath = $specInputs[$serviceName]['Generated']
    if (-not [string]::IsNullOrWhiteSpace($generatedSpecPath)) {
        Assert-SpecContainsExpectedPaths `
            -ServiceName $serviceName `
            -SpecPath $generatedSpecPath `
            -ExpectedPaths $expectedPaths
        Assert-TextFilesMatch `
            -ServiceName $serviceName `
            -SnapshotPath $specPath `
            -GeneratedPath $generatedSpecPath
        Write-Host "$(U '\u901a\u8fc7\u5feb\u7167\u6f02\u79fb\u6821\u9a8c\uff1a')$serviceName"
    }
}

Write-Host (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u5951\u7ea6\u68c0\u67e5\u901a\u8fc7\u3002')
