# Voice inbox history pagination

Removed dependence on migration 121's messageType history filter from automatic
voice retention. First processing walks all available history pages backward;
subsequent changes in the same inbox instance page forward from the completed
sequence. Each page is processed serially and only received voice is retained.
Nonadvancing pagination fails retryably. No read receipts are issued.

Nine inbox/prefetch tests passed, including an older voice hidden behind a full
text-only page and a later incremental query. This fixes the preview compile
dependency as well as avoiding an undeployed request-contract field. The
existing first-50-conversation/unread eligibility remains unchanged. Phone
automatic retention acceptance remains pending.
