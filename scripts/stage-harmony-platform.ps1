param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated Harmony probe.' }
$destination = Join-Path $root 'native_plugins/kingclub_platform_ohos'
if (Test-Path $destination) { throw 'Already staged; do not overwrite.' }
$manifestPath = Join-Path $root 'pubspec.yaml'
$manifest = Get-Content $manifestPath -Raw
if ($manifest -notmatch '(?m)^dependencies:') { throw 'Missing dependencies.' }
$themePath = Join-Path $root 'lib/src/core/design_system/king_theme.dart'
$theme = Get-Content $themePath -Raw
$anchor = '          TargetPlatform.android: KingSlidePageTransitionsBuilder(),'
if (!$theme.Contains($anchor) -or $theme.Contains('TargetPlatform.ohos')) { throw 'Review changed theme.' }
Copy-Item (Join-Path $repo 'harmony/plugins/kingclub_platform_ohos') $destination -Recurse
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  kingclub_platform_ohos:`n    path: native_plugins/kingclub_platform_ohos"
[IO.File]::WriteAllText($manifestPath,$manifest)
[IO.File]::WriteAllText($themePath,$theme.Replace($anchor, "          TargetPlatform.ohos: KingSlidePageTransitionsBuilder(),`n$anchor"))
Write-Host 'Harmony installed metadata and existing slide transition staged.'
