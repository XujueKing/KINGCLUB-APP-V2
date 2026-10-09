param(
    [string]$DevEcoRoot = 'C:/HuaweiTools/DevEcoStudio',
    [string]$FlutterOhosRoot = 'D:/SDK/flutter-ohos',
    [string]$HarmonyPubCache = 'C:/HuaweiTools/pub-cache'
)
# Dot-source in a dedicated PowerShell: . ./scripts/enter-harmony.ps1
# Changes apply only to this process; Android/iOS shells remain unchanged.
$ErrorActionPreference = 'Stop'
$required = @(
    "$DevEcoRoot/sdk/default/openharmony/toolchains/hdc.exe",
    "$DevEcoRoot/tools/ohpm/bin/ohpm.bat",
    "$DevEcoRoot/tools/hvigor/bin/hvigorw.bat",
    "$DevEcoRoot/tools/node/node.exe",
    "$FlutterOhosRoot/bin/flutter.bat"
)
foreach ($file in $required) {
    if (!(Test-Path -LiteralPath $file)) { throw "Missing Harmony tool: $file" }
}
$env:DEVECO_SDK_HOME = "$DevEcoRoot/sdk"
if (!(Test-Path -LiteralPath $HarmonyPubCache)) { throw "Missing Harmony pub cache: $HarmonyPubCache" }
$env:PUB_CACHE = $HarmonyPubCache
$env:PATH = (@(
    "$FlutterOhosRoot/bin",
    "$DevEcoRoot/tools/node",
    "$DevEcoRoot/tools/ohpm/bin",
    "$DevEcoRoot/tools/hvigor/bin",
    "$DevEcoRoot/sdk/default/openharmony/toolchains",
    $env:PATH
) -join [IO.Path]::PathSeparator)
Write-Host 'Harmony environment set for this PowerShell only. Run flutter doctor -v; use an isolated build directory until compatibility is validated.'
