param(
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [string]$PathProviderSource = 'C:/HuaweiTools/harmony-path-provider-sparse',
    [string]$SqliteSource = 'C:/HuaweiTools/harmony-sqflite'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
if ($root -eq (Split-Path $PSScriptRoot -Parent)) { throw 'Only stage into an isolated Harmony probe.' }
$manifestPath = Join-Path $root 'pubspec.yaml'
$manifest = Get-Content -LiteralPath $manifestPath -Raw
if ($manifest -notmatch '(?m)^dependency_overrides:') { throw 'Prepare the Harmony probe first.' }
$sources = @(
    @{ Root = $PathProviderSource; Commit = 'd4e49daa0acbd0bc419d58b1da27d64d44fab54b'; Prefix = 'packages/path_provider'; Names = @('path_provider', 'path_provider_ohos') },
    @{ Root = $SqliteSource; Commit = '38d829a84202bf73f9475352bb01fcbfa00e431b'; Prefix = ''; Names = @('sqflite', 'sqflite_ohos') }
)
# Validate every source and destination before making changes. Never patch caches.
foreach ($source in $sources) {
    $revision = & git -C $source.Root rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne $source.Commit) { throw "Unexpected plugin revision: $($source.Root)" }
    foreach ($name in $source.Names) {
        if (Test-Path -LiteralPath (Join-Path $root "native_plugins/$name")) { throw "Already staged: $name" }
        if (!(Test-Path -LiteralPath (Join-Path $source.Root "$($source.Prefix)/$name/pubspec.yaml"))) { throw "Missing plugin: $name" }
        if ($manifest -match "(?m)^  ${name}:\s*\r?\n\s+path:") { throw "Existing path override: $name" }
    }
}
New-Item -ItemType Directory -Force -Path (Join-Path $root 'native_plugins') | Out-Null
foreach ($source in $sources) {
    foreach ($name in $source.Names) {
        $packageSource = Join-Path $source.Root "$($source.Prefix)/$name"
        Copy-Item -LiteralPath $packageSource -Destination (Join-Path $root "native_plugins/$name") -Recurse
        $manifest += "`n  ${name}:`n    path: native_plugins/$name`n"
    }
}
[IO.File]::WriteAllText($manifestPath, $manifest)
Write-Host 'Storage plugins staged with original licenses. Run flutter pub get, build and device persistence tests; staging alone does not validate runtime behavior.'
