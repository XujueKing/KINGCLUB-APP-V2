param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated Harmony probe.' }
$destination = Join-Path $root 'native_plugins/kingclub_map_ohos'
if (Test-Path $destination) { throw 'Already staged; do not overwrite.' }
$manifestPath = Join-Path $root 'pubspec.yaml'
$manifest = Get-Content $manifestPath -Raw
if ($manifest -notmatch '(?m)^dependencies:') { throw 'Missing dependencies.' }
Copy-Item (Join-Path $repo 'harmony/plugins/kingclub_map_ohos') $destination -Recurse
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  kingclub_map_ohos:`n    path: native_plugins/kingclub_map_ohos"
[IO.File]::WriteAllText($manifestPath,$manifest)
Write-Host 'Harmony system map channel staged; embedded map remains a separate node.'
