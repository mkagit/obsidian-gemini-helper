param(
  [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$Branch = "master",
  [switch]$SkipNpmInstall
)

$ErrorActionPreference = "Stop"

$script:LogPath = $null

function Write-Log {
  param([string]$Message)
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$timestamp] $Message"
  Write-Output $line
  if ($script:LogPath) {
    Add-Content -Path $script:LogPath -Value $line
  }
}

Push-Location $RepoPath
try {
  $gitRoot = (git rev-parse --show-toplevel 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
    throw "Not a git repository: $RepoPath"
  }

  $automationDir = Join-Path $gitRoot ".automation"
  New-Item -ItemType Directory -Force -Path $automationDir | Out-Null
  $script:LogPath = Join-Path $automationDir "local-sync.log"

  $dirty = git status --porcelain
  if (-not [string]::IsNullOrWhiteSpace(($dirty | Out-String))) {
    Write-Log "Skip sync: working tree has local changes."
    exit 0
  }

  $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
  if ($currentBranch -ne $Branch) {
    Write-Log "Skip sync: current branch is '$currentBranch' (expected '$Branch')."
    exit 0
  }

  Write-Log "Fetching origin..."
  git fetch --prune origin
  if ($LASTEXITCODE -ne 0) {
    throw "git fetch failed."
  }

  $localSha = (git rev-parse HEAD).Trim()
  $remoteSha = (git rev-parse "origin/$Branch").Trim()
  if ($localSha -eq $remoteSha) {
    Write-Log "Already up to date with origin/$Branch."
    exit 0
  }

  $changedFiles = git diff --name-only $localSha $remoteSha

  Write-Log "Pulling updates from origin/$Branch..."
  git pull --ff-only origin $Branch
  if ($LASTEXITCODE -ne 0) {
    throw "git pull --ff-only failed."
  }

  if (-not $SkipNpmInstall -and (Test-Path "package.json")) {
    $depsChanged = $false
    foreach ($file in $changedFiles) {
      if ($file -eq "package.json" -or $file -eq "package-lock.json") {
        $depsChanged = $true
        break
      }
    }

    if ($depsChanged) {
      Write-Log "Dependencies changed. Running npm ci..."
      npm ci
      if ($LASTEXITCODE -ne 0) {
        throw "npm ci failed."
      }
    }
  }

  Write-Log "Local sync finished."
}
catch {
  Write-Log "Sync failed: $($_.Exception.Message)"
  exit 1
}
finally {
  Pop-Location
}
