param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
if ($root -eq $repo -or $root.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use an isolated Harmony application directory.'
}
$modulePath = Join-Path $root 'ohos/entry/src/main/module.json5'
$module = Get-Content -LiteralPath $modulePath -Raw
if (!$module.Contains('"ohos.permission.CAMERA"')) {
    $anchor = '"requestPermissions": ['
    if (!$module.Contains($anchor)) { throw 'Missing Harmony permission declaration.' }
    $module = $module.Replace($anchor, $anchor + "`n" + '      {"name":"ohos.permission.CAMERA","reason":"$string:camera_reason","usedScene":{"abilities":["EntryAbility"],"when":"inuse"}},')
    [IO.File]::WriteAllText($modulePath, $module, [Text.UTF8Encoding]::new($false))
}
$stringsPath = Join-Path $root 'ohos/entry/src/main/resources/base/element/string.json'
$strings = Get-Content -LiteralPath $stringsPath -Raw | ConvertFrom-Json
if (!($strings.string | Where-Object { $_.name -eq 'camera_reason' })) {
    $strings.string += [pscustomobject]@{name='camera_reason';value='用于视频通话中的实时画面'}
}
foreach ($item in $strings.string) {
    if ($item.name -eq 'microphone_reason') { $item.value = '用于聊天语音录制及语音、视频通话' }
}
[IO.File]::WriteAllText($stringsPath, ($strings | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Write-Host 'Harmony foreground call permission declarations synchronized.'
