param(
    [string]$ReleaseContractsDir = '',
    [string]$BackendNativeManifestPath = '',
    [string]$ReleaseManifestPath = '',
    [string]$BackendBuildPath = '',
    [string]$BackendServicesManifestPath = '',
    [string]$AssetRoot = '',
    [string[]]$ScanPath = @(),
    [string]$ExamplesDir = '',
    [switch]$SkipExamples
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($ReleaseContractsDir)) {
    $ReleaseContractsDir = Join-Path $RepoRoot 'packages/shared/contracts/release'
}

if ([string]::IsNullOrWhiteSpace($ExamplesDir)) {
    $ExamplesDir = Join-Path $ReleaseContractsDir 'examples'
}

$RequiredSchemas = [ordered]@{
    'backend-native-manifest.schema.json' = 'backend-native'
    'release-manifest.schema.json' = 'release'
    'backend-build.schema.json' = 'backend-build'
    'backend-services-manifest.schema.json' = 'backend-services'
}

$ForbiddenPathRules = @(
    @{ Name = 'Java 源码'; Pattern = '(^|/)(src/main/java|src/test/java)/|\.java$' },
    @{ Name = 'Kotlin 源码'; Pattern = '(^|/)(src/main/kotlin|src/test/kotlin)/|\.kt$' },
    @{ Name = 'Groovy 源码'; Pattern = '(^|/)(src/main/groovy|src/test/groovy)/|\.groovy$' },
    @{ Name = 'Scala 源码'; Pattern = '(^|/)(src/main/scala|src/test/scala)/|\.scala$' },
    @{ Name = 'Maven 源工程文件'; Pattern = '(^|/)pom\.xml$|(^|/)\.mvn/|(^|/)mvnw(\.cmd)?$' },
    @{ Name = 'JAR 压缩包'; Pattern = '\.jar$' },
    @{ Name = 'WAR 压缩包'; Pattern = '\.war$' },
    @{ Name = 'Java class 文件'; Pattern = '\.class$' },
    @{ Name = '编译 classes 目录'; Pattern = '(^|/)target/classes(/|$)|(^|/)build/classes(/|$)' },
    @{ Name = '构建中间目录'; Pattern = '(^|/)target/(generated-sources|generated-test-sources|maven-status|surefire-reports|failsafe-reports|test-classes)(/|$)|(^|/)\.gradle(/|$)' }
)

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "缺少文件：$Path"
    }

    try {
        $jsonText = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
        $convertFromJson = Get-Command ConvertFrom-Json
        if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
            return $jsonText | ConvertFrom-Json -Depth 100 -DateKind String
        }
        return $jsonText | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "JSON 解析失败：$Path"
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
    return ,$property.Value
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

function Test-JsonObject {
    param($Value)
    return $null -ne $Value -and $Value -is [pscustomobject]
}

function Test-JsonArray {
    param($Value)
    return $null -ne $Value -and $Value -is [System.Array]
}

function Test-JsonString {
    param($Value)
    return $Value -is [string] -or $Value -is [datetime] -or $Value -is [datetimeoffset]
}

function Get-JsonStringValue {
    param($Value)

    if ($Value -is [datetime]) {
        return $Value.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [datetimeoffset]) {
        return $Value.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return [string]$Value
}

function Test-JsonInteger {
    param($Value)
    return (
        $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int] -or
        $Value -is [uint32] -or
        $Value -is [long] -or
        $Value -is [uint64]
    )
}

function Test-JsonNumber {
    param($Value)
    return (Test-JsonInteger -Value $Value) -or $Value -is [float] -or $Value -is [double] -or $Value -is [decimal]
}

function Get-JsonTypeName {
    param($Value)

    if ($null -eq $Value) {
        return 'null'
    }
    if (Test-JsonObject -Value $Value) {
        return 'object'
    }
    if (Test-JsonArray -Value $Value) {
        return 'array'
    }
    if (Test-JsonString -Value $Value) {
        return 'string'
    }
    if ($Value -is [bool]) {
        return 'boolean'
    }
    if (Test-JsonInteger -Value $Value) {
        return 'integer'
    }
    if (Test-JsonNumber -Value $Value) {
        return 'number'
    }
    return $Value.GetType().FullName
}

function Assert-JsonType {
    param(
        $Value,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $matched = switch ($Type) {
        'object' { Test-JsonObject -Value $Value }
        'array' { Test-JsonArray -Value $Value }
        'string' { Test-JsonString -Value $Value }
        'integer' { Test-JsonInteger -Value $Value }
        'number' { Test-JsonNumber -Value $Value }
        'boolean' { $Value -is [bool] }
        default { throw "$Path 使用了暂不支持的 JSON Schema type：$Type" }
    }

    if (-not $matched) {
        throw "$Path 类型无效，期望 $Type，实际 $(Get-JsonTypeName -Value $Value)"
    }
}

function Resolve-JsonSchemaRef {
    param(
        [Parameter(Mandatory = $true)][string]$Ref,
        [Parameter(Mandatory = $true)]$RootSchema,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not $Ref.StartsWith('#/')) {
        throw "$Path 使用了暂不支持的 JSON Schema `$ref：$Ref"
    }

    $current = $RootSchema
    foreach ($rawSegment in $Ref.Substring(2).Split('/')) {
        $segment = $rawSegment.Replace('~1', '/').Replace('~0', '~')
        $current = Get-JsonPropertyValue -Object $current -Name $segment
        if ($null -eq $current) {
            throw "$Path 无法解析 JSON Schema `$ref：$Ref"
        }
    }

    return $current
}

function Test-DateTimeFormat {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$') {
        return $false
    }

    $parsed = [System.DateTimeOffset]::MinValue
    return [System.DateTimeOffset]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
}

function Assert-JsonSchema {
    param(
        $Value,
        [Parameter(Mandatory = $true)]$Schema,
        [Parameter(Mandatory = $true)]$RootSchema,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $ref = Get-JsonPropertyValue -Object $Schema -Name '$ref'
    if ($null -ne $ref) {
        $resolvedSchema = Resolve-JsonSchemaRef -Ref ([string]$ref) -RootSchema $RootSchema -Path $Path
        Assert-JsonSchema -Value $Value -Schema $resolvedSchema -RootSchema $RootSchema -Path $Path
        return
    }

    $type = Get-JsonPropertyValue -Object $Schema -Name 'type'
    if ($null -ne $type) {
        Assert-JsonType -Value $Value -Type ([string]$type) -Path $Path
    }

    if (Test-JsonPropertyExists -Object $Schema -Name 'const') {
        $constValue = Get-JsonPropertyValue -Object $Schema -Name 'const'
        if ($Value -ne $constValue) {
            throw "$Path 必须等于 $constValue，实际：$Value"
        }
    }

    $enum = Get-JsonPropertyValue -Object $Schema -Name 'enum'
    if ($null -ne $enum) {
        $matchedEnum = $false
        foreach ($enumValue in @($enum)) {
            if ($Value -eq $enumValue) {
                $matchedEnum = $true
                break
            }
        }
        if (-not $matchedEnum) {
            throw "$Path 不在允许枚举范围内：$Value"
        }
    }

    $pattern = Get-JsonPropertyValue -Object $Schema -Name 'pattern'
    if ($null -ne $pattern -and (Test-JsonString -Value $Value) -and (Get-JsonStringValue -Value $Value) -notmatch ([string]$pattern)) {
        throw "$Path 字符串格式不匹配：$(Get-JsonStringValue -Value $Value)"
    }

    $notSchema = Get-JsonPropertyValue -Object $Schema -Name 'not'
    if ($null -ne $notSchema) {
        $matchedNotSchema = $false
        try {
            Assert-JsonSchema -Value $Value -Schema $notSchema -RootSchema $RootSchema -Path $Path
            $matchedNotSchema = $true
        }
        catch {
            $matchedNotSchema = $false
        }
        if ($matchedNotSchema) {
            throw "$Path 命中禁止的 JSON Schema not 约束"
        }
    }

    $format = Get-JsonPropertyValue -Object $Schema -Name 'format'
    if ($format -eq 'date-time' -and (Test-JsonString -Value $Value) -and -not (Test-DateTimeFormat -Value (Get-JsonStringValue -Value $Value))) {
        throw "$Path 不是有效 date-time：$(Get-JsonStringValue -Value $Value)"
    }

    $minLength = Get-JsonPropertyValue -Object $Schema -Name 'minLength'
    if ($null -ne $minLength -and (Test-JsonString -Value $Value) -and (Get-JsonStringValue -Value $Value).Length -lt [int]$minLength) {
        throw "$Path 字符串长度不能小于 $minLength"
    }

    $minimum = Get-JsonPropertyValue -Object $Schema -Name 'minimum'
    if ($null -ne $minimum -and (Test-JsonNumber -Value $Value) -and $Value -lt $minimum) {
        throw "$Path 数值不能小于 $minimum"
    }

    if (Test-JsonObject -Value $Value) {
        $required = Get-JsonPropertyValue -Object $Schema -Name 'required'
        if ($null -ne $required) {
            foreach ($requiredName in @($required)) {
                if (-not (Test-JsonPropertyExists -Object $Value -Name ([string]$requiredName))) {
                    throw "$Path 缺少必填字段：$requiredName"
                }
            }
        }

        $properties = Get-JsonPropertyValue -Object $Schema -Name 'properties'
        if ($null -ne $properties) {
            foreach ($propertySchema in $properties.PSObject.Properties) {
                if (Test-JsonPropertyExists -Object $Value -Name $propertySchema.Name) {
                    $childValue = Get-JsonPropertyValue -Object $Value -Name $propertySchema.Name
                    Assert-JsonSchema -Value $childValue -Schema $propertySchema.Value -RootSchema $RootSchema -Path "$Path.$($propertySchema.Name)"
                }
            }
        }

        $additionalProperties = Get-JsonPropertyValue -Object $Schema -Name 'additionalProperties'
        if ($additionalProperties -eq $false) {
            $allowedNames = @{}
            if ($null -ne $properties) {
                foreach ($propertySchema in $properties.PSObject.Properties) {
                    $allowedNames[$propertySchema.Name] = $true
                }
            }
            foreach ($property in $Value.PSObject.Properties) {
                if (-not $allowedNames.ContainsKey($property.Name)) {
                    throw "$Path 不允许额外字段：$($property.Name)"
                }
            }
        }
    }

    if (Test-JsonArray -Value $Value) {
        $minItems = Get-JsonPropertyValue -Object $Schema -Name 'minItems'
        if ($null -ne $minItems -and $Value.Count -lt [int]$minItems) {
            throw "$Path 数组长度不能小于 $minItems"
        }

        $itemsSchema = Get-JsonPropertyValue -Object $Schema -Name 'items'
        if ($null -ne $itemsSchema) {
            for ($index = 0; $index -lt $Value.Count; $index += 1) {
                Assert-JsonSchema -Value $Value[$index] -Schema $itemsSchema -RootSchema $RootSchema -Path "$Path[$index]"
            }
        }

        $uniqueItems = Get-JsonPropertyValue -Object $Schema -Name 'uniqueItems'
        if ($uniqueItems -eq $true) {
            $seen = @{}
            foreach ($item in $Value) {
                $key = $item | ConvertTo-Json -Compress -Depth 100
                if ($seen.ContainsKey($key)) {
                    throw "$Path 数组元素必须唯一"
                }
                $seen[$key] = $true
            }
        }
    }
}

function Get-SchemaFileNameForKind {
    param([Parameter(Mandatory = $true)][string]$Kind)

    foreach ($entry in $RequiredSchemas.GetEnumerator()) {
        if ($entry.Value -eq $Kind) {
            return $entry.Key
        }
    }

    throw "未知 manifestKind：$Kind"
}

function Assert-ManifestJsonSchema {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $schemaPath = Join-Path $ReleaseContractsDir (Get-SchemaFileNameForKind -Kind $Kind)
    $schema = Read-JsonFile -Path $schemaPath
    Assert-JsonSchema -Value $Manifest -Schema $schema -RootSchema $schema -Path $Context
}

function Assert-StringValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $value = Get-JsonPropertyValue -Object $Object -Name $Name
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        throw "$Context 缺少必填字段：$Name"
    }
    return [string]$value
}

function Assert-ArrayValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ($null -eq $Object) {
        throw "$Context 缺少必填字段：$Name"
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw "$Context 缺少必填字段：$Name"
    }

    $value = $property.Value
    if (-not (Test-JsonArray -Value $value)) {
        throw "$Context 字段必须是数组：$Name"
    }

    if ($value.Count -eq 0) {
        throw "$Context 字段必须是数组：$Name"
    }

    return $value
}

function Assert-Pattern {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ($Value -notmatch $Pattern) {
        throw "$Context 字段格式无效：$Value"
    }
}

function Assert-NotLatest {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ($Value -match 'latest') {
        throw "$Context 字段不能使用 latest：$Value"
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
        throw "$Context 缺少必填字段：root"
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
        throw "$Context schemaVersion 必须是 1.0，实际：$schemaVersion"
    }

    $manifestKind = Assert-StringValue -Object $Manifest -Name 'manifestKind' -Context $Context
    if ($manifestKind -ne $ExpectedKind) {
        throw "$Context manifestKind 必须是 $ExpectedKind，实际：$manifestKind"
    }

    $version = Assert-StringValue -Object $Manifest -Name 'version' -Context $Context
    Assert-Version -Value $version -Context "$Context.version"
    Assert-RootRef -Root (Get-JsonPropertyValue -Object $Manifest -Name 'root') -Context $Context
}

function Assert-OptionalManifestFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Kind,
        [string]$AssetRoot = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $manifest = Read-JsonFile -Path $Path
    Assert-ManifestJsonSchema -Manifest $manifest -Kind $Kind -Context $Path
    Assert-BaseManifest -Manifest $manifest -ExpectedKind $Kind -Context $Path
    Assert-ManifestFileHashes -Manifest $manifest -Kind $Kind -Context $Path -AssetRoot $AssetRoot
    Write-Host "通过：$Path"

    switch ($Kind) {
        'backend-native' {
            $backend = Get-JsonPropertyValue -Object $manifest -Name 'backend'
            if ($null -eq $backend) {
                throw "$Path 缺少必填字段：backend"
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
                throw "$Path 缺少必填字段：backendNativeManifest"
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
                    throw "$Path.assets 缺少必填字段：source"
                }
                $sourceCommit = Assert-StringValue -Object $source -Name 'commit' -Context "$Path.assets.source"
                Assert-GitCommit -Value $sourceCommit -Context "$Path.assets.source.commit"
            }
        }
        'backend-build' {
            $desktop = Get-JsonPropertyValue -Object $manifest -Name 'desktop'
            if ($null -eq $desktop) {
                throw "$Path 缺少必填字段：desktop"
            }
            $desktopCommit = Assert-StringValue -Object $desktop -Name 'commit' -Context "$Path.desktop"
            Assert-GitCommit -Value $desktopCommit -Context "$Path.desktop.commit"
            $backend = Get-JsonPropertyValue -Object $manifest -Name 'backend'
            if ($null -eq $backend) {
                throw "$Path 缺少必填字段：backend"
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
                throw "$Path 缺少必填字段：backend"
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

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-TrackedFileHash {
    param(
        [Parameter(Mandatory = $true)][string]$AssetRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [int64]$ExpectedSizeBytes = -1,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $assetPath = Join-Path $AssetRoot $RelativePath
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw "$Context 指向的文件不存在：$assetPath"
    }

    $actualSha256 = Get-FileSha256 -Path $assetPath
    if ($actualSha256 -ne $ExpectedSha256) {
        throw "$Context sha256 不匹配：期望 $ExpectedSha256，实际 $actualSha256"
    }

    if ($ExpectedSizeBytes -ge 0) {
        $actualSizeBytes = (Get-Item -LiteralPath $assetPath).Length
        if ($actualSizeBytes -ne $ExpectedSizeBytes) {
            throw "$Context sizeBytes 不匹配：期望 $ExpectedSizeBytes，实际 $actualSizeBytes"
        }
    }
}

function Assert-ManifestFileHashes {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Context,
        [string]$AssetRoot = ''
    )

    if ([string]::IsNullOrWhiteSpace($AssetRoot)) {
        return
    }

    if (-not (Test-Path -LiteralPath $AssetRoot -PathType Container)) {
        throw "AssetRoot 不存在：$AssetRoot"
    }

    $resolvedAssetRoot = (Resolve-Path -LiteralPath $AssetRoot).Path

    switch ($Kind) {
        'backend-native' {
            foreach ($artifact in Assert-ArrayValue -Object $Manifest -Name 'artifacts' -Context $Context) {
                Assert-TrackedFileHash `
                    -AssetRoot $resolvedAssetRoot `
                    -RelativePath (Get-JsonPropertyValue -Object $artifact -Name 'fileName') `
                    -ExpectedSha256 (Get-JsonPropertyValue -Object $artifact -Name 'sha256') `
                    -ExpectedSizeBytes ([int64](Get-JsonPropertyValue -Object $artifact -Name 'sizeBytes')) `
                    -Context "$Context.artifacts"
            }
        }
        'release' {
            foreach ($asset in Assert-ArrayValue -Object $Manifest -Name 'assets' -Context $Context) {
                Assert-TrackedFileHash `
                    -AssetRoot $resolvedAssetRoot `
                    -RelativePath (Get-JsonPropertyValue -Object $asset -Name 'fileName') `
                    -ExpectedSha256 (Get-JsonPropertyValue -Object $asset -Name 'sha256') `
                    -ExpectedSizeBytes ([int64](Get-JsonPropertyValue -Object $asset -Name 'sizeBytes')) `
                    -Context "$Context.assets"
            }
        }
        'backend-build' {
            $backend = Get-JsonPropertyValue -Object $Manifest -Name 'backend'
            Assert-TrackedFileHash `
                -AssetRoot $resolvedAssetRoot `
                -RelativePath (Get-JsonPropertyValue -Object $backend -Name 'archiveFileName') `
                -ExpectedSha256 (Get-JsonPropertyValue -Object $backend -Name 'archiveSha256') `
                -Context "$Context.backend.archiveFileName"
        }
        'backend-services' {
            foreach ($file in Assert-ArrayValue -Object $Manifest -Name 'files' -Context $Context) {
                Assert-TrackedFileHash `
                    -AssetRoot $resolvedAssetRoot `
                    -RelativePath (Get-JsonPropertyValue -Object $file -Name 'path') `
                    -ExpectedSha256 (Get-JsonPropertyValue -Object $file -Name 'sha256') `
                    -ExpectedSizeBytes ([int64](Get-JsonPropertyValue -Object $file -Name 'sizeBytes')) `
                    -Context "$Context.files"
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
            throw "禁止文件扫描失败：$Source 包含 $Path，命中规则：$($rule.Name)"
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
        throw "无法扫描 tar/tar.gz，因为未找到 tar 命令。路径：$Path"
    }

    $entries = & $tar.Source -tf $Path
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw "tar 列表失败，退出码：$exitCode，路径：$Path"
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
        throw "扫描路径不存在：$Path"
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    Write-Host "扫描禁止文件：$resolved"

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

function Get-ManifestKindFromFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $manifest = Read-JsonFile -Path $Path
    $kind = Get-JsonPropertyValue -Object $manifest -Name 'manifestKind'
    if ($kind -isnot [string] -or [string]::IsNullOrWhiteSpace($kind)) {
        throw "$Path 缺少 manifestKind，无法选择 schema"
    }

    return [string]$kind
}

function Assert-ExpectedFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock
    }
    catch {
        Write-Host "通过：$Name 按预期失败。"
        return
    }

    throw "$Name 应该失败但实际通过。"
}

function Invoke-ReleaseManifestExamples {
    param([Parameter(Mandatory = $true)][string]$ExamplesDir)

    if (-not (Test-Path -LiteralPath $ExamplesDir -PathType Container)) {
        Write-Host "未找到样例目录，跳过样例检查：$ExamplesDir"
        return
    }

    $validDir = Join-Path $ExamplesDir 'valid'
    if (Test-Path -LiteralPath $validDir -PathType Container) {
        foreach ($example in Get-ChildItem -LiteralPath $validDir -Filter '*.json' -File | Sort-Object Name) {
            $kind = Get-ManifestKindFromFile -Path $example.FullName
            Assert-OptionalManifestFile -Path $example.FullName -Kind $kind
        }
    }

    $validHashDir = Join-Path $ExamplesDir 'valid-hash'
    $assetsDir = Join-Path $ExamplesDir 'assets'
    if (Test-Path -LiteralPath $validHashDir -PathType Container) {
        foreach ($example in Get-ChildItem -LiteralPath $validHashDir -Filter '*.json' -File | Sort-Object Name) {
            $kind = Get-ManifestKindFromFile -Path $example.FullName
            Assert-OptionalManifestFile -Path $example.FullName -Kind $kind -AssetRoot $assetsDir
        }
    }

    $invalidSchemaDir = Join-Path $ExamplesDir 'invalid-schema'
    if (Test-Path -LiteralPath $invalidSchemaDir -PathType Container) {
        foreach ($example in Get-ChildItem -LiteralPath $invalidSchemaDir -Filter '*.json' -File | Sort-Object Name) {
            Assert-ExpectedFailure -Name $example.FullName -ScriptBlock {
                $kind = Get-ManifestKindFromFile -Path $example.FullName
                Assert-OptionalManifestFile -Path $example.FullName -Kind $kind
            }
        }
    }

    $invalidHashDir = Join-Path $ExamplesDir 'invalid-hash'
    if (Test-Path -LiteralPath $invalidHashDir -PathType Container) {
        foreach ($example in Get-ChildItem -LiteralPath $invalidHashDir -Filter '*.json' -File | Sort-Object Name) {
            Assert-ExpectedFailure -Name $example.FullName -ScriptBlock {
                $kind = Get-ManifestKindFromFile -Path $example.FullName
                Assert-OptionalManifestFile -Path $example.FullName -Kind $kind -AssetRoot $assetsDir
            }
        }
    }

    $invalidForbiddenDir = Join-Path $ExamplesDir 'invalid-forbidden'
    if (Test-Path -LiteralPath $invalidForbiddenDir -PathType Container) {
        $pathFixture = Join-Path $invalidForbiddenDir 'paths.json'
        if (Test-Path -LiteralPath $pathFixture -PathType Leaf) {
            $paths = Read-JsonFile -Path $pathFixture
            foreach ($path in @($paths.paths)) {
                Assert-ExpectedFailure -Name "$pathFixture::$path" -ScriptBlock {
                    Test-ForbiddenEntryPath -Path $path -Source $pathFixture
                }
            }
        }
        else {
            Assert-ExpectedFailure -Name $invalidForbiddenDir -ScriptBlock {
                Invoke-ForbiddenScan -Path $invalidForbiddenDir
            }
        }
    }
}

Write-Host 'Release manifest 校验'
Write-Host "Release 契约目录：$ReleaseContractsDir"

Write-Section 'Schema 文件检查'
foreach ($schemaName in $RequiredSchemas.Keys) {
    $schemaPath = Join-Path $ReleaseContractsDir $schemaName
    $schema = Read-JsonFile -Path $schemaPath
    $manifestKind = Get-JsonPropertyValue -Object (Get-JsonPropertyValue -Object $schema -Name 'properties') -Name 'manifestKind'
    $constValue = Get-JsonPropertyValue -Object $manifestKind -Name 'const'
    if ($constValue -ne $RequiredSchemas[$schemaName]) {
        throw "$schemaName manifestKind const 必须是 $($RequiredSchemas[$schemaName])，实际：$constValue"
    }
    Write-Host "通过：$schemaName"
}

Write-Section 'Manifest 实例检查'
$manifestInputs = @(
    @{ Path = $BackendNativeManifestPath; Kind = 'backend-native' },
    @{ Path = $ReleaseManifestPath; Kind = 'release' },
    @{ Path = $BackendBuildPath; Kind = 'backend-build' },
    @{ Path = $BackendServicesManifestPath; Kind = 'backend-services' }
)

$checkedManifestCount = 0
foreach ($input in $manifestInputs) {
    if (-not [string]::IsNullOrWhiteSpace($input.Path)) {
        Assert-OptionalManifestFile -Path $input.Path -Kind $input.Kind -AssetRoot $AssetRoot
        $checkedManifestCount += 1
    }
}

if ($checkedManifestCount -eq 0) {
    Write-Host '未传入 manifest 实例，跳过实例字段检查。'
}

Write-Section '禁止文件扫描'
if ($ScanPath.Count -eq 0) {
    Write-Host '未传入扫描路径，跳过禁止文件扫描。'
}
else {
    foreach ($path in $ScanPath) {
        Invoke-ForbiddenScan -Path $path
    }
}

Write-Section '样例检查'
if ($SkipExamples) {
    Write-Host '已按参数跳过样例检查。'
}
else {
    Invoke-ReleaseManifestExamples -ExamplesDir $ExamplesDir
}

Write-Section 'Release manifest 校验完成'
Write-Host '全部检查通过。'
