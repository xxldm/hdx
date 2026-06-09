param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactRoot,

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
    [string]$BackendRunId,

    [Parameter(Mandatory = $true)]
    [string]$BackendRunAttempt,

    [Parameter(Mandatory = $true)]
    [string]$BackendArtifactName,

    [Parameter(Mandatory = $true)]
    [string]$OpenApiSnapshotHash,

    [string]$BackendArtifactId = '',

    [string]$OutputDirectory = 'target/release-draft-minimal/assets',

    [string]$ExtractRoot = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

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

$artifactRootFull = Get-FullPath -Path $ArtifactRoot
$outputRootFull = Get-FullPath -Path $OutputDirectory
$targetRoot = Join-Path $RepoRoot 'target'
Assert-PathWithin -Parent $targetRoot -Child $outputRootFull

if ([string]::IsNullOrWhiteSpace($ExtractRoot)) {
    $ExtractRoot = Join-Path $RepoRoot "target/release-draft-minimal/extracted-$BackendRunId"
}

$releaseBackendArtifactCheck = Join-Path $PSScriptRoot 'release-backend-artifact-check.ps1'
& pwsh -NoLogo -NoProfile -File $releaseBackendArtifactCheck `
    -ArtifactRoot $artifactRootFull `
    -ExpectedVersion $Version `
    -ExpectedRootRepository $RootRepository `
    -ExpectedRootRef $RootRef `
    -ExpectedRootCommit $RootCommit `
    -ExpectedBackendRepository $BackendRepository `
    -ExpectedBackendCommit $BackendCommit `
    -ExpectedRunId $BackendRunId `
    -ExpectedRunAttempt $BackendRunAttempt `
    -ExpectedArtifactName $BackendArtifactName `
    -ExpectedOpenApiSnapshotHash $OpenApiSnapshotHash `
    -ExtractRoot $ExtractRoot

if ($LASTEXITCODE -ne 0) {
    throw "后端 artifact 内容校验失败，退出码：$LASTEXITCODE"
}

if (Test-Path -LiteralPath $outputRootFull) {
    Remove-Item -LiteralPath $outputRootFull -Recurse -Force
}
New-Item -ItemType Directory -Path $outputRootFull | Out-Null

$backendNativeManifestSource = Join-Path $artifactRootFull 'backend-native-manifest.json'
$backendNativeManifest = Read-JsonFile -Path $backendNativeManifestSource
$backendNativeManifestPath = Join-Path $outputRootFull 'backend-native-manifest.json'
Copy-Item -LiteralPath $backendNativeManifestSource -Destination $backendNativeManifestPath
$backendNativeManifestSha256 = Get-Sha256 -Path $backendNativeManifestPath

$releaseAssets = @()
$scanPaths = @()
foreach ($artifact in @($backendNativeManifest.artifacts)) {
    $sourcePath = Join-Path $artifactRootFull $artifact.fileName
    $destinationPath = Join-Path $outputRootFull $artifact.fileName
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath

    $scanPaths += $destinationPath
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
            backendNativeFingerprint = (New-BackendNativeFingerprint `
                -BackendNativeManifest $backendNativeManifest `
                -Artifact $artifact `
                -BackendRepository $BackendRepository `
                -BackendCommit $BackendCommit `
                -OpenApiSnapshotHash $OpenApiSnapshotHash)
        }
    }
}

$githubActions = [ordered]@{
    workflow = $backendNativeManifest.githubActions.workflow
    runId = [long]$backendNativeManifest.githubActions.runId
    runAttempt = [int]$backendNativeManifest.githubActions.runAttempt
    artifactName = $backendNativeManifest.githubActions.artifactName
}

[long]$backendArtifactIdValue = 0
if (-not [string]::IsNullOrWhiteSpace($BackendArtifactId)) {
    if (-not [long]::TryParse($BackendArtifactId, [ref]$backendArtifactIdValue) -or $backendArtifactIdValue -lt 1) {
        throw 'BackendArtifactId 必须是大于 0 的整数。'
    }
    $githubActions['artifactId'] = $backendArtifactIdValue
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
            githubActions = $githubActions
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
    '-ScanPath'
) + $scanPaths

& pwsh @releaseCheckArgs
if ($LASTEXITCODE -ne 0) {
    throw "Release 资产校验失败，退出码：$LASTEXITCODE"
}

Write-Host 'Draft Release 最小资产已生成并通过本地校验。'
Write-Host "资产目录：$outputRootFull"
Get-ChildItem -LiteralPath $outputRootFull -File | Sort-Object Name | Select-Object Name, Length | Format-Table | Out-String | Write-Host
