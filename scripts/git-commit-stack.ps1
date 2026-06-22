param(
    [string]$BackendMessage = '',
    [string]$WebMessage = '',
    [string]$DesktopMessage = '',
    [string]$RootMessage = '',
    [switch]$StageAll,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

function Invoke-GitCommand {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Write-Host "git -C $WorkingDirectory $($Arguments -join ' ')"

    if ($DryRun) {
        return @()
    }

    $output = & git -C $WorkingDirectory @Arguments
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "Git 命令失败，退出码：$exitCode"
    }

    return @($output)
}

function Get-GitStatusLines {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory)

    $output = & git -C $WorkingDirectory status --porcelain=v1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "Git 状态读取失败：$WorkingDirectory"
    }

    return @($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-HasStagedChanges {
    param([Parameter(Mandatory = $true)][string[]]$StatusLines)

    foreach ($line in $StatusLines) {
        if ($line.Length -lt 2) {
            continue
        }

        $indexStatus = $line[0]
        if ($indexStatus -ne ' ' -and $indexStatus -ne '?') {
            return $true
        }
    }

    return $false
}

function Test-HasUnstagedOrUntrackedChanges {
    param([Parameter(Mandatory = $true)][string[]]$StatusLines)

    foreach ($line in $StatusLines) {
        if ($line.Length -lt 2) {
            continue
        }

        $indexStatus = $line[0]
        $worktreeStatus = $line[1]
        if ($indexStatus -eq '?' -or $worktreeStatus -ne ' ') {
            return $true
        }
    }

    return $false
}

function Write-StatusLines {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string[]]$StatusLines
    )

    Write-Host ''
    Write-Host "== $Label =="
    foreach ($line in $StatusLines) {
        Write-Host $line
    }
}

function Commit-RepositoryIfNeeded {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [string]$Message = ''
    )

    $statusLines = @(Get-GitStatusLines -WorkingDirectory $WorkingDirectory)
    if ($statusLines.Count -eq 0) {
        Write-Host "跳过：$Label 没有未提交改动。"
        return
    }

    Write-StatusLines -Label $Label -StatusLines $statusLines

    if ([string]::IsNullOrWhiteSpace($Message)) {
        throw "$Label 存在未提交改动，但没有提供提交信息。"
    }

    if ($DryRun) {
        if ($StageAll) {
            Write-Host "DryRun：会暂存 $Label 的全部改动并提交：$Message"
            return
        }

        if (Test-HasUnstagedOrUntrackedChanges -StatusLines $statusLines) {
            throw "$Label 存在未暂存或未跟踪改动。请先手动暂存，或显式传入 -StageAll。"
        }

        if (Test-HasStagedChanges -StatusLines $statusLines) {
            Write-Host "DryRun：会提交 $Label 的已暂存改动：$Message"
        }
        else {
            Write-Host "DryRun：$Label 没有已暂存改动。"
        }
        return
    }

    if ($StageAll) {
        Invoke-GitCommand -WorkingDirectory $WorkingDirectory -Arguments @('add', '-A') | Out-Null
        $statusLines = @(Get-GitStatusLines -WorkingDirectory $WorkingDirectory)
    }
    elseif (Test-HasUnstagedOrUntrackedChanges -StatusLines $statusLines) {
        throw "$Label 存在未暂存或未跟踪改动。请先手动暂存，或显式传入 -StageAll。"
    }

    if (-not (Test-HasStagedChanges -StatusLines $statusLines)) {
        Write-Host "跳过：$Label 没有已暂存改动。"
        return
    }

    Invoke-GitCommand -WorkingDirectory $WorkingDirectory -Arguments @('commit', '-m', $Message) | ForEach-Object { Write-Host $_ }
}

Commit-RepositoryIfNeeded `
    -Label 'services/backend' `
    -WorkingDirectory (Join-Path $RepoRoot 'services/backend') `
    -Message $BackendMessage

Commit-RepositoryIfNeeded `
    -Label 'apps/web' `
    -WorkingDirectory (Join-Path $RepoRoot 'apps/web') `
    -Message $WebMessage

Commit-RepositoryIfNeeded `
    -Label 'apps/desktop' `
    -WorkingDirectory (Join-Path $RepoRoot 'apps/desktop') `
    -Message $DesktopMessage

Commit-RepositoryIfNeeded `
    -Label 'root' `
    -WorkingDirectory $RepoRoot `
    -Message $RootMessage

Write-Host ''
Write-Host '提交编排完成。'
