param(
  [Parameter(Mandatory = $true)][string]$SourceRoot,
  [ValidateSet('release', 'debug')][string]$NativeProfile = 'release',
  [string]$FlutterCommand = 'flutter',
  [string]$CargoCommand = 'cargo',
  [string[]]$Tests = @(
    'test/novorudp_download_completion_test.dart',
    'test/novorudp_file_sender_test.dart',
    'test/udp_http_handoff_test.dart'
  )
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$head = & git -C $source rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head.Trim() -ne '579008d18db917bd2e12610a8d1f93bebbef3f51') {
  throw 'Unreviewed SUPERVM source revision.'
}
& git -C $source diff --quiet HEAD -- crates/novovm-network/src/novorudp.rs crates/novovm-network/src/product_overlay.rs crates/novovm-network/src/product_nat.rs crates/novovm-network/src/product_directory.rs
if ($LASTEXITCODE -ne 0) { throw 'Upstream protocol source has unreviewed changes.' }
$savedSource = $env:NOVORUDP_SOURCE_ROOT
$savedLibrary = $env:NOVORUDP_NATIVE_LIBRARY
Push-Location $projectRoot
try {
  $env:NOVORUDP_SOURCE_ROOT = $source.Replace('\', '/')
  $buildArgs = @('build', '--offline', '--locked', '--manifest-path', 'native/novorudp/Cargo.toml', '--target-dir', 'build/novorudp-host')
  if ($NativeProfile -eq 'release') { $buildArgs += '--release' }
  # Android's native library is built with --release even for Flutter profile
  # previews. Use the same optimization level for throughput acceptance.
  $ErrorActionPreference = 'Continue'
  & $CargoCommand @buildArgs
  $buildExit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($buildExit -ne 0) { throw 'NovoRUDP native build failed.' }
  $env:NOVORUDP_NATIVE_LIBRARY = Join-Path $projectRoot "build/novorudp-host/$NativeProfile/kingclub_novorudp.dll"
  Write-Output "NOVORUDP_TEST nativeProfile=$NativeProfile upstream=$($head.Trim())"
  $ErrorActionPreference = 'Continue'
  & $FlutterCommand test @Tests --reporter expanded
  $testExit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($testExit -ne 0) { throw 'NovoRUDP file tests failed.' }
} finally {
  Pop-Location
  $env:NOVORUDP_SOURCE_ROOT = $savedSource
  $env:NOVORUDP_NATIVE_LIBRARY = $savedLibrary
}
