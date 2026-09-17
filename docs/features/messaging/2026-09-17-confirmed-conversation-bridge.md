# Confirmed conversation continuity

Direct/group controllers now request a display-head write when committing a
confirmed message that still belongs to their pending queue. History and the
minimal encrypted conversation summary commit in one SQLite transaction before
outbox removal. History epoch, visibility floor and tombstone rules still apply;
ordinary history pagination does not create these local confirmed rows.

Local confirmed summaries survive missing/older server list heads. An equal or
newer server head takes over. Pending-queue refresh reads committed local summaries
before removing the pending-only display. Cache writes also preserve outstanding
local confirmed summaries. Existing clear/deletion cache cleanup applies, and
late pending reads are invalidated when a history removal event arrives.

Server pagination uses returned server row counts rather than the merged UI row
count. Summaries carry display data only and do not grant permissions. Missing
name metadata still uses a generic friend/group label. Other-device hide state
requires the existing server/history reconciliation; this is not complete
multi-device acceptance.

97 history/cache/controller/group/recovery tests passed, including new direct and
group database reopen/server takeover/clear-stale-epoch cases. Six-file analysis
passed. No phone installation; runtime transition and cold restart remain pending.

After pagination changes, 12 cache/list/relay/draft widget checks also passed (overlapping cache coverage, not an additional unique total).
