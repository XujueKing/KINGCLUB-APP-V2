param(
  [Parameter(Mandatory = $true)][string]$ProbeRoot,
  [string]$GeolocatorSource = 'C:/HuaweiTools/harmony-geolocator'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
if ($root -eq (Split-Path $PSScriptRoot -Parent)) { throw 'Use an isolated probe.' }
$revision = & git -C $GeolocatorSource rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne '6fa6307b29fa6bc0e1983b146d2c33de48740862') { throw 'Unexpected geolocator revision.' }
$dirty = & git -C $GeolocatorSource status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Upstream source must be clean.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'geolocator'
if (!$package) { throw 'Resolve geolocator first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 14\.0\.3\s*$') { throw 'Review changed API first.' }
$wrapper = Join-Path $root 'native_plugins/geolocator'
$adapter = Join-Path $root 'native_plugins/flutter_geolocator_ohos'
if ((Test-Path $wrapper) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
if ((Get-Content $probeManifestPath -Raw) -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe.' }
Copy-Item -LiteralPath $source -Destination $wrapper -Recurse
Copy-Item -LiteralPath (Join-Path $GeolocatorSource 'geolocator_ohos') -Destination $adapter -Recurse
Get-ChildItem -LiteralPath $adapter -Recurse -File | Where-Object Extension -in '.dart','.ets','.ts' | ForEach-Object {
  [IO.File]::WriteAllText($_.FullName, ([IO.File]::ReadAllText($_.FullName)).Replace("`r`n", "`n"))
}
$patch = Join-Path (Split-Path $PSScriptRoot -Parent) 'harmony/patches/geolocator-ohos.patch'
& git -C $adapter apply --check $patch
if ($LASTEXITCODE -ne 0) { throw 'Patch no longer applies.' }
& git -C $adapter apply $patch
if ($LASTEXITCODE -ne 0) { throw 'Patch failed.' }
[IO.File]::WriteAllText((Join-Path $adapter 'lib/flutter_geolocator_ohos.dart'), "export 'geolocator_ohos.dart';`n")
$adapterManifest = Get-Content (Join-Path $adapter 'pubspec.yaml') -Raw
$adapterManifest = $adapterManifest -replace '(?ms)  geolocator_platform_interface:\s*git:.*?(?=  meta:)', "  geolocator_platform_interface: ^4.3.0`n"
$adapterManifest = $adapterManifest.Replace('        pluginClass: GeolocatorOhosPlugin', "        pluginClass: GeolocatorOhosPlugin`n        dartPluginClass: GeolocatorOhos")
[IO.File]::WriteAllText((Join-Path $adapter 'pubspec.yaml'), $adapterManifest)
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  flutter_geolocator_ohos: ^1.0.1"
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: flutter_geolocator_ohos`n      android:")
[IO.File]::WriteAllText((Join-Path $wrapper 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  geolocator:`n    path: native_plugins/geolocator`n  flutter_geolocator_ohos:`n    path: native_plugins/flutter_geolocator_ohos"
$modulePath = Join-Path $root 'ohos/entry/src/main/module.json5'
$module = Get-Content $modulePath -Raw
if ($module -notmatch 'ohos.permission.APPROXIMATELY_LOCATION') {
  $permissions = @'
      {"name":"ohos.permission.APPROXIMATELY_LOCATION","reason":"$string:location_reason","usedScene":{"abilities":["EntryAbility"],"when":"inuse"}},
      {"name":"ohos.permission.LOCATION","reason":"$string:location_reason","usedScene":{"abilities":["EntryAbility"],"when":"inuse"}},
'@
  $module = $module.Replace('"requestPermissions": [', '"requestPermissions": [' + "`n" + $permissions)
  [IO.File]::WriteAllText($modulePath, $module)
}
$stringsPath = Join-Path $root 'ohos/entry/src/main/resources/base/element/string.json'
$strings = Get-Content $stringsPath -Raw | ConvertFrom-Json
if (!($strings.string | Where-Object name -eq 'location_reason')) {
  $strings.string += @{name='location_reason';value='用于识别当前城市和发送当前位置'}
  [IO.File]::WriteAllText($stringsPath, ($strings | ConvertTo-Json -Depth 10))
}
Write-Host 'Foreground geolocator staged. Reverse geocoding and device verification remain pending.'
