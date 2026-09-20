# Peer deadline preview build

Built from clean detached source `76a793e8ec286bc2f9a5edf4165fc1ef99d75fa2`
in the isolated chat build worktree. No uncommitted onboarding changes were
included. Preview/profile ARM64 compilation and packaged native ELF validation
succeeded. Gradle reported 176.7 seconds.

APK: `build/app/outputs/flutter-apk/app-preview-profile.apk` in that worktree.
Size: 168,112,200 bytes. SHA-256:
`7e9f87b39b9ab30eddd55f382ae71357a7c43d9e06027cefc734ad76037fc27f`.

Configuration retains the previous isolated chat API, signed LAN relay identity
and pinned public certificate, peer/group media and LAN flags. Native source
remains pinned to `579008d18db917bd2e12610a8d1f93bebbef3f51`.
Public ingress was not enabled.

Installation is pending: after the build, ADB returned an empty device list,
and Windows listed no connected Android/ADB handset. No device was wiped,
uninstalled or logged out. Resume with an in-place install when the phones
return, then repeat the recovered-route check from
`2026-09-20-ab-adaptive-route.md`. The earlier LAN success does not accept this
new build or establish stable recovery. The local relay's bounded run has also
ended; restart its existing configuration for the next LAN test.
