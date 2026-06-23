param(
    [string]$WebRoot = '',
    [string]$HostName = '127.0.0.1',
    [int]$Port = 3000,
    [int]$WaitSeconds = 90,
    [switch]$StatusOnly,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw '本项目 PowerShell 脚本要求 PowerShell 7+ / pwsh，不支持 Windows PowerShell 5.1。'
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($WebRoot)) {
    $WebRoot = Join-Path $RepoRoot 'apps/web'
}

if (-not (Test-Path -LiteralPath $WebRoot)) {
    throw "未找到 Web 目录：$WebRoot"
}

$WebRoot = (Resolve-Path $WebRoot).Path

if ($Port -le 0 -or $Port -gt 65535) {
    throw "端口无效：$Port"
}

if ($WaitSeconds -le 0) {
    throw 'WaitSeconds 必须大于 0。'
}

. (Join-Path $RepoRoot 'scripts/lib/quality-gate-common.ps1')

$DevServerUrl = "http://$($HostName):$Port/"

function Test-WebDevServer {
    param([Parameter(Mandatory = $true)][string]$Uri)

    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 5
        return [pscustomobject]@{
            healthy = $true
            statusCode = [int]$response.StatusCode
            error = ''
        }
    }
    catch {
        return [pscustomobject]@{
            healthy = $false
            statusCode = $null
            error = $_.Exception.Message
        }
    }
}

function Get-PortListeners {
    param([Parameter(Mandatory = $true)][int]$TargetPort)

    try {
        return @(Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction Stop)
    }
    catch {
        return @()
    }
}

function Write-PortListeners {
    param([object[]]$Listeners)

    if ($Listeners.Count -eq 0) {
        Write-Host '监听进程：未发现。'
        return
    }

    Write-Host '监听进程：'
    foreach ($listener in $Listeners) {
        $commandLine = ''
        try {
            $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($listener.OwningProcess)"
            $commandLine = [string]$processInfo.CommandLine
        }
        catch {
            $commandLine = '无法读取命令行。'
        }

        Write-Host "  $($listener.LocalAddress):$($listener.LocalPort) pid=$($listener.OwningProcess) $commandLine"
    }
}

Write-Section 'Web dev server'
Write-Host "Web 目录：$WebRoot"
Write-Host "目标地址：$DevServerUrl"
Write-Host "StatusOnly: $StatusOnly"
Write-Host "DryRun: $DryRun"

$probe = Test-WebDevServer -Uri $DevServerUrl
$listeners = @(Get-PortListeners -TargetPort $Port)

if ($probe.healthy) {
    Write-Host "已可访问：HTTP $($probe.statusCode)。复用已有 Web dev server，不重复启动。"
    Write-PortListeners -Listeners $listeners
    exit 0
}

if ($StatusOnly) {
    Write-Host "未发现可访问的 Web dev server：$($probe.error)"
    Write-PortListeners -Listeners $listeners
    exit 0
}

if ($listeners.Count -gt 0) {
    Write-PortListeners -Listeners $listeners
    throw "端口 $Port 已被监听，但 $DevServerUrl 探测失败：$($probe.error)。为避免重复启动到其他端口，脚本不会自动启动。"
}

$pnpm = Get-PnpmCommand
$runRoot = Join-Path $RepoRoot '.tmp/web-dev'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDirectory = Join-Path $runRoot "web-dev-$timestamp"
$stdout = Join-Path $logDirectory 'web-dev.out.log'
$stderr = Join-Path $logDirectory 'web-dev.err.log'
$arguments = @('dev', '--host', $HostName, '--port', [string]$Port)

if ($DryRun) {
    Write-Host "[DryRun] 将启动：$pnpm $($arguments -join ' ')"
    Write-Host "日志目录：$logDirectory"
    exit 0
}

New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

Write-Host "启动 Web dev server：$pnpm $($arguments -join ' ')"
Write-Host "stdout：$stdout"
Write-Host "stderr：$stderr"

$process = Start-Process `
    -FilePath $pnpm `
    -ArgumentList $arguments `
    -WorkingDirectory $WebRoot `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -PassThru `
    -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$lastError = $probe.error

while ((Get-Date) -lt $deadline) {
    $probe = Test-WebDevServer -Uri $DevServerUrl
    if ($probe.healthy) {
        Write-Host "Web dev server 已就绪：$DevServerUrl"
        Write-Host "启动命令进程 pid=$($process.Id)"
        Write-PortListeners -Listeners (Get-PortListeners -TargetPort $Port)
        exit 0
    }

    $lastError = $probe.error
    Start-Sleep -Seconds 1
}

throw "等待 Web dev server 就绪超时：$DevServerUrl。最后错误：$lastError。日志：$stdout / $stderr"
