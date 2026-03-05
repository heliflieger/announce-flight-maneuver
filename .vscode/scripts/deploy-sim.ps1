param(
  [Parameter(Mandatory = $true)][string]$Workspace,
  [Parameter(Mandatory = $true)][string]$SimRootRelative
)

$ErrorActionPreference = 'Stop'

$simScriptsRoot = Join-Path (Join-Path $Workspace $SimRootRelative) 'scripts'
$simToolsRoot = Join-Path $simScriptsRoot 'tools'
$simUserRoot = Join-Path $simScriptsRoot 'FlightAnnouncer.user'

$srcApp = Join-Path $Workspace 'scripts\FlightAnnouncer'
$srcUser = Join-Path $Workspace 'scripts\FlightAnnouncer.user'

if (-not (Test-Path $srcApp)) {
  throw "Source app folder not found: $srcApp"
}
if (-not (Test-Path $srcUser)) {
  throw "Source user folder not found: $srcUser"
}

New-Item -ItemType Directory -Force -Path $simScriptsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $simToolsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $simUserRoot | Out-Null

Copy-Item -Path $srcApp -Destination $simScriptsRoot -Recurse -Force
Copy-Item -Path $srcApp -Destination $simToolsRoot -Recurse -Force

$srcDefault = Join-Path $srcUser 'default.user'
$dstDefault = Join-Path $simUserRoot 'default.user'
if ((Test-Path $srcDefault) -and (-not (Test-Path $dstDefault))) {
  Copy-Item -Path $srcDefault -Destination $dstDefault -Force
}

Remove-Item -Path (Join-Path $simScriptsRoot 'FlightAnnouncer\main.luac') -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $simToolsRoot 'FlightAnnouncer\main.luac') -ErrorAction SilentlyContinue

Write-Host "Deploy complete to: $simScriptsRoot"
exit 0
