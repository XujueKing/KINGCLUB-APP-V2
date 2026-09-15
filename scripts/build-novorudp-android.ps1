param(
  [string]$SourceRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'SUPERVM'),
  [string]$NdkRoot = 'D:/SDK/Android/ndk/28.2.13676358',
  [string]$CargoCommand = (Join-Path $env:USERPROFILE '.cargo/bin/cargo.exe')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$linker = Join-Path $NdkRoot 'toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android24-clang.cmd'
if (!(Test-Path -LiteralPath $linker)) { throw 'Android API 24 ARM64 linker is missing.' }
# Compile the reviewed upstream sources, not an arbitrary local branch revision.
$upstreamHead = & git -C $source rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $upstreamHead.Trim() -ne '6939dc96c4d0c93c1162307c5481b9145faee32f') { throw 'Unreviewed SUPERVM source revision.' }
& git -C $source diff --quiet HEAD -- crates/novovm-network/src/novorudp.rs crates/novovm-network/src/product_overlay.rs crates/novovm-network/src/product_nat.rs crates/novovm-network/src/product_directory.rs
if ($LASTEXITCODE -ne 0) { throw 'Upstream protocol source has unreviewed changes.' }
$names = @('NOVORUDP_SOURCE_ROOT','CARGO_TARGET_DIR','CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
try {
  $env:NOVORUDP_SOURCE_ROOT = $source.Replace('\','/')
  $env:CARGO_TARGET_DIR = Join-Path $projectRoot 'build/novorudp-native'
  $env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $linker
  $ErrorActionPreference = 'Continue'
  & $CargoCommand build --offline --locked --release --target aarch64-linux-android --manifest-path (Join-Path $projectRoot 'native/novorudp/Cargo.toml')
  $buildResult = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($buildResult -ne 0) { throw 'NovoRUDP Android native build failed.' }
  $library = Join-Path $env:CARGO_TARGET_DIR 'aarch64-linux-android/release/libkingclub_novorudp.so'
  $jniRoot = Join-Path $projectRoot 'build/novorudp-jni'
  $abiRoot = Join-Path $jniRoot 'arm64-v8a'
  New-Item -ItemType Directory -Force -Path $abiRoot | Out-Null
  Copy-Item -LiteralPath $library -Destination (Join-Path $abiRoot 'libkingclub_novorudp.so') -Force
  Write-Output $jniRoot
} finally {
  foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$saved[$name],'Process') }
}
