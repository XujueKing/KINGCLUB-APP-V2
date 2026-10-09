param(
  [Parameter(Mandatory = $true)][string]$ProbeRoot,
  [string]$AudioSource = 'C:/HuaweiTools/harmony-audioplayers'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated probe.' }
$revision = & git -C $AudioSource rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne 'b853cdafdef1549be31b478a954f6d8b36d314e6') { throw 'Unexpected audio source revision.' }
$dirty = & git -C $AudioSource status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Upstream source must be clean.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'audioplayers'
if (!$package) { throw 'Resolve audioplayers first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 6\.8\.1\s*$') { throw 'Review changed audio API first.' }
$wrapper = Join-Path $root 'native_plugins/audioplayers'
$adapter = Join-Path $root 'native_plugins/audioplayers_ohos'
if ((Test-Path $wrapper) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
if ((Get-Content $probeManifestPath -Raw) -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe.' }
Copy-Item -LiteralPath $source -Destination $wrapper -Recurse
Copy-Item -LiteralPath (Join-Path $AudioSource 'packages/audioplayers_ohos') -Destination $adapter -Recurse
Get-ChildItem -LiteralPath $adapter -Recurse -Filter '*.ets' -File | ForEach-Object {
  [IO.File]::WriteAllText($_.FullName, ([IO.File]::ReadAllText($_.FullName)).Replace("`r`n", "`n"))
}
$patch = Join-Path $repo 'harmony/patches/audioplayers-ohos.patch'
& git -C $adapter apply --check $patch
if ($LASTEXITCODE -ne 0) { throw 'Patch no longer applies.' }
& git -C $adapter apply $patch
if ($LASTEXITCODE -ne 0) { throw 'Patch failed.' }
$adapterManifest = Get-Content (Join-Path $adapter 'pubspec.yaml') -Raw
$adapterManifest = $adapterManifest -replace '(?m)^resolution: workspace\r?\n', ''
$adapterManifest = $adapterManifest -replace '(?ms)  audioplayers_platform_interface:\s*git:.*?(?=  flutter:)', "  audioplayers_platform_interface: ^7.2.0`n"
[IO.File]::WriteAllText((Join-Path $adapter 'pubspec.yaml'), $adapterManifest)
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  audioplayers_ohos: ^5.2.1"
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: audioplayers_ohos`n      android:")
[IO.File]::WriteAllText((Join-Path $wrapper 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  audioplayers:`n    path: native_plugins/audioplayers`n  audioplayers_ohos:`n    path: native_plugins/audioplayers_ohos"
Write-Host 'Foreground audio staged; recording and device playback are not verified.'
