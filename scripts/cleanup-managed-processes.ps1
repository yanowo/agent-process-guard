$RunDir = if ($env:PROCESS_GUARD_RUN_DIR) { $env:PROCESS_GUARD_RUN_DIR } else { ".agent-run" }
$pidDir = "$RunDir/pids"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $pidDir)) {
  Write-Output "No managed PID directory found"
  exit 0
}

$files = Get-ChildItem $pidDir -Filter "*.pid" -ErrorAction SilentlyContinue
if (-not $files) {
  Write-Output "No managed processes found"
  exit 0
}

foreach ($file in $files) {
  $name = $file.BaseName
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir "stop-managed-process.ps1") -Name $name
}
