# Native group file download through real member APIs

The combined Flutter integration exposed a real integration gap: the downloader
still bypassed group peer transfers, despite its runtime callback supporting
groups. Earlier runtime/HTTP tests did not cover this combined branch. Removed
the obsolete guards and made final peer authority validation explicitly request
group scope and require a valid authoritative group ID. HTTP fallback refreshes
group download authorization just as it does for direct files.

Extended `member_relay_http_test.dart` to create a group through the real API and
send the real uploaded asset as a group message. Both direct and group downloads
must match all 4097 original bytes, register one native peer transfer and make
zero HTTP chunk requests. Removing the sender cache must produce the same bytes
through HTTP fallback without another successful peer transfer. This passed
against real compiled CCSOP services, isolated SQL/Redis, native device-key
registration and a local SuperVM WSS daemon. No mocked authority responses.
Existing text reconciliation/idempotence and device-revocation checks also passed.

Two earlier runs correctly failed the group native-transfer count at zero; the
final run passed after the production downloader correction. Log:
`build/group-native-http.log`. The fixture container was stopped, its synthetic
sessions revoked by host cleanup, local credential file removed, and owned SSH
and relay processes stopped. Synthetic history remains in the isolated test DB;
no real members, production containers or phones were changed.

Scope: loopback native relay reached an isolated server by SSH tunnel. The
fixture now removes both follow edges through real APIs after creating the group.
Both ordinary device directories and the existing private lane reject access,
while native group-file download and HTTP fallback still pass. Friendship is
then restored and a fresh private lane is revalidated before independently
checking device-key revocation. The updated combined test passed in eight seconds;
Dart analysis passed. These are synthetic members only. Local key storage is a test substitute,
and this does not prove mobile hardware keystore behavior, public NAT traversal,
or group RTC. Group transport remains default-off pending device acceptance.

## Local-network upgrade follow-up

The combined test also passed with `--dart-define=KINGCLUB_NOVORUDP_LAN=true`
(11 seconds). Existing private endpoints both report authenticated LAN readiness.
For the non-friend group, the test observes the runtime's group-lane event, waits
for authenticated LAN readiness, and repeats the file download before evicting
the sender cache. Both peer downloads match all bytes and make zero HTTP chunk
requests; cache-miss fallback then succeeds over HTTP. Dart analysis is clean.

This proves route establishment plus successful peer transfer while the LAN
route is ready on this host. It does not count individual UDP versus WSS frames,
force LAN loss mid-file, or demonstrate two physical phones / public NAT. The
shared local log was replaced by this latest successful invocation. Owned helper
processes were stopped and synthetic sessions revoked by fixture cleanup.

## Preview build option

`scripts/build-chat-preview.ps1 -EnableGroupFiles` now explicitly forwards the
runtime group-file flag. It requires `-EnablePeerFiles`, which in turn requires
the native library and a configured authenticated relay. The switch is opt-in;
normal preview builds remain unchanged. Only enable it against an environment
with group-file authority/directory/context interfaces deployed. PowerShell
syntax and the missing-peer-file dependency rejection were checked.
