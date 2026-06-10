param(
  [Parameter(Mandatory=$true)] [string] $Name,
  [Parameter(Mandatory=$true)] [string] $Command,
  [int] $Port = 0,
  [string] $HealthUrl = "",
  [string] $ReadyCommand = "",
  [string] $ReadyLogPattern = "",
  [int] $TimeoutSeconds = 60,
  [string] $Cwd = "",
  [int] $GraceSeconds = 5
)

$ErrorActionPreference = "Stop"

if ($Name -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid process name: $Name" }

. "$PSScriptRoot/_common.ps1"

$RunDir = Get-PgRunDir
New-Item -ItemType Directory -Force -Path "$RunDir/logs" | Out-Null
New-Item -ItemType Directory -Force -Path "$RunDir/pids" | Out-Null
New-Item -ItemType Directory -Force -Path "$RunDir/meta" | Out-Null

$stdoutLog = "$RunDir/logs/$Name.out.log"
$stderrLog = "$RunDir/logs/$Name.err.log"
$pidPath = "$RunDir/pids/$Name.pid"
$metaPath = "$RunDir/meta/$Name.env"
$runCwd = if ($Cwd) { (Resolve-Path $Cwd).Path } else { (Get-Location).Path }

function Test-TcpPort([int] $PortToCheck) {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect("127.0.0.1", $PortToCheck, $null, $null)
    $success = $iar.AsyncWaitHandle.WaitOne(1000, $false)
    if ($success -and $client.Connected) {
      $client.EndConnect($iar)
      $client.Close()
      return $true
    }
    $client.Close()
    return $false
  } catch { return $false }
}

function Test-ManagedProcessAlive([System.Diagnostics.Process] $ManagedProcess) {
  try {
    $ManagedProcess.Refresh()
    return -not $ManagedProcess.HasExited
  } catch {
    return $false
  }
}

function Write-LogTailToStderr([string] $Path) {
  if (Test-Path $Path) {
    foreach ($line in (Get-Content $Path -Tail 120 -ErrorAction SilentlyContinue)) {
      [Console]::Error.WriteLine($line)
    }
  }
}

function Fail-ExitedBeforeReadiness {
  [Console]::Error.WriteLine("Process '$Name' exited before readiness. Last stdout/stderr logs follow.")
  Write-LogTailToStderr $stdoutLog
  Write-LogTailToStderr $stderrLog
  Remove-Item $pidPath, $metaPath -Force -ErrorAction SilentlyContinue
  exit 1
}

function Confirm-Ready([System.Diagnostics.Process] $ManagedProcess) {
  Start-Sleep -Milliseconds 250
  return (Test-ManagedProcessAlive $ManagedProcess)
}

if (Test-Path $pidPath) {
  $oldPid = Get-Content $pidPath -ErrorAction SilentlyContinue
  if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
    throw "Managed process '$Name' already running with PID $oldPid"
  }
  Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
  Remove-Item $metaPath -Force -ErrorAction SilentlyContinue
}

if ($Port -gt 0 -and (Test-TcpPort $Port)) {
  throw "Port $Port is already listening before starting '$Name'. Refusing to kill unknown processes."
}

Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
$process = Start-Process powershell.exe `
  -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encodedCommand `
  -WorkingDirectory $runCwd `
  -RedirectStandardOutput $stdoutLog `
  -RedirectStandardError $stderrLog `
  -PassThru `
  -WindowStyle Hidden

Set-Content -Path $pidPath -Value $process.Id
@"
NAME=$Name
PID=$($process.Id)
PORT=$Port
HEALTH_URL=$HealthUrl
STDOUT_LOG=$stdoutLog
STDERR_LOG=$stderrLog
COMMAND=$Command
CWD=$runCwd
STARTED_AT=$((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
"@ | Set-Content -Path $metaPath

$hasReadiness = $false
if ($HealthUrl -or $Port -gt 0 -or $ReadyCommand -or $ReadyLogPattern) { $hasReadiness = $true }

if ($hasReadiness) {
  $ready = $false
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (-not (Test-ManagedProcessAlive $process)) {
      Fail-ExitedBeforeReadiness
    }

    if ($HealthUrl) {
      try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri $HealthUrl -TimeoutSec 2
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400 -and (Confirm-Ready $process)) { $ready = $true; break }
      } catch {}
    }

    if ($Port -gt 0 -and (Test-TcpPort $Port) -and (Confirm-Ready $process)) { $ready = $true; break }

    if ($ReadyCommand) {
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $ReadyCommand | Out-Null
      if ($LASTEXITCODE -eq 0 -and (Confirm-Ready $process)) { $ready = $true; break }
    }

    if ($ReadyLogPattern) {
      $matched = $false
      foreach ($path in @($stdoutLog, $stderrLog)) {
        if ((Test-Path $path) -and (Select-String -Path $path -Pattern $ReadyLogPattern -Quiet -ErrorAction SilentlyContinue)) { $matched = $true }
      }
      if ($matched -and (Confirm-Ready $process)) { $ready = $true; break }
    }

    if (-not (Test-ManagedProcessAlive $process)) {
      Fail-ExitedBeforeReadiness
    }
    Start-Sleep -Seconds 1
  }

  if (-not $ready) {
    [Console]::Error.WriteLine("Process '$Name' did not become ready within $TimeoutSeconds seconds. Last stdout/stderr logs follow.")
    Write-LogTailToStderr $stdoutLog
    Write-LogTailToStderr $stderrLog
    Stop-Tree -RootPid $process.Id -GraceSeconds $GraceSeconds
    Remove-Item $pidPath, $metaPath -Force -ErrorAction SilentlyContinue
    exit 1
  }
} else {
  Start-Sleep -Seconds 2
  if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("Process '$Name' exited immediately. Last stdout/stderr logs follow.")
    Write-LogTailToStderr $stdoutLog
    Write-LogTailToStderr $stderrLog
    Remove-Item $pidPath, $metaPath -Force -ErrorAction SilentlyContinue
    exit 1
  }
  Write-Warning "No readiness check was provided. Process is alive but readiness is unverified."
}

Write-Output "Started $Name"
Write-Output "PID: $($process.Id)"
Write-Output "Stdout log: $stdoutLog"
Write-Output "Stderr log: $stderrLog"
if ($Port -gt 0) { Write-Output "Port: $Port" }
if ($HealthUrl) { Write-Output "Health URL: $HealthUrl" }
