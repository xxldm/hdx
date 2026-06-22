param(
    [switch]$DryRun,
    [switch]$SkipBackend,
    [switch]$SkipWeb,
    [switch]$SkipDesktop,
    [switch]$SkipRoot
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

    if ($DryRun -and $Arguments[0] -eq 'push') {
        return @()
    }

    $output = & git -C $WorkingDirectory @Arguments
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "Git 命令失败，退出码：$exitCode"
    }

    return @($output)
}

function Get-CurrentBranch {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory)

    $branch = & git -C $WorkingDirectory branch --show-current
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
        throw "无法读取当前分支：$WorkingDirectory"
    }

    return [string]$branch
}

function Get-UpstreamRef {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory)

    $upstream = & git -C $WorkingDirectory rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($upstream)) {
        return $null
    }

    return [string]$upstream
}

function Get-AheadCount {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Upstream
    )

    $countText = & git -C $WorkingDirectory rev-list --count "$Upstream..HEAD"
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "无法计算 ahead 数量：$WorkingDirectory"
    }

    return [int]$countText
}

function Assert-CleanWorktree {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory)

    $statusLines = & git -C $WorkingDirectory status --porcelain=v1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "无法读取 Git 状态：$WorkingDirectory"
    }

    $dirtyLines = @($statusLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($dirtyLines.Count -gt 0) {
        Write-Host "发现未提交改动：$WorkingDirectory"
        foreach ($line in $dirtyLines) {
            Write-Host $line
        }
        throw '推送前必须先提交或清理工作树。'
    }
}

function Push-RepositoryIfNeeded {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    Write-Host ''
    Write-Host "== $Label =="

    Assert-CleanWorktree -WorkingDirectory $WorkingDirectory

    $branch = Get-CurrentBranch -WorkingDirectory $WorkingDirectory
    $upstream = Get-UpstreamRef -WorkingDirectory $WorkingDirectory
    if ($null -eq $upstream) {
        throw "$Label 当前分支 $branch 没有 upstream，拒绝猜测推送目标。"
    }

    $aheadCount = Get-AheadCount -WorkingDirectory $WorkingDirectory -Upstream $upstream
    Write-Host "分支：$branch"
    Write-Host "上游：$upstream"
    Write-Host "ahead: $aheadCount"

    if ($aheadCount -eq 0) {
        Write-Host "跳过：$Label 没有需要推送的提交。"
        return
    }

    Invoke-GitCommand -WorkingDirectory $WorkingDirectory -Arguments @('push') | ForEach-Object { Write-Host $_ }
}

if (-not $SkipBackend) {
    Push-RepositoryIfNeeded -Label 'services/backend' -WorkingDirectory (Join-Path $RepoRoot 'services/backend')
}

if (-not $SkipWeb) {
    Push-RepositoryIfNeeded -Label 'apps/web' -WorkingDirectory (Join-Path $RepoRoot 'apps/web')
}

if (-not $SkipDesktop) {
    Push-RepositoryIfNeeded -Label 'apps/desktop' -WorkingDirectory (Join-Path $RepoRoot 'apps/desktop')
}

if (-not $SkipRoot) {
    Push-RepositoryIfNeeded -Label 'root' -WorkingDirectory $RepoRoot
}

Write-Host ''
Write-Host '推送编排完成。'
