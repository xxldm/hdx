param(
  [switch]$Check,
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'sync-skill-wrappers.ps1') -Scope web -Check:$Check -RepoRoot $RepoRoot
