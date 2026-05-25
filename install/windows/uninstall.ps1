param(
  [string]$TaskName = "Iconia Print Helper",
  [string]$InstallDir = "$env:ProgramData\Iconia\PrintHelper"
)

$ErrorActionPreference = "Stop"

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Write-Host "Iconia Print Helper stopped and removed from auto-start."
Write-Host "Local files remain at: $InstallDir"
Write-Host "Remove that folder manually if local config is no longer needed."
