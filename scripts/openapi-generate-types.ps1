param(
    [string]$SnapshotsDir = '',
    [string]$OutputDir = '',
    [string]$AuthSpecPath = '',
    [string]$GatewaySpecPath = '',
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($SnapshotsDir)) {
    $SnapshotsDir = Join-Path $RepoRoot 'packages/shared/contracts/openapi/snapshots'
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot 'packages/shared/generated/openapi'
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
        throw "缺少文件：$Path"
    }

    try {
        return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        throw "JSON 格式无效：$Path"
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

function Format-TsStringLiteral {
    param([Parameter(Mandatory = $true)][string]$Value)
    return ($Value | ConvertTo-Json -Compress)
}

function Assert-TsIdentifier {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ($Name -notmatch '^[A-Za-z_$][0-9A-Za-z_$]*$') {
        throw "不支持的 TypeScript 标识符：$Name"
    }
}

function Format-TsPropertyName {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ($Name -match '^[A-Za-z_$][0-9A-Za-z_$]*$') {
        return $Name
    }

    return (Format-TsStringLiteral -Value $Name)
}

function Get-SchemaNameFromRef {
    param([Parameter(Mandatory = $true)][string]$Ref)

    $prefix = '#/components/schemas/'
    if (-not $Ref.StartsWith($prefix)) {
        throw "不支持的 OpenAPI ref：$Ref"
    }

    $schemaName = $Ref.Substring($prefix.Length)
    Assert-TsIdentifier -Name $schemaName
    return $schemaName
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

function Format-ArrayType {
    param([Parameter(Mandatory = $true)][string]$ItemType)

    if ($ItemType.Contains('|')) {
        return "Array<$ItemType>"
    }

    return "$ItemType[]"
}

function Convert-EnumToTsType {
    param(
        [Parameter(Mandatory = $true)]$EnumValues,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $values = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($EnumValues)) {
        if ($null -eq $item) {
            $values.Add('null')
        }
        elseif ($item -is [string]) {
            $values.Add((Format-TsStringLiteral -Value $item))
        }
        elseif ($item -is [bool]) {
            $values.Add($(if ($item) { 'true' } else { 'false' }))
        }
        elseif ($item -is [int] -or $item -is [long] -or $item -is [decimal] -or $item -is [double]) {
            $values.Add(([string]$item))
        }
        else {
            throw "不支持的 OpenAPI enum 值：$Context"
        }
    }

    if ($values.Count -eq 0) {
        return 'never'
    }

    return ($values.ToArray() -join ' | ')
}

function Convert-SchemaToTsType {
    param(
        [Parameter(Mandatory = $true)]$Schema,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $ref = Get-JsonPropertyValue -Object $Schema -Name '$ref'
    if ($null -ne $ref) {
        $baseType = Get-SchemaNameFromRef -Ref ([string]$ref)
        if (Test-SchemaNullable -Schema $Schema) {
            return "$baseType | null"
        }
        return $baseType
    }

    if (Test-JsonPropertyExists -Object $Schema -Name 'enum') {
        $enumType = Convert-EnumToTsType -EnumValues (Get-JsonPropertyValue -Object $Schema -Name 'enum') -Context $Context
        if ((Test-SchemaNullable -Schema $Schema) -and -not $enumType.Contains('null')) {
            return "$enumType | null"
        }
        return $enumType
    }

    $typeNames = @(Get-SchemaTypeNames -Schema $Schema | Where-Object { $_ -ne 'null' })
    if ($typeNames.Count -gt 1) {
        $unionTypes = [System.Collections.Generic.List[string]]::new()
        foreach ($typeName in $typeNames) {
            $copy = [ordered]@{}
            foreach ($property in $Schema.PSObject.Properties) {
                if ($property.Name -ne 'type') {
                    $copy[$property.Name] = $property.Value
                }
            }
            $copy['type'] = $typeName
            $unionTypes.Add((Convert-SchemaToTsType -Schema ([pscustomobject]$copy) -Context $Context))
        }
        $baseType = ($unionTypes.ToArray() -join ' | ')
        if (Test-SchemaNullable -Schema $Schema) {
            return "$baseType | null"
        }
        return $baseType
    }

    $typeName = if ($typeNames.Count -eq 1) { $typeNames[0] } else { '' }
    switch ($typeName) {
        'string' {
            $baseType = 'string'
        }
        'integer' {
            $baseType = 'number'
        }
        'number' {
            $baseType = 'number'
        }
        'boolean' {
            $baseType = 'boolean'
        }
        'array' {
            $items = Get-JsonPropertyValue -Object $Schema -Name 'items'
            if ($null -eq $items) {
                $baseType = 'unknown[]'
            }
            else {
                $baseType = Format-ArrayType -ItemType (Convert-SchemaToTsType -Schema $items -Context "$Context.items")
            }
        }
        'object' {
            $additionalProperties = Get-JsonPropertyValue -Object $Schema -Name 'additionalProperties'
            if ($additionalProperties -is [bool] -and $additionalProperties) {
                $baseType = 'Record<string, unknown>'
            }
            elseif ($null -ne $additionalProperties -and $additionalProperties -isnot [bool]) {
                $baseType = "Record<string, $(Convert-SchemaToTsType -Schema $additionalProperties -Context "$Context.additionalProperties")>"
            }
            else {
                $baseType = 'Record<string, unknown>'
            }
        }
        default {
            if (Test-JsonPropertyExists -Object $Schema -Name 'properties') {
                $baseType = 'Record<string, unknown>'
            }
            else {
                $baseType = 'unknown'
            }
        }
    }

    if (Test-SchemaNullable -Schema $Schema) {
        return "$baseType | null"
    }

    return $baseType
}

function Convert-SchemaToDeclaration {
    param(
        [Parameter(Mandatory = $true)][string]$SchemaName,
        [Parameter(Mandatory = $true)]$Schema
    )

    Assert-TsIdentifier -Name $SchemaName

    $properties = Get-JsonPropertyValue -Object $Schema -Name 'properties'
    if ($null -eq $properties) {
        $type = Convert-SchemaToTsType -Schema $Schema -Context $SchemaName
        return @("export type $SchemaName = $type;")
    }

    $required = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($name in @($Schema.required)) {
        if ($name -is [string]) {
            [void]$required.Add($name)
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("export interface $SchemaName {")
    foreach ($propertyName in @(Get-JsonPropertyNames -Object $properties | Sort-Object)) {
        $propertySchema = Get-JsonPropertyValue -Object $properties -Name $propertyName
        $optional = if ($required.Contains($propertyName)) { '' } else { '?' }
        $propertyType = Convert-SchemaToTsType -Schema $propertySchema -Context "$SchemaName.$propertyName"
        $lines.Add("  $(Format-TsPropertyName -Name $propertyName)${optional}: $propertyType;")
    }

    if ($lines.Count -eq 1) {
        $lines.Add('  [key: string]: unknown;')
    }

    $lines.Add('}')
    return $lines.ToArray()
}

function Join-Lines {
    param([AllowEmptyString()][string[]]$Lines)
    return ($Lines -join "`n") + "`n"
}

function New-ServiceTypesContent {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$SpecPath
    )

    $spec = Read-JsonFile -Path $SpecPath
    if ($null -eq $spec.components -or $null -eq $spec.components.schemas) {
        throw "OpenAPI 文档缺少 components.schemas：$SpecPath"
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('// Generated by scripts/openapi-generate-types.ps1. Do not edit by hand.')
    $lines.Add("// Source: packages/shared/contracts/openapi/snapshots/$ServiceName.openapi.json")
    $lines.Add('')

    foreach ($schemaName in @(Get-JsonPropertyNames -Object $spec.components.schemas | Sort-Object)) {
        $schema = Get-JsonPropertyValue -Object $spec.components.schemas -Name $schemaName
        foreach ($line in Convert-SchemaToDeclaration -SchemaName $schemaName -Schema $schema) {
            $lines.Add($line)
        }
        $lines.Add('')
    }

    return (Join-Lines -Lines $lines.ToArray())
}

function New-IndexTypesContent {
    $lines = @(
        '// Generated by scripts/openapi-generate-types.ps1. Do not edit by hand.',
        '',
        "export * from './auth-service';",
        "export * from './gateway';"
    )
    return (Join-Lines -Lines $lines)
}

function Normalize-NewLines {
    param([Parameter(Mandatory = $true)][string]$Text)
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Read-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Assert-GeneratedFileMatches {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "缺少生成的 TypeScript 类型文件：$Path"
    }

    $actual = Read-TextFile -Path $Path
    if ((Normalize-NewLines -Text $actual) -ne (Normalize-NewLines -Text $Expected)) {
        throw "OpenAPI TypeScript 类型已漂移：$Path。请运行 scripts/openapi-generate-types.ps1 并提交生成物。"
    }
}

$specInputs = [ordered]@{
    'auth-service' = @{
        Path = $AuthSpecPath
        File = 'auth-service.ts'
    }
    'gateway' = @{
        Path = $GatewaySpecPath
        File = 'gateway.ts'
    }
}

Write-Host 'OpenAPI TypeScript 类型生成'
Write-Host "快照目录：$SnapshotsDir"
Write-Host "输出目录：$OutputDir"

$generatedFiles = [ordered]@{}
foreach ($serviceName in $specInputs.Keys) {
    $input = $specInputs[$serviceName]
    $generatedFiles[$input.File] = New-ServiceTypesContent -ServiceName $serviceName -SpecPath $input.Path
}
$generatedFiles['index.ts'] = New-IndexTypesContent

if ($Check) {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        throw "缺少生成类型目录：$OutputDir"
    }

    $expectedNames = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($fileName in $generatedFiles.Keys) {
        [void]$expectedNames.Add($fileName)
        Assert-GeneratedFileMatches -Path (Join-Path $OutputDir $fileName) -Expected $generatedFiles[$fileName]
    }

    foreach ($existingFile in @(Get-ChildItem -LiteralPath $OutputDir -Filter '*.ts' -File)) {
        if (-not $expectedNames.Contains($existingFile.Name)) {
            throw "检测到未预期的生成类型文件：$($existingFile.FullName)"
        }
    }

    Write-Host 'OpenAPI TypeScript 类型生成检查通过。'
    exit 0
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

foreach ($fileName in $generatedFiles.Keys) {
    $path = Join-Path $OutputDir $fileName
    Write-TextFile -Path $path -Content $generatedFiles[$fileName]
    Write-Host "已生成：$path"
}

Write-Host 'OpenAPI TypeScript 类型生成完成。'
