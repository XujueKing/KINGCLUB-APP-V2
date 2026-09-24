param(
  [uri]$ApiBaseUrl = 'https://api.wuyexin.cn/kingclub-v2',
  [uri]$CommerceApiBaseUrl = 'https://api.wuyexin.cn',
  [string]$FlutterCommand = 'D:/SDK/flutter/bin/flutter.bat'
)

$ErrorActionPreference = 'Stop'

foreach ($entry in @(
  @{ Name = 'API base URL'; Value = $ApiBaseUrl },
  @{ Name = 'Commerce API base URL'; Value = $CommerceApiBaseUrl }
)) {
  if ($entry.Value.Scheme -ne 'https' -or $entry.Value.UserInfo -or
      $entry.Value.Query -or $entry.Value.Fragment) {
    throw "$($entry.Name) must be an HTTPS URL without credentials, query, or fragment."
  }
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  & $FlutterCommand build apk --profile --flavor commerce --target-platform android-arm64 --no-pub `
    "--dart-define=KINGCLUB_API_BASE_URL=$($ApiBaseUrl.AbsoluteUri.TrimEnd('/'))" `
    "--dart-define=KINGCLUB_COMMERCE_API_BASE_URL=$($CommerceApiBaseUrl.AbsoluteUri.TrimEnd('/'))" `
    '--dart-define=KINGCLUB_NOVORUDP_DEVICE_BINDING=false'
  if ($LASTEXITCODE -ne 0) { throw 'Commerce preview APK build failed.' }
} finally {
  Pop-Location
}
