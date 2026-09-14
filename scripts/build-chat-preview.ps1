param(
  [Parameter(Mandatory=$true)][uri]$ApiBaseUrl,
  [string]$FlutterCommand = 'D:/SDK/flutter/bin/flutter.bat'
)
$ErrorActionPreference = 'Stop'
if ($ApiBaseUrl.Scheme -ne 'https' -or $ApiBaseUrl.UserInfo -or $ApiBaseUrl.Query -or $ApiBaseUrl.Fragment) {
  throw 'A real HTTPS API base URL without credentials or query is required.'
}
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  & $FlutterCommand build apk --profile --flavor preview --target-platform android-arm64 "--dart-define=KINGCLUB_API_BASE_URL=$($ApiBaseUrl.AbsoluteUri.TrimEnd('/'))"
  if ($LASTEXITCODE -ne 0) { throw 'Chat preview APK build failed.' }
} finally { Pop-Location }
