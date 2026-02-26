param(
  [string]$TaskName = "ObsidianGeminiHelperAutoSync",
  [int]$IntervalMinutes = 30,
  [string]$Branch = "master"
)

$ErrorActionPreference = "Stop"

if ($IntervalMinutes -lt 1) {
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

schtasks /Create `
  /TN $TaskName `
  /SC MINUTE `
  /MO $IntervalMinutes `
  /TR $taskCommand `
  /F `
  /RL LIMITED | Out-Null

Write-Output "Task '$TaskName' installed. It runs every $IntervalMinutes minute(s)."
Write-Output "Run now: schtasks /Run /TN `"$TaskName`""
