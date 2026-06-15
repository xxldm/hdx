$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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
    Write-Host "目录：$WorkingDirectory"
    Write-Host "命令：$(Format-CommandLine -Command $Command -Arguments $Arguments)"

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
            throw "命令失败，退出码：$exitCode"
        }
    }
    finally {
        Pop-Location
        foreach ($name in $Environment.Keys) {
            [System.Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
    }

    $elapsed = (Get-Date) - $startedAt
    Write-Host ([string]::Format('通过：{0:N1}s', $elapsed.TotalSeconds))
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $output = & git -C $WorkingDirectory @Arguments
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "Git 命令失败：git -C $WorkingDirectory $($Arguments -join ' ')"
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

    throw '未找到 pnpm。请先安装 pnpm，或确认 apps/web 或 apps/desktop 的本地 Node 环境可用。'
}
