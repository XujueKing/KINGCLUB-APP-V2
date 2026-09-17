# Names for local conversation rows

Pending-only and generic locally confirmed rows resolve names from the encrypted
contact snapshot, preferring a saved remark over nickname. Known cached group
names are also reusable. A current server-provided name remains authoritative.
New text drafts capture the currently displayed name (including remark/group name)
instead of the original route argument; old drafts may use the local lookup.
Name lookup is optional: a damaged contact snapshot does not hide queued messages.
Account invalidation clears the name map together with local rows.

14 cache/list/draft tests passed, including an offline pending conversation using
a remark loaded from a real encrypted SQLite contact snapshot. Analysis passed.
No phone installation; actual device acceptance remains pending. A first-ever
group with no cached name may still use the generic group label.
