param(
  [Parameter(Mandatory=$true)][uri]$ApiBaseUrl,
  [string]$FlutterCommand = 'D:/SDK/flutter/bin/flutter.bat',
  [uri]$RelayUrl,
  [string]$RelayPeer,
  [string]$RelayCertificatePath,
  [string]$NovoRudpSourceRoot,
  [string]$StunHost,
  [ValidateRange(1,65535)][int]$StunPort = 3478,
  [switch]$SkipNovoRudp,
  [switch]$EnablePeerFiles,
  [switch]$EnableGroupFiles,
  [switch]$EnableLan
)
$ErrorActionPreference = 'Stop'
if ($ApiBaseUrl.Scheme -ne 'https' -or $ApiBaseUrl.UserInfo -or $ApiBaseUrl.Query -or $ApiBaseUrl.Fragment) {
  throw 'A real HTTPS API base URL without credentials or query is required.'
}
Push-Location (Split-Path -Parent $PSScriptRoot)
$previousJni = $env:KINGCLUB_NOVORUDP_JNI_DIR
try {
  $relayArguments = @()
  if ($StunHost) {
    if ($SkipNovoRudp -or !$RelayUrl -or !$RelayPeer) {
      throw 'Public UDP discovery requires the configured authenticated NovoRUDP relay.'
    }
    # Host only: never embed credentials, a URL, whitespace or shell arguments.
    # The current route implements IPv4 STUN; IPv6 endpoints are not supported.
    $hostKind = [Uri]::CheckHostName($StunHost)
    if ($StunHost.Length -gt 253 -or
        $StunHost -cnotmatch '^[A-Za-z0-9][A-Za-z0-9.-]*$' -or
        $hostKind -notin @([UriHostNameType]::Dns, [UriHostNameType]::IPv4)) {
      throw 'StunHost must be an IPv4 address or DNS hostname without a scheme or port.'
    }
    $relayArguments += "--dart-define=KINGCLUB_NOVORUDP_STUN_HOST=$StunHost"
    $relayArguments += "--dart-define=KINGCLUB_NOVORUDP_STUN_PORT=$StunPort"
  } elseif ($PSBoundParameters.ContainsKey('StunPort')) {
    throw 'StunPort requires StunHost.'
  }
  if ($EnableGroupFiles -and !$EnablePeerFiles) {
    throw 'Group peer files require EnablePeerFiles and the deployed group-file authorization interfaces.'
  }
  if ($EnableGroupFiles) {
    $relayArguments += '--dart-define=KINGCLUB_NOVORUDP_GROUP_FILES=true'
  }
  if ($EnableLan -and ($SkipNovoRudp -or !$RelayUrl -or !$RelayPeer)) {
    throw 'LAN upgrade requires the configured authenticated NovoRUDP relay.'
  }
  if ($EnableLan) {
    $relayArguments += '--dart-define=KINGCLUB_NOVORUDP_LAN=true'
  }
  if ($EnablePeerFiles -and ($SkipNovoRudp -or !$RelayUrl -or !$RelayPeer)) {
    throw 'Peer files require the configured authenticated NovoRUDP relay.'
  }
  if ($EnablePeerFiles) {
    $relayArguments += '--dart-define=KINGCLUB_NOVORUDP_FILE_TRANSFER=true'
  }
  if ($RelayUrl -or $RelayPeer -or $RelayCertificatePath) {
    if ($SkipNovoRudp -or !$RelayUrl -or $RelayUrl.Scheme -ne 'wss' -or
        !$RelayUrl.Host -or $RelayUrl.UserInfo -or $RelayUrl.Query -or $RelayUrl.Fragment -or
        $RelayUrl.AbsolutePath -ne '/novovm' -or $RelayPeer -cnotmatch '^novovm-ed25519:[0-9a-f]{64}$') {
      throw 'Relay requires NovoRUDP, a credential-free WSS /novovm URL and a pinned Ed25519 peer ID.'
    }
    $relayArguments += "--dart-define=KINGCLUB_NOVORUDP_RELAY_URL=$($RelayUrl.AbsoluteUri)"
    $relayArguments += "--dart-define=KINGCLUB_NOVORUDP_RELAY_PEER=$RelayPeer"
    if ($RelayCertificatePath) {
      $certificate = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $RelayCertificatePath).Path)
      $pem = [Text.Encoding]::UTF8.GetString($certificate).Trim()
      if ($certificate.Length -gt 49152 -or !$pem.StartsWith('-----BEGIN CERTIFICATE-----') -or
          !$pem.EndsWith('-----END CERTIFICATE-----') -or $pem.Contains('PRIVATE KEY')) {
        throw 'Relay certificate must contain only public PEM certificate data.'
      }
      $relayArguments += "--dart-define=KINGCLUB_NOVORUDP_RELAY_CA_BASE64=$([Convert]::ToBase64String($certificate))"
    }
  }
  $env:KINGCLUB_NOVORUDP_JNI_DIR = $null
  if (!$SkipNovoRudp) {
    $sourceArguments = @{}
    if ($NovoRudpSourceRoot) { $sourceArguments.SourceRoot = $NovoRudpSourceRoot }
    & (Join-Path $PSScriptRoot 'build-novorudp-android.ps1') @sourceArguments | Out-Host
    $env:KINGCLUB_NOVORUDP_JNI_DIR = Join-Path (Get-Location).Path 'build/novorudp-jni'
  }
  # Windows PowerShell treats native stderr warnings as errors when redirected.
  # Flutter's exit code, not a plugin warning, determines build success.
  $ErrorActionPreference = 'Continue'
  $bindingEnabled = if ($SkipNovoRudp) { 'false' } else { 'true' }
  & $FlutterCommand build apk --profile --flavor preview --target-platform android-arm64 "--dart-define=KINGCLUB_API_BASE_URL=$($ApiBaseUrl.AbsoluteUri.TrimEnd('/'))" "--dart-define=KINGCLUB_NOVORUDP_DEVICE_BINDING=$bindingEnabled" @relayArguments
  $buildExitCode = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($buildExitCode -ne 0) { throw 'Chat preview APK build failed.' }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $apk = [IO.Compression.ZipFile]::OpenRead((Join-Path (Get-Location).Path 'build/app/outputs/flutter-apk/app-preview-profile.apk'))
  try {
    $entry = $apk.GetEntry('lib/arm64-v8a/libkingclub_novorudp.so')
    if ($SkipNovoRudp) {
      if ($entry) { throw 'APK unexpectedly includes a stale NovoRUDP library.' }
    } else {
      if (!$entry -or $entry.Length -lt 4096) { throw 'APK is missing the NovoRUDP library.' }
      $stream = $entry.Open()
      try {
        $header = New-Object byte[] 20
        if ($stream.Read($header,0,20) -ne 20 -or $header[0] -ne 127 -or $header[1] -ne 69 -or $header[2] -ne 76 -or $header[3] -ne 70 -or $header[18] -ne 183 -or $header[19] -ne 0) {
          throw 'Packaged NovoRUDP library is not an ARM64 ELF.'
        }
      } finally { $stream.Dispose() }
    }
  } finally { $apk.Dispose() }
} finally {
  $env:KINGCLUB_NOVORUDP_JNI_DIR = $previousJni
  Pop-Location
}
