param(
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [string]$ScannerSource = 'C:/HuaweiTools/harmony-mobile-scanner'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
if ($root -eq (Split-Path $PSScriptRoot -Parent)) { throw 'Use an isolated probe.' }
$revision = & git -C $ScannerSource rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne 'f5a4ff52f003e1645db1d4de743a2db0313665a8') { throw 'Unexpected scanner revision.' }
$dirty = & git -C $ScannerSource status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Scanner upstream source must be clean.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'mobile_scanner'
if (!$package) { throw 'Resolve mobile_scanner first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 7\.4\.1\s*$') { throw 'Review changed scanner API before adapting.' }
$target = Join-Path $root 'native_plugins/mobile_scanner'
if (Test-Path $target) { throw 'Already staged; do not overwrite local changes.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
$probeManifest = Get-Content $probeManifestPath -Raw
if ($probeManifest -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe overrides.' }
Copy-Item -LiteralPath $source -Destination $target -Recurse
Copy-Item -LiteralPath (Join-Path $ScannerSource 'ohos') -Destination (Join-Path $target 'ohos') -Recurse
Get-ChildItem -LiteralPath $ScannerSource -Filter 'LICENSE*' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target ('OHOS-' + $_.Name))
}
foreach ($name in @('lib/src/method_channel/mobile_scanner_method_channel.dart', 'lib/src/method_channel/rotated_preview.dart', 'ohos/src/main/ets/MobileScannerPlugin.ets')) {
    $path = Join-Path $target $name
    [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n"))
}
foreach ($name in @('mobile-scanner-dart-ohos.patch', 'mobile-scanner-native-ohos.patch')) {
    $patch = Join-Path (Split-Path $PSScriptRoot -Parent) "harmony/patches/$name"
    & git -C $target apply --check $patch
    if ($LASTEXITCODE -ne 0) { throw "Scanner patch no longer applies: $name" }
    & git -C $target apply $patch
    if ($LASTEXITCODE -ne 0) { throw "Scanner patch failed: $name" }
}
$manifest = $manifest.Replace('      android:', "      ohos:`n        pluginClass: MobileScannerPlugin`n      android:")
[IO.File]::WriteAllText((Join-Path $target 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  mobile_scanner:`n    path: native_plugins/mobile_scanner"
Write-Host 'Scanner staged. Existing Dart controller and app routing retained. Device verification pending.'
