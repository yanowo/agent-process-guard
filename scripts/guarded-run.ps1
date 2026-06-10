param(
  [Parameter(Mandatory=$true)] [string] $Command,
  [int] $TimeoutSeconds = 120,
  [string] $LogName = ""
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/_common.ps1"
$RunDir = Get-PgRunDir
New-Item -ItemType Directory -Force -Path "$RunDir/logs" | Out-Null

$tempPrefix = Join-Path ([System.IO.Path]::GetTempPath()) ("process-guard-" + [guid]::NewGuid().ToString("N"))
$stdoutLog = "$tempPrefix.out.log"
$stderrLog = "$tempPrefix.err.log"
$removeLogsAfterRun = $true
if ($LogName) {
  if ($LogName -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid log name: $LogName" }
  $stdoutLog = "$RunDir/logs/$LogName.once.out.log"
  $stderrLog = "$RunDir/logs/$LogName.once.err.log"
  $removeLogsAfterRun = $false
}

$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
$process = Start-Process powershell.exe `
  -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encodedCommand `
  -RedirectStandardOutput $stdoutLog `
  -RedirectStandardError $stderrLog `
  -PassThru `
  -WindowStyle Hidden

$timedOut = $false
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
  $timedOut = $true
  Stop-Tree -RootPid $process.Id
}

$stdout = if (Test-Path $stdoutLog) { Get-Content -Raw -Path $stdoutLog -ErrorAction SilentlyContinue } else { "" }
$stderr = if (Test-Path $stderrLog) { Get-Content -Raw -Path $stderrLog -ErrorAction SilentlyContinue } else { "" }

if ($stdout) { [Console]::Out.Write($stdout) }
if ($stderr) { [Console]::Error.Write($stderr) }

if ($removeLogsAfterRun) {
  Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue
}

if ($timedOut) {
  [Console]::Error.WriteLine("Command timed out after $TimeoutSeconds seconds: $Command")
  exit 124
}

exit $process.ExitCode
