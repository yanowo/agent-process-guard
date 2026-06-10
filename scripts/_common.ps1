# Shared helpers for process-guard scripts.
# Dot-source from a sibling script with:
#   . "$PSScriptRoot/_common.ps1"

# Run-dir root. Single source of truth for where state lives on disk.
function Get-PgRunDir {
  if ($env:PROCESS_GUARD_RUN_DIR) { $env:PROCESS_GUARD_RUN_DIR } else { ".agent-run" }
}

# Terminate a process and its descendants: recurse into children, then stop the
# root gracefully and force-kill anything still standing after the grace period.
function Stop-Tree([int] $RootPid, [int] $GraceSeconds = 5) {
  try {
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$RootPid" -ErrorAction SilentlyContinue
    foreach ($child in $children) { Stop-Tree -RootPid ([int]$child.ProcessId) -GraceSeconds $GraceSeconds }
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

# Stop a managed process by name: terminate its tree and clear its state files.
function Stop-ManagedProcess([string] $Name, [int] $GraceSeconds = 5) {
  $runDir = Get-PgRunDir
  $pidPath = "$runDir/pids/$Name.pid"
  $metaPath = "$runDir/meta/$Name.env"

  if (-not (Test-Path $pidPath)) {
    Write-Output "No PID file found for $Name"
    return
  }

  $pidValue = Get-Content $pidPath -ErrorAction SilentlyContinue
  if ($pidValue -and $pidValue -match '^[0-9]+$') {
    if (Get-Process -Id $pidValue -ErrorAction SilentlyContinue) {
      Stop-Tree -RootPid ([int]$pidValue) -GraceSeconds $GraceSeconds
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
}
