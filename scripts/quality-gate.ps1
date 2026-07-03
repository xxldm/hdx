param(
    [ValidateSet('changed', 'all', 'backend', 'web', 'desktop', 'docs')]
    [string]$Scope = 'changed',
    [switch]$SkipBackend,
    [switch]$SkipWeb,
    [switch]$SkipDesktop,
    [switch]$NoBuild,
    [string]$JavaHome = 'D:\JetBrains\.jdks\graalvm-25.1.3+9.1',
    [string]$MavenPath = 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BackendRoot = Join-Path $RepoRoot 'services/backend'
$WebRoot = Join-Path $RepoRoot 'apps/web'
$DesktopRoot = Join-Path $RepoRoot 'apps/desktop'
$InternalDocsRoot = Join-Path $RepoRoot 'internal-docs'
$InternalDocsSafeDirectory = $InternalDocsRoot.Replace('\', '/')
$SubmoduleStatusScript = Join-Path $RepoRoot 'scripts/git-submodule-status.ps1'
$PowerShellCommand = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($PowerShellCommand)) {
    $PowerShellCommand = 'pwsh'
}

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

. (Join-Path $RepoRoot 'scripts/lib/quality-gate-common.ps1')

function Assert-Tooling {
    $javaPath = Join-Path $JavaHome 'bin/java.exe'
    if (-not (Test-Path -LiteralPath $javaPath)) {
        throw "未找到 GraalVM JDK 25：$JavaHome"
    }
    if (-not (Test-Path -LiteralPath $MavenPath)) {
        throw "未找到 Maven：$MavenPath"
    }
    if (-not (Test-Path -LiteralPath $BackendRoot)) {
        throw "未找到后端目录：$BackendRoot"
    }
    if (-not (Test-Path -LiteralPath $WebRoot)) {
        throw "未找到 Web 目录：$WebRoot"
    }
    if (-not (Test-Path -LiteralPath $DesktopRoot)) {
        throw "未找到 Desktop 目录：$DesktopRoot"
    }
}

function Test-InternalDocsCheckout {
    return (Test-Path -LiteralPath (Join-Path $InternalDocsRoot '.git'))
}

function Test-InternalDocsGitAvailable {
    if (-not (Test-InternalDocsCheckout)) {
        return $false
    }

    $null = & git -c "safe.directory=$InternalDocsSafeDirectory" -C $InternalDocsRoot status --porcelain=v1 2>$null
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    return $exitCode -eq 0
}

function Invoke-DocChecks {
    Write-Section '文档与根仓库检查'
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
            throw "缺少文档：$relativePath"
        }
        Get-Content -LiteralPath $path -Raw | Out-Null
    }

    $internalDocsReadme = Join-Path $InternalDocsRoot 'README.md'
    if (Test-Path -LiteralPath $internalDocsReadme) {
        Get-Content -LiteralPath $internalDocsReadme -Raw | Out-Null
    }
    Write-Host '通过：关键文档可读取。'

    Invoke-Step `
        -Title '根仓库空白检查' `
        -WorkingDirectory $RepoRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    if (Test-InternalDocsGitAvailable) {
        Invoke-Step `
            -Title '内部文档空白检查' `
            -WorkingDirectory $RepoRoot `
            -Command 'git' `
            -Arguments @('-c', "safe.directory=$InternalDocsSafeDirectory", '-C', $InternalDocsRoot, 'diff', '--check')
    }
    elseif (Test-Path -LiteralPath $InternalDocsRoot) {
        Write-Host '跳过：internal-docs 不可作为 Git 工作树读取，可能未检出、没有私有仓库权限或 Git ownership 不匹配；仅检查主仓库子模块指针。'
    }

    Invoke-Step `
        -Title 'Active 计划状态索引检查' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            (Join-Path $RepoRoot 'scripts/sync-active-plan-status.ps1'),
            '-Check'
        )

    Invoke-Step `
        -Title 'Release manifest 校验' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            (Join-Path $RepoRoot 'scripts/release-manifest-check.ps1')
        )

    Invoke-Step `
        -Title 'Desktop Release asset 打包 fixture 检查' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            (Join-Path $RepoRoot 'scripts/check-desktop-release-asset-packaging.ps1')
        )

    Invoke-Step `
        -Title 'OpenAPI 契约检查' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            (Join-Path $RepoRoot 'scripts/openapi-contract-check.ps1')
        )

    Invoke-Step `
        -Title 'OpenAPI TypeScript 类型生成检查' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            (Join-Path $RepoRoot 'scripts/openapi-generate-types.ps1'),
            '-Check'
        )

    Invoke-Step `
        -Title 'OpenAPI 与 Web 类型对齐检查' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            (Join-Path $RepoRoot 'scripts/openapi-web-type-check.ps1')
        )
}

function Invoke-BackendChecks {
    if ($SkipBackend) {
        Write-Host '跳过：后端检查已被 -SkipBackend 禁用。'
        return
    }

    $backendVerifyArguments = @(
        '-NoLogo',
        '-NoProfile',
        '-File',
        (Join-Path $RepoRoot 'scripts/backend-verify.ps1'),
        '-BackendRoot',
        $BackendRoot,
        '-JavaHome',
        $JavaHome,
        '-MavenPath',
        $MavenPath
    )
    if ($NoBuild) {
        $backendVerifyArguments += '-NoBuild'
    }
    else {
        $backendVerifyArguments += '-AotSmoke'
    }

    Invoke-Step `
        -Title '后端聚合验证' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments $backendVerifyArguments
}

function Invoke-WebChecks {
    if ($SkipWeb) {
        Write-Host '跳过：Web 检查已被 -SkipWeb 禁用。'
        return
    }

    $webVerifyArguments = @(
        '-NoLogo',
        '-NoProfile',
        '-File',
        (Join-Path $RepoRoot 'scripts/web-verify.ps1'),
        '-WebRoot',
        $WebRoot
    )
    if (-not $NoBuild) {
        $webVerifyArguments += '-Build'
    }

    Invoke-Step `
        -Title 'Web 聚合验证' `
        -WorkingDirectory $RepoRoot `
        -Command $PowerShellCommand `
        -Arguments $webVerifyArguments
}

function Assert-DesktopStaticFiles {
    $requiredFiles = @(
        'package.json',
        'tsconfig.json',
        'vite.config.ts',
        'index.html',
        'src/main.ts',
        'src/styles.css',
        'src-tauri/Cargo.toml',
        'src-tauri/Cargo.lock',
        'src-tauri/build.rs',
        'src-tauri/tauri.conf.json',
        'src-tauri/tauri.full.conf.json',
        'src-tauri/tauri.online.conf.json',
        'src-tauri/capabilities/default.json',
        'src-tauri/icons/icon.ico',
        'src-tauri/permissions/desktop-status.toml',
        'src-tauri/src/main.rs',
        'src-tauri/src/lib.rs',
        'src-tauri/src/flavor.rs',
        'src-tauri/src/capabilities.rs',
        'src-tauri/src/commands.rs'
    )

    foreach ($relativePath in $requiredFiles) {
        $path = Join-Path $DesktopRoot $relativePath
        if (-not (Test-Path -LiteralPath $path)) {
            throw "缺少 Desktop 骨架文件：$relativePath"
        }
    }

    $jsonFiles = @(
        'package.json',
        'tsconfig.json',
        'src-tauri/tauri.conf.json',
        'src-tauri/tauri.full.conf.json',
        'src-tauri/tauri.online.conf.json',
        'src-tauri/capabilities/default.json'
    )
    foreach ($relativePath in $jsonFiles) {
        $path = Join-Path $DesktopRoot $relativePath
        Get-Content -LiteralPath $path -Encoding UTF8 -Raw | ConvertFrom-Json | Out-Null
    }

    $packageJsonPath = Join-Path $DesktopRoot 'package.json'
    $packageJson = Get-Content -LiteralPath $packageJsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
    foreach ($scriptName in @('dev:full', 'dev:online', 'build:full', 'build:online', 'typecheck')) {
        if ($null -eq $packageJson.scripts.$scriptName) {
            throw "缺少 Desktop 脚本：$scriptName"
        }
    }

    $cargoToml = Get-Content -LiteralPath (Join-Path $DesktopRoot 'src-tauri/Cargo.toml') -Encoding UTF8 -Raw
    foreach ($requiredText in @('flavor-full', 'flavor-online', 'tauri = { version = "2.11.2"')) {
        if (-not $cargoToml.Contains($requiredText)) {
            throw "Desktop Cargo 配置缺少：$requiredText"
        }
    }

    Write-Host '通过：Desktop 骨架文件和配置可静态读取。'
}

function Invoke-DesktopChecks {
    if ($SkipDesktop) {
        Write-Host '跳过：Desktop 检查已被 -SkipDesktop 禁用。'
        return
    }

    Write-Section 'Desktop 静态骨架检查'
    Assert-DesktopStaticFiles

    Invoke-Step `
        -Title 'Desktop 空白检查' `
        -WorkingDirectory $DesktopRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    if ($NoBuild) {
        Invoke-Step `
            -Title 'Desktop Node 环境检查' `
            -WorkingDirectory $DesktopRoot `
            -Command 'node' `
            -Arguments @('--version')

        $cargo = Get-Command cargo -ErrorAction SilentlyContinue
        if ($null -eq $cargo) {
            Write-Host '提示：当前环境未找到 cargo，-NoBuild 已跳过 Rust 编译检查。'
        }
        else {
            Write-Host "通过：已找到 cargo：$($cargo.Source)"
        }
        return
    }

    $pnpm = Get-PnpmCommand
    Invoke-Step `
        -Title 'Desktop TypeScript 检查' `
        -WorkingDirectory $DesktopRoot `
        -Command $pnpm `
        -Arguments @('run', 'typecheck')

    $cargo = Get-Command cargo -ErrorAction SilentlyContinue
    if ($null -eq $cargo) {
        throw '未找到 cargo。请先安装 Rust 工具链，或确认 PATH 已生效。'
    }

    Invoke-Step `
        -Title 'Desktop Rust Full flavor 检查' `
        -WorkingDirectory $DesktopRoot `
        -Command $cargo.Source `
        -Arguments @('check', '--manifest-path', (Join-Path $DesktopRoot 'src-tauri/Cargo.toml'), '--features', 'flavor-full')

    Invoke-Step `
        -Title 'Desktop Rust Online flavor 检查' `
        -WorkingDirectory $DesktopRoot `
        -Command $cargo.Source `
        -Arguments @('check', '--manifest-path', (Join-Path $DesktopRoot 'src-tauri/Cargo.toml'), '--features', 'flavor-online')
}

function Show-GitStatus {
    Write-Section 'Git 状态'
    Write-Host '根仓库：'
    Invoke-Git -WorkingDirectory $RepoRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }

    if (Test-Path -LiteralPath $SubmoduleStatusScript) {
        Invoke-Step `
            -Title 'Git 子模块状态检查' `
            -WorkingDirectory $RepoRoot `
            -Command $PowerShellCommand `
            -Arguments @(
                '-NoLogo',
                '-NoProfile',
                '-File',
                $SubmoduleStatusScript,
                '-RepoRoot',
                $RepoRoot
            )
    }

    if (Test-Path -LiteralPath $BackendRoot) {
        Write-Host 'services/backend:'
        Invoke-Git -WorkingDirectory $BackendRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }
    }

    if (Test-Path -LiteralPath $WebRoot) {
        Write-Host 'apps/web:'
        Invoke-Git -WorkingDirectory $WebRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }
    }

    if (Test-Path -LiteralPath $DesktopRoot) {
        Write-Host 'apps/desktop:'
        Invoke-Git -WorkingDirectory $DesktopRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }
    }
}

Assert-Tooling
Show-GitStatus

$rootPaths = Get-GitStatusPaths -WorkingDirectory $RepoRoot
$backendChanged = $false
$webChanged = $false
$desktopChanged = $false
$docsChanged = $false

switch ($Scope) {
    'all' {
        $backendChanged = $true
        $webChanged = $true
        $desktopChanged = $true
        $docsChanged = $true
    }
    'backend' {
        $backendChanged = $true
    }
    'web' {
        $webChanged = $true
    }
    'desktop' {
        $desktopChanged = $true
    }
    'docs' {
        $docsChanged = $true
    }
    'changed' {
        $backendChanged = (Test-PathChanged -Paths $rootPaths -Prefixes @('services/backend')) -or (Test-HasGitChanges -WorkingDirectory $BackendRoot)
        $webChanged = (Test-PathChanged -Paths $rootPaths -Prefixes @('apps/web')) -or (Test-HasGitChanges -WorkingDirectory $WebRoot)
        $desktopChanged = (Test-PathChanged -Paths $rootPaths -Prefixes @('apps/desktop')) -or (Test-HasGitChanges -WorkingDirectory $DesktopRoot)
        $docsChanged = Test-PathChanged -Paths $rootPaths -Prefixes @(
            'docs',
            'internal-docs',
            'packages/shared',
            'scripts',
            'README.md',
            'AGENTS.md',
            'WORKFLOW.md',
            '.env.example',
            '.env.symphony.example'
        )
    }
}

if (-not $backendChanged -and -not $webChanged -and -not $desktopChanged -and -not $docsChanged) {
    Write-Host ''
    Write-Host 'changed 范围未检测到需要运行的模块验证；已完成基础 Git 状态检查。'
    exit 0
}

Write-Section '本轮质量门禁范围'
Write-Host "Scope: $Scope"
Write-Host "Docs: $docsChanged"
Write-Host "Backend: $backendChanged"
Write-Host "Web: $webChanged"
Write-Host "Desktop: $desktopChanged"
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

if ($desktopChanged) {
    Invoke-DesktopChecks
}

Write-Section '质量门禁完成'
Write-Host '全部检查通过。'
