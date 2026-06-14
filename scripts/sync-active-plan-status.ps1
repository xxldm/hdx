param(
    [switch]$Check,
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

$ActivePlanDir = Join-Path $RepoRoot 'docs/plans/active'
$ReadmePath = Join-Path $ActivePlanDir 'README.md'
$StatusStartMarker = '<!-- active-plan-status:start -->'
$StatusEndMarker = '<!-- active-plan-status:end -->'
$IndexStartMarker = '<!-- active-plan-index:start -->'
$IndexEndMarker = '<!-- active-plan-index:end -->'
$RequiredFields = @('何时读取', '当前状态', '下一步', '主要剩余风险')

function Escape-MarkdownTableCell {
    param([Parameter(Mandatory = $true)][string]$Value)

    return ($Value -replace "`r?`n", ' ' -replace '\|', '\|').Trim()
}

function Get-StatusBlock {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$PlanFile)

    $content = Get-Content -LiteralPath $PlanFile.FullName -Encoding UTF8 -Raw
    $start = $content.IndexOf($StatusStartMarker, [System.StringComparison]::Ordinal)
    $end = $content.IndexOf($StatusEndMarker, [System.StringComparison]::Ordinal)
    if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
        throw "缺少 active plan 状态块：$($PlanFile.FullName)"
    }

    $blockStart = $start + $StatusStartMarker.Length
    $block = $content.Substring($blockStart, $end - $blockStart)
    $values = [ordered]@{}
    foreach ($line in ($block -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -notmatch '^\s*-\s*(何时读取|当前状态|下一步|主要剩余风险)：\s*(.+?)\s*$') {
            throw "状态块格式错误：$($PlanFile.Name)：$line"
        }

        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($values.Contains($name)) {
            throw "状态块字段重复：$($PlanFile.Name)：$name"
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "状态块字段不能为空：$($PlanFile.Name)：$name"
        }
        $values[$name] = $value
    }

    foreach ($field in $RequiredFields) {
        if (-not $values.Contains($field)) {
            throw "状态块缺少字段：$($PlanFile.Name)：$field"
        }
    }

    return [pscustomobject]@{
        FileName = $PlanFile.Name
        When = $values['何时读取']
        Status = $values['当前状态']
        Next = $values['下一步']
        Risk = $values['主要剩余风险']
    }
}

function New-IndexTable {
    param([Parameter(Mandatory = $true)][object[]]$Statuses)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| 计划 | 何时读取 | 当前状态 | 下一步 | 主要剩余风险 |')
    $lines.Add('| --- | --- | --- | --- | --- |')
    foreach ($status in $Statuses) {
        $link = "[$($status.FileName)]($($status.FileName))"
        $lines.Add(('| {0} | {1} | {2} | {3} | {4} |' -f `
            $link,
            (Escape-MarkdownTableCell $status.When),
            (Escape-MarkdownTableCell $status.Status),
            (Escape-MarkdownTableCell $status.Next),
            (Escape-MarkdownTableCell $status.Risk)))
    }
    return ($lines -join [Environment]::NewLine)
}

if (-not (Test-Path -LiteralPath $ReadmePath)) {
    throw "缺少 Active 计划索引：$ReadmePath"
}

$planFiles = Get-ChildItem -LiteralPath $ActivePlanDir -Filter '*.md' |
    Where-Object { $_.Name -ne 'README.md' } |
    Sort-Object Name

if ($planFiles.Count -eq 0) {
    throw "没有找到 active plan：$ActivePlanDir"
}

$statuses = foreach ($planFile in $planFiles) {
    Get-StatusBlock -PlanFile $planFile
}

$table = New-IndexTable -Statuses @($statuses)
$replacement = $IndexStartMarker + [Environment]::NewLine + $table + [Environment]::NewLine + $IndexEndMarker
$readme = Get-Content -LiteralPath $ReadmePath -Encoding UTF8 -Raw
$pattern = [regex]::Escape($IndexStartMarker) + '(?s).*?' + [regex]::Escape($IndexEndMarker)
if (-not [regex]::IsMatch($readme, $pattern)) {
    throw "Active 计划索引缺少生成标记：$ReadmePath"
}

$updated = [regex]::Replace($readme, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement }, 1)

if ($Check) {
    if ($updated -ne $readme) {
        throw "Active 计划索引未同步。请运行：pwsh -NoLogo -NoProfile -File scripts/sync-active-plan-status.ps1"
    }
    Write-Host '通过：Active 计划状态索引已同步。'
    exit 0
}

Set-Content -LiteralPath $ReadmePath -Encoding UTF8 -NoNewline -Value $updated
Write-Host "已同步 Active 计划状态索引：$ReadmePath"
