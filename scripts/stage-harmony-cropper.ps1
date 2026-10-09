param(
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [string]$CropperSource = 'C:/HuaweiTools/harmony-image-cropper'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
if ($root -eq (Split-Path $PSScriptRoot -Parent)) { throw 'Use an isolated probe.' }
$revision = & git -C $CropperSource rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne '6844f7d86b7dfc34e164fa913d8624fd114f3a32') { throw 'Unexpected cropper revision.' }
$dirty = & git -C $CropperSource status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Cropper upstream source must be clean.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'image_cropper'
if (!$package) { throw 'Resolve image_cropper first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 12\.2\.1\s*$') { throw 'Review changed cropper API before adapting.' }
$target = Join-Path $root 'native_plugins/image_cropper'
if (Test-Path $target) { throw 'Already staged; do not overwrite local changes.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
$probeManifest = Get-Content $probeManifestPath -Raw
if ($probeManifest -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe overrides.' }
Copy-Item -LiteralPath $source -Destination $target -Recurse
Copy-Item -LiteralPath (Join-Path $CropperSource 'image_cropper/ohos') -Destination (Join-Path $target 'ohos') -Recurse
Get-ChildItem -LiteralPath $CropperSource -Filter 'LICENSE*' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target ('OHOS-' + $_.Name))
}
$nativeFile = Join-Path $target 'ohos/src/main/ets/components/plugin/ImageCropperPlugin.ets'
[IO.File]::WriteAllText($nativeFile, ([IO.File]::ReadAllText($nativeFile)).Replace("`r`n", "`n"))
foreach ($name in @('image-cropper-ohos.patch')) {
    $patch = Join-Path (Split-Path $PSScriptRoot -Parent) "harmony/patches/$name"
    & git -C $target apply --check $patch
    if ($LASTEXITCODE -ne 0) { throw "Cropper patch no longer applies: $name" }
    & git -C $target apply $patch
    if ($LASTEXITCODE -ne 0) { throw "Cropper patch failed: $name" }
}
$manifest = $manifest.Replace('      android:', "      ohos:`n        pluginClass: ImageCropperPlugin`n      android:")
[IO.File]::WriteAllText((Join-Path $target 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  image_cropper:`n    path: native_plugins/image_cropper"
Write-Host 'Cropper staged. Existing Dart API and app flow retained. Device verification pending.'
