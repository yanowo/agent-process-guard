param(
  [ValidateSet("codex", "claude", "both")] [string] $Target = "both",
  [ValidateSet("user", "project")] [string] $Scope = "user"
)

$ErrorActionPreference = "Stop"
$SourceDir = Resolve-Path (Join-Path $PSScriptRoot "..")

function Copy-Skill([string] $DestRoot) {
  $Dest = Join-Path $DestRoot "process-guard"
  $excludedNames = @(".git", ".agent-run", ".codex-run", ".agents", ".claude")
  New-Item -ItemType Directory -Force $DestRoot | Out-Null
  if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
  New-Item -ItemType Directory -Force $Dest | Out-Null
  Get-ChildItem -Path $SourceDir -Force | Where-Object { $excludedNames -notcontains $_.Name -and $_.Extension -ne ".zip" } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $Dest -Recurse -Force
  }
  Write-Output "Installed process-guard to $Dest"
}

if ($Target -eq "codex" -or $Target -eq "both") {
  if ($Scope -eq "user") { Copy-Skill (Join-Path $HOME ".agents\skills") }
  else { Copy-Skill ".agents\skills" }
}

if ($Target -eq "claude" -or $Target -eq "both") {
  if ($Scope -eq "user") { Copy-Skill (Join-Path $HOME ".claude\skills") }
  else { Copy-Skill ".claude\skills" }
}
