[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$FlutterRoot = $env:KINGCLUB_FLUTTER_ROOT,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArguments = @('--version')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $FlutterRoot) {
  $FlutterRoot = Join-Path (Split-Path -Parent $repositoryRoot) 'tools/flutter-3.47.1'
}
$flutterCommand = Join-Path $FlutterRoot 'bin/flutter.bat'
$versionFile = Join-Path $FlutterRoot 'bin/cache/flutter.version.json'
if (-not (Test-Path -LiteralPath $flutterCommand) -or
    -not (Test-Path -LiteralPath $versionFile)) {
  throw 'Install and initialize Flutter 3.47.1, then set KINGCLUB_FLUTTER_ROOT to its SDK directory.'
}
$sdkVersion = Get-Content -Raw -LiteralPath $versionFile | ConvertFrom-Json
if ($sdkVersion.flutterVersion -ne '3.47.1' -or
    $sdkVersion.dartSdkVersion -notmatch '^3\.13\.1(?:\s|$)' -or
    $sdkVersion.frameworkRevision -ne '6655482ec06e547f90abf8ae7590466f4415978d') {
  throw 'SDK mismatch: this project requires official Flutter 3.47.1 / Dart 3.13.1. Existing SDKs were not changed.'
}
Push-Location $repositoryRoot
try {
  & $flutterCommand @FlutterArguments
  $flutterExitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
exit $flutterExitCode
