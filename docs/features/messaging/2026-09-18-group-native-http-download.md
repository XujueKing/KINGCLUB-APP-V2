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
fixture members are friends and group members; non-friend group access was
validated separately at the service layer. Local key storage is a test substitute,
and this does not prove mobile hardware keystore behavior, public NAT traversal,
or group RTC. Group transport remains default-off pending device acceptance.
