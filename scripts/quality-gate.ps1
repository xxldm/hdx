param(
    [ValidateSet('changed', 'all', 'backend', 'web', 'docs')]
    [string]$Scope = 'changed',
    [switch]$SkipBackend,
    [switch]$SkipWeb,
    [switch]$NoBuild,
    [string]$JavaHome = 'D:\JetBrains\.jdks\graalvm-jdk-25.0.3+9.1',
    [string]$MavenPath = 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd'
)

$ErrorActionPreference = 'Stop'

function U {
    param([Parameter(Mandatory = $true)][string]$Escaped)
    return [System.Text.RegularExpressions.Regex]::Unescape($Escaped)
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BackendRoot = Join-Path $RepoRoot 'services/backend'
$WebRoot = Join-Path $RepoRoot 'apps/web'

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Format-CommandLine {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )
    return ((@($Command) + $Arguments) -join ' ')
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [hashtable]$Environment = @{}
    )

    Write-Section $Title
    Write-Host "$(U '\u76ee\u5f55\uff1a')$WorkingDirectory"
    Write-Host "$(U '\u547d\u4ee4\uff1a')$(Format-CommandLine -Command $Command -Arguments $Arguments)"

    $previous = @{}
    foreach ($name in $Environment.Keys) {
        $previous[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
        [System.Environment]::SetEnvironmentVariable($name, [string]$Environment[$name], 'Process')
    }

    $startedAt = Get-Date
    Push-Location $WorkingDirectory
    try {
        & $Command @Arguments
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
        if ($exitCode -ne 0) {
            throw "$(U '\u547d\u4ee4\u5931\u8d25\uff0c\u9000\u51fa\u7801\uff1a')$exitCode"
        }
    }
    finally {
        Pop-Location
        foreach ($name in $Environment.Keys) {
            [System.Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
    }

    $elapsed = (Get-Date) - $startedAt
    Write-Host ([string]::Format((U '\u901a\u8fc7\uff1a{0:N1}s'), $elapsed.TotalSeconds))
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $output = & git -C $WorkingDirectory @Arguments
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "$(U '\u0047\u0069\u0074\u0020\u547d\u4ee4\u5931\u8d25\uff1a')git -C $WorkingDirectory $($Arguments -join ' ')"
    }
    return @($output)
}

function Get-GitStatusPaths {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory)

    $lines = Invoke-Git -WorkingDirectory $WorkingDirectory -Arguments @('status', '--porcelain=v1')
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        if ($line.Length -lt 4) {
            continue
        }
        $path = $line.Substring(3).Trim()
        if ($path.Contains(' -> ')) {
            $parts = $path -split ' -> '
            $path = $parts[$parts.Count - 1]
        }
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $paths.Add($path.Replace('\', '/'))
        }
    }
    return $paths.ToArray()
}

function Test-HasGitChanges {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory)
    return (Get-GitStatusPaths -WorkingDirectory $WorkingDirectory).Count -gt 0
}

function Test-PathChanged {
    param(
        [Parameter(Mandatory = $true)][string[]]$Paths,
        [Parameter(Mandatory = $true)][string[]]$Prefixes
    )
    foreach ($path in $Paths) {
        foreach ($prefix in $Prefixes) {
            if ($path -eq $prefix -or $path.StartsWith("$prefix/")) {
                return $true
            }
        }
    }
    return $false
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

function Assert-Tooling {
    $javaPath = Join-Path $JavaHome 'bin/java.exe'
    if (-not (Test-Path -LiteralPath $javaPath)) {
        throw "$(U '\u672a\u627e\u5230\u0020GraalVM JDK 25\uff1a')$JavaHome"
    }
    if (-not (Test-Path -LiteralPath $MavenPath)) {
        throw "$(U '\u672a\u627e\u5230\u0020Maven\uff1a')$MavenPath"
    }
    if (-not (Test-Path -LiteralPath $BackendRoot)) {
        throw "$(U '\u672a\u627e\u5230\u540e\u7aef\u76ee\u5f55\uff1a')$BackendRoot"
    }
    if (-not (Test-Path -LiteralPath $WebRoot)) {
        throw "$(U '\u672a\u627e\u5230\u0020Web\u0020\u76ee\u5f55\uff1a')$WebRoot"
    }
}

function Invoke-DocChecks {
    Write-Section (U '\u6587\u6863\u4e0e\u6839\u4ed3\u5e93\u68c0\u67e5')
    $docFiles = @(
        'AGENTS.md',
        'README.md',
        'docs/CONSTRAINTS.md',
        'docs/ARCHITECTURE.md',
        'docs/QUALITY.md',
        'docs/GIT.md',
        'docs/plans/README.md'
    )

    foreach ($relativePath in $docFiles) {
        $path = Join-Path $RepoRoot $relativePath
        if (-not (Test-Path -LiteralPath $path)) {
            throw "$(U '\u7f3a\u5c11\u6587\u6863\uff1a')$relativePath"
        }
        Get-Content -LiteralPath $path -Encoding UTF8 | Out-Null
    }
    Write-Host (U '\u901a\u8fc7\uff1a\u5173\u952e\u6587\u6863\u53ef\u6309\u0020UTF-8\u0020\u8bfb\u53d6\u3002')

    Invoke-Step `
        -Title (U '\u6839\u4ed3\u5e93\u7a7a\u767d\u68c0\u67e5') `
        -WorkingDirectory $RepoRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    Invoke-Step `
        -Title (U '\u004f\u0070\u0065\u006e\u0041\u0050\u0049\u0020\u5951\u7ea6\u68c0\u67e5') `
        -WorkingDirectory $RepoRoot `
        -Command 'powershell' `
        -Arguments @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $RepoRoot 'scripts/openapi-contract-check.ps1')
        )
}

function Invoke-BackendChecks {
    if ($SkipBackend) {
        Write-Host (U '\u8df3\u8fc7\uff1a\u540e\u7aef\u68c0\u67e5\u5df2\u88ab\u0020-SkipBackend\u0020\u7981\u7528\u3002')
        return
    }

    $toolEnv = @{
        JAVA_HOME = $JavaHome
        PATH = "$JavaHome\bin;$(Split-Path -Parent $MavenPath);$env:PATH"
    }

    Invoke-Step `
        -Title (U '\u540e\u7aef\u7a7a\u767d\u68c0\u67e5') `
        -WorkingDirectory $BackendRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    if ($NoBuild) {
        Invoke-Step `
            -Title (U '\u540e\u7aef\u0020Maven\u0020\u73af\u5883\u68c0\u67e5') `
            -WorkingDirectory $BackendRoot `
            -Command $MavenPath `
            -Arguments @('-version') `
            -Environment $toolEnv
        return
    }

    Invoke-Step `
        -Title (U '\u540e\u7aef\u6d4b\u8bd5') `
        -WorkingDirectory $BackendRoot `
        -Command $MavenPath `
        -Arguments @('test') `
        -Environment $toolEnv
}

function Invoke-WebChecks {
    if ($SkipWeb) {
        Write-Host (U '\u8df3\u8fc7\uff1aWeb\u0020\u68c0\u67e5\u5df2\u88ab\u0020-SkipWeb\u0020\u7981\u7528\u3002')
        return
    }

    $pnpm = Get-PnpmCommand

    Invoke-Step `
        -Title (U '\u0057\u0065\u0062\u0020\u7a7a\u767d\u68c0\u67e5') `
        -WorkingDirectory $WebRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    Invoke-Step `
        -Title (U '\u0057\u0065\u0062\u0020\u5355\u5143\u6d4b\u8bd5') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('test')

    Invoke-Step `
        -Title (U '\u0057\u0065\u0062\u0020\u7c7b\u578b\u68c0\u67e5') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('typecheck')

    Invoke-Step `
        -Title (U '\u0057\u0065\u0062\u0020lint') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('lint')

    if ($NoBuild) {
        Write-Host (U '\u8df3\u8fc7\uff1a-NoBuild\u0020\u5df2\u8df3\u8fc7\u0020Web build\u3002')
        return
    }

    Invoke-Step `
        -Title (U '\u0057\u0065\u0062\u0020build') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('build')
}

function Show-GitStatus {
    Write-Section (U '\u0047\u0069\u0074\u0020\u72b6\u6001')
    Write-Host (U '\u6839\u4ed3\u5e93\uff1a')
    Invoke-Git -WorkingDirectory $RepoRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }

    if (Test-Path -LiteralPath $BackendRoot) {
        Write-Host 'services/backend:'
        Invoke-Git -WorkingDirectory $BackendRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }
    }

    if (Test-Path -LiteralPath $WebRoot) {
        Write-Host 'apps/web:'
        Invoke-Git -WorkingDirectory $WebRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }
    }
}

Assert-Tooling
Show-GitStatus

$rootPaths = Get-GitStatusPaths -WorkingDirectory $RepoRoot
$backendChanged = $false
$webChanged = $false
$docsChanged = $false

switch ($Scope) {
    'all' {
        $backendChanged = $true
        $webChanged = $true
        $docsChanged = $true
    }
    'backend' {
        $backendChanged = $true
    }
    'web' {
        $webChanged = $true
    }
    'docs' {
        $docsChanged = $true
    }
    'changed' {
        $backendChanged = (Test-PathChanged -Paths $rootPaths -Prefixes @('services/backend')) -or (Test-HasGitChanges -WorkingDirectory $BackendRoot)
        $webChanged = (Test-PathChanged -Paths $rootPaths -Prefixes @('apps/web')) -or (Test-HasGitChanges -WorkingDirectory $WebRoot)
        $docsChanged = Test-PathChanged -Paths $rootPaths -Prefixes @(
            'docs',
            'scripts',
            'README.md',
            'AGENTS.md',
            'WORKFLOW.md',
            '.env.example',
            '.env.symphony.example'
        )
    }
}

if (-not $backendChanged -and -not $webChanged -and -not $docsChanged) {
    Write-Host ''
    Write-Host (U 'changed\u0020\u8303\u56f4\u672a\u68c0\u6d4b\u5230\u9700\u8981\u8fd0\u884c\u7684\u6a21\u5757\u9a8c\u8bc1\uff1b\u5df2\u5b8c\u6210\u57fa\u7840\u0020Git\u0020\u72b6\u6001\u68c0\u67e5\u3002')
    exit 0
}

Write-Section (U '\u672c\u8f6e\u8d28\u91cf\u95e8\u7981\u8303\u56f4')
Write-Host "Scope: $Scope"
Write-Host "Docs: $docsChanged"
Write-Host "Backend: $backendChanged"
Write-Host "Web: $webChanged"
Write-Host "NoBuild: $NoBuild"

if ($docsChanged) {
    Invoke-DocChecks
}

if ($backendChanged) {
    Invoke-BackendChecks
}

if ($webChanged) {
    Invoke-WebChecks
}

Write-Section (U '\u8d28\u91cf\u95e8\u7981\u5b8c\u6210')
Write-Host (U '\u5168\u90e8\u68c0\u67e5\u901a\u8fc7\u3002')
