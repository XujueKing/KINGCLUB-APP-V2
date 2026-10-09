param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated probe.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'file_picker'
if (!$package) { throw 'Resolve file_picker first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 12\.3\.0\s*$') { throw 'Review changed file_picker API first.' }
$wrapper = Join-Path $root 'native_plugins/file_picker'
$adapter = Join-Path $root 'native_plugins/kingclub_file_picker_ohos'
if ((Test-Path $wrapper) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
if ((Get-Content $probeManifestPath -Raw) -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe.' }
Copy-Item -LiteralPath $source -Destination $wrapper -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'harmony/plugins/kingclub_file_picker_ohos') -Destination $adapter -Recurse
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  kingclub_file_picker_ohos: ^0.1.0"
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: kingclub_file_picker_ohos`n      android:")
[IO.File]::WriteAllText((Join-Path $wrapper 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  file_picker:`n    path: native_plugins/file_picker`n  kingclub_file_picker_ohos:`n    path: native_plugins/kingclub_file_picker_ohos"
Write-Host 'Single document picker staged in isolated probe. Device verification pending.'
