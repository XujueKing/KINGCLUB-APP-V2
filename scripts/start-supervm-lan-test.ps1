param(
  [string]$Executable = 'D:/WEB3_AI/SUPERVM/target/debug/novovm-product-nat.exe',
  [string]$RuntimeDirectory = 'D:/WEB3_AI/KINGCLUB-APP-V2/build/supervm-lan'
)
$ErrorActionPreference = 'Stop'
$binary = (Resolve-Path -LiteralPath $Executable).Path
$runtime = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
$started = @()
foreach ($name in @('observer','punch')) {
  $configPath = Join-Path $runtime "$name.json"
  $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $endpoint = $config.bind_addr.Split(':')
  if ($endpoint.Length -ne 2 -or !(Get-NetIPAddress -AddressFamily IPv4 -IPAddress $endpoint[0] -ErrorAction SilentlyContinue)) {
    throw 'The configured LAN address is no longer assigned to this computer.'
  }
  $port = [int]$endpoint[1]
  $bound = @(Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue)
  if ($bound.Count -gt 0) {
    $existing = Get-CimInstance Win32_Process -Filter "ProcessId=$($bound[0].OwningProcess)"
    if ($existing.ExecutablePath -eq $binary -and $existing.CommandLine.Contains($configPath)) {
      $started += @{ service=$name; pid=$existing.ProcessId; endpoint=$config.bind_addr; reused=$true }
      continue
    }
    throw "UDP port $port is already owned by another process."
  }
  $process = Start-Process -FilePath $binary -ArgumentList ('"' + $configPath + '"') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime "$name.stdout.log") -RedirectStandardError (Join-Path $runtime "$name.stderr.log")
  Start-Sleep -Milliseconds 500
  if ($process.HasExited) { throw "SUPERVM $name exited. Inspect its local stderr log." }
  $bound = @(Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue | Where-Object {$_.OwningProcess -eq $process.Id})
  if ($bound.Count -eq 0) { throw "SUPERVM $name process started but UDP binding is unverified." }
  $started += @{ service=$name; pid=$process.Id; endpoint=$config.bind_addr; reused=$false }
}
$started | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtime 'processes.json') -Encoding UTF8
$started | ConvertTo-Json
