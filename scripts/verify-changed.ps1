param(
    [ValidateSet('quick', 'commit', 'full')]
    [string]$Profile = 'commit',
    [switch]$SkipDocs,
    [switch]$SkipBackend,
    [switch]$SkipWeb,
    [switch]$SkipDesktop,
    [switch]$SkipOpenApi,
    [switch]$IncludeOpenApi,
    [switch]$NoBuild,
    [switch]$DryRun,
    [string]$JavaHome = 'D:\JetBrains\.jdks\graalvm-jdk-25.0.3+9.1',
    [string]$MavenPath = 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BackendRoot = Join-Path $RepoRoot 'services/backend'
$WebRoot = Join-Path $RepoRoot 'apps/web'
$DesktopRoot = Join-Path $RepoRoot 'apps/desktop'
$PowerShellCommand = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($PowerShellCommand)) {
    $PowerShellCommand = 'pwsh'
}

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

. (Join-Path $RepoRoot 'scripts/lib/quality-gate-common.ps1')

function Test-PathChangedBySubstring {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Paths,
        [Parameter(Mandatory = $true)][string[]]$Needles
    )

    foreach ($path in $Paths) {
        foreach ($needle in $Needles) {
            if ($path.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                return $true
            }
        }
    }

    return $false
}

function Test-AnyPathChanged {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Paths,
        [Parameter(Mandatory = $true)][string[]]$Prefixes
    )

    if ($Paths.Count -eq 0) {
        return $false
    }

    return Test-PathChanged -Paths $Paths -Prefixes $Prefixes
}

function Invoke-VerificationStep {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $commandArguments = @('-NoLogo', '-NoProfile', '-File', $ScriptPath) + $Arguments
    if ($DryRun) {
        Write-Section $Title
        Write-Host "预览命令：$(Format-CommandLine -Command $PowerShellCommand -Arguments $commandArguments)"
        return
    }

    Invoke-Step `
        -Title $Title `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments $commandArguments
}

function Invoke-RootGitDiffCheck {
    if ($DryRun) {
        Write-Section '根仓库空白检查'
        Write-Host '预览命令：git diff --check'
        return
    }

    Invoke-Step `
        -Title '根仓库空白检查' `
        -WorkingDirectory $RepoRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')
}

function Invoke-TargetedDocChecks {
    param(
        [Parameter(Mandatory = $true)][string[]]$RootPaths,
        [Parameter(Mandatory = $true)][bool]$ShouldRunOpenApi
    )

    Invoke-RootGitDiffCheck

    if (Test-AnyPathChanged -Paths $RootPaths -Prefixes @('docs/plans')) {
        Invoke-VerificationStep `
            -Title 'Active 计划状态索引检查' `
            -ScriptPath (Join-Path $RepoRoot 'scripts/sync-active-plan-status.ps1') `
            -Arguments @('-Check')
    }

    $releaseChanged = (Test-AnyPathChanged -Paths $RootPaths -Prefixes @(
        'packages/shared/contracts/release'
    )) -or (Test-PathChangedBySubstring -Paths $RootPaths -Needles @(
        'release-',
        'release-manifest'
    ))

    if ($releaseChanged) {
        Invoke-VerificationStep `
            -Title 'Release manifest 校验' `
            -ScriptPath (Join-Path $RepoRoot 'scripts/release-manifest-check.ps1')
    }

    $desktopAssetChanged = Test-PathChangedBySubstring -Paths $RootPaths -Needles @(
        'package-desktop-release-assets.ps1',
        'check-desktop-release-asset-packaging.ps1'
    )

    if ($desktopAssetChanged) {
        Invoke-VerificationStep `
            -Title 'Desktop Release asset 打包 fixture 检查' `
            -ScriptPath (Join-Path $RepoRoot 'scripts/check-desktop-release-asset-packaging.ps1')
    }

    if ($ShouldRunOpenApi) {
        Invoke-VerificationStep `
            -Title 'OpenAPI 聚合验证' `
            -ScriptPath (Join-Path $RepoRoot 'scripts/openapi-verify.ps1')
    }
}

function Invoke-BackendVerification {
    $arguments = @(
        '-BackendRoot',
        $BackendRoot,
        '-JavaHome',
        $JavaHome,
        '-MavenPath',
        $MavenPath
    )

    if ($Profile -eq 'quick') {
        $arguments += '-NoBuild'
    }
    elseif ($Profile -eq 'full' -and -not $NoBuild) {
        $arguments += '-AotSmoke'
    }

    Invoke-VerificationStep `
        -Title '后端变更验证' `
        -ScriptPath (Join-Path $RepoRoot 'scripts/backend-verify.ps1') `
        -Arguments $arguments
}

function Invoke-WebVerification {
    $arguments = @('-WebRoot', $WebRoot)

    if ($Profile -eq 'quick') {
        $arguments += @('-SkipTest', '-SkipTypecheck', '-SkipLint')
    }
    elseif ($Profile -eq 'full' -and -not $NoBuild) {
        $arguments += '-Build'
    }

    Invoke-VerificationStep `
        -Title 'Web 变更验证' `
        -ScriptPath (Join-Path $RepoRoot 'scripts/web-verify.ps1') `
        -Arguments $arguments
}

function Invoke-DesktopVerification {
    $arguments = @(
        '-Scope',
        'desktop',
        '-JavaHome',
        $JavaHome,
        '-MavenPath',
        $MavenPath
    )
    if ($Profile -ne 'full' -or $NoBuild) {
        $arguments += '-NoBuild'
    }

    Invoke-VerificationStep `
        -Title 'Desktop 变更验证' `
        -ScriptPath (Join-Path $RepoRoot 'scripts/quality-gate.ps1') `
        -Arguments $arguments
}

$rootPaths = @(Get-GitStatusPaths -WorkingDirectory $RepoRoot)
$backendPaths = @(if (Test-Path -LiteralPath $BackendRoot) { Get-GitStatusPaths -WorkingDirectory $BackendRoot })
$webPaths = @(if (Test-Path -LiteralPath $WebRoot) { Get-GitStatusPaths -WorkingDirectory $WebRoot })
$desktopPaths = @(if (Test-Path -LiteralPath $DesktopRoot) { Get-GitStatusPaths -WorkingDirectory $DesktopRoot })

$backendChanged = -not $SkipBackend -and (
    (Test-AnyPathChanged -Paths $rootPaths -Prefixes @('services/backend')) -or
    $backendPaths.Count -gt 0
)
$webChanged = -not $SkipWeb -and (
    (Test-AnyPathChanged -Paths $rootPaths -Prefixes @('apps/web')) -or
    $webPaths.Count -gt 0
)
$desktopChanged = -not $SkipDesktop -and (
    (Test-AnyPathChanged -Paths $rootPaths -Prefixes @('apps/desktop')) -or
    $desktopPaths.Count -gt 0
)
$docsChanged = -not $SkipDocs -and (Test-AnyPathChanged -Paths $rootPaths -Prefixes @(
    'docs',
    'packages/shared',
    'scripts',
    'README.md',
    'AGENTS.md',
    'WORKFLOW.md',
    '.env.example',
    '.env.symphony.example'
))

$openApiPathChanged = (Test-AnyPathChanged -Paths $rootPaths -Prefixes @(
    'packages/shared/contracts/openapi',
    'packages/shared/generated/openapi',
    'scripts/checks/openapi-web-type-compatibility.ts'
)) -or (Test-PathChangedBySubstring -Paths $rootPaths -Needles @(
    'openapi-'
)) -or (Test-AnyPathChanged -Paths $backendPaths -Prefixes @(
    'backend-contract'
)) -or (Test-PathChangedBySubstring -Paths $backendPaths -Needles @(
    'openapi',
    'OpenApi'
)) -or (Test-AnyPathChanged -Paths $webPaths -Prefixes @(
    'server/api/hdx',
    'app/types/hdx-api.ts',
    'app/utils/hdx-api-client.ts',
    'app/utils/api-error.ts'
))

$shouldRunOpenApi = -not $SkipOpenApi -and ($IncludeOpenApi -or ($Profile -ne 'quick' -and $openApiPathChanged))
$hasWork = $docsChanged -or $backendChanged -or $webChanged -or $desktopChanged -or $shouldRunOpenApi

Write-Section '变更验证范围'
Write-Host "Profile: $Profile"
Write-Host "DryRun: $DryRun"
Write-Host "Docs: $docsChanged"
Write-Host "Backend: $backendChanged"
Write-Host "Web: $webChanged"
Write-Host "Desktop: $desktopChanged"
Write-Host "OpenAPI: $shouldRunOpenApi"
Write-Host "NoBuild: $NoBuild"

if (-not $hasWork) {
    Write-Host ''
    Write-Host '未检测到需要运行的变更验证。'
    exit 0
}

if ($docsChanged -or $shouldRunOpenApi) {
    Invoke-TargetedDocChecks -RootPaths $rootPaths -ShouldRunOpenApi $shouldRunOpenApi
}

if ($backendChanged) {
    Invoke-BackendVerification
}

if ($webChanged) {
    Invoke-WebVerification
}

if ($desktopChanged) {
    Invoke-DesktopVerification
}

Write-Section '变更验证完成'
if ($DryRun) {
    Write-Host '预览完成。'
}
else {
    Write-Host '全部检查通过。'
}
