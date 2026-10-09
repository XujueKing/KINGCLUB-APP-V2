param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated probe.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'get_thumbnail_video'
if (!$package) { throw 'Resolve get_thumbnail_video first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 0\.7\.3\s*$') { throw 'Review changed get_thumbnail_video API first.' }
$wrapper = Join-Path $root 'native_plugins/get_thumbnail_video'
$adapter = Join-Path $root 'native_plugins/kingclub_video_thumbnail_ohos'
if ((Test-Path $wrapper) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
if ((Get-Content $probeManifestPath -Raw) -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe.' }
Copy-Item -LiteralPath $source -Destination $wrapper -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'harmony/plugins/kingclub_video_thumbnail_ohos') -Destination $adapter -Recurse
$manifest = $manifest -replace '(?m)^    implements: get_thumbnail_video\r?\n', ''
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  kingclub_video_thumbnail_ohos: ^0.1.0"
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: kingclub_video_thumbnail_ohos`n      android:")
[IO.File]::WriteAllText((Join-Path $wrapper 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  get_thumbnail_video:`n    path: native_plugins/get_thumbnail_video`n  kingclub_video_thumbnail_ohos:`n    path: native_plugins/kingclub_video_thumbnail_ohos"
Write-Host 'System get_thumbnail_video staged in isolated probe. Device verification pending.'
