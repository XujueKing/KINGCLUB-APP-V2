param([string]$WhisperRoot = (Join-Path $PSScriptRoot '../build/whisper-source'))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $WhisperRoot).Path
$model = Join-Path $root 'models/ggml-base.bin'
$cli = Join-Path $root 'build/bin/Release/whisper-cli.exe'
if ((Get-FileHash $model -Algorithm SHA256).Hash -ne '60ED5BC3DD14EEA856493D334349B405782DDCAF0028D4B5DF4088345FBA2EFE') { throw 'Unexpected base model checksum' }
$head = & git -C $root rev-parse HEAD
if ($head -ne '927cfce34f31707e17f2bff35c349632fb9e2c3a') { throw 'Unexpected whisper.cpp source revision' }
Add-Type -AssemblyName System.Speech
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
$wave = Join-Path $root 'samples/kingclub-zh.wav'
try {
  $speaker.SelectVoice('Microsoft Huihui Desktop')
  $format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(16000,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
  $speaker.SetOutputToWaveFile($wave,$format)
  $speaker.Speak('你好，我们明天晚上七点在门口见面。请把照片发给我。')
} finally { $speaker.Dispose() }
$output = Join-Path $root 'build/kingclub-zh-result'
$ErrorActionPreference = 'Continue'
& $cli -m $model -f $wave -l zh -t 2 -ng -otxt -of $output *> "$output.log"
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($code -ne 0) { throw 'Recognition failed' }
$result = Get-Content -Raw -Encoding UTF8 "$output.txt"
$result
Get-Content "$output.log" | Select-String 'total time|load time|encode time'
if ($result -notmatch '门口见面' -or $result -notmatch '照片发给我') { throw 'Synthetic Chinese recognition did not retain expected phrases' }
