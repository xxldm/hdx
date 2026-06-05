param(
    [string[]]$Path = @('.env.local'),
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

function U {
    param([Parameter(Mandatory = $true)][string]$Escaped)
    return [System.Text.RegularExpressions.Regex]::Unescape($Escaped)
}

function Convert-DotEnvValue {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    $trimmed = $Value.Trim()
    if ($trimmed -match '^"(.*)"$') {
        return [System.Text.RegularExpressions.Regex]::Unescape($Matches[1])
    }

    if ($trimmed -match "^'(.*)'$") {
        return $Matches[1]
    }

    return $trimmed
}

function Import-DotEnvFile {
    param([Parameter(Mandatory = $true)][string]$DotEnvPath)

    if (-not (Test-Path -LiteralPath $DotEnvPath)) {
        return @()
    }

    $loaded = [System.Collections.Generic.List[string]]::new()
    $lines = Get-Content -LiteralPath $DotEnvPath -Encoding UTF8
    for ($lineNumber = 0; $lineNumber -lt $lines.Count; $lineNumber++) {
        $line = $lines[$lineNumber].Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        if ($line.StartsWith('export ')) {
            $line = $line.Substring(7).TrimStart()
        }

        $match = [System.Text.RegularExpressions.Regex]::Match($line, '^(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$')
        if (-not $match.Success) {
            throw "$(U '\u672c\u5730\u73af\u5883\u6587\u4ef6\u683c\u5f0f\u65e0\u6548\uff1a')${DotEnvPath}:$($lineNumber + 1)"
        }

        $name = $match.Groups['name'].Value
        $value = Convert-DotEnvValue $match.Groups['value'].Value
        [System.Environment]::SetEnvironmentVariable($name, $value, 'Process')
        $loaded.Add($name)
    }

    return $loaded.ToArray()
}

function Set-DerivedEnvDefaults {
    $derived = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrWhiteSpace($env:NUXT_BACKEND_BASE_URL) -and -not [string]::IsNullOrWhiteSpace($env:HDX_BACKEND_BASE_URL)) {
        $env:NUXT_BACKEND_BASE_URL = $env:HDX_BACKEND_BASE_URL
        $derived.Add('NUXT_BACKEND_BASE_URL')
    }

    return $derived.ToArray()
}

$loadedNames = [System.Collections.Generic.List[string]]::new()
foreach ($dotEnvPath in $Path) {
    $resolvedPath = if ([System.IO.Path]::IsPathRooted($dotEnvPath)) {
        $dotEnvPath
    }
    else {
        Join-Path (Get-Location) $dotEnvPath
    }

    $loaded = Import-DotEnvFile -DotEnvPath $resolvedPath
    foreach ($name in $loaded) {
        $loadedNames.Add($name)
    }
}

$derivedNames = Set-DerivedEnvDefaults
foreach ($name in $derivedNames) {
    $loadedNames.Add($name)
}

if ($ValidateOnly) {
    if ($loadedNames.Count -gt 0) {
        Write-Host "$(U '\u5df2\u8bfb\u53d6\u672c\u5730\u73af\u5883\u53d8\u91cf\uff1a')$($loadedNames -join ', ')"
    }
    else {
        Write-Host (U '\u672a\u8bfb\u53d6\u5230\u672c\u5730\u73af\u5883\u53d8\u91cf\u3002')
    }
}
