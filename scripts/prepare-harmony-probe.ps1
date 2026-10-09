param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [string]$FlutterOhosRoot = 'D:/SDK/flutter-ohos'
)
$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$destinationPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) { throw 'Use a new empty destination; this script never resets an existing project.' }
if ($destinationPath.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use a destination outside the main application checkout.'
}
$revision = & git -C $FlutterOhosRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne '39285df71a97ffe0c23241dcc459d997a9d8b7c6') {
    throw 'Probe requires the verified 3.44.9+ohos-0.0.1-canary1 SDK commit.'
}
New-Item -ItemType Directory -Path $destinationPath | Out-Null
foreach ($item in @('lib', 'assets', 'pubspec.lock', 'analysis_options.yaml')) {
    Copy-Item -LiteralPath (Join-Path $source $item) -Destination $destinationPath -Recurse
}
$manifest = Get-Content -LiteralPath (Join-Path $source 'pubspec.yaml') -Raw
if ($manifest -notmatch 'sdk: \^3\.13\.1') { throw 'Source SDK constraint changed; review compatibility before staging.' }
$manifest = $manifest.Replace('sdk: ^3.13.1', 'sdk: ^3.12.2')
# Generators stay on the primary SDK. This probe compiles checked-in Dart output.
# Removing them here avoids analyzer/meta conflicts with the older Flutter SDK.
$manifest = [regex]::Replace($manifest, '(?m)^  (build_runner|riverpod_generator|go_router_builder|sqflite_common_ffi):[^\r\n]*\r?\n', '')
Set-Content -LiteralPath (Join-Path $destinationPath 'pubspec.yaml') -Value $manifest -Encoding utf8
Push-Location $destinationPath
try {
    & "$FlutterOhosRoot/bin/flutter.bat" create --platforms=ohos --org com.lingmei --project-name kingclub --no-pub .
    if ($LASTEXITCODE -ne 0) { throw 'Harmony host generation failed.' }
    & "$FlutterOhosRoot/bin/flutter.bat" pub get
    if ($LASTEXITCODE -ne 0) { throw 'Harmony dependency resolution failed.' }
    # Hvigor rejects cross-drive and junction-backed module paths on this host.
    # Stage native plugin sources beside the app; preserve their licenses.
    $configFile = Join-Path $destinationPath '.dart_tool/package_config.json'
    $baseUri = [Uri]::new($configFile)
    $packages = (Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json).packages
    $overrides = @('', 'dependency_overrides:')
    foreach ($package in $packages) {
        $root = ([Uri]::new($baseUri, [string]$package.rootUri)).LocalPath
        if (!(Test-Path -LiteralPath (Join-Path $root 'ohos'))) { continue }
        if ($package.name -eq 'kingclub') { continue }
        $nativeRoot = Join-Path $destinationPath 'native_plugins'
        New-Item -ItemType Directory -Force -Path $nativeRoot | Out-Null
        Copy-Item -LiteralPath $root -Destination (Join-Path $nativeRoot $package.name) -Recurse
        $overrides += "  $($package.name):"
        $overrides += "    path: native_plugins/$($package.name)"
    }
    if ($overrides.Count -gt 2) {
        if ($manifest -match '(?m)^dependency_overrides:') { throw 'Merge existing overrides manually before probing.' }
        Add-Content -LiteralPath 'pubspec.yaml' -Value ($overrides -join "`n")
        & "$FlutterOhosRoot/bin/flutter.bat" pub get
        if ($LASTEXITCODE -ne 0) { throw 'Local Harmony plugin resolution failed.' }
    }
} finally { Pop-Location }
Write-Host "Prepared experimental application copy at $destinationPath. It is not a releasable or signed application."
