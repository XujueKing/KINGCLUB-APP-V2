param(
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [Parameter(Mandatory = $true)][uri]$ApiBaseUrl,
    [switch]$Unsigned
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
if ($root -eq (Split-Path $PSScriptRoot -Parent)) { throw 'Use an isolated Harmony application directory.' }
if ($ApiBaseUrl.Scheme -ne 'https' -or $ApiBaseUrl.UserInfo -or $ApiBaseUrl.Query -or $ApiBaseUrl.Fragment) {
    throw 'Provide an HTTPS API base without credentials, query or fragment.'
}
if ($ApiBaseUrl.Host -eq 'api.wuyexin.cn' -and $ApiBaseUrl.AbsolutePath.TrimEnd('/') -ne '/kingclub-v2') {
    throw 'KINGCLUB login requires https://api.wuyexin.cn/kingclub-v2, not the gateway root.'
}
foreach ($plugin in @('kingclub_secure_storage_ohos','path_provider_ohos','sqflite_ohos','video_player_ohos')) {
    if (!(Test-Path (Join-Path $root "native_plugins/$plugin/pubspec.yaml"))) { throw "Missing startup adapter: $plugin" }
}
& (Join-Path $PSScriptRoot 'stage-harmony-branding.ps1') -ProbeRoot $root
. (Join-Path $PSScriptRoot 'enter-harmony.ps1')
$argsList = @('build', 'hap', '--debug', "--dart-define=KINGCLUB_API_BASE_URL=$($ApiBaseUrl.AbsoluteUri.TrimEnd('/'))")
if ($ApiBaseUrl.Host -eq 'api.wuyexin.cn') {
    $argsList += '--dart-define=KINGCLUB_COMMERCE_API_BASE_URL=https://api.wuyexin.cn/commerce'
}
if ($Unsigned) { $argsList += '--no-codesign' }
Push-Location $root
try {
    & flutter @argsList
    if ($LASTEXITCODE -ne 0) { throw 'Harmony device build failed.' }
} finally { Pop-Location }
Write-Host 'Built an experimental real-network app. Build success does not certify unsupported plugins, signing or device behavior.'
