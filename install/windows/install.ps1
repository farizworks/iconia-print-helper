param(
  [string]$ConfigPath = "",
  [string]$BinaryPath = "",
  [string]$InstallDir = "$env:ProgramData\Iconia\PrintHelper",
  [string]$TaskName = "Iconia Print Helper"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HelperRoot = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Join-Path $HelperRoot "config.json"
}
if (-not (Test-Path $ConfigPath)) {
  throw "Config file not found: $ConfigPath. Create it from config.example.json before installing."
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$TargetExe = Join-Path $InstallDir "iconia_print_helper.exe"
$TargetConfig = Join-Path $InstallDir "config.json"

if (-not [string]::IsNullOrWhiteSpace($BinaryPath)) {
  if (-not (Test-Path $BinaryPath)) {
    throw "Compiled helper not found: $BinaryPath"
  }
  Copy-Item $BinaryPath $TargetExe -Force
} else {
  if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    throw "Dart is required to compile locally, or provide -BinaryPath with iconia_print_helper.exe."
  }
  Push-Location $HelperRoot
  try {
    dart pub get
    dart compile exe bin\print_helper.dart -o $TargetExe
  } finally {
    Pop-Location
  }
}

Copy-Item $ConfigPath $TargetConfig -Force
$Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls $TargetConfig /inheritance:r /grant:r "${Identity}:(R,W)" | Out-Null

$Action = New-ScheduledTaskAction -Execute $TargetExe -Argument "`"$TargetConfig`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet `
  -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 1) `
  -ExecutionTimeLimit (New-TimeSpan -Days 0)
$Principal = New-ScheduledTaskPrincipal -UserId $Identity -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $Action `
  -Trigger $Trigger `
  -Settings $Settings `
  -Principal $Principal `
  -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName
Write-Host "Iconia Print Helper installed and started."
Write-Host "Config: $TargetConfig"
Write-Host "Task Scheduler task: $TaskName"
