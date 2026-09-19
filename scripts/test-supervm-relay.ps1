param(
  [Parameter(Mandatory = $true)][string]$RelayUrl,
  [Parameter(Mandatory = $true)][string]$RelayPeer,
  [Parameter(Mandatory = $true)][string]$RelayCertificate,
  [Parameter(Mandatory = $true)][string]$SourceRoot,
  [string]$FlutterCommand = 'flutter',
  [string]$CargoCommand = 'cargo'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$certificate = (Resolve-Path -LiteralPath $RelayCertificate).Path
$upstreamHead = & git -C $source rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $upstreamHead.Trim() -ne '579008d18db917bd2e12610a8d1f93bebbef3f51') {
  throw 'Unreviewed SUPERVM source revision.'
}
& git -C $source diff --quiet HEAD -- crates/novovm-network/src/novorudp.rs crates/novovm-network/src/product_overlay.rs crates/novovm-network/src/product_nat.rs crates/novovm-network/src/product_directory.rs
if ($LASTEXITCODE -ne 0) { throw 'Upstream protocol source has unreviewed changes.' }
$names = @('NOVORUDP_SOURCE_ROOT', 'NOVORUDP_NATIVE_LIBRARY', 'SUPERVM_TEST_RELAY_URL', 'SUPERVM_TEST_RELAY_PEER', 'SUPERVM_TEST_RELAY_CERT')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
Push-Location $projectRoot
try {
  $env:NOVORUDP_SOURCE_ROOT = $source.Replace('\', '/')
  # Always build before loading: an old DLL can pass same-host tests while
  # missing the reviewed cross-host clock-skew validation used by Android.
  & $CargoCommand build --offline --locked --manifest-path native/novorudp/Cargo.toml --target-dir build/novorudp-host
  if ($LASTEXITCODE -ne 0) { throw 'NovoRUDP host native build failed.' }
  $env:NOVORUDP_NATIVE_LIBRARY = Join-Path $projectRoot 'build/novorudp-host/debug/kingclub_novorudp.dll'
  $env:SUPERVM_TEST_RELAY_URL = $RelayUrl
  $env:SUPERVM_TEST_RELAY_PEER = $RelayPeer
  $env:SUPERVM_TEST_RELAY_CERT = $certificate
  & $FlutterCommand test test/supervm_relay_file_test.dart --reporter expanded
  if ($LASTEXITCODE -ne 0) { throw 'SuperVM relay integration failed.' }
} finally {
  Pop-Location
  foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
