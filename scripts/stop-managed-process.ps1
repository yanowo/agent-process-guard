param(
  [Parameter(Mandatory=$true)] [string] $Name,
  [int] $GraceSeconds = 5
)

. "$PSScriptRoot/_common.ps1"

Stop-ManagedProcess -Name $Name -GraceSeconds $GraceSeconds
