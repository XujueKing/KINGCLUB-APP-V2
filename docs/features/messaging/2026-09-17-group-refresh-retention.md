# Group refresh continuity

Group details and announcements retain the current in-memory snapshot on an
explicit NETWORK_ERROR instead of emptying the page. Group setting, rename,
member management and announcement mutation guards require a fresh snapshot.
Failed detail refresh invalidates previously opened action confirmations.
Successful refresh restores normal operations. Permission/auth/invalid-data
failures continue to remove the snapshot; session changes keep existing clearing.
Refresh errors use the shared user-facing text instead of raw backend messages.

This is continuity within an already open page, not cold-start offline caching
of group membership or authorization. It does not authorize offline mutations.
10 group details/announcement/retention tests passed, and analysis of all four
changed Dart files passed. Device acceptance remains pending the combined build.
