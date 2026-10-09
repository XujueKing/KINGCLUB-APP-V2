param(
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [string]$PickerSource = 'C:/HuaweiTools/harmony-image-picker'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
if ($root -eq (Split-Path $PSScriptRoot -Parent)) { throw 'Use an isolated probe.' }
$revision = & git -C $PickerSource rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne '1af98579e1a95d4fca19e422d26f5b6856ac38ba') { throw 'Unexpected image picker revision.' }
$dirty = & git -C $PickerSource status --porcelain -- packages/image_picker/image_picker_ohos
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Adapter source must be clean.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'image_picker'
if (!$package) { throw 'Resolve image_picker first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 1\.2\.3\s*$') { throw 'Review changed image_picker API before adapting.' }
$target = Join-Path $root 'native_plugins/image_picker'
$adapter = Join-Path $root 'native_plugins/image_picker_ohos'
if ((Test-Path $target) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite local changes.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
$probeManifest = Get-Content $probeManifestPath -Raw
if ($probeManifest -notmatch '(?m)^dependency_overrides:\s*$' -or $probeManifest -notmatch '(?s)dependency_overrides:.*\z') { throw 'Expected prepared probe overrides.' }
Copy-Item -LiteralPath $source -Destination $target -Recurse
Copy-Item -LiteralPath (Join-Path $PickerSource 'packages/image_picker/image_picker_ohos') -Destination $adapter -Recurse
$patch = Join-Path (Split-Path $PSScriptRoot -Parent) 'harmony/patches/image-picker-ohos.patch'
& git -C $adapter apply --check $patch
if ($LASTEXITCODE -ne 0) { throw 'Image picker patch no longer applies.' }
& git -C $adapter apply $patch
if ($LASTEXITCODE -ne 0) { throw 'Image picker patch failed.' }
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: image_picker_ohos`n      android:")
$manifest = [regex]::Replace($manifest, '(?m)^dependencies:', "dependencies:`n  image_picker_ohos:`n    path: ../image_picker_ohos")
[IO.File]::WriteAllText((Join-Path $target 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  image_picker:`n    path: native_plugins/image_picker"
Write-Host 'Image picker staged with cancellation and pending-call fixes. Device verification remains required.'
