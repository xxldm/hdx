param(
    [string]$ReleaseContractsDir = '',
    [string]$BackendNativeManifestPath = '',
    [string]$ReleaseManifestPath = '',
    [string]$BackendBuildPath = '',
    [string]$BackendServicesManifestPath = '',
    [string[]]$ScanPath = @()
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function U {
    param([Parameter(Mandatory = $true)][string]$Escaped)
    return [System.Text.RegularExpressions.Regex]::Unescape($Escaped)
}

if ([string]::IsNullOrWhiteSpace($ReleaseContractsDir)) {
    $ReleaseContractsDir = Join-Path $RepoRoot 'packages/shared/contracts/release'
}

$RequiredSchemas = [ordered]@{
    'backend-native-manifest.schema.json' = 'backend-native'
    'release-manifest.schema.json' = 'release'
    'backend-build.schema.json' = 'backend-build'
    'backend-services-manifest.schema.json' = 'backend-services'
}

$ForbiddenPathRules = @(
    @{ Name = (U 'Java \u6e90\u7801'); Pattern = '(^|/)(src/main/java|src/test/java)/|\.java$' },
    @{ Name = (U 'Kotlin \u6e90\u7801'); Pattern = '(^|/)(src/main/kotlin|src/test/kotlin)/|\.kt$' },
    @{ Name = (U 'Groovy \u6e90\u7801'); Pattern = '(^|/)(src/main/groovy|src/test/groovy)/|\.groovy$' },
    @{ Name = (U 'Scala \u6e90\u7801'); Pattern = '(^|/)(src/main/scala|src/test/scala)/|\.scala$' },
    @{ Name = (U 'Maven \u6e90\u5de5\u7a0b\u6587\u4ef6'); Pattern = '(^|/)pom\.xml$|(^|/)\.mvn/|(^|/)mvnw(\.cmd)?$' },
    @{ Name = (U 'JAR \u538b\u7f29\u5305'); Pattern = '\.jar$' },
    @{ Name = (U 'WAR \u538b\u7f29\u5305'); Pattern = '\.war$' },
    @{ Name = (U 'Java class \u6587\u4ef6'); Pattern = '\.class$' },
    @{ Name = (U '\u7f16\u8bd1 classes \u76ee\u5f55'); Pattern = '(^|/)target/classes(/|$)|(^|/)build/classes(/|$)' },
    @{ Name = (U '\u6784\u5efa\u4e2d\u95f4\u76ee\u5f55'); Pattern = '(^|/)target/(generated-sources|generated-test-sources|maven-status|surefire-reports|failsafe-reports|test-classes)(/|$)|(^|/)\.gradle(/|$)' }
)

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$(U '\u7f3a\u5c11\u6587\u4ef6\uff1a')$Path"
    }

    try {
        return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        throw "$(U 'JSON \u89e3\u6790\u5931\u8d25\uff1a')$Path"
    }
}

function Get-JsonPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Test-JsonPropertyExists {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }
    return $null -ne $Object.PSObject.Properties[$Name]
}

function Assert-StringValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $value = Get-JsonPropertyValue -Object $Object -Name $Name
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        throw "$Context $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')$Name"
    }
    return [string]$value
}

function Assert-ArrayValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $value = Get-JsonPropertyValue -Object $Object -Name $Name
    if ($null -eq $value) {
        throw "$Context $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')$Name"
    }

    $items = @($value)
    if ($items.Count -eq 0) {
        throw "$Context $(U '\u5b57\u6bb5\u5fc5\u987b\u662f\u6570\u7ec4\uff1a')$Name"
    }
    return $items
}

function Assert-Pattern {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ($Value -notmatch $Pattern) {
        throw "$Context $(U '\u5b57\u6bb5\u683c\u5f0f\u65e0\u6548\uff1a')$Value"
    }
}

function Assert-NotLatest {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ($Value -match 'latest') {
        throw "$Context $(U '\u5b57\u6bb5\u4e0d\u80fd\u4f7f\u7528 latest\uff1a')$Value"
    }
}

function Assert-GitCommit {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-Pattern -Value $Value -Pattern '^[0-9a-f]{40}$' -Context $Context
}

function Assert-Sha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-Pattern -Value $Value -Pattern '^[0-9a-f]{64}$' -Context $Context
}

function Assert-Version {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-NotLatest -Value $Value -Context $Context
    Assert-Pattern -Value $Value -Pattern '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$' -Context $Context
}

function Assert-RootRef {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ($null -eq $Root) {
        throw "$Context $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')root"
    }

    [void](Assert-StringValue -Object $Root -Name 'repository' -Context "$Context.root")
    $ref = Assert-StringValue -Object $Root -Name 'ref' -Context "$Context.root"
    Assert-NotLatest -Value $ref -Context "$Context.root.ref"
    $commit = Assert-StringValue -Object $Root -Name 'commit' -Context "$Context.root"
    Assert-GitCommit -Value $commit -Context "$Context.root.commit"
}

function Assert-BaseManifest {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ExpectedKind,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $schemaVersion = Assert-StringValue -Object $Manifest -Name 'schemaVersion' -Context $Context
    if ($schemaVersion -ne '1.0') {
        throw "$Context $(U 'schemaVersion \u5fc5\u987b\u662f 1.0\uff0c\u5b9e\u9645\uff1a')$schemaVersion"
    }

    $manifestKind = Assert-StringValue -Object $Manifest -Name 'manifestKind' -Context $Context
    if ($manifestKind -ne $ExpectedKind) {
        throw "$Context $(U 'manifestKind \u5fc5\u987b\u662f ')$ExpectedKind$(U '\uff0c\u5b9e\u9645\uff1a')$manifestKind"
    }

    $version = Assert-StringValue -Object $Manifest -Name 'version' -Context $Context
    Assert-Version -Value $version -Context "$Context.version"
    Assert-RootRef -Root (Get-JsonPropertyValue -Object $Manifest -Name 'root') -Context $Context
}

function Assert-OptionalManifestFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Kind
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    Write-Host "$(U '\u5df2\u6821\u9a8c manifest \u5b9e\u4f8b\uff1a')$Path"
    $manifest = Read-JsonFile -Path $Path
    Assert-BaseManifest -Manifest $manifest -ExpectedKind $Kind -Context $Path

    switch ($Kind) {
        'backend-native' {
            $backend = Get-JsonPropertyValue -Object $manifest -Name 'backend'
            if ($null -eq $backend) {
                throw "$Path $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')backend"
            }
            $backendCommit = Assert-StringValue -Object $backend -Name 'commit' -Context "$Path.backend"
            Assert-GitCommit -Value $backendCommit -Context "$Path.backend.commit"
            $openapiHash = Assert-StringValue -Object $manifest -Name 'openapiSnapshotHash' -Context $Path
            Assert-Sha256 -Value $openapiHash -Context "$Path.openapiSnapshotHash"
            foreach ($artifact in Assert-ArrayValue -Object $manifest -Name 'artifacts' -Context $Path) {
                [void](Assert-StringValue -Object $artifact -Name 'kind' -Context "$Path.artifacts")
                $fileName = Assert-StringValue -Object $artifact -Name 'fileName' -Context "$Path.artifacts"
                Assert-NotLatest -Value $fileName -Context "$Path.artifacts.fileName"
                $sha256 = Assert-StringValue -Object $artifact -Name 'sha256' -Context "$Path.artifacts"
                Assert-Sha256 -Value $sha256 -Context "$Path.artifacts.sha256"
            }
        }
        'release' {
            $backendNativeManifest = Get-JsonPropertyValue -Object $manifest -Name 'backendNativeManifest'
            if ($null -eq $backendNativeManifest) {
                throw "$Path $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')backendNativeManifest"
            }
            $backendCommit = Assert-StringValue -Object $backendNativeManifest -Name 'backendCommit' -Context "$Path.backendNativeManifest"
            Assert-GitCommit -Value $backendCommit -Context "$Path.backendNativeManifest.backendCommit"
            $manifestSha256 = Assert-StringValue -Object $backendNativeManifest -Name 'sha256' -Context "$Path.backendNativeManifest"
            Assert-Sha256 -Value $manifestSha256 -Context "$Path.backendNativeManifest.sha256"
            foreach ($asset in Assert-ArrayValue -Object $manifest -Name 'assets' -Context $Path) {
                $fileName = Assert-StringValue -Object $asset -Name 'fileName' -Context "$Path.assets"
                Assert-NotLatest -Value $fileName -Context "$Path.assets.fileName"
                $sha256 = Assert-StringValue -Object $asset -Name 'sha256' -Context "$Path.assets"
                Assert-Sha256 -Value $sha256 -Context "$Path.assets.sha256"
                $source = Get-JsonPropertyValue -Object $asset -Name 'source'
                if ($null -eq $source) {
                    throw "$Path.assets $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')source"
                }
                $sourceCommit = Assert-StringValue -Object $source -Name 'commit' -Context "$Path.assets.source"
                Assert-GitCommit -Value $sourceCommit -Context "$Path.assets.source.commit"
            }
        }
        'backend-build' {
            $desktop = Get-JsonPropertyValue -Object $manifest -Name 'desktop'
            if ($null -eq $desktop) {
                throw "$Path $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')desktop"
            }
            $desktopCommit = Assert-StringValue -Object $desktop -Name 'commit' -Context "$Path.desktop"
            Assert-GitCommit -Value $desktopCommit -Context "$Path.desktop.commit"
            $backend = Get-JsonPropertyValue -Object $manifest -Name 'backend'
            if ($null -eq $backend) {
                throw "$Path $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')backend"
            }
            $backendCommit = Assert-StringValue -Object $backend -Name 'commit' -Context "$Path.backend"
            Assert-GitCommit -Value $backendCommit -Context "$Path.backend.commit"
            foreach ($name in @('archiveSha256', 'manifestSha256')) {
                $hash = Assert-StringValue -Object $backend -Name $name -Context "$Path.backend"
                Assert-Sha256 -Value $hash -Context "$Path.backend.$name"
            }
            $archiveFileName = Assert-StringValue -Object $backend -Name 'archiveFileName' -Context "$Path.backend"
            Assert-NotLatest -Value $archiveFileName -Context "$Path.backend.archiveFileName"
        }
        'backend-services' {
            $backend = Get-JsonPropertyValue -Object $manifest -Name 'backend'
            if ($null -eq $backend) {
                throw "$Path $(U '\u7f3a\u5c11\u5fc5\u586b\u5b57\u6bb5\uff1a')backend"
            }
            $backendCommit = Assert-StringValue -Object $backend -Name 'commit' -Context "$Path.backend"
            Assert-GitCommit -Value $backendCommit -Context "$Path.backend.commit"
            [void](Assert-ArrayValue -Object $manifest -Name 'services' -Context $Path)
            foreach ($file in Assert-ArrayValue -Object $manifest -Name 'files' -Context $Path) {
                $filePath = Assert-StringValue -Object $file -Name 'path' -Context "$Path.files"
                Assert-NotLatest -Value $filePath -Context "$Path.files.path"
                $sha256 = Assert-StringValue -Object $file -Name 'sha256' -Context "$Path.files"
                Assert-Sha256 -Value $sha256 -Context "$Path.files.sha256"
            }
        }
    }
}

function Normalize-EntryPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return $Path.Replace('\', '/').TrimStart('./').ToLowerInvariant()
}

function Test-ForbiddenEntryPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $normalized = Normalize-EntryPath -Path $Path
    foreach ($rule in $ForbiddenPathRules) {
        if ($normalized -match $rule.Pattern) {
            throw "$(U '\u7981\u6b62\u6587\u4ef6\u626b\u63cf\u5931\u8d25\uff1a')$Source$(U ' \u5305\u542b ')$Path$(U '\uff0c\u547d\u4e2d\u89c4\u5219\uff1a')$($rule.Name)"
        }
    }
}

function Get-ZipEntries {
    param([Parameter(Mandatory = $true)][string]$Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        return @($zip.Entries | ForEach-Object { $_.FullName })
    }
    finally {
        $zip.Dispose()
    }
}

function Get-TarEntries {
    param([Parameter(Mandatory = $true)][string]$Path)

    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if ($null -eq $tar) {
        throw "$(U '\u65e0\u6cd5\u626b\u63cf tar/tar.gz\uff0c\u56e0\u4e3a\u672a\u627e\u5230 tar \u547d\u4ee4\u3002\u8def\u5f84\uff1a')$Path"
    }

    $entries = & $tar.Source -tf $Path
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "$(U 'tar \u5217\u8868\u5931\u8d25\uff0c\u9000\u51fa\u7801\uff1a')$exitCode$(U '\uff0c\u8def\u5f84\uff1a')$Path"
    }
    return @($entries)
}

function Get-RelativePathCompat {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $baseFull = [System.IO.Path]::GetFullPath($BasePath)
    $targetFull = [System.IO.Path]::GetFullPath($FullPath)
    $separator = [string][System.IO.Path]::DirectorySeparatorChar

    if (-not $baseFull.EndsWith($separator)) {
        $baseFull = $baseFull + $separator
    }

    if ($targetFull.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $targetFull.Substring($baseFull.Length)
    }

    return (Split-Path -Leaf $targetFull)
}

function Invoke-ForbiddenScan {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$(U '\u626b\u63cf\u8def\u5f84\u4e0d\u5b58\u5728\uff1a')$Path"
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    Write-Host "$(U '\u626b\u63cf\u7981\u6b62\u6587\u4ef6\uff1a')$resolved"

    if (Test-Path -LiteralPath $resolved -PathType Container) {
        foreach ($item in Get-ChildItem -LiteralPath $resolved -Recurse -Force) {
            $relativePath = Get-RelativePathCompat -BasePath $resolved -FullPath $item.FullName
            Test-ForbiddenEntryPath -Path $relativePath -Source $resolved
        }
        return
    }

    $lower = $resolved.ToLowerInvariant()
    if ($lower.EndsWith('.zip')) {
        foreach ($entry in Get-ZipEntries -Path $resolved) {
            Test-ForbiddenEntryPath -Path $entry -Source $resolved
        }
        return
    }

    if ($lower.EndsWith('.tar') -or $lower.EndsWith('.tar.gz') -or $lower.EndsWith('.tgz')) {
        foreach ($entry in Get-TarEntries -Path $resolved) {
            Test-ForbiddenEntryPath -Path $entry -Source $resolved
        }
        return
    }

    Test-ForbiddenEntryPath -Path (Split-Path -Leaf $resolved) -Source $resolved
}

Write-Host (U 'Release manifest \u6821\u9a8c')
Write-Host "$(U 'Release \u5951\u7ea6\u76ee\u5f55\uff1a')$ReleaseContractsDir"

Write-Section (U 'Schema \u6587\u4ef6\u68c0\u67e5')
foreach ($schemaName in $RequiredSchemas.Keys) {
    $schemaPath = Join-Path $ReleaseContractsDir $schemaName
    $schema = Read-JsonFile -Path $schemaPath
    $manifestKind = Get-JsonPropertyValue -Object (Get-JsonPropertyValue -Object $schema -Name 'properties') -Name 'manifestKind'
    $constValue = Get-JsonPropertyValue -Object $manifestKind -Name 'const'
    if ($constValue -ne $RequiredSchemas[$schemaName]) {
        throw "$schemaName$(U ' manifestKind const \u5fc5\u987b\u662f ')$($RequiredSchemas[$schemaName])$(U '\uff0c\u5b9e\u9645\uff1a')$constValue"
    }
    Write-Host "$(U '\u901a\u8fc7\uff1a')$schemaName"
}

Write-Section (U 'Manifest \u5b9e\u4f8b\u68c0\u67e5')
$manifestInputs = @(
    @{ Path = $BackendNativeManifestPath; Kind = 'backend-native' },
    @{ Path = $ReleaseManifestPath; Kind = 'release' },
    @{ Path = $BackendBuildPath; Kind = 'backend-build' },
    @{ Path = $BackendServicesManifestPath; Kind = 'backend-services' }
)

$checkedManifestCount = 0
foreach ($input in $manifestInputs) {
    if (-not [string]::IsNullOrWhiteSpace($input.Path)) {
        Assert-OptionalManifestFile -Path $input.Path -Kind $input.Kind
        $checkedManifestCount += 1
    }
}

if ($checkedManifestCount -eq 0) {
    Write-Host (U '\u672a\u4f20\u5165 manifest \u5b9e\u4f8b\uff0c\u8df3\u8fc7\u5b9e\u4f8b\u5b57\u6bb5\u68c0\u67e5\u3002')
}

Write-Section (U '\u7981\u6b62\u6587\u4ef6\u626b\u63cf')
if ($ScanPath.Count -eq 0) {
    Write-Host (U '\u672a\u4f20\u5165\u626b\u63cf\u8def\u5f84\uff0c\u8df3\u8fc7\u7981\u6b62\u6587\u4ef6\u626b\u63cf\u3002')
}
else {
    foreach ($path in $ScanPath) {
        Invoke-ForbiddenScan -Path $path
    }
}

Write-Section (U 'Release manifest \u6821\u9a8c\u5b8c\u6210')
Write-Host (U '\u5168\u90e8\u68c0\u67e5\u901a\u8fc7\u3002')
