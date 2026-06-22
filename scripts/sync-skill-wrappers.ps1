param(
  [ValidateSet('all', 'web', 'backend')]
  [string]$Scope = 'all',
  [switch]$Check,
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
  throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

$rootSkillsDir = Join-Path $RepoRoot '.codex\skills'

$projects = @(
  [pscustomobject]@{
    Scope = 'web'
    Prefix = 'hdx-web'
    Label = 'HDX Web / apps/web'
    ProjectRoot = 'apps/web'
    LockPath = 'apps/web/skills-lock.json'
    GithubInstallRoot = '.agents'
  },
  [pscustomobject]@{
    Scope = 'backend'
    Prefix = 'hdx-backend'
    Label = 'HDX Backend / services/backend'
    ProjectRoot = 'services/backend'
    LockPath = 'services/backend/skills-lock.json'
    GithubInstallRoot = '.agents'
  }
)

function ConvertTo-YamlSingleQuotedScalar {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  return "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-SingleLineDescription {
  param(
    [AllowEmptyString()]
    [string[]]$Lines
  )

  return (($Lines | ForEach-Object { $_.Trim() }) -join ' ' -replace '\s+', ' ').Trim()
}

function ConvertFrom-SimpleYamlScalar {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  $text = $Value.Trim()

  if ($text.Length -ge 2 -and $text.StartsWith("'") -and $text.EndsWith("'")) {
    return $text.Substring(1, $text.Length - 2).Replace("''", "'")
  }

  if ($text.Length -ge 2 -and $text.StartsWith('"') -and $text.EndsWith('"')) {
    return $text.Substring(1, $text.Length - 2).Replace('\"', '"')
  }

  return $text
}

function ConvertTo-RepoRelativeDisplayPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return ($Path -replace '\\', '/')
}

function Get-SkillDescription {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SkillPath
  )

  if (-not (Test-Path -LiteralPath $SkillPath)) {
    throw "找不到真实技能文件：$SkillPath"
  }

  $lines = Get-Content -LiteralPath $SkillPath

  if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') {
    throw "技能文件缺少 frontmatter：$SkillPath"
  }

  $frontmatter = [System.Collections.Generic.List[string]]::new()

  for ($index = 1; $index -lt $lines.Count; $index++) {
    if ($lines[$index].Trim() -eq '---') {
      break
    }

    $frontmatter.Add(($lines[$index]))
  }

  for ($index = 0; $index -lt $frontmatter.Count; $index++) {
    $line = $frontmatter[$index]

    if ($line -notmatch '^description:\s*(.*)$') {
      continue
    }

    $rawValue = $Matches[1].Trim()

    if ($rawValue -match '^[|>][+-]?$') {
      $blockLines = [System.Collections.Generic.List[string]]::new()

      for ($blockIndex = $index + 1; $blockIndex -lt $frontmatter.Count; $blockIndex++) {
        $blockLine = $frontmatter[$blockIndex]

        if ($blockLine -match '^[A-Za-z0-9_-]+:\s*') {
          break
        }

        $blockLines.Add(($blockLine -replace '^\s{2}', ''))
      }

      return ConvertTo-SingleLineDescription -Lines $blockLines
    }

    return ConvertTo-SingleLineDescription -Lines @((ConvertFrom-SimpleYamlScalar -Value $rawValue))
  }

  throw "技能文件缺少 description：$SkillPath"
}

function Resolve-RealSkillPath {
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Project,
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Skill
  )

  $projectRoot = Join-Path $RepoRoot $Project.ProjectRoot
  $skillPath = [string]$Skill.skillPath
  $normalizedSkillPath = $skillPath -replace '/', '\'

  if ($skillPath.StartsWith('.agents/') -or $skillPath.StartsWith('.codex/')) {
    return Join-Path $projectRoot $normalizedSkillPath
  }

  if ($Skill.sourceType -eq 'github') {
    return Join-Path $projectRoot (Join-Path $Project.GithubInstallRoot $normalizedSkillPath)
  }

  return Join-Path $projectRoot $normalizedSkillPath
}

function Get-DisplaySkillPath {
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Project,
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Skill
  )

  $skillPath = [string]$Skill.skillPath

  if ($skillPath.StartsWith('.agents/') -or $skillPath.StartsWith('.codex/')) {
    return ConvertTo-RepoRelativeDisplayPath (Join-Path $Project.ProjectRoot $skillPath)
  }

  if ($Skill.sourceType -eq 'github') {
    return ConvertTo-RepoRelativeDisplayPath (Join-Path $Project.ProjectRoot (Join-Path $Project.GithubInstallRoot $skillPath))
  }

  return ConvertTo-RepoRelativeDisplayPath (Join-Path $Project.ProjectRoot $skillPath)
}

function New-SkillWrapperContent {
  param(
    [Parameter(Mandatory = $true)]
    [string]$WrapperName,
    [Parameter(Mandatory = $true)]
    [string]$WrapperDescription,
    [Parameter(Mandatory = $true)]
    [string]$DisplaySkillPath
  )

  return @"
---
name: $WrapperName
description: $WrapperDescription
---

# $WrapperName

真实技能路径：$DisplaySkillPath

使用前请读取真实技能文件，并遵循其中说明。
"@
}

function Get-SelectedProjects {
  if ($Scope -eq 'all') {
    return $projects
  }

  return @($projects | Where-Object { $_.Scope -eq $Scope })
}

function New-ExpectedWrappers {
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$SelectedProjects
  )

  $wrappers = [ordered]@{}

  foreach ($project in $SelectedProjects) {
    $lockPath = Join-Path $RepoRoot $project.LockPath
    if (-not (Test-Path -LiteralPath $lockPath)) {
      throw "找不到 skills lock：$lockPath"
    }

    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json

    foreach ($skillName in $lock.skills.PSObject.Properties.Name) {
      $skill = $lock.skills.$skillName
      $wrapperName = "$($project.Prefix)-$skillName"
      $realSkillFilePath = Resolve-RealSkillPath -Project $project -Skill $skill
      $sourceDescription = Get-SkillDescription -SkillPath $realSkillFilePath
      $wrapperDescription = ConvertTo-YamlSingleQuotedScalar -Value "$($project.Label): $sourceDescription"
      $displaySkillPath = Get-DisplaySkillPath -Project $project -Skill $skill

      $wrappers[$wrapperName] = New-SkillWrapperContent `
        -WrapperName $wrapperName `
        -WrapperDescription $wrapperDescription `
        -DisplaySkillPath $displaySkillPath
    }
  }

  return $wrappers
}

function Test-GeneratedWrappers {
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.Specialized.OrderedDictionary]$ExpectedWrappers,
    [Parameter(Mandatory = $true)]
    [object[]]$SelectedProjects
  )

  foreach ($wrapperName in $ExpectedWrappers.Keys) {
    $wrapperPath = Join-Path $rootSkillsDir (Join-Path $wrapperName 'SKILL.md')
    if (-not (Test-Path -LiteralPath $wrapperPath)) {
      throw "技能 wrapper 缺失：$wrapperPath"
    }

    $actual = Get-Content -LiteralPath $wrapperPath -Raw
    if ($actual -ne $ExpectedWrappers[$wrapperName]) {
      throw "技能 wrapper 未同步：$wrapperPath"
    }
  }

  foreach ($project in $SelectedProjects) {
    $expectedNames = [System.Collections.Generic.HashSet[string]]::new([string[]]($ExpectedWrappers.Keys | Where-Object {
      $_.StartsWith("$($project.Prefix)-")
    }))

    Get-ChildItem -LiteralPath $rootSkillsDir -Directory -Filter "$($project.Prefix)-*" -ErrorAction SilentlyContinue | ForEach-Object {
      if (-not $expectedNames.Contains($_.Name)) {
        throw "发现多余技能 wrapper：$($_.FullName)"
      }
    }
  }
}

function Write-GeneratedWrappers {
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.Specialized.OrderedDictionary]$ExpectedWrappers,
    [Parameter(Mandatory = $true)]
    [object[]]$SelectedProjects
  )

  if (-not (Test-Path -LiteralPath $rootSkillsDir)) {
    New-Item -ItemType Directory -Path $rootSkillsDir | Out-Null
  }

  $resolvedRootSkillsDir = (Resolve-Path -LiteralPath $rootSkillsDir).Path

  foreach ($project in $SelectedProjects) {
    $expectedNames = [System.Collections.Generic.HashSet[string]]::new([string[]]($ExpectedWrappers.Keys | Where-Object {
      $_.StartsWith("$($project.Prefix)-")
    }))

    Get-ChildItem -LiteralPath $rootSkillsDir -Directory -Filter "$($project.Prefix)-*" -ErrorAction SilentlyContinue | ForEach-Object {
      if ($expectedNames.Contains($_.Name)) {
        return
      }

      $resolvedTarget = (Resolve-Path -LiteralPath $_.FullName).Path
      if (-not ($resolvedTarget.StartsWith($resolvedRootSkillsDir, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "拒绝删除 root skills 目录之外的路径：$resolvedTarget"
      }

      Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    }
  }

  foreach ($wrapperName in $ExpectedWrappers.Keys) {
    $entryDir = Join-Path $rootSkillsDir $wrapperName
    New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $entryDir 'SKILL.md') -Value $ExpectedWrappers[$wrapperName] -NoNewline -Encoding utf8
  }
}

$selectedProjects = @(Get-SelectedProjects)
$expectedWrappers = New-ExpectedWrappers -SelectedProjects $selectedProjects

if ($Check) {
  Test-GeneratedWrappers -ExpectedWrappers $expectedWrappers -SelectedProjects $selectedProjects
  Write-Host "通过：$Scope 技能 wrapper 已同步。"
  exit 0
}

Write-GeneratedWrappers -ExpectedWrappers $expectedWrappers -SelectedProjects $selectedProjects
Write-Host "已同步 $Scope 技能 wrapper 到 $rootSkillsDir"
