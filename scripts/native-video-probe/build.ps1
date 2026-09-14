param(
  [string]$AndroidSdk = 'D:/SDK/Android',
  [string]$Jdk = 'C:/Program Files/Eclipse Adoptium/jdk-21.0.12.101-hotspot',
  [string]$DebugKeystore = 'C:/Users/xiaoshafa/.android/debug.keystore'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $root 'build/native-video-probe'
$androidJar = Join-Path $AndroidSdk 'platforms/android-36/android.jar'
$buildTools = Join-Path $AndroidSdk 'build-tools/36.0.0'
if (!(Test-Path "$out/assets/source.mp4")) { throw 'Generate the synthetic source fixture first.' }
New-Item -ItemType Directory -Force "$out/classes", "$out/dex" | Out-Null
& "$Jdk/bin/javac.exe" -source 8 -target 8 -classpath $androidJar -d "$out/classes" "$PSScriptRoot/VideoUploadProbe.java"
if ($LASTEXITCODE -ne 0) { throw 'Probe Java compilation failed.' }
& "$Jdk/bin/java.exe" -cp "$buildTools/lib/d8.jar" com.android.tools.r8.D8 --min-api 24 --lib $androidJar --output "$out/dex" "$out/classes/com/lingmei/kingclub/videoprobe/VideoUploadProbe.class"
if ($LASTEXITCODE -ne 0) { throw 'Probe dex compilation failed.' }
& "$buildTools/aapt2.exe" link -I $androidJar --manifest "$PSScriptRoot/AndroidManifest.xml" -A "$out/assets" -o "$out/probe-unsigned.apk"
if ($LASTEXITCODE -ne 0) { throw 'Probe APK linking failed.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open("$out/probe-unsigned.apk", 'Update')
try {
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$out/dex/classes.dex", 'classes.dex') | Out-Null
} finally { $zip.Dispose() }
& "$Jdk/bin/java.exe" -jar "$buildTools/lib/apksigner.jar" sign --ks $DebugKeystore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out "$out/probe.apk" "$out/probe-unsigned.apk"
if ($LASTEXITCODE -ne 0) { throw 'Probe signing failed.' }
Write-Output 'NATIVE_VIDEO_PROBE_APK_BUILT'
