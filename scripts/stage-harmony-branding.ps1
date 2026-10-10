param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
if ($root -eq $repo -or $root.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use an isolated Harmony application directory.'
}
$source = Join-Path $repo 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'
$app = Get-Content -LiteralPath (Join-Path $root 'ohos/AppScope/app.json5') -Raw
$module = Get-Content -LiteralPath (Join-Path $root 'ohos/entry/src/main/module.json5') -Raw
if (!$app.Contains('"$media:app_icon"') -or !$module.Contains('"$media:icon"')) {
    throw 'Review Harmony icon resource references before building.'
}
$targets = @(
    (Join-Path $root 'ohos/AppScope/resources/base/media/app_icon.png'),
    (Join-Path $root 'ohos/entry/src/main/resources/base/media/icon.png')
)
foreach ($target in $targets) {
    if (!(Test-Path -LiteralPath (Split-Path $target -Parent))) { throw 'Missing Harmony media directory.' }
    Copy-Item -LiteralPath $source -Destination $target -Force
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
        throw 'Harmony brand icon copy failed.'
    }
}
Write-Host 'KINGCLUB launcher and launch-window icons synchronized.'
