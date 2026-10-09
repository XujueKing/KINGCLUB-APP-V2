param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$mainRoot = Split-Path $PSScriptRoot -Parent
if ($root -eq $mainRoot) { throw 'Only stage into an isolated Harmony probe.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
$package = $config.packages | Where-Object name -eq 'flutter_secure_storage'
if (!$package) { throw 'Resolve the existing application dependencies first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$sourceManifest = Get-Content -LiteralPath (Join-Path $source 'pubspec.yaml') -Raw
if ($sourceManifest -notmatch '(?m)^version: 11\.1\.0\s*$') { throw 'Review the new secure storage package before adapting.' }
$appManifestPath = Join-Path $root 'pubspec.yaml'
$appManifest = Get-Content -LiteralPath $appManifestPath -Raw
if ($appManifest -notmatch '(?m)^dependency_overrides:') { throw 'Prepare the Harmony probe first.' }
$target = Join-Path $root 'native_plugins/flutter_secure_storage'
$pluginTarget = Join-Path $root 'native_plugins/kingclub_secure_storage_ohos'
if ((Test-Path $target) -or (Test-Path $pluginTarget)) { throw 'Storage already staged. Review edits instead of overwriting.' }
Copy-Item -LiteralPath $source -Destination $target -Recurse
Copy-Item -LiteralPath (Join-Path $mainRoot 'harmony/plugins/kingclub_secure_storage_ohos') -Destination $pluginTarget -Recurse
# Preserve all upstream files and licenses, adding only the OHOS implementation.
$sourceManifest = $sourceManifest.Replace('      android:', "      ohos:`n        default_package: kingclub_secure_storage_ohos`n      android:")
$sourceManifest = [regex]::Replace($sourceManifest, '(?m)^dependencies:', "dependencies:`n  kingclub_secure_storage_ohos:`n    path: ../kingclub_secure_storage_ohos")
[IO.File]::WriteAllText((Join-Path $target 'pubspec.yaml'), $sourceManifest)
$dartPath = Join-Path $target 'lib/flutter_secure_storage.dart'
$dart = Get-Content -LiteralPath $dartPath -Raw
$needle = '} else if (defaultTargetPlatform == TargetPlatform.linux) {'
if (!$dart.Contains($needle)) { throw 'Upstream option selection changed.' }
$dart = $dart.Replace($needle, "} else if (defaultTargetPlatform == TargetPlatform.ohos) {`n      return const <String, String>{};`n    $needle")
[IO.File]::WriteAllText($dartPath, $dart)
$appManifest += "`n  flutter_secure_storage:`n    path: native_plugins/flutter_secure_storage`n"
[IO.File]::WriteAllText($appManifestPath, $appManifest)
Write-Host 'System-backed Harmony storage staged. Run pub get and build; device security and persistence tests are still required.'
