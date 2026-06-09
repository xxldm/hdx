param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactRoot,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedRootRepository,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedRootRef,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedRootCommit,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedBackendRepository,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedBackendCommit,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedRunId,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedRunAttempt,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedArtifactName,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedOpenApiSnapshotHash,

    [string]$ExtractRoot = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Assert-Pattern {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Value -notmatch $Pattern) {
        throw "$Name 无效：$Message"
    }
}

function Assert-NoLatest {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    if ($Value -match '(?i)latest') {
        throw "$Name 不能包含 latest。"
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        $Actual,
        $Expected
    )

    if ($Actual -ne $Expected) {
        throw "$Name 不一致：期望 $Expected，实际 $Actual"
    }
}

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Assert-PathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Child
    )

    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $parentWithSeparator = $parentFull + [System.IO.Path]::DirectorySeparatorChar

    if (
        $childFull -ne $parentFull -and
        -not $childFull.StartsWith($parentWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        throw "路径必须位于 $parentFull 之下：$childFull"
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "缺少 JSON 文件：$Path"
    }

    $jsonText = Get-Content -LiteralPath $Path -Raw
    $convertFromJson = Get-Command ConvertFrom-Json
    if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
        return $jsonText | ConvertFrom-Json -Depth 100 -DateKind String
    }
    return $jsonText | ConvertFrom-Json -Depth 100
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Expand-NativeArchive {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$Packaging,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    if ($Packaging -eq 'tar.gz') {
        $tar = Get-Command tar -ErrorAction SilentlyContinue
        if ($null -eq $tar) {
            throw "无法解压 tar.gz，因为未找到 tar 命令：$ArchivePath"
        }

        & $tar.Source -xzf $ArchivePath -C $Destination
        if ($LASTEXITCODE -ne 0) {
            throw "解压 tar.gz 失败：$ArchivePath"
        }
        return
    }

    if ($Packaging -eq 'zip') {
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $Destination -Force
        return
    }

    throw "不支持的后端 native 包格式：$Packaging"
}

Assert-Pattern -Name 'ExpectedVersion' -Value $ExpectedVersion -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-NoLatest -Name 'ExpectedVersion' -Value $ExpectedVersion
Assert-NoLatest -Name 'ExpectedRootRef' -Value $ExpectedRootRef
Assert-NoLatest -Name 'ExpectedArtifactName' -Value $ExpectedArtifactName
Assert-Pattern -Name 'ExpectedRootCommit' -Value $ExpectedRootCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'ExpectedBackendCommit' -Value $ExpectedBackendCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'ExpectedOpenApiSnapshotHash' -Value $ExpectedOpenApiSnapshotHash -Pattern '^[0-9a-f]{64}$' -Message '必须是 64 位小写 SHA-256。'
Assert-Pattern -Name 'ExpectedBackendRepository' -Value $ExpectedBackendRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'ExpectedRootRepository' -Value $ExpectedRootRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'

[long]$runIdValue = 0
if (-not [long]::TryParse($ExpectedRunId, [ref]$runIdValue) -or $runIdValue -lt 1) {
    throw 'ExpectedRunId 必须是大于 0 的整数。'
}

[int]$runAttemptValue = 0
if (-not [int]::TryParse($ExpectedRunAttempt, [ref]$runAttemptValue) -or $runAttemptValue -lt 1) {
    throw 'ExpectedRunAttempt 必须是大于 0 的整数。'
}

$artifactRootFull = Get-FullPath -Path $ArtifactRoot
if (-not (Test-Path -LiteralPath $artifactRootFull -PathType Container)) {
    throw "ArtifactRoot 不存在：$artifactRootFull"
}

if ([string]::IsNullOrWhiteSpace($ExtractRoot)) {
    $ExtractRoot = Join-Path $RepoRoot "target/release-backend-artifact-check/extracted-$runIdValue"
}

$extractRootFull = Get-FullPath -Path $ExtractRoot
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $extractRootFull

if (Test-Path -LiteralPath $extractRootFull) {
    Remove-Item -LiteralPath $extractRootFull -Recurse -Force
}
New-Item -ItemType Directory -Path $extractRootFull | Out-Null

$manifestPath = Join-Path $artifactRootFull 'backend-native-manifest.json'
$manifest = Read-JsonFile -Path $manifestPath

Assert-Equal -Name 'manifest.schemaVersion' -Actual $manifest.schemaVersion -Expected '1.0'
Assert-Equal -Name 'manifest.manifestKind' -Actual $manifest.manifestKind -Expected 'backend-native'
Assert-Equal -Name 'manifest.version' -Actual $manifest.version -Expected $ExpectedVersion
Assert-Equal -Name 'manifest.root.repository' -Actual $manifest.root.repository -Expected $ExpectedRootRepository
Assert-Equal -Name 'manifest.root.ref' -Actual $manifest.root.ref -Expected $ExpectedRootRef
Assert-Equal -Name 'manifest.root.commit' -Actual $manifest.root.commit -Expected $ExpectedRootCommit
Assert-Equal -Name 'manifest.backend.repository' -Actual $manifest.backend.repository -Expected $ExpectedBackendRepository
Assert-Equal -Name 'manifest.backend.commit' -Actual $manifest.backend.commit -Expected $ExpectedBackendCommit
Assert-Equal -Name 'manifest.backend.sourceVisibility' -Actual $manifest.backend.sourceVisibility -Expected 'private'
Assert-Equal -Name 'manifest.githubActions.runId' -Actual ([long]$manifest.githubActions.runId) -Expected $runIdValue
Assert-Equal -Name 'manifest.githubActions.runAttempt' -Actual ([int]$manifest.githubActions.runAttempt) -Expected $runAttemptValue
Assert-Equal -Name 'manifest.githubActions.artifactName' -Actual $manifest.githubActions.artifactName -Expected $ExpectedArtifactName
Assert-Equal -Name 'manifest.openapiSnapshotHash' -Actual $manifest.openapiSnapshotHash -Expected $ExpectedOpenApiSnapshotHash
Assert-Equal -Name 'manifest.forbiddenFilesScan.status' -Actual $manifest.forbiddenFilesScan.status -Expected 'passed'

$artifacts = @($manifest.artifacts)
if ($artifacts.Count -lt 1) {
    throw 'backend-native-manifest.json 至少需要 1 个 artifacts 条目。'
}

$scanPaths = @()
foreach ($artifact in $artifacts) {
    $archivePath = Join-Path $artifactRootFull $artifact.fileName
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "manifest 指向的后端 native 包不存在：$archivePath"
    }

    $actualSha256 = Get-Sha256 -Path $archivePath
    if ($actualSha256 -ne $artifact.sha256) {
        throw "后端 native 包 sha256 不匹配：$($artifact.fileName)，期望 $($artifact.sha256)，实际 $actualSha256"
    }

    $actualSize = (Get-Item -LiteralPath $archivePath).Length
    if ($actualSize -ne [int64]$artifact.sizeBytes) {
        throw "后端 native 包 sizeBytes 不匹配：$($artifact.fileName)，期望 $($artifact.sizeBytes)，实际 $actualSize"
    }

    $artifactExtractRoot = Join-Path $extractRootFull ([System.IO.Path]::GetFileNameWithoutExtension($artifact.fileName))
    if ($artifact.fileName.EndsWith('.tar.gz')) {
        $artifactExtractRoot = Join-Path $extractRootFull ($artifact.fileName.Substring(0, $artifact.fileName.Length - '.tar.gz'.Length))
    }

    Expand-NativeArchive -ArchivePath $archivePath -Packaging $artifact.packaging -Destination $artifactExtractRoot
    $scanPaths += $artifactExtractRoot
}

$releaseManifestCheck = Join-Path $PSScriptRoot 'release-manifest-check.ps1'
$releaseCheckArgs = @(
    '-NoLogo',
    '-NoProfile',
    '-File',
    $releaseManifestCheck,
    '-BackendNativeManifestPath',
    $manifestPath,
    '-AssetRoot',
    $artifactRootFull,
    '-ScanPath'
) + $scanPaths

& pwsh @releaseCheckArgs
if ($LASTEXITCODE -ne 0) {
    throw "Release manifest 校验失败，退出码：$LASTEXITCODE"
}

Write-Host '后端 Actions artifact 下载内容校验通过。'
Write-Host "artifactName：$ExpectedArtifactName"
Write-Host "backendCommit：$ExpectedBackendCommit"
Write-Host "rootCommit：$ExpectedRootCommit"
