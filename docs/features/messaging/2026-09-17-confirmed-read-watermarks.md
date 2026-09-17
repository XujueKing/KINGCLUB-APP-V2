# Confirmed local read positions

Read receipt delivery no longer removes the only local read position. The secure
account-scoped read store persists a confirmed watermark before removing an
acknowledged retry intent. Display projection merges confirmed and pending values
using the maximum; background retry still reads pending intents only.

This prevents an old cached conversation badge from reappearing after a successful
read acknowledgement and offline restart. Newer server heads retain their unread
count, and nearby relay unread counts remain independent. Direct/group/account
namespaces remain separate. The confirmed value is the locally viewed sequence,
not an arbitrarily larger server acknowledgement.

This does not calculate partial unread counts or change server read authority.
No phone install was performed; offline phone acceptance is pending.

Validation: 38 tests passed across read outbox/projection, direct/group acknowledgements, retry and relay reconciliation/widget coverage. Dart analysis passed for implementation and new watermark tests.
