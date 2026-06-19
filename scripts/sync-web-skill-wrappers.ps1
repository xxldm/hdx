param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$webRoot = Join-Path $RepoRoot 'apps\web'
$lockPath = Join-Path $webRoot 'skills-lock.json'
$rootSkillsDir = Join-Path $RepoRoot '.codex\skills'

if (-not (Test-Path -LiteralPath $lockPath)) {
  throw "找不到 Web skills-lock.json：$lockPath"
}

$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $rootSkillsDir)) {
  New-Item -ItemType Directory -Path $rootSkillsDir | Out-Null
}

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

Get-ChildItem -LiteralPath $rootSkillsDir -Directory -Filter 'hdx-web-*' | ForEach-Object {
  Remove-Item -LiteralPath $_.FullName -Recurse -Force
}

foreach ($skillName in $lock.skills.PSObject.Properties.Name) {
  $skill = $lock.skills.$skillName
  $wrapperName = "hdx-web-$skillName"
  $realSkillPath = if ($skill.sourceType -eq 'github') {
    "apps/web/.agents/$($skill.skillPath)"
  } else {
    "apps/web/$($skill.skillPath)"
  }
  $realSkillFilePath = Join-Path $RepoRoot ($realSkillPath -replace '/', '\')
  $sourceDescription = Get-SkillDescription -SkillPath $realSkillFilePath
  $wrapperDescription = ConvertTo-YamlSingleQuotedScalar -Value "HDX Web / apps/web: $sourceDescription"
  $entryDir = Join-Path $rootSkillsDir $wrapperName

  New-Item -ItemType Directory -Path $entryDir -Force | Out-Null

  $wrapper = @"
---
name: $wrapperName
description: $wrapperDescription
---

# $wrapperName

真实技能路径：$realSkillPath

使用前请读取真实技能文件，并遵循其中说明。
"@

  Set-Content -LiteralPath (Join-Path $entryDir 'SKILL.md') -Value $wrapper -NoNewline -Encoding utf8
}

Write-Host "已同步 Web 技能 wrapper 到 $rootSkillsDir"
