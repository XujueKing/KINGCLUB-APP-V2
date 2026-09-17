# Native binding recovery while the app stays open

Observed source gap: MessagingRepository.open starts native binding once, but
an initial offline failure leaves no scheduled retry. The foreground outbox
worker already runs every 15 seconds and receives reconnect notifications.
Have each active recovery notification kick native binding for persisted real
repositories. Runtime start retains its existing single-flight, account-generation
and five-minute failure cooldown. Test-only repositories do not start native FFI.

Do not await native initialization in message recovery. Native setup failure must
not block service messages or read receipts. Closed/background workers stop
kicking initialization; successful binding starts remain no-ops. This supplies
retry wiring, not decentralized identity or public-network acceptance.

Validation: 10 outbox recovery tests passed, including an empty-queue timer kick,
service sending despite native-start failure, another notification retry, closed
worker silence, direct/group recovery and revoked group denial. Both modified
Dart files passed analysis. Callback fixtures verify scheduling/isolation; they
do not replace actual Android binding/network-recovery acceptance. Not installed.
