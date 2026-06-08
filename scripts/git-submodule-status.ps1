param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Write-CommandOutput {
    param([Parameter(Mandatory = $true)]$Result)

    foreach ($line in $Result.Output) {
        if ($null -ne $line -and -not [string]::IsNullOrWhiteSpace([string]$line)) {
            Write-Host $line
        }
    }
}

function Find-GitBash {
    $candidates = [System.Collections.Generic.List[string]]::new()

    $execPathResult = Invoke-ExternalCommand -FilePath 'git' -Arguments @('--exec-path') -WorkingDirectory $RepoRoot
    if ($execPathResult.ExitCode -eq 0 -and $execPathResult.Output.Count -gt 0) {
        $execPath = ([string]$execPathResult.Output[0]).Trim()
        if (-not [string]::IsNullOrWhiteSpace($execPath)) {
            $gitRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $execPath))
            $candidates.Add((Join-Path $gitRoot 'bin/bash.exe'))
        }
    }

    $candidates.Add('C:\Program Files\Git\bin\bash.exe')
    $candidates.Add('C:\Program Files (x86)\Git\bin\bash.exe')

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-SubmodulePointerStatus {
    $lsFilesResult = Invoke-ExternalCommand `
        -FilePath 'git' `
        -Arguments @('ls-files', '-s') `
        -WorkingDirectory $RepoRoot

    if ($lsFilesResult.ExitCode -ne 0) {
        throw '无法读取 Git 索引中的子模块指针。'
    }

    $submodules = @()
    foreach ($line in $lsFilesResult.Output) {
        $text = [string]$line
        if (-not $text.StartsWith('160000 ')) {
            continue
        }

        $match = [regex]::Match($text, '^160000\s+([0-9a-f]{40})\s+\d+\s+(.+)$')
        if (-not $match.Success) {
            continue
        }

        $submodules += [PSCustomObject]@{
            Hash = $match.Groups[1].Value
            Path = $match.Groups[2].Value
        }
    }

    foreach ($submodule in $submodules) {
        $submodulePath = Join-Path $RepoRoot $submodule.Path
        $prefix = '-'

        if (Test-Path -LiteralPath $submodulePath) {
            $headResult = Invoke-ExternalCommand `
                -FilePath 'git' `
                -Arguments @('-C', $submodulePath, 'rev-parse', 'HEAD') `
                -WorkingDirectory $RepoRoot

            if ($headResult.ExitCode -eq 0 -and $headResult.Output.Count -gt 0) {
                $head = ([string]$headResult.Output[0]).Trim()
                if ($head -eq $submodule.Hash) {
                    $prefix = ' '
                }
                else {
                    $prefix = '+'
                }
            }
        }

        Write-Host "$prefix$($submodule.Hash) $($submodule.Path)"
    }
}

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$directResult = Invoke-ExternalCommand `
    -FilePath 'git' `
    -Arguments @('submodule', 'status') `
    -WorkingDirectory $resolvedRepoRoot

if ($directResult.ExitCode -eq 0) {
    Write-CommandOutput -Result $directResult
    exit 0
}

$gitBash = Find-GitBash
if ($null -ne $gitBash) {
    $bashResult = Invoke-ExternalCommand `
        -FilePath $gitBash `
        -Arguments @('-lc', 'git submodule status') `
        -WorkingDirectory $resolvedRepoRoot

    if ($bashResult.ExitCode -eq 0) {
        Write-CommandOutput -Result $bashResult
        exit 0
    }
}

Get-SubmodulePointerStatus
exit 0
