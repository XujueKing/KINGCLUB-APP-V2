param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$repo = Split-Path $PSScriptRoot -Parent
if ($root -eq $repo) { throw 'Use an isolated Harmony probe.' }
$destination = Join-Path $root 'native_plugins/kingclub_file_export_ohos'
if (Test-Path $destination) { throw 'Already staged; do not overwrite.' }
$manifestPath = Join-Path $root 'pubspec.yaml'
$manifest = Get-Content $manifestPath -Raw
if ($manifest -notmatch '(?m)^dependencies:') { throw 'Missing dependencies.' }
$pagePath = Join-Path $root 'lib/src/features/messaging/presentation/chat_file_details_page.dart'
$page = Get-Content $pagePath -Raw
if (($page | Select-String 'Platform.isAndroid' -AllMatches).Matches.Count -ne 2) { throw 'Review changed export page.' }
Copy-Item (Join-Path $repo 'harmony/plugins/kingclub_file_export_ohos') $destination -Recurse
$manifest = $manifest -replace '(?m)^dependencies:', "dependencies:`n  kingclub_file_export_ohos:`n    path: native_plugins/kingclub_file_export_ohos"
[IO.File]::WriteAllText($manifestPath,$manifest)
[IO.File]::WriteAllText($pagePath,$page.Replace('Platform.isAndroid',"(Platform.isAndroid || Platform.operatingSystem == 'ohos')"))
Write-Host 'Harmony file export staged; existing authorization and session guards retained.'
