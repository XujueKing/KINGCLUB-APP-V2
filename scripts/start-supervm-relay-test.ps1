param(
  [string]$Executable = 'D:/WEB3_AI/SUPERVM/target/debug/novovm-product-relay.exe',
  [string]$RuntimeDirectory = 'D:/WEB3_AI/KINGCLUB-APP-V2/build/supervm-lan',
  [string]$OpenSsl = 'C:/Program Files/Git/usr/bin/openssl.exe',
  [string]$LanAddress = '192.168.1.5',
  [ValidateRange(1024,65535)][int]$Port = 45172
)
$ErrorActionPreference = 'Stop'
$binary = (Resolve-Path -LiteralPath $Executable).Path
$runtime = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
$address = [Net.IPAddress]::Parse($LanAddress)
if ($address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
    !(Get-NetIPAddress -AddressFamily IPv4 -IPAddress $LanAddress -ErrorAction SilentlyContinue)) {
  throw 'A currently assigned IPv4 LAN address is required.'
}
$configPath = Join-Path $runtime 'relay.json'
$bound = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
if ($bound.Count -gt 0) {
  $existing = Get-CimInstance Win32_Process -Filter "ProcessId=$($bound[0].OwningProcess)"
  if ($existing.ExecutablePath -eq $binary -and $existing.CommandLine.Contains($configPath)) {
    if (!($bound | Where-Object {$_.OwningProcess -eq $existing.ProcessId -and $_.LocalAddress -eq $LanAddress})) {
      throw 'Existing relay listens on a different address. Stop that test process before changing the bind address.'
    }
    @{ pid=$existing.ProcessId; endpoint="wss://${LanAddress}:$Port/novovm"; reused=$true } | ConvertTo-Json
    exit 0
  }
  throw 'The relay test port is already in use by another process.'
}
$identity = (Resolve-Path -LiteralPath (Join-Path $runtime 'nat-identity.hex')).Path
$cert = Join-Path $runtime 'relay-test-cert.pem'
$key = Join-Path $runtime 'relay-test-key.pem'
if ((Test-Path -LiteralPath $cert) -ne (Test-Path -LiteralPath $key)) {
  throw 'Incomplete local certificate pair; existing files were not overwritten.'
}
if (!(Test-Path -LiteralPath $cert)) {
  # Runtime directory inherits the restricted test-identity ACL. Nothing is
  # installed into Windows/Android certificate stores or committed to Git.
  $ErrorActionPreference = 'Continue'
  & $OpenSsl req -x509 -newkey rsa:2048 -sha256 -noenc -days 2 -subj '/CN=KINGCLUB local relay test' -addext "subjectAltName=IP:$LanAddress,IP:127.0.0.1,DNS:localhost" -keyout $key -out $cert 2> (Join-Path $runtime 'relay-cert-generation.log')
  $certificateExit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($certificateExit -ne 0) { throw 'Local test certificate creation failed.' }
}
@{
  bind_addr="${LanAddress}:$Port"; tls_cert_path=$cert; tls_key_path=$key
  relay_identity_key_path=$identity; report_path=(Join-Path $runtime 'relay-report.json')
  report_interval_ms=1000; run_for_ms=7200000; max_connections=32; max_sessions=16
} | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding Ascii
$process = Start-Process -FilePath $binary -ArgumentList ('"'+$configPath+'"') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'relay.stdout.log') -RedirectStandardError (Join-Path $runtime 'relay.stderr.log')
Start-Sleep -Milliseconds 500
if ($process.HasExited) { throw 'Relay exited; inspect its local stderr log.' }
$bound = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Where-Object {$_.OwningProcess -eq $process.Id -and $_.LocalAddress -eq $LanAddress})
if ($bound.Count -eq 0) { throw 'Relay process started but listener not verified.' }
@{ pid=$process.Id; endpoint="wss://${LanAddress}:$Port/novovm"; reused=$false } | ConvertTo-Json
