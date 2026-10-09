param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
# Read-only inventory; never resolve packages with the experimental SDK here.
$configPath = Join-Path $ProjectRoot '.dart_tool/package_config.json'
if (!(Test-Path -LiteralPath $configPath)) { throw 'Run pub get with the existing supported Flutter SDK first.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$baseUri = [Uri]::new((Resolve-Path -LiteralPath $configPath).Path)
$plugins = foreach ($package in $config.packages) {
    $rootUri = [Uri]::new($baseUri, [string]$package.rootUri)
    $manifest = Join-Path $rootUri.LocalPath 'pubspec.yaml'
    if (!(Test-Path -LiteralPath $manifest)) { continue }
    $content = Get-Content -LiteralPath $manifest -Raw
    if ($content -notmatch '(?m)^\s+plugin:\s*$') { continue }
    [pscustomobject]@{
        package = $package.name
        declaresOhos = [bool]($content -match '(?m)^\s+ohos:\s*')
        hasOhosDirectory = Test-Path -LiteralPath (Join-Path $rootUri.LocalPath 'ohos')
    }
}
$channels = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'lib') -Filter '*.dart' -Recurse |
    Select-String -Pattern 'kingclub/[a-zA-Z0-9_/-]+' -AllMatches |
    ForEach-Object { foreach ($match in $_.Matches) { $match.Value } } |
    Where-Object { $_ -notmatch '^kingclub/src/' } |
    Sort-Object -Unique
[pscustomobject]@{
    note = 'Manifest evidence only: a declared platform does not prove runtime compatibility. Review federated implementations separately.'
    plugins = @($plugins | Sort-Object package)
    # Includes channel and resource identifiers; each needs source review.
    nativeIdentifierCandidates = @($channels)
} | ConvertTo-Json -Depth 5
