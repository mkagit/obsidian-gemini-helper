param(
  [string]$TaskName = "ObsidianGeminiHelperAutoSync",
  [ValidateSet("minute", "daily")]
  [string]$Schedule = "daily",
  [int]$IntervalMinutes = 30,
  [string]$DailyAt = "09:00",
  [string]$Branch = "master"
)

$ErrorActionPreference = "Stop"

if ($Schedule -eq "minute" -and $IntervalMinutes -lt 1) {
  throw "IntervalMinutes must be >= 1."
}

$syncScript = Join-Path $PSScriptRoot "sync-local.ps1"

if (-not (Test-Path $syncScript)) {
  throw "Missing script: $syncScript"
}

$taskCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$syncScript`""
if ($Branch -ne "master") {
  $taskCommand += " -Branch `"$Branch`""
}

if ($Schedule -eq "daily") {
  schtasks /Create `
    /TN $TaskName `
    /SC DAILY `
    /ST $DailyAt `
    /TR $taskCommand `
    /F `
    /RL LIMITED | Out-Null
} else {
  schtasks /Create `
    /TN $TaskName `
    /SC MINUTE `
    /MO $IntervalMinutes `
    /TR $taskCommand `
    /F `
    /RL LIMITED | Out-Null
}

if ($Schedule -eq "daily") {
  Write-Output "Task '$TaskName' installed. It runs daily at $DailyAt."
} else {
  Write-Output "Task '$TaskName' installed. It runs every $IntervalMinutes minute(s)."
}
Write-Output "Run now: schtasks /Run /TN `"$TaskName`""
