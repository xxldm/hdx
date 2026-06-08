param(
    [ValidateSet('changed', 'all', 'backend', 'web', 'desktop', 'docs')]
    [string]$Scope = 'changed',
    [switch]$SkipBackend,
    [switch]$SkipWeb,
    [switch]$SkipDesktop,
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
$DesktopRoot = Join-Path $RepoRoot 'apps/desktop'
$SubmoduleStatusScript = Join-Path $RepoRoot 'scripts/git-submodule-status.ps1'

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
    Write-Host "$(U '目录：')$WorkingDirectory"
    Write-Host "$(U '命令：')$(Format-CommandLine -Command $Command -Arguments $Arguments)"

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
            throw "$(U '命令失败，退出码：')$exitCode"
        }
    }
    finally {
        Pop-Location
        foreach ($name in $Environment.Keys) {
            [System.Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
    }

    $elapsed = (Get-Date) - $startedAt
    Write-Host ([string]::Format((U '通过：{0:N1}s'), $elapsed.TotalSeconds))
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $output = & git -C $WorkingDirectory @Arguments
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "$(U 'Git 命令失败：')git -C $WorkingDirectory $($Arguments -join ' ')"
    }
    return @($output)
}

function Get-TrackedPowerShellScripts {
    $relativePaths = Invoke-Git -WorkingDirectory $RepoRoot -Arguments @('ls-files', '--', '*.ps1', 'scripts/*.ps1')
    return @($relativePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Assert-PowerShellScriptEncoding {
    Write-Section (U 'PowerShell 脚本编码检查')

    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
    $scripts = Get-TrackedPowerShellScripts
    foreach ($relativePath in $scripts) {
        $fullPath = Join-Path $RepoRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath)) {
            throw "$(U '缺少 PowerShell 脚本：')$relativePath"
        }

        $bytes = [System.IO.File]::ReadAllBytes($fullPath)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        if (-not $hasBom) {
            throw "$(U 'PowerShell 脚本必须使用 UTF-8 with BOM：')$relativePath"
        }

        $content = [System.IO.File]::ReadAllText($fullPath, $utf8Strict)
        if ($content -match '\\u[0-9a-fA-F]{4}') {
            throw "$(U 'PowerShell 脚本不应保留 Unicode 转义中文：')$relativePath"
        }
    }

    Write-Host (U '通过：PowerShell 脚本均为 UTF-8 with BOM，且未保留 Unicode 转义中文。')
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

    throw (U '未找到 pnpm。请先安装 pnpm，或确认 apps/web 或 apps/desktop 的本地 Node 环境可用。')
}

function Assert-Tooling {
    $javaPath = Join-Path $JavaHome 'bin/java.exe'
    if (-not (Test-Path -LiteralPath $javaPath)) {
        throw "$(U '未找到 GraalVM JDK 25：')$JavaHome"
    }
    if (-not (Test-Path -LiteralPath $MavenPath)) {
        throw "$(U '未找到 Maven：')$MavenPath"
    }
    if (-not (Test-Path -LiteralPath $BackendRoot)) {
        throw "$(U '未找到后端目录：')$BackendRoot"
    }
    if (-not (Test-Path -LiteralPath $WebRoot)) {
        throw "$(U '未找到 Web 目录：')$WebRoot"
    }
    if (-not (Test-Path -LiteralPath $DesktopRoot)) {
        throw "$(U '未找到 Desktop 目录：')$DesktopRoot"
    }
}

function Invoke-DocChecks {
    Write-Section (U '文档与根仓库检查')
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
            throw "$(U '缺少文档：')$relativePath"
        }
        Get-Content -LiteralPath $path -Encoding UTF8 | Out-Null
    }
    Write-Host (U '通过：关键文档可按 UTF-8 读取。')

    Assert-PowerShellScriptEncoding

    Invoke-Step `
        -Title (U '根仓库空白检查') `
        -WorkingDirectory $RepoRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    Invoke-Step `
        -Title (U 'Release manifest 校验') `
        -WorkingDirectory $RepoRoot `
        -Command 'powershell' `
        -Arguments @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $RepoRoot 'scripts/release-manifest-check.ps1')
        )

    Invoke-Step `
        -Title (U 'OpenAPI 契约检查') `
        -WorkingDirectory $RepoRoot `
        -Command 'powershell' `
        -Arguments @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $RepoRoot 'scripts/openapi-contract-check.ps1')
        )

    Invoke-Step `
        -Title (U 'OpenAPI TypeScript 类型生成检查') `
        -WorkingDirectory $RepoRoot `
        -Command 'powershell' `
        -Arguments @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $RepoRoot 'scripts/openapi-generate-types.ps1'),
            '-Check'
        )

    Invoke-Step `
        -Title (U 'OpenAPI 与 Web 类型对齐检查') `
        -WorkingDirectory $RepoRoot `
        -Command 'powershell' `
        -Arguments @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $RepoRoot 'scripts/openapi-web-type-check.ps1')
        )
}

function Invoke-BackendChecks {
    if ($SkipBackend) {
        Write-Host (U '跳过：后端检查已被 -SkipBackend 禁用。')
        return
    }

    $toolEnv = @{
        JAVA_HOME = $JavaHome
        PATH = "$JavaHome\bin;$(Split-Path -Parent $MavenPath);$env:PATH"
    }

    Invoke-Step `
        -Title (U '后端空白检查') `
        -WorkingDirectory $BackendRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    if ($NoBuild) {
        Invoke-Step `
            -Title (U '后端 Maven 环境检查') `
            -WorkingDirectory $BackendRoot `
            -Command $MavenPath `
            -Arguments @('-version') `
            -Environment $toolEnv
        return
    }

    Invoke-Step `
        -Title (U '后端测试') `
        -WorkingDirectory $BackendRoot `
        -Command $MavenPath `
        -Arguments @('test') `
        -Environment $toolEnv
}

function Invoke-WebChecks {
    if ($SkipWeb) {
        Write-Host (U '跳过：Web 检查已被 -SkipWeb 禁用。')
        return
    }

    $pnpm = Get-PnpmCommand

    Invoke-Step `
        -Title (U 'Web 空白检查') `
        -WorkingDirectory $WebRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    Invoke-Step `
        -Title (U 'Web 单元测试') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('test')

    Invoke-Step `
        -Title (U 'Web 类型检查') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('typecheck')

    Invoke-Step `
        -Title (U 'Web lint') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('lint')

    if ($NoBuild) {
        Write-Host (U '跳过：-NoBuild 已跳过 Web build。')
        return
    }

    Invoke-Step `
        -Title (U 'Web build') `
        -WorkingDirectory $WebRoot `
        -Command $pnpm `
        -Arguments @('build')
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
        'src-tauri/tauri.local.conf.json',
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
            throw "$(U '缺少 Desktop 骨架文件：')$relativePath"
        }
    }

    $jsonFiles = @(
        'package.json',
        'tsconfig.json',
        'src-tauri/tauri.conf.json',
        'src-tauri/tauri.local.conf.json',
        'src-tauri/tauri.online.conf.json',
        'src-tauri/capabilities/default.json'
    )
    foreach ($relativePath in $jsonFiles) {
        $path = Join-Path $DesktopRoot $relativePath
        Get-Content -LiteralPath $path -Encoding UTF8 -Raw | ConvertFrom-Json | Out-Null
    }

    $packageJsonPath = Join-Path $DesktopRoot 'package.json'
    $packageJson = Get-Content -LiteralPath $packageJsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
    foreach ($scriptName in @('dev:local', 'dev:online', 'build:local', 'build:online', 'typecheck')) {
        if ($null -eq $packageJson.scripts.$scriptName) {
            throw "$(U '缺少 Desktop 脚本：')$scriptName"
        }
    }

    $cargoToml = Get-Content -LiteralPath (Join-Path $DesktopRoot 'src-tauri/Cargo.toml') -Encoding UTF8 -Raw
    foreach ($requiredText in @('flavor-local', 'flavor-online', 'tauri = { version = "2.11.2"')) {
        if (-not $cargoToml.Contains($requiredText)) {
            throw "$(U ' Desktop Cargo 配置缺少：')$requiredText"
        }
    }

    Write-Host (U '通过：Desktop 骨架文件和配置可静态读取。')
}

function Invoke-DesktopChecks {
    if ($SkipDesktop) {
        Write-Host (U '跳过：Desktop 检查已被 -SkipDesktop 禁用。')
        return
    }

    Write-Section (U 'Desktop 静态骨架检查')
    Assert-DesktopStaticFiles

    Invoke-Step `
        -Title (U 'Desktop 空白检查') `
        -WorkingDirectory $DesktopRoot `
        -Command 'git' `
        -Arguments @('diff', '--check')

    if ($NoBuild) {
        Invoke-Step `
            -Title (U 'Desktop Node 环境检查') `
            -WorkingDirectory $DesktopRoot `
            -Command 'node' `
            -Arguments @('--version')

        $cargo = Get-Command cargo -ErrorAction SilentlyContinue
        if ($null -eq $cargo) {
            Write-Host (U '提示：当前环境未找到 cargo，-NoBuild 已跳过 Rust 编译检查。')
        }
        else {
            Write-Host "$(U '通过：已找到 cargo：')$($cargo.Source)"
        }
        return
    }

    $pnpm = Get-PnpmCommand
    Invoke-Step `
        -Title (U 'Desktop TypeScript 检查') `
        -WorkingDirectory $DesktopRoot `
        -Command $pnpm `
        -Arguments @('run', 'typecheck')

    $cargo = Get-Command cargo -ErrorAction SilentlyContinue
    if ($null -eq $cargo) {
        throw (U '未找到 cargo。请先安装 Rust 工具链，或确认 PATH 已生效。')
    }

    Invoke-Step `
        -Title (U 'Desktop Rust Local flavor 检查') `
        -WorkingDirectory $DesktopRoot `
        -Command $cargo.Source `
        -Arguments @('check', '--manifest-path', (Join-Path $DesktopRoot 'src-tauri/Cargo.toml'), '--features', 'flavor-local')

    Invoke-Step `
        -Title (U 'Desktop Rust Online flavor 检查') `
        -WorkingDirectory $DesktopRoot `
        -Command $cargo.Source `
        -Arguments @('check', '--manifest-path', (Join-Path $DesktopRoot 'src-tauri/Cargo.toml'), '--features', 'flavor-online')
}

function Show-GitStatus {
    Write-Section (U 'Git 状态')
    Write-Host (U '根仓库：')
    Invoke-Git -WorkingDirectory $RepoRoot -Arguments @('status', '--short', '--branch') | ForEach-Object { Write-Host $_ }

    if (Test-Path -LiteralPath $SubmoduleStatusScript) {
        Invoke-Step `
            -Title (U 'Git 子模块状态检查') `
            -WorkingDirectory $RepoRoot `
            -Command 'powershell' `
            -Arguments @(
                '-NoProfile',
                '-ExecutionPolicy',
                'Bypass',
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
    Write-Host (U 'changed 范围未检测到需要运行的模块验证；已完成基础 Git 状态检查。')
    exit 0
}

Write-Section (U '本轮质量门禁范围')
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

Write-Section (U '质量门禁完成')
Write-Host (U '全部检查通过。')
