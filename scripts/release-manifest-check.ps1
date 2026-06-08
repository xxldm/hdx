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
    @{ Name = (U 'Java 源码'); Pattern = '(^|/)(src/main/java|src/test/java)/|\.java$' },
    @{ Name = (U 'Kotlin 源码'); Pattern = '(^|/)(src/main/kotlin|src/test/kotlin)/|\.kt$' },
    @{ Name = (U 'Groovy 源码'); Pattern = '(^|/)(src/main/groovy|src/test/groovy)/|\.groovy$' },
    @{ Name = (U 'Scala 源码'); Pattern = '(^|/)(src/main/scala|src/test/scala)/|\.scala$' },
    @{ Name = (U 'Maven 源工程文件'); Pattern = '(^|/)pom\.xml$|(^|/)\.mvn/|(^|/)mvnw(\.cmd)?$' },
    @{ Name = (U 'JAR 压缩包'); Pattern = '\.jar$' },
    @{ Name = (U 'WAR 压缩包'); Pattern = '\.war$' },
    @{ Name = (U 'Java class 文件'); Pattern = '\.class$' },
    @{ Name = (U '编译 classes 目录'); Pattern = '(^|/)target/classes(/|$)|(^|/)build/classes(/|$)' },
    @{ Name = (U '构建中间目录'); Pattern = '(^|/)target/(generated-sources|generated-test-sources|maven-status|surefire-reports|failsafe-reports|test-classes)(/|$)|(^|/)\.gradle(/|$)' }
)

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$(U '缺少文件：')$Path"
    }

    try {
        return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        throw "$(U 'JSON 解析失败：')$Path"
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
        throw "$Context $(U '缺少必填字段：')$Name"
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
        throw "$Context $(U '缺少必填字段：')$Name"
    }

    $items = @($value)
    if ($items.Count -eq 0) {
        throw "$Context $(U '字段必须是数组：')$Name"
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
        throw "$Context $(U '字段格式无效：')$Value"
    }
}

function Assert-NotLatest {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ($Value -match 'latest') {
        throw "$Context $(U '字段不能使用 latest：')$Value"
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
        throw "$Context $(U '缺少必填字段：')root"
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
        throw "$Context $(U 'schemaVersion 必须是 1.0，实际：')$schemaVersion"
    }

    $manifestKind = Assert-StringValue -Object $Manifest -Name 'manifestKind' -Context $Context
    if ($manifestKind -ne $ExpectedKind) {
        throw "$Context $(U 'manifestKind 必须是 ')$ExpectedKind$(U '，实际：')$manifestKind"
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

    Write-Host "$(U '已校验 manifest 实例：')$Path"
    $manifest = Read-JsonFile -Path $Path
    Assert-BaseManifest -Manifest $manifest -ExpectedKind $Kind -Context $Path

    switch ($Kind) {
        'backend-native' {
            $backend = Get-JsonPropertyValue -Object $manifest -Name 'backend'
            if ($null -eq $backend) {
                throw "$Path $(U '缺少必填字段：')backend"
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
                throw "$Path $(U '缺少必填字段：')backendNativeManifest"
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
                    throw "$Path.assets $(U '缺少必填字段：')source"
                }
                $sourceCommit = Assert-StringValue -Object $source -Name 'commit' -Context "$Path.assets.source"
                Assert-GitCommit -Value $sourceCommit -Context "$Path.assets.source.commit"
            }
        }
        'backend-build' {
            $desktop = Get-JsonPropertyValue -Object $manifest -Name 'desktop'
            if ($null -eq $desktop) {
                throw "$Path $(U '缺少必填字段：')desktop"
            }
            $desktopCommit = Assert-StringValue -Object $desktop -Name 'commit' -Context "$Path.desktop"
            Assert-GitCommit -Value $desktopCommit -Context "$Path.desktop.commit"
            $backend = Get-JsonPropertyValue -Object $manifest -Name 'backend'
            if ($null -eq $backend) {
                throw "$Path $(U '缺少必填字段：')backend"
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
                throw "$Path $(U '缺少必填字段：')backend"
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
            throw "$(U '禁止文件扫描失败：')$Source$(U ' 包含 ')$Path$(U '，命中规则：')$($rule.Name)"
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
        throw "$(U '无法扫描 tar/tar.gz，因为未找到 tar 命令。路径：')$Path"
    }

    $entries = & $tar.Source -tf $Path
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "$(U 'tar 列表失败，退出码：')$exitCode$(U '，路径：')$Path"
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
        throw "$(U '扫描路径不存在：')$Path"
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    Write-Host "$(U '扫描禁止文件：')$resolved"

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

Write-Host (U 'Release manifest 校验')
Write-Host "$(U 'Release 契约目录：')$ReleaseContractsDir"

Write-Section (U 'Schema 文件检查')
foreach ($schemaName in $RequiredSchemas.Keys) {
    $schemaPath = Join-Path $ReleaseContractsDir $schemaName
    $schema = Read-JsonFile -Path $schemaPath
    $manifestKind = Get-JsonPropertyValue -Object (Get-JsonPropertyValue -Object $schema -Name 'properties') -Name 'manifestKind'
    $constValue = Get-JsonPropertyValue -Object $manifestKind -Name 'const'
    if ($constValue -ne $RequiredSchemas[$schemaName]) {
        throw "$schemaName$(U ' manifestKind const 必须是 ')$($RequiredSchemas[$schemaName])$(U '，实际：')$constValue"
    }
    Write-Host "$(U '通过：')$schemaName"
}

Write-Section (U 'Manifest 实例检查')
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
    Write-Host (U '未传入 manifest 实例，跳过实例字段检查。')
}

Write-Section (U '禁止文件扫描')
if ($ScanPath.Count -eq 0) {
    Write-Host (U '未传入扫描路径，跳过禁止文件扫描。')
}
else {
    foreach ($path in $ScanPath) {
        Invoke-ForbiddenScan -Path $path
    }
}

Write-Section (U 'Release manifest 校验完成')
Write-Host (U '全部检查通过。')
