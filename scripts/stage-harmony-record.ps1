param(
  [Parameter(Mandatory = $true)][string]$ProbeRoot,
  [string]$RecordSource = 'C:/HuaweiTools/harmony-record'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated probe.' }
$revision = & git -C $RecordSource rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne 'c719424e0cd869bf57198e71768d11f995cce849') { throw 'Unexpected audio source revision.' }
$dirty = & git -C $RecordSource status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Upstream source must be clean.' }
$configFile = Join-Path $root '.dart_tool/package_config.json'
$package = (Get-Content $configFile -Raw | ConvertFrom-Json).packages | Where-Object name -eq 'record'
if (!$package) { throw 'Resolve record first.' }
$source = ([Uri]::new([Uri]::new($configFile), [string]$package.rootUri)).LocalPath
$manifest = Get-Content (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch '(?m)^version: 7\.1\.1\s*$') { throw 'Review changed audio API first.' }
$wrapper = Join-Path $root 'native_plugins/record'
$adapter = Join-Path $root 'native_plugins/record_ohos'
if ((Test-Path $wrapper) -or (Test-Path $adapter)) { throw 'Already staged; do not overwrite.' }
$probeManifestPath = Join-Path $root 'pubspec.yaml'
if ((Get-Content $probeManifestPath -Raw) -notmatch '(?m)^dependency_overrides:\s*$') { throw 'Expected prepared probe.' }
Copy-Item -LiteralPath $source -Destination $wrapper -Recurse
Copy-Item -LiteralPath (Join-Path $RecordSource 'record_ohos') -Destination $adapter -Recurse
Get-ChildItem -LiteralPath $adapter -Recurse -Filter '*.ets' -File | ForEach-Object {
  [IO.File]::WriteAllText($_.FullName, ([IO.File]::ReadAllText($_.FullName)).Replace("`r`n", "`n"))
}
$patch = Join-Path $repo 'harmony/patches/record-ohos.patch'
& git -C $adapter apply --check $patch
if ($LASTEXITCODE -ne 0) { throw 'Patch no longer applies.' }
& git -C $adapter apply $patch
if ($LASTEXITCODE -ne 0) { throw 'Patch failed.' }
$adapterManifest = Get-Content (Join-Path $adapter 'pubspec.yaml') -Raw
$adapterManifest = $adapterManifest.Replace('record_platform_interface: ^1.0.2', 'record_platform_interface: ^2.1.0').Replace('  uuid: ^3.0.7', '')
$adapterManifest = $adapterManifest.Replace('        pluginClass: RecordOhosPlugin', "        pluginClass: RecordOhosPlugin`n        dartPluginClass: KingclubRecordOhos")
New-Item -ItemType Directory -Path (Join-Path $adapter 'lib') -Force | Out-Null
Copy-Item (Join-Path $repo 'harmony/verification/record_ohos.dart.template') (Join-Path $adapter 'lib/record_ohos.dart')
[IO.File]::WriteAllText((Join-Path $adapter 'pubspec.yaml'), $adapterManifest)
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  record_ohos: ^1.0.0"
$manifest = $manifest.Replace('      android:', "      ohos:`n        default_package: record_ohos`n      android:")
[IO.File]::WriteAllText((Join-Path $wrapper 'pubspec.yaml'), $manifest)
Add-Content -LiteralPath $probeManifestPath -Value "`n  record:`n    path: native_plugins/record`n  record_ohos:`n    path: native_plugins/record_ohos"
$modulePath = Join-Path $root 'ohos/entry/src/main/module.json5'
$module = Get-Content $modulePath -Raw
if ($module -notmatch 'ohos.permission.MICROPHONE') {
  $permissions = @'
      {"name":"ohos.permission.MICROPHONE","reason":"$string:microphone_reason","usedScene":{"abilities":["EntryAbility"],"when":"inuse"}},
'@
  $module = $module.Replace('"requestPermissions": [', '"requestPermissions": [' + "`n" + $permissions)
  [IO.File]::WriteAllText($modulePath, $module)
}
$stringsPath = Join-Path $root 'ohos/entry/src/main/resources/base/element/string.json'
$strings = Get-Content $stringsPath -Raw | ConvertFrom-Json
if (!($strings.string | Where-Object name -eq 'microphone_reason')) {
  $strings.string += @{name='microphone_reason';value='用于按住说话录制聊天语音'}
  [IO.File]::WriteAllText($stringsPath, ($strings | ConvertTo-Json -Depth 10))
}
Write-Host 'Foreground AAC recording staged; device verification remains pending.'
