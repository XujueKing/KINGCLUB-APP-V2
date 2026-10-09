param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated probe.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'geocoding'
if (!$package) { throw 'Resolve geocoding first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 5\.0\.0\s*$') { throw 'Review changed geocoding API first.' }
$wrapper = Join-Path $root 'native_plugins/geocoding'
$adapter = Join-Path $root 'native_plugins/kingclub_geocoding_ohos'
if ((Test-Path $wrapper) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
if ((Get-Content $probeManifestPath -Raw) -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe.' }
Copy-Item -LiteralPath $source -Destination $wrapper -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'harmony/plugins/kingclub_geocoding_ohos') -Destination $adapter -Recurse
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  kingclub_geocoding_ohos: ^0.1.0"
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: kingclub_geocoding_ohos`n      android:")
[IO.File]::WriteAllText((Join-Path $wrapper 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  geocoding:`n    path: native_plugins/geocoding`n  kingclub_geocoding_ohos:`n    path: native_plugins/kingclub_geocoding_ohos"
Write-Host 'System geocoding staged in isolated probe. Device verification pending.'
