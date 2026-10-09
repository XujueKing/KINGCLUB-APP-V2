param(
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [string]$VideoSource = 'C:/HuaweiTools/harmony-video-player'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
if ($root -eq (Split-Path $PSScriptRoot -Parent)) { throw 'Use an isolated probe.' }
$revision = & git -C $VideoSource rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne 'fadef928861f00e88e5f6b802a2b0145eb54349e') { throw 'Unexpected video adapter revision.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'video_player'
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 2\.14\.0\s*$') { throw 'Review changed video_player API before adapting.' }
$target = Join-Path $root 'native_plugins/video_player'
$adapter = Join-Path $root 'native_plugins/video_player_ohos'
if ((Test-Path $target) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite local changes.' }
Copy-Item -LiteralPath $source -Destination $target -Recurse
Copy-Item -LiteralPath (Join-Path $VideoSource 'packages/video_player/video_player_ohos') -Destination $adapter -Recurse
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: video_player_ohos`n      android:")
$manifest = [regex]::Replace($manifest, '(?m)^dependencies:', "dependencies:`n  video_player_ohos:`n    path: ../video_player_ohos")
[IO.File]::WriteAllText((Join-Path $target 'pubspec.yaml'), $manifest)
# Pigeon is only a code generator; use upstream checked-in Dart/ArkTS channel code.
$adapterManifestPath = Join-Path $adapter 'pubspec.yaml'
$adapterManifest = Get-Content $adapterManifestPath -Raw
$adapterManifest = [regex]::Replace($adapterManifest, '(?m)^  pigeon:\r?\n    path: ../../pigeon\r?\n', '')
[IO.File]::WriteAllText($adapterManifestPath, $adapterManifest)
Add-Content -LiteralPath (Join-Path $root 'pubspec.yaml') -Value "`n  video_player:`n    path: native_plugins/video_player"
Write-Host 'Video adapter staged. Main app UI and playback flow remain unchanged. Run dependency, build and device checks.'
