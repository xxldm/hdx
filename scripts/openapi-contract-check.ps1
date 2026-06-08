param(
    [string]$ExpectedPathsPath = '',
    [string]$ExpectedSchemasPath = '',
    [string]$AuthSpecPath = '',
    [string]$GatewaySpecPath = '',
    [string]$AuthGeneratedSpecPath = '',
    [string]$GatewayGeneratedSpecPath = '',
    [string]$SnapshotsDir = '',
    [switch]$AllowMissingSpec
)

$ErrorActionPreference = 'Stop'

function U {
    param([Parameter(Mandatory = $true)][string]$Escaped)
    return [System.Text.RegularExpressions.Regex]::Unescape($Escaped)
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($ExpectedPathsPath)) {
    $ExpectedPathsPath = Join-Path $RepoRoot 'packages/shared/contracts/openapi/expected-paths.json'
}

if ([string]::IsNullOrWhiteSpace($ExpectedSchemasPath)) {
    $ExpectedSchemasPath = Join-Path $RepoRoot 'packages/shared/contracts/openapi/expected-schemas.json'
}

if ([string]::IsNullOrWhiteSpace($SnapshotsDir)) {
    $SnapshotsDir = Join-Path $RepoRoot 'packages/shared/contracts/openapi/snapshots'
}

if ([string]::IsNullOrWhiteSpace($AuthSpecPath)) {
    $AuthSpecPath = Join-Path $SnapshotsDir 'auth-service.openapi.json'
}

if ([string]::IsNullOrWhiteSpace($GatewaySpecPath)) {
    $GatewaySpecPath = Join-Path $SnapshotsDir 'gateway.openapi.json'
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
        throw "$(U 'JSON 格式无效：')$Path"
    }
}

function Get-JsonPropertyNames {
    param([Parameter(Mandatory = $true)]$Object)
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-JsonPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

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

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Assert-ExpectedPaths {
    param([Parameter(Mandatory = $true)]$Expected)

    foreach ($serviceName in Get-JsonPropertyNames -Object $Expected) {
        $paths = @(Get-JsonPropertyValue -Object $Expected -Name $serviceName)
        if ($paths.Count -eq 0) {
            throw "$(U '缺少期望路径：')$serviceName"
        }

        $seen = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($path in $paths) {
            if ($path -isnot [string] -or -not $path.StartsWith('/')) {
                throw "$(U '期望路径必须以 / 开头：')$serviceName"
            }
            if (-not $seen.Add($path)) {
                throw "$(U '期望路径重复：')$serviceName $path"
            }
        }
    }
}

function Assert-SpecContainsExpectedPaths {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SpecPath,
        [Parameter(Mandatory = $true)][string[]]$ExpectedPaths
    )

    $spec = Read-JsonFile -Path $SpecPath
    if ($null -eq $spec.paths) {
        throw "$(U 'OpenAPI 文档缺少 paths：')$SpecPath"
    }

    $actualPaths = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($path in Get-JsonPropertyNames -Object $spec.paths) {
        [void]$actualPaths.Add($path)
    }

    foreach ($expectedPath in $ExpectedPaths) {
        if (-not $actualPaths.Contains($expectedPath)) {
            throw "$(U 'OpenAPI 文档缺少路径：')$ServiceName $expectedPath"
        }
    }
}

function Assert-RequiredContainsExpected {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SchemaName,
        [Parameter(Mandatory = $true)]$ActualSchema,
        [Parameter(Mandatory = $true)][string[]]$ExpectedRequired
    )

    $actualRequired = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($name in @($ActualSchema.required)) {
        if ($name -is [string]) {
            [void]$actualRequired.Add($name)
        }
    }

    foreach ($name in $ExpectedRequired) {
        if (-not $actualRequired.Contains($name)) {
            throw "$(U 'OpenAPI schema 缺少必填字段：')$ServiceName $SchemaName.$name"
        }
    }
}

function Assert-StringPropertyEquals {
    param(
        [Parameter(Mandatory = $true)][string]$Context,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $expectedValue = Get-JsonPropertyValue -Object $Expected -Name $Name
    if ($null -eq $expectedValue) {
        return
    }

    $actualValue = Get-JsonPropertyValue -Object $Actual -Name $Name
    if ([string]$actualValue -ne [string]$expectedValue) {
        throw "$(U 'OpenAPI schema 字段不匹配：')$Context $Name=$(U '期望')$expectedValue$(U '，实际')$actualValue"
    }
}

function Get-SchemaTypeNames {
    param([Parameter(Mandatory = $true)]$Schema)

    $typesValue = Get-JsonPropertyValue -Object $Schema -Name 'types'
    if ($null -ne $typesValue) {
        return @($typesValue | Where-Object { $_ -is [string] })
    }

    $typeValue = Get-JsonPropertyValue -Object $Schema -Name 'type'
    if ($null -eq $typeValue) {
        return @()
    }

    return @($typeValue | Where-Object { $_ -is [string] })
}

function Test-SchemaNullable {
    param([Parameter(Mandatory = $true)]$Schema)

    $nullable = Get-JsonPropertyValue -Object $Schema -Name 'nullable'
    if ($nullable -is [bool] -and $nullable) {
        return $true
    }

    foreach ($typeName in Get-SchemaTypeNames -Schema $Schema) {
        if ($typeName -eq 'null') {
            return $true
        }
    }

    return $false
}

function Assert-TypePropertyMatches {
    param(
        [Parameter(Mandatory = $true)][string]$Context,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected
    )

    if (-not (Test-JsonPropertyExists -Object $Expected -Name 'type')) {
        return
    }

    $expectedTypes = @(Get-SchemaTypeNames -Schema $Expected | Where-Object { $_ -ne 'null' })
    $actualTypes = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($typeName in Get-SchemaTypeNames -Schema $Actual) {
        [void]$actualTypes.Add($typeName)
    }

    foreach ($typeName in $expectedTypes) {
        if (-not $actualTypes.Contains($typeName)) {
            throw "$(U 'OpenAPI schema 字段不匹配：')$Context type=$(U '期望')$typeName$(U '，实际')$($actualTypes -join ' ')"
        }
    }

    $expectedNullable = Test-SchemaNullable -Schema $Expected
    if ($expectedNullable -and -not (Test-SchemaNullable -Schema $Actual)) {
        throw "$(U 'OpenAPI schema 缺少可空标记：')$Context"
    }
}

function Assert-NumberPropertyEquals {
    param(
        [Parameter(Mandatory = $true)][string]$Context,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $expectedValue = Get-JsonPropertyValue -Object $Expected -Name $Name
    if ($null -eq $expectedValue) {
        return
    }

    $actualValue = Get-JsonPropertyValue -Object $Actual -Name $Name
    if ([int]$actualValue -ne [int]$expectedValue) {
        throw "$(U 'OpenAPI schema 数值不匹配：')$Context $Name=$(U '期望')$expectedValue$(U '，实际')$actualValue"
    }
}

function Assert-BooleanPropertyEquals {
    param(
        [Parameter(Mandatory = $true)][string]$Context,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-JsonPropertyExists -Object $Expected -Name $Name)) {
        return
    }

    $expectedValue = Get-JsonPropertyValue -Object $Expected -Name $Name
    $actualValue = Get-JsonPropertyValue -Object $Actual -Name $Name
    if ([bool]$actualValue -ne [bool]$expectedValue) {
        throw "$(U 'OpenAPI schema 布尔值不匹配：')$Context $Name=$(U '期望')$expectedValue$(U '，实际')$actualValue"
    }
}

function Assert-EnumContainsExpected {
    param(
        [Parameter(Mandatory = $true)][string]$Context,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected
    )

    if (-not (Test-JsonPropertyExists -Object $Expected -Name 'enum')) {
        return
    }

    $expectedEnum = @(Get-JsonPropertyValue -Object $Expected -Name 'enum')
    $actualEnum = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($item in @($Actual.enum)) {
        if ($item -is [string]) {
            [void]$actualEnum.Add($item)
        }
    }

    foreach ($item in $expectedEnum) {
        if (-not $actualEnum.Contains($item)) {
            throw "$(U 'OpenAPI schema enum 缺少值：')$Context $item"
        }
    }
}

function Assert-PropertyMatches {
    param(
        [Parameter(Mandatory = $true)][string]$Context,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected
    )

    Assert-TypePropertyMatches -Context $Context -Actual $Actual -Expected $Expected
    Assert-StringPropertyEquals -Context $Context -Actual $Actual -Expected $Expected -Name 'format'
    Assert-StringPropertyEquals -Context $Context -Actual $Actual -Expected $Expected -Name '$ref'
    Assert-NumberPropertyEquals -Context $Context -Actual $Actual -Expected $Expected -Name 'maxLength'
    if ((Test-JsonPropertyExists -Object $Expected -Name 'nullable') -and -not (Test-SchemaNullable -Schema $Expected)) {
        Assert-BooleanPropertyEquals -Context $Context -Actual $Actual -Expected $Expected -Name 'nullable'
    }
    Assert-EnumContainsExpected -Context $Context -Actual $Actual -Expected $Expected

    $expectedItems = Get-JsonPropertyValue -Object $Expected -Name 'items'
    if ($null -ne $expectedItems) {
        $actualItems = Get-JsonPropertyValue -Object $Actual -Name 'items'
        if ($null -eq $actualItems) {
            throw "$(U 'OpenAPI schema 字段缺少 items：')$Context"
        }
        Assert-PropertyMatches -Context "$Context.items" -Actual $actualItems -Expected $expectedItems
    }
}

function Assert-SpecContainsExpectedSchemas {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SpecPath,
        [Parameter(Mandatory = $true)]$ExpectedSchemas
    )

    $spec = Read-JsonFile -Path $SpecPath
    if ($null -eq $spec.components -or $null -eq $spec.components.schemas) {
        throw "$(U 'OpenAPI 文档缺少 components.schemas：')$ServiceName $SpecPath"
    }

    foreach ($schemaName in Get-JsonPropertyNames -Object $ExpectedSchemas) {
        $expectedSchema = Get-JsonPropertyValue -Object $ExpectedSchemas -Name $schemaName
        $actualSchema = Get-JsonPropertyValue -Object $spec.components.schemas -Name $schemaName
        if ($null -eq $actualSchema) {
            throw "$(U 'OpenAPI 文档缺少 schema：')$ServiceName $schemaName"
        }

        $expectedRequired = @()
        if (Test-JsonPropertyExists -Object $expectedSchema -Name 'required') {
            $expectedRequired = @(Get-JsonPropertyValue -Object $expectedSchema -Name 'required' | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })
        }
        if ($expectedRequired.Count -gt 0) {
            Assert-RequiredContainsExpected `
                -ServiceName $ServiceName `
                -SchemaName $schemaName `
                -ActualSchema $actualSchema `
                -ExpectedRequired $expectedRequired
        }

        $expectedProperties = Get-JsonPropertyValue -Object $expectedSchema -Name 'properties'
        if ($null -eq $expectedProperties) {
            continue
        }

        foreach ($propertyName in Get-JsonPropertyNames -Object $expectedProperties) {
            $expectedProperty = Get-JsonPropertyValue -Object $expectedProperties -Name $propertyName
            $actualProperties = Get-JsonPropertyValue -Object $actualSchema -Name 'properties'
            $actualProperty = if ($null -eq $actualProperties) { $null } else { Get-JsonPropertyValue -Object $actualProperties -Name $propertyName }
            if ($null -eq $actualProperty) {
                throw "$(U 'OpenAPI schema 缺少字段：')$ServiceName $schemaName.$propertyName"
            }

            Assert-PropertyMatches `
                -Context "$ServiceName $schemaName.$propertyName" `
                -Actual $actualProperty `
                -Expected $expectedProperty
        }
    }
}

function Assert-TextFilesMatch {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SnapshotPath,
        [Parameter(Mandatory = $true)][string]$GeneratedPath
    )

    if (-not (Test-Path -LiteralPath $GeneratedPath)) {
        throw "$(U '缺少生成的 OpenAPI spec：')$ServiceName $GeneratedPath"
    }

    $snapshotContent = Get-Content -LiteralPath $SnapshotPath -Encoding UTF8 -Raw
    $generatedContent = Get-Content -LiteralPath $GeneratedPath -Encoding UTF8 -Raw
    if ($snapshotContent -ne $generatedContent) {
        throw "$(U 'OpenAPI 快照已漂移：')$ServiceName$(U '。如果该变更符合预期，请先运行 scripts/openapi-refresh-snapshots.ps1 并提交快照。')"
    }
}

Write-Host (U 'OpenAPI 契约检查')
Write-Host "$(U '期望路径：')$ExpectedPathsPath"
Write-Host "$(U '期望 schema：')$ExpectedSchemasPath"
Write-Host "$(U '快照目录：')$SnapshotsDir"

$expected = Read-JsonFile -Path $ExpectedPathsPath
Assert-ExpectedPaths -Expected $expected
$expectedSchemasByService = Read-JsonFile -Path $ExpectedSchemasPath

$specInputs = @{
    'auth-service' = @{
        Snapshot = $AuthSpecPath
        Generated = $AuthGeneratedSpecPath
    }
    'gateway' = @{
        Snapshot = $GatewaySpecPath
        Generated = $GatewayGeneratedSpecPath
    }
}

foreach ($serviceName in Get-JsonPropertyNames -Object $expected) {
    if (-not $specInputs.ContainsKey($serviceName)) {
        throw "$(U '缺少 spec 配置：')$serviceName"
    }

    $expectedPaths = @(Get-JsonPropertyValue -Object $expected -Name $serviceName)
    $specPath = $specInputs[$serviceName]['Snapshot']
    if (-not (Test-Path -LiteralPath $specPath)) {
        if (-not $AllowMissingSpec) {
            throw "$(U '缺少 OpenAPI spec 快照：')$serviceName $specPath$(U '。请先运行后端 OpenAPI 测试，再运行 scripts/openapi-refresh-snapshots.ps1。')"
        }
        Write-Host "$(U '跳过 spec 路径校验：')$serviceName"
        continue
    }

    Assert-SpecContainsExpectedPaths `
        -ServiceName $serviceName `
        -SpecPath $specPath `
        -ExpectedPaths $expectedPaths
    Write-Host "$(U '通过 spec 路径校验：')$serviceName"

    $expectedSchemas = Get-JsonPropertyValue -Object $expectedSchemasByService -Name $serviceName
    if ($null -ne $expectedSchemas) {
        Assert-SpecContainsExpectedSchemas `
            -ServiceName $serviceName `
            -SpecPath $specPath `
            -ExpectedSchemas $expectedSchemas
        Write-Host "$(U '通过 schema 字段校验：')$serviceName"
    }

    $generatedSpecPath = $specInputs[$serviceName]['Generated']
    if (-not [string]::IsNullOrWhiteSpace($generatedSpecPath)) {
        Assert-SpecContainsExpectedPaths `
            -ServiceName $serviceName `
            -SpecPath $generatedSpecPath `
            -ExpectedPaths $expectedPaths
        Assert-TextFilesMatch `
            -ServiceName $serviceName `
            -SnapshotPath $specPath `
            -GeneratedPath $generatedSpecPath
        Write-Host "$(U '通过快照漂移校验：')$serviceName"
    }
}

Write-Host (U 'OpenAPI 契约检查通过。')
