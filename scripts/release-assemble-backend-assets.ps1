param(
    [Parameter(Mandatory = $true)]
    [string]$SourcesJsonPath,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$RootRepository,

    [Parameter(Mandatory = $true)]
    [string]$RootRef,

    [Parameter(Mandatory = $true)]
    [string]$RootCommit,

    [Parameter(Mandatory = $true)]
    [string]$BackendRepository,

    [Parameter(Mandatory = $true)]
    [string]$BackendCommit,

    [Parameter(Mandatory = $true)]
    [string]$OpenApiSnapshotHash,

    [string]$OutputDirectory = 'target/release/assets',

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
        throw "$Name 不能包含 latest：$Value"
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

function Get-StringSha256 {
    param([Parameter(Mandatory = $true)][string]$Value)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
}

function Get-ContentType {
    param([Parameter(Mandatory = $true)][string]$FileName)

    $lower = $FileName.ToLowerInvariant()
    if ($lower.EndsWith('.tar.gz') -or $lower.EndsWith('.tgz')) {
        return 'application/gzip'
    }
    if ($lower.EndsWith('.zip')) {
        return 'application/zip'
    }
    if ($lower.EndsWith('.json')) {
        return 'application/json'
    }
    if ($lower -eq 'sha256sums') {
        return 'text/plain'
    }
    return 'application/octet-stream'
}

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Context 缺少字段：$Name"
    }

    return $property.Value
}

function Get-OptionalProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $DefaultValue = $null
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function New-BackendServiceFingerprintItems {
    param([Parameter(Mandatory = $true)]$Artifact)

    if ($Artifact.kind -ne 'backend-services') {
        return @()
    }

    $services = @()
    foreach ($entrypoint in @($Artifact.entrypoints)) {
        $executableName = Split-Path -Leaf $entrypoint
        $module = switch ($executableName) {
            'hdx-auth-service' { 'backend-auth-service' }
            'hdx-gateway' { 'backend-gateway' }
            'hdx-core-service' { 'backend-core-service' }
            default {
                if ($executableName.StartsWith('hdx-')) {
                    "backend-$($executableName.Substring(4))"
                }
                else {
                    $executableName
                }
            }
        }

        $services += [ordered]@{
            id = $executableName
            module = $module
            executablePath = $entrypoint
        }
    }

    return $services
}

function New-BackendNativeFingerprint {
    param(
        [Parameter(Mandatory = $true)]$BackendNativeManifest,
        [Parameter(Mandatory = $true)]$Artifact,
        [Parameter(Mandatory = $true)][string]$BackendRepository,
        [Parameter(Mandatory = $true)][string]$BackendCommit,
        [Parameter(Mandatory = $true)][string]$OpenApiSnapshotHash
    )

    $artifactFingerprint = [ordered]@{
        kind = $Artifact.kind
        platform = $Artifact.platform
        packaging = $Artifact.packaging
    }
    if ($null -ne $Artifact.PSObject.Properties['entrypoints']) {
        $artifactFingerprint['entrypoints'] = @($Artifact.entrypoints)
    }

    $fingerprint = [ordered]@{
        algorithm = 'hdx-backend-native-fingerprint-v1'
        backend = [ordered]@{
            repository = $BackendRepository
            commit = $BackendCommit
        }
        artifact = $artifactFingerprint
        openapiSnapshotHash = $OpenApiSnapshotHash
        packaging = [ordered]@{
            manifestSchemaVersion = $BackendNativeManifest.schemaVersion
            packagingScriptVersion = $BackendNativeManifest.forbiddenFilesScan.scannerVersion
        }
        runtime = [ordered]@{
            javaVersion = '25'
            graalvmVersion = 'GraalVM Native Image 25'
        }
        nativeInputs = [ordered]@{
            mavenProfile = 'native'
            nativeImageArgs = @('-Dnative.skip=false')
            springAot = [ordered]@{
                enabled = $true
            }
            runtimeHints = @('Spring AOT generated runtime hints')
            reachabilityMetadata = @('GraalVM Reachability Metadata Repository')
            nativeMetadata = @('Hibernate enhance')
        }
    }

    $services = @(New-BackendServiceFingerprintItems -Artifact $Artifact)
    if ($services.Count -gt 0) {
        $fingerprint['services'] = $services
    }

    $fingerprintJson = $fingerprint | ConvertTo-Json -Depth 100 -Compress
    $fingerprintWithHash = [ordered]@{
        algorithm = $fingerprint.algorithm
        sha256 = Get-StringSha256 -Value $fingerprintJson
        backend = $fingerprint.backend
        artifact = $fingerprint.artifact
    }
    if ($fingerprint.Contains('services')) {
        $fingerprintWithHash['services'] = $fingerprint.services
    }
    $fingerprintWithHash['openapiSnapshotHash'] = $fingerprint.openapiSnapshotHash
    $fingerprintWithHash['packaging'] = $fingerprint.packaging
    $fingerprintWithHash['runtime'] = $fingerprint.runtime
    $fingerprintWithHash['nativeInputs'] = $fingerprint.nativeInputs

    return $fingerprintWithHash
}

Assert-Pattern -Name 'Version' -Value $Version -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Message '必须形如 v1.2.3，可携带 prerelease 或 build metadata。'
Assert-NoLatest -Name 'Version' -Value $Version
Assert-NoLatest -Name 'RootRef' -Value $RootRef
Assert-Pattern -Name 'RootCommit' -Value $RootCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'BackendCommit' -Value $BackendCommit -Pattern '^[0-9a-f]{40}$' -Message '必须是 40 位小写 Git SHA。'
Assert-Pattern -Name 'OpenApiSnapshotHash' -Value $OpenApiSnapshotHash -Pattern '^[0-9a-f]{64}$' -Message '必须是 64 位小写 SHA-256。'
Assert-Pattern -Name 'BackendRepository' -Value $BackendRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'
Assert-Pattern -Name 'RootRepository' -Value $RootRepository -Pattern '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -Message '必须形如 owner/repo。'

$sourcesJsonFull = Get-FullPath -Path $SourcesJsonPath
$sourcesPayload = Read-JsonFile -Path $sourcesJsonFull
$sourcesProperty = $sourcesPayload.PSObject.Properties['sources']
$sources = if ($null -ne $sourcesProperty) { @($sourcesProperty.Value) } else { @($sourcesPayload) }
if ($sources.Count -lt 1) {
    throw 'SourcesJsonPath 至少需要一个 sources 条目。'
}

$outputRootFull = Get-FullPath -Path $OutputDirectory
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $outputRootFull

if ([string]::IsNullOrWhiteSpace($ExtractRoot)) {
    $ExtractRoot = Join-Path $RepoRoot "target/release-assemble-backend-assets/extracted-$Version"
}
$extractRootFull = Get-FullPath -Path $ExtractRoot
Assert-PathWithin -Parent $targetRoot -Child $extractRootFull

if (Test-Path -LiteralPath $outputRootFull) {
    Remove-Item -LiteralPath $outputRootFull -Recurse -Force
}
New-Item -ItemType Directory -Path $outputRootFull | Out-Null

if (Test-Path -LiteralPath $extractRootFull) {
    Remove-Item -LiteralPath $extractRootFull -Recurse -Force
}
New-Item -ItemType Directory -Path $extractRootFull | Out-Null

$releaseBackendArtifactCheck = Join-Path $PSScriptRoot 'release-backend-artifact-check.ps1'
$nativeArtifacts = @()
$releaseAssetInputs = @()
$githubActionsArtifacts = @()
$checkedPatterns = [System.Collections.Generic.List[string]]::new()
$seenKindPlatforms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$seenFileNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$aggregateWorkflow = ''
$aggregateRunId = 0L
$aggregateRunAttempt = 0

for ($index = 0; $index -lt $sources.Count; $index++) {
    $source = $sources[$index]
    $context = "sources[$index]"
    $sourceType = [string](Get-RequiredProperty -Object $source -Name 'type' -Context $context)
    Assert-Equal -Name "$context.type" -Actual $sourceType -Expected 'github-actions-artifact'

    $artifactRoot = [string](Get-RequiredProperty -Object $source -Name 'artifactRoot' -Context $context)
    $artifactRootFull = Get-FullPath -Path $artifactRoot
    if (-not (Test-Path -LiteralPath $artifactRootFull -PathType Container)) {
        throw "$context.artifactRoot 不存在：$artifactRootFull"
    }

    $sourceBackendRepository = [string](Get-RequiredProperty -Object $source -Name 'backendRepository' -Context $context)
    Assert-Equal -Name "$context.backendRepository" -Actual $sourceBackendRepository -Expected $BackendRepository

    $runId = [long](Get-RequiredProperty -Object $source -Name 'runId' -Context $context)
    $runAttempt = [int](Get-OptionalProperty -Object $source -Name 'runAttempt' -DefaultValue 1)
    $artifactName = [string](Get-RequiredProperty -Object $source -Name 'artifactName' -Context $context)
    Assert-NoLatest -Name "$context.artifactName" -Value $artifactName

    $artifactIdValue = Get-OptionalProperty -Object $source -Name 'artifactId' -DefaultValue $null
    [long]$artifactId = 0
    if ($null -ne $artifactIdValue) {
        $artifactId = [long]$artifactIdValue
        if ($artifactId -lt 1) {
            throw "$context.artifactId 必须是大于 0 的整数。"
        }
    }

    $sourceExtractRoot = Join-Path $extractRootFull "source-$index"
    & pwsh -NoLogo -NoProfile -File $releaseBackendArtifactCheck `
        -ArtifactRoot $artifactRootFull `
        -ExpectedVersion $Version `
        -ExpectedRootRepository $RootRepository `
        -ExpectedRootRef $RootRef `
        -ExpectedRootCommit $RootCommit `
        -ExpectedBackendRepository $BackendRepository `
        -ExpectedBackendCommit $BackendCommit `
        -ExpectedRunId ([string]$runId) `
        -ExpectedRunAttempt ([string]$runAttempt) `
        -ExpectedArtifactName $artifactName `
        -ExpectedOpenApiSnapshotHash $OpenApiSnapshotHash `
        -ExtractRoot $sourceExtractRoot
    if ($LASTEXITCODE -ne 0) {
        throw "$context 后端 artifact 内容校验失败，退出码：$LASTEXITCODE"
    }

    $manifestPath = Join-Path $artifactRootFull 'backend-native-manifest.json'
    $manifest = Read-JsonFile -Path $manifestPath

    if ([string]::IsNullOrWhiteSpace($aggregateWorkflow)) {
        $aggregateWorkflow = [string]$manifest.githubActions.workflow
        $aggregateRunId = [long]$manifest.githubActions.runId
        $aggregateRunAttempt = [int]$manifest.githubActions.runAttempt
    }
    else {
        Assert-Equal -Name "$context.githubActions.workflow" -Actual $manifest.githubActions.workflow -Expected $aggregateWorkflow
        Assert-Equal -Name "$context.githubActions.runId" -Actual ([long]$manifest.githubActions.runId) -Expected $aggregateRunId
        Assert-Equal -Name "$context.githubActions.runAttempt" -Actual ([int]$manifest.githubActions.runAttempt) -Expected $aggregateRunAttempt
    }

    foreach ($pattern in @($manifest.forbiddenFilesScan.checkedPatterns)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$pattern)) {
            $checkedPatterns.Add([string]$pattern)
        }
    }

    foreach ($artifact in @($manifest.artifacts)) {
        $kind = [string]$artifact.kind
        $platform = [string]$artifact.platform
        $kindPlatform = "$kind/$platform"
        if (-not $seenKindPlatforms.Add($kindPlatform)) {
            throw "重复的后端 native asset kind/platform：$kindPlatform"
        }

        $sourcePath = Join-Path $artifactRootFull $artifact.fileName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "$context manifest 指向的 archive 不存在：$sourcePath"
        }

        if (-not $seenFileNames.Add([string]$artifact.fileName)) {
            throw "重复的后端 native asset 文件名：$($artifact.fileName)"
        }

        $destinationPath = Join-Path $outputRootFull $artifact.fileName
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath

        $githubActions = [ordered]@{
            workflow = $manifest.githubActions.workflow
            runId = [long]$manifest.githubActions.runId
            runAttempt = [int]$manifest.githubActions.runAttempt
            artifactName = $artifactName
        }
        if ($artifactId -gt 0) {
            $githubActions['artifactId'] = $artifactId
        }

        $githubActionsArtifacts += [ordered]@{
            kind = $kind
            platform = $platform
            githubActions = $githubActions
        }

        $nativeArtifact = [ordered]@{
            kind = $kind
            platform = $platform
            fileName = $artifact.fileName
            packaging = $artifact.packaging
            sha256 = $artifact.sha256
            sizeBytes = [int64]$artifact.sizeBytes
        }
        if ($null -ne $artifact.PSObject.Properties['entrypoints']) {
            $nativeArtifact['entrypoints'] = @($artifact.entrypoints)
        }
        $nativeArtifacts += $nativeArtifact

        $releaseAssetInputs += [ordered]@{
            artifact = $artifact
            githubActions = $githubActions
            manifest = $manifest
            destinationPath = $destinationPath
        }
    }
}

$checkedPatternValues = @($checkedPatterns | Sort-Object -Unique)
if ($checkedPatternValues.Count -lt 1) {
    $checkedPatternValues = @('src/main/java', 'target/classes', '*.jar', '*.war', '*.class')
}

$aggregateGitHubActions = [ordered]@{
    workflow = $aggregateWorkflow
    runId = $aggregateRunId
    runAttempt = $aggregateRunAttempt
    artifactName = "multi-backend-native-assets-$Version"
}

$backendNativeManifest = [ordered]@{
    schemaVersion = '1.0'
    manifestKind = 'backend-native'
    version = $Version
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    root = [ordered]@{
        repository = $RootRepository
        ref = $RootRef
        commit = $RootCommit
    }
    backend = [ordered]@{
        repository = $BackendRepository
        commit = $BackendCommit
        sourceVisibility = 'private'
    }
    githubActions = $aggregateGitHubActions
    githubActionsArtifacts = $githubActionsArtifacts
    openapiSnapshotHash = $OpenApiSnapshotHash
    forbiddenFilesScan = [ordered]@{
        status = 'passed'
        scannerVersion = 'release-assemble-backend-assets.ps1'
        checkedPatterns = $checkedPatternValues
    }
    artifacts = $nativeArtifacts
}

$backendNativeManifestPath = Join-Path $outputRootFull 'backend-native-manifest.json'
$backendNativeManifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $backendNativeManifestPath
$backendNativeManifestSha256 = Get-Sha256 -Path $backendNativeManifestPath

$releaseAssets = @()
foreach ($input in $releaseAssetInputs) {
    $artifact = $input.artifact
    $githubActions = $input.githubActions
    $manifest = $input.manifest
    $releaseAssets += [ordered]@{
        kind = $artifact.kind
        platform = $artifact.platform
        fileName = $artifact.fileName
        contentType = Get-ContentType -FileName $artifact.fileName
        sha256 = $artifact.sha256
        sizeBytes = [int64]$artifact.sizeBytes
        source = [ordered]@{
            type = 'backend'
            commit = $BackendCommit
            manifestSha256 = $backendNativeManifestSha256
            openapiSnapshotHash = $OpenApiSnapshotHash
            githubActions = $githubActions
            backendNativeFingerprint = (New-BackendNativeFingerprint `
                -BackendNativeManifest $manifest `
                -Artifact $artifact `
                -BackendRepository $BackendRepository `
                -BackendCommit $BackendCommit `
                -OpenApiSnapshotHash $OpenApiSnapshotHash)
        }
    }
}

$releaseManifest = [ordered]@{
    schemaVersion = '1.0'
    manifestKind = 'release'
    version = $Version
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    root = [ordered]@{
        repository = $RootRepository
        ref = $RootRef
        commit = $RootCommit
    }
    sources = [ordered]@{
        backend = [ordered]@{
            repository = $BackendRepository
            commit = $BackendCommit
        }
    }
    openapiSnapshotHash = $OpenApiSnapshotHash
    backendNativeManifest = [ordered]@{
        fileName = 'backend-native-manifest.json'
        sha256 = $backendNativeManifestSha256
        backendCommit = $BackendCommit
        source = [ordered]@{
            type = 'github-actions-artifact'
            githubActions = $aggregateGitHubActions
            githubActionsArtifacts = $githubActionsArtifacts
        }
    }
    assets = $releaseAssets
}

$releaseManifestPath = Join-Path $outputRootFull 'release-manifest.json'
$releaseManifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $releaseManifestPath

$trackedFiles = Get-ChildItem -LiteralPath $outputRootFull -File | Sort-Object Name
$sha256SumsPath = Join-Path $outputRootFull 'SHA256SUMS'
$shaLines = foreach ($file in $trackedFiles) {
    if ($file.Name -eq 'SHA256SUMS') {
        continue
    }
    "$(Get-Sha256 -Path $file.FullName)  $($file.Name)"
}
$shaLines | Set-Content -LiteralPath $sha256SumsPath

$releaseManifestCheck = Join-Path $PSScriptRoot 'release-manifest-check.ps1'
$releaseCheckArgs = @(
    '-NoLogo',
    '-NoProfile',
    '-File',
    $releaseManifestCheck,
    '-BackendNativeManifestPath',
    $backendNativeManifestPath,
    '-ReleaseManifestPath',
    $releaseManifestPath,
    '-AssetRoot',
    $outputRootFull,
    '-ScanPath',
    $outputRootFull
)

& pwsh @releaseCheckArgs
if ($LASTEXITCODE -ne 0) {
    throw "Release 多后端资产校验失败，退出码：$LASTEXITCODE"
}

Write-Host 'Release 多后端 native asset 已生成并通过本地校验。'
Write-Host "资产目录：$outputRootFull"
Get-ChildItem -LiteralPath $outputRootFull -File | Sort-Object Name | Select-Object Name, Length | Format-Table | Out-String | Write-Host
