param(
  [Parameter(Mandatory=$true)] [string] $Name,
  [Parameter(Mandatory=$true)] [string] $Command,
  [Parameter(Mandatory=$true)] [string] $CheckCommand,
  [int] $Port = 0,
  [string] $HealthUrl = "",
  [string] $ReadyCommand = "",
  [string] $ReadyLogPattern = "",
  [int] $TimeoutSeconds = 60,
  [string] $Cwd = "",
  [int] $GraceSeconds = 5
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$start = Join-Path $scriptDir "start-managed-process.ps1"
$stop = Join-Path $scriptDir "stop-managed-process.ps1"

try {
  $args = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $start,
    "-Name", $Name,
    "-Command", $Command,
    "-TimeoutSeconds", $TimeoutSeconds,
    "-GraceSeconds", $GraceSeconds
  )
  if ($Port -gt 0) { $args += @("-Port", $Port) }
  if ($HealthUrl) { $args += @("-HealthUrl", $HealthUrl) }
  if ($ReadyCommand) { $args += @("-ReadyCommand", $ReadyCommand) }
  if ($ReadyLogPattern) { $args += @("-ReadyLogPattern", $ReadyLogPattern) }
  if ($Cwd) { $args += @("-Cwd", $Cwd) }

  & powershell @args
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  & powershell -NoProfile -ExecutionPolicy Bypass -Command $CheckCommand
  $checkStatus = $LASTEXITCODE
} finally {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $stop -Name $Name -GraceSeconds $GraceSeconds
}

exit $checkStatus
