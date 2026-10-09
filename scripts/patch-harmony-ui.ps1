param([Parameter(Mandatory = $true)][string]$ProbeRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProbeRoot).Path
$mainRoot = Split-Path $PSScriptRoot -Parent
if ($root -eq $mainRoot) { throw 'Only patch an isolated Harmony probe.' }
$manifestPath = Join-Path $root 'pubspec.yaml'
$manifest = Get-Content -LiteralPath $manifestPath -Raw
if ($manifest -notmatch '(?m)^dependency_overrides:') { throw 'Prepare the Harmony probe first.' }
$configPath = Join-Path $root '.dart_tool/package_config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$base = [Uri]::new($configPath)
foreach ($name in @('cupertino_ui', 'material_ui')) {
    $target = Join-Path $root "harmony_packages/$name"
    if (Test-Path -LiteralPath $target) { throw "Already staged: $name. Review existing patches instead of overwriting." }
    $package = $config.packages | Where-Object name -eq $name
    if (!$package) { throw "Missing resolved dependency: $name" }
    $source = ([Uri]::new($base, [string]$package.rootUri)).LocalPath
    $expected = if ($name -eq 'material_ui') { '1.1.0' } else { '1.0.1' }
    $sourceManifest = Get-Content -LiteralPath (Join-Path $source 'pubspec.yaml') -Raw
    if ($sourceManifest -notmatch "(?m)^version: $([regex]::Escape($expected))\s*$") { throw "Review new $name version before patching." }
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Recurse
    $changed = 0
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $target 'lib') -Filter '*.dart' -Recurse) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        # Harmony follows the existing touch/Material branch. Only switch labels
        # and patterns change; never rewrite platform comparisons or shared cache.
        $updated = [regex]::Replace($text, 'case TargetPlatform\.android:', 'case TargetPlatform.ohos: case TargetPlatform.android:')
        $updated = [regex]::Replace($updated, 'TargetPlatform\.android(?=\s*(?:\|\||=>))', 'TargetPlatform.ohos || TargetPlatform.android')
        if ($updated -ne $text) {
            [IO.File]::WriteAllText($file.FullName, $updated)
            $changed++
        }
    }
    $manifest += "`n  ${name}:`n    path: harmony_packages/$name`n"
    Write-Host "$name $expected : $changed source files patched; licenses preserved."
}
[IO.File]::WriteAllText($manifestPath, $manifest)
