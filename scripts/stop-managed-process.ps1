param(
  [Parameter(Mandatory=$true)] [string] $Name,
  [int] $GraceSeconds = 5
)

$RunDir = if ($env:PROCESS_GUARD_RUN_DIR) { $env:PROCESS_GUARD_RUN_DIR } else { ".agent-run" }
$pidPath = "$RunDir/pids/$Name.pid"
$metaPath = "$RunDir/meta/$Name.env"

function Stop-Tree([int] $RootPid) {
  try {
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$RootPid" -ErrorAction SilentlyContinue
    foreach ($child in $children) { Stop-Tree -RootPid ([int]$child.ProcessId) }
  } catch {}
  try {
    $p = Get-Process -Id $RootPid -ErrorAction SilentlyContinue
    if ($p) {
      Stop-Process -Id $RootPid -ErrorAction SilentlyContinue
      Start-Sleep -Seconds $GraceSeconds
      $p = Get-Process -Id $RootPid -ErrorAction SilentlyContinue
      if ($p) { Stop-Process -Id $RootPid -Force -ErrorAction SilentlyContinue }
    }
  } catch {}
}

if (-not (Test-Path $pidPath)) {
  Write-Output "No PID file found for $Name"
  exit 0
}

$pidValue = Get-Content $pidPath -ErrorAction SilentlyContinue
if ($pidValue -and $pidValue -match '^[0-9]+$') {
  $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
  if ($process) {
    Stop-Tree -RootPid ([int]$pidValue)
    if (Get-Process -Id $pidValue -ErrorAction SilentlyContinue) {
      Write-Warning "PID $pidValue for $Name still appears alive after cleanup"
    } else {
      Write-Output "Stopped $Name PID $pidValue"
    }
  } else {
    Write-Output "PID $pidValue for $Name was not running"
  }
} else {
  Write-Warning "Invalid or empty PID file for $Name"
}

Remove-Item $pidPath, $metaPath -Force -ErrorAction SilentlyContinue
