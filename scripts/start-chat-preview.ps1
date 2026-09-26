param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$Serial,
  [string]$AdbCommand = 'D:/SDK/Android/platform-tools/adb.exe'
)
$ErrorActionPreference = 'Stop'
$package = 'com.lingmei.kingclub'
$component = "$package/com.lingmei.kingclub.MainActivity"

# An install can return Success before the vendor package manager finishes
# stopping the previous process. A successful am start is not foreground proof.
$deviceState = & $AdbCommand -s $Serial get-state 2>&1
if ($LASTEXITCODE -ne 0 -or ($deviceState -join '').Trim() -ne 'device') {
  throw 'The selected device is not connected and authorized.'
}
for ($attempt = 1; $attempt -le 2; $attempt++) {
  $start = & $AdbCommand -s $Serial shell am start -W -n $component 2>&1
  if ($LASTEXITCODE -ne 0 -or ($start -match '^Error:')) {
    throw 'The preview activity could not be started.'
  }
  $stable = 0
  for ($sample = 0; $sample -lt 10; $sample++) {
    $activities = & $AdbCommand -s $Serial shell dumpsys activity activities
    if ($LASTEXITCODE -ne 0) { throw 'Could not verify the foreground activity.' }
    # Newer Android reports topResumedActivity; older builds use mResumedActivity.
    $foreground = @($activities | Where-Object { $_ -match '^\s*topResumedActivity=' })
    if ($foreground.Count -eq 0) {
      $foreground = @($activities | Where-Object { $_ -match '^\s*mResumedActivity:' })
    }
    if ($foreground.Count -eq 1 -and $foreground[0].Contains($component)) {
      $stable++
      if ($stable -ge 3) {
        Write-Output "KINGCLUB_PREVIEW_FOREGROUND_VERIFIED serial=$Serial attempt=$attempt"
        Write-Output 'Read the current UI before tapping; activity verification does not verify the page.'
        return
      }
    } else {
      $stable = 0
    }
    Start-Sleep -Seconds 1
  }
}
throw 'KINGCLUB did not remain in the foreground. Stop UI actions and inspect the device; no taps were sent.'
