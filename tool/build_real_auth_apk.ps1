$project = 'D:\WEB3_AI\KINGCLUB-APP-V2'
$log = Join-Path $project 'build\real-auth-build.log'
$errorLog = Join-Path $project 'build\real-auth-build.error.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$process = Start-Process -FilePath 'D:\SDK\flutter\bin\flutter.bat' `
  -ArgumentList @('build','apk','--debug','--flavor','preview','--dart-define=KINGCLUB_API_BASE_URL=https://test.wuyexin.cn/kingclub-v2') `
  -WorkingDirectory $project -WindowStyle Hidden -Wait -PassThru `
  -RedirectStandardOutput $log -RedirectStandardError $errorLog
if ($process.ExitCode -ne 0) { exit $process.ExitCode }
'BUILD_OK' | Add-Content $log
