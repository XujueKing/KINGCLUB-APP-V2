# Installed native video bridge verification

This instrumentation APK has no launcher activity, no Internet permission and
does not send any chat messages. It loads the installed preview app's actual
`ChatVideoUpload` class and passes a synthetic MP4 through it. Use only synthetic
media here; never bundle member videos or credentials into the probe.

1. Generate a synthetic, SDR, portrait, audible MP4 larger than 4 MiB into
   `build/native-video-probe/assets/source.mp4`. For example, with FFmpeg:

   ```sh
   ffmpeg -y -f lavfi -i testsrc2=size=720x1280:rate=29 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 8 -c:v libx264 -preset ultrafast -b:v 8M -minrate 8M -maxrate 8M -bufsize 8M -x264-params nal-hrd=cbr -pix_fmt yuv420p -c:a aac -b:a 48k source.mp4
   ```

2. Run `scripts/native-video-probe/build.ps1`. The Android SDK, JDK and debug
   keystore are parameters; the default paths match the current development PC.
3. Install `build/native-video-probe/probe.apk` onto the authorized device. Its
   debug signing certificate must match the installed preview app.
4. Run:

   ```sh
   adb -s DEVICE shell am instrument -w com.lingmei.kingclub.videoprobe/com.lingmei.kingclub.videoprobe.VideoUploadProbe
   ```

   Require `result=COMPRESSED`, positive `outputBytes < sourceBytes` and a finite
   elapsed time. For this fixed 8-second fixture, output must also be at most
   2,000,000 bytes; BITRATE_OVERSHOOT fails the requested upload budget.
   The instrumentation exit code alone is not a passing result.
   `FELL_BACK_TO_SOURCE` is useful evidence of a native problem, not a pass.
5. Uninstall only `com.lingmei.kingclub.videoprobe`, then reopen the preview app.

The runner removes its source copy and successful output. The private native
bridge also checks output duration and audio presence. This proves real device
encoding, not visual quality, audible playback, A/V sync or end-to-end delivery.

2026-09-15: connected PCLM50 returned COMPRESSED, sourceBytes=8468630,
outputBytes=2938329, elapsedMs=3651. Probe uninstalled, preview relaunched.
The member's separately sent ~18 MiB clip still requires diagnosis in the normal
Flutter send flow; this synthetic result does not resolve that report.
