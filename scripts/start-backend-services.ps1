param(
    [string]$BackendRoot = '',
    [string[]]$EnvPath = @('.env.local'),
    [string]$JavaHome = 'D:\JetBrains\.jdks\graalvm-25.1.3+9.1',
    [string]$MavenPath = 'D:\JetBrains\.m2\apache-maven-3.8.8\bin\mvn.cmd',
    [string]$RunRoot = '',
    [string]$AuthBaseUrl = '',
    [string]$CoreBaseUrl = '',
    [string]$GatewayBaseUrl = '',
    [int]$HealthTimeoutSeconds = 120,
    [int]$PollSeconds = 2,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($BackendRoot)) {
    $BackendRoot = Join-Path $RepoRoot 'services/backend'
}
$BackendRoot = (Resolve-Path $BackendRoot).Path

if ([string]::IsNullOrWhiteSpace($RunRoot)) {
    $RunRoot = Join-Path $RepoRoot '.tmp/backend-services'
}

if ($HealthTimeoutSeconds -le 0) {
    throw 'HealthTimeoutSeconds 必须大于 0。'
}

if ($PollSeconds -le 0) {
    throw 'PollSeconds 必须大于 0。'
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)

    Write-Host ''
    Write-Host "== $Title =="
}

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $RepoRoot $Path
}

function Get-ConfiguredPort {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Default
    )

    $value = [System.Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    $parsed = 0
    if ([int]::TryParse($value, [ref]$parsed) -and $parsed -gt 0) {
        return $parsed
    }

    throw "环境变量 $Name 不是有效端口：$value"
}

function Join-UrlPath {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Path
    )

    return "$($BaseUrl.TrimEnd('/'))/$($Path.TrimStart('/'))"
}

function Invoke-JsonEndpoint {
    param([Parameter(Mandatory = $true)][string]$Uri)

    return Invoke-RestMethod -Uri $Uri -TimeoutSec 5
}

function Test-HealthUp {
    param([Parameter(Mandatory = $true)][string]$HealthUri)

    try {
        $response = Invoke-JsonEndpoint -Uri $HealthUri
        return $response.status -eq 'UP'
    }
    catch {
        return $false
    }
}

function Wait-Endpoint {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][scriptblock]$Validator
    )

    $deadline = (Get-Date).AddSeconds($HealthTimeoutSeconds)
    $lastError = ''

    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-JsonEndpoint -Uri $Uri
            if (& $Validator $response) {
                return $response
            }
            $lastError = '响应内容未达到 ready 条件。'
        }
        catch {
            $lastError = $_.Exception.Message
        }

        Start-Sleep -Seconds $PollSeconds
    }

    throw "等待 $Name 就绪超时：$Uri。最后错误：$lastError"
}

function Wait-ServiceHealth {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$BaseUrl
    )

    $healthUri = Join-UrlPath -BaseUrl $BaseUrl -Path '/actuator/health'
    [void](Wait-Endpoint `
        -Name "$Name health" `
        -Uri $healthUri `
        -Validator { param($Response) $Response.status -eq 'UP' })
    return $healthUri
}

function Get-RuntimePidFromLog {
    param([Parameter(Mandatory = $true)][string]$LogPath)

    if (-not (Test-Path -LiteralPath $LogPath)) {
        return $null
    }

    $match = Select-String -LiteralPath $LogPath -Pattern ' with PID (?<pid>\d+) ' | Select-Object -Last 1
    if ($null -eq $match) {
        return $null
    }

    return [int]$match.Matches[0].Groups['pid'].Value
}

function Start-BackendService {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Module,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$LogDirectory
    )

    $healthUri = Join-UrlPath -BaseUrl $BaseUrl -Path '/actuator/health'
    if (Test-HealthUp -HealthUri $healthUri) {
        Write-Host "$Name 已在运行：$healthUri"
        return [pscustomobject]@{
            name = $Name
            module = $Module
            baseUrl = $BaseUrl
            healthUri = $healthUri
            status = 'already-running'
            commandPid = $null
            runtimePid = $null
            stdout = $null
            stderr = $null
        }
    }

    $stdout = Join-Path $LogDirectory "$Name.out.log"
    $stderr = Join-Path $LogDirectory "$Name.err.log"
    $arguments = @('-pl', $Module, '-am', 'spring-boot:run', '-Dspring-boot.run.profiles=service')

    if ($DryRun) {
        Write-Host "[DryRun] 将启动 $Name：$MavenPath $($arguments -join ' ')"
        return [pscustomobject]@{
            name = $Name
            module = $Module
            baseUrl = $BaseUrl
            healthUri = $healthUri
            status = 'dry-run'
            commandPid = $null
            runtimePid = $null
            stdout = $stdout
            stderr = $stderr
        }
    }

    Write-Host "启动 $Name：$Module"
    Write-Host "日志：$stdout"
    $process = Start-Process `
        -FilePath $MavenPath `
        -ArgumentList $arguments `
        -WorkingDirectory $BackendRoot `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru `
        -WindowStyle Hidden

    [void](Wait-ServiceHealth -Name $Name -BaseUrl $BaseUrl)
    $runtimePid = Get-RuntimePidFromLog -LogPath $stdout

    Write-Host "$Name 已就绪：$healthUri"
    return [pscustomobject]@{
        name = $Name
        module = $Module
        baseUrl = $BaseUrl
        healthUri = $healthUri
        status = 'started'
        commandPid = $process.Id
        runtimePid = $runtimePid
        stdout = $stdout
        stderr = $stderr
    }
}

if (-not (Test-Path -LiteralPath $BackendRoot)) {
    throw "未找到后端目录：$BackendRoot"
}

if (-not (Test-Path -LiteralPath $JavaHome)) {
    throw "未找到 GraalVM JDK 25：$JavaHome"
}

if (-not (Test-Path -LiteralPath $MavenPath)) {
    throw "未找到 Maven：$MavenPath"
}

$resolvedEnvPaths = @()
foreach ($path in $EnvPath) {
    $resolvedEnvPaths += Resolve-RepoPath -Path $path
}

. (Join-Path $RepoRoot 'scripts/load-env.ps1') -Path $resolvedEnvPaths

$env:JAVA_HOME = $JavaHome
$env:PATH = "$JavaHome\bin;$(Split-Path -Parent $MavenPath);$env:PATH"

if ([string]::IsNullOrWhiteSpace($AuthBaseUrl)) {
    $AuthBaseUrl = "http://localhost:$(Get-ConfiguredPort -Name 'HDX_AUTH_PORT' -Default 18082)"
}

if ([string]::IsNullOrWhiteSpace($CoreBaseUrl)) {
    $CoreBaseUrl = "http://localhost:$(Get-ConfiguredPort -Name 'HDX_CORE_PORT' -Default 18081)"
}

if ([string]::IsNullOrWhiteSpace($GatewayBaseUrl)) {
    $GatewayBaseUrl = "http://localhost:$(Get-ConfiguredPort -Name 'HDX_GATEWAY_PORT' -Default 18080)"
}

Write-Section '后端 service profile 一键启动'
Write-Host "后端目录：$BackendRoot"
Write-Host "环境文件：$($resolvedEnvPaths -join ', ')"
Write-Host "Auth: $AuthBaseUrl"
Write-Host "Core: $CoreBaseUrl"
Write-Host "Gateway: $GatewayBaseUrl"
Write-Host "DryRun: $DryRun"

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDirectory = Join-Path $RunRoot "backend-service-$timestamp"

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
}

$results = [System.Collections.Generic.List[object]]::new()

$auth = Start-BackendService `
    -Name 'auth-service' `
    -Module ':backend-auth-service' `
    -BaseUrl $AuthBaseUrl `
    -LogDirectory $logDirectory
$results.Add($auth)

# core-service 和 gateway 自身会等待 issuer discovery，脚本只负责启动顺序和 health 检查。
$core = Start-BackendService `
    -Name 'core-service' `
    -Module ':backend-core-service' `
    -BaseUrl $CoreBaseUrl `
    -LogDirectory $logDirectory
$results.Add($core)

$gateway = Start-BackendService `
    -Name 'gateway' `
    -Module ':backend-gateway' `
    -BaseUrl $GatewayBaseUrl `
    -LogDirectory $logDirectory
$results.Add($gateway)

if (-not $DryRun) {
    $state = [pscustomobject]@{
        startedAt = (Get-Date).ToString('o')
        profile = 'service'
        backendRoot = $BackendRoot
        logDirectory = $logDirectory
        services = $results.ToArray()
    }
    $statePath = Join-Path $RunRoot 'backend-service-latest.json'
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8

    Write-Section '启动完成'
    Write-Host "状态文件：$statePath"
    Write-Host "日志目录：$logDirectory"
}
else {
    Write-Section 'DryRun 完成'
}
