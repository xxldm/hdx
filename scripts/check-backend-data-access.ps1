param(
    [string]$BackendRoot = '',
    [switch]$ChangedOnly,
    [switch]$IncludeTests,
    [switch]$FailOnFindings
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($BackendRoot)) {
    $BackendRoot = Join-Path $RepoRoot 'services/backend'
}

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

if (-not (Test-Path -LiteralPath $BackendRoot)) {
    throw "未找到后端目录：$BackendRoot"
}

function Get-ChangedJavaFiles {
    $lines = & git -C $BackendRoot status --porcelain=v1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw '读取后端 Git 状态失败。'
    }

    foreach ($line in $lines) {
        if ($line.Length -lt 4) {
            continue
        }

        $relativePath = $line.Substring(3).Trim()
        if ($relativePath.Contains(' -> ')) {
            $parts = $relativePath -split ' -> '
            $relativePath = $parts[$parts.Count - 1]
        }

        if ($relativePath.EndsWith('.java', [StringComparison]::OrdinalIgnoreCase)) {
            $path = Join-Path $BackendRoot $relativePath
            if (Test-Path -LiteralPath $path) {
                Get-Item -LiteralPath $path
            }
        }
    }
}

function Get-JavaFiles {
    if ($ChangedOnly) {
        return @(Get-ChangedJavaFiles)
    }

    return @(Get-ChildItem -LiteralPath $BackendRoot -Recurse -File -Filter '*.java' |
        Where-Object { $_.FullName -notmatch '\\target\\' })
}

function Test-IsTestFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return $Path -match '\\src\\test\\'
}

function Convert-ToRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetRelativePath($BackendRoot, $Path).Replace('\', '/')
}

function Write-Finding {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$LineNumber = 0,
        [string]$Line = '',
        [Parameter(Mandatory = $true)][string]$Guidance
    )

    $script:FindingCount += 1
    $relativePath = Convert-ToRelativePath -Path $Path
    if ($LineNumber -gt 0) {
        Write-Host "- [$Kind] ${relativePath}:$LineNumber"
        Write-Host "  $($Line.Trim())"
    }
    else {
        Write-Host "- [$Kind] $relativePath"
    }
    Write-Host "  提醒：$Guidance"
}

$checks = @(
    @{
        Kind = '手写 JPA 查询'
        Pattern = '@(Query|Modifying)\b'
        Guidance = '普通查询优先派生查询、EntityGraph 或 projection；保留 @Query/@Modifying 时确认复杂 projection、fetch join、批量更新或清晰性理由。'
    },
    @{
        Kind = 'JDBC 访问'
        Pattern = '\bJdbc(Client|Template|Operations)\b'
        Guidance = '普通业务默认 JPA；JDBC 仅用于官方 schema、安全流程、CAS/批量、底层集成或测试夹具等明确例外。'
    },
    @{
        Kind = '原生 SQL'
        Pattern = 'createNativeQuery|nativeQuery\s*=\s*true'
        Guidance = '原生 SQL 需要 JPA 无法表达、数据库特性或性能验证理由。'
    },
    @{
        Kind = '显式数据库锁'
        Pattern = 'LockModeType|PESSIMISTIC_(READ|WRITE)|@Lock\b'
        Guidance = '可变业务记录默认 @Version 乐观锁；悲观锁需要确认必须串行化访问同一资源。'
    },
    @{
        Kind = '手动版本递增'
        Pattern = 'getVersion\(\)\s*\+\s*1|setVersion\(|recordVersion\s*\+|version\s*\+\s*1'
        Guidance = '可变业务记录默认交给 JPA @Version 递增；手动递增需记录例外理由。'
    }
)

$files = @(Get-JavaFiles | Where-Object {
    $IncludeTests -or -not (Test-IsTestFile -Path $_.FullName)
})

Write-Host '后端数据访问风格检查'
Write-Host "后端目录：$BackendRoot"
Write-Host "ChangedOnly: $ChangedOnly"
Write-Host "IncludeTests: $IncludeTests"
Write-Host ''

if ($files.Count -eq 0) {
    Write-Host '未找到需要扫描的 Java 文件。'
    exit 0
}

$FindingCount = 0

foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw

    foreach ($check in $checks) {
        $matches = Select-String -LiteralPath $file.FullName -Pattern $check.Pattern
        foreach ($match in $matches) {
            Write-Finding `
                -Kind $check.Kind `
                -Path $file.FullName `
                -LineNumber $match.LineNumber `
                -Line $match.Line `
                -Guidance $check.Guidance
        }
    }

    if ($content -match '@Entity\b' -and $content -notmatch '@Version\b') {
        Write-Finding `
            -Kind 'Entity 未声明 @Version' `
            -Path $file.FullName `
            -Guidance 'HDX 自建可变业务表默认需要 @Version；追加型日志、只读参考、从属明细、官方 schema 或安全基础设施需要确认例外。'
    }
}

Write-Host ''
if ($FindingCount -eq 0) {
    Write-Host '通过：未发现需要人工确认的数据访问偏离项。'
    exit 0
}

Write-Host "发现 $FindingCount 项需要按 docs/BACKEND_DATA_ACCESS.md 人工确认的数据访问偏离项。"
if ($FailOnFindings) {
    throw '后端数据访问风格检查发现偏离项。'
}

Write-Host '提示：当前默认只提醒不失败；确认合理后可继续。'
