param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$PrivateRulesPath
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

$RepoRoot = (Resolve-Path $RepoRoot).Path
$excludedRelativePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
[void]$excludedRelativePaths.Add('scripts/check-public-doc-boundary.ps1')

$scanRoots = @(
    [pscustomobject]@{
        Path = 'docs'
        Include = @('*.md', '*.yml', '*.yaml')
    },
    [pscustomobject]@{
        Path = 'scripts'
        Include = @('*.ps1', '*.psm1', '*.ts', '*.js', '*.mjs')
    },
    [pscustomobject]@{
        Path = '.github/workflows'
        Include = @('*.md', '*.yml', '*.yaml')
    }
)

$rootFiles = @('AGENTS.md', 'README.md')

$rules = [System.Collections.Generic.List[object]]::new()

function Add-BoundaryRule {
    param(
        [Parameter(Mandatory = $true)][object]$Rule
    )

    foreach ($property in @('Id', 'Pattern', 'Reason')) {
        if ([string]::IsNullOrWhiteSpace([string]$Rule.$property)) {
            throw "文档边界规则缺少字段：$property"
        }
    }

    $rules.Add([pscustomobject]@{
        Id = [string]$Rule.Id
        Pattern = [string]$Rule.Pattern
        Reason = [string]$Rule.Reason
    })
}

@(
    [pscustomobject]@{
        Id = 'secret-like-token'
        Pattern = '(?i)\b(ghp_|github_pat_|glpat-|xox[baprs]-|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,})'
        Reason = '疑似访问令牌、API key 或云访问密钥不应出现在公开文档/脚本说明中。'
    },
    [pscustomobject]@{
        Id = 'private-key-block'
        Pattern = '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----'
        Reason = '私钥内容不得出现在公开文档/脚本说明中。'
    }
) | ForEach-Object { Add-BoundaryRule -Rule $_ }

if ([string]::IsNullOrWhiteSpace($PrivateRulesPath)) {
    $PrivateRulesPath = Join-Path $RepoRoot 'services/backend/docs/config/public-doc-boundary-rules.psd1'
}

if (Test-Path -LiteralPath $PrivateRulesPath) {
    $privateRulesData = Import-PowerShellDataFile -LiteralPath $PrivateRulesPath
    foreach ($rule in @($privateRulesData.Rules)) {
        Add-BoundaryRule -Rule ([pscustomobject]$rule)
    }

    Write-Host "已加载内部文档边界规则：$([System.IO.Path]::GetRelativePath($RepoRoot, (Resolve-Path $PrivateRulesPath).Path).Replace('\', '/'))"
}
else {
    Write-Host '提示：未找到内部文档边界规则，仅运行公开通用检查。'
}

function Convert-ToRepoRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = (Resolve-Path $Path).Path
    return [System.IO.Path]::GetRelativePath($RepoRoot, $fullPath).Replace('\', '/')
}

function Get-ScanFiles {
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($rootFile in $rootFiles) {
        $path = Join-Path $RepoRoot $rootFile
        if (Test-Path -LiteralPath $path) {
            $files.Add((Get-Item -LiteralPath $path))
        }
    }

    foreach ($scanRoot in $scanRoots) {
        $path = Join-Path $RepoRoot $scanRoot.Path
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        foreach ($include in $scanRoot.Include) {
            Get-ChildItem -LiteralPath $path -Recurse -File -Filter $include |
                ForEach-Object { $files.Add($_) }
        }
    }

    return $files |
        Sort-Object FullName -Unique |
        Where-Object {
            $relativePath = Convert-ToRepoRelativePath -Path $_.FullName
            -not $excludedRelativePaths.Contains($relativePath)
        }
}

$matches = [System.Collections.Generic.List[object]]::new()

foreach ($file in Get-ScanFiles) {
    $relativePath = Convert-ToRepoRelativePath -Path $file.FullName
    foreach ($rule in $rules) {
        $found = Select-String -LiteralPath $file.FullName -Pattern $rule.Pattern -AllMatches -CaseSensitive
        foreach ($match in $found) {
            $matches.Add([pscustomobject]@{
                Path = $relativePath
                Line = $match.LineNumber
                Rule = $rule.Id
                Reason = $rule.Reason
                Text = $match.Line.Trim()
            })
        }
    }
}

if ($matches.Count -gt 0) {
    Write-Host '公开文档边界检查失败：发现可能泄露后端内部实现的内容。'
    foreach ($match in $matches) {
        Write-Host ("- {0}:{1} [{2}] {3}" -f $match.Path, $match.Line, $match.Rule, $match.Reason)
        Write-Host ("  {0}" -f $match.Text)
    }
    throw '公开文档边界检查失败。'
}

Write-Host '通过：公开文档边界检查未发现禁止项。'
