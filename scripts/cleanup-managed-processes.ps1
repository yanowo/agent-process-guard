. "$PSScriptRoot/_common.ps1"

$RunDir = Get-PgRunDir
$pidDir = "$RunDir/pids"

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
  Stop-ManagedProcess -Name $file.BaseName
}
