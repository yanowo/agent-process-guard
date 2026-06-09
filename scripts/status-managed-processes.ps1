$RunDir = if ($env:PROCESS_GUARD_RUN_DIR) { $env:PROCESS_GUARD_RUN_DIR } else { ".agent-run" }
$pidDir = "$RunDir/pids"
$metaDir = "$RunDir/meta"

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
  $pidValue = Get-Content $file.FullName -ErrorAction SilentlyContinue
  $status = "stopped"
  if ($pidValue -and (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) { $status = "running" }
  $stdoutLog = "$RunDir/logs/$name.out.log"
  $stderrLog = "$RunDir/logs/$name.err.log"
  $port = ""
  $health = ""
  $metaPath = Join-Path $metaDir "$name.env"
  if (Test-Path $metaPath) {
    $meta = Get-Content $metaPath -ErrorAction SilentlyContinue
    foreach ($line in $meta) {
      if ($line -match '^PORT=(.*)$') { $port = $Matches[1] }
      if ($line -match '^HEALTH_URL=(.*)$') { $health = $Matches[1] }
      if ($line -match '^STDOUT_LOG=(.*)$') { $stdoutLog = $Matches[1] }
      if ($line -match '^STDERR_LOG=(.*)$') { $stderrLog = $Matches[1] }
    }
  }
  $extra = ""
  if ($port) { $extra += " port=$port" }
  if ($health) { $extra += " health=$health" }
  Write-Output "$name PID=$pidValue $status stdout=$stdoutLog stderr=$stderrLog$extra"
}
