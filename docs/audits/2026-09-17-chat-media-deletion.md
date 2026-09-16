# Chat media deletion — partial implementation

Explicit history clear now removes image/video message-local copies (including
thumbnail/poster and own sent copies) before deleting their encrypted message
metadata. Records are read in batches of 50 inside the clear transaction. A
filesystem failure propagates and preserves the database metadata for retry.
Other accounts and avatar keys are untouched.

Validation: 12 history/cleanup tests passed; analyzer passed for three files.
The cleanup test writes real files and reopens the store to check removal and
account isolation. No phone build or full deletion acceptance yet.

Remaining: voice and file stores; transport-cache aliases; media not represented
in persisted history; durable cleanup retry; prevention of late media writes;
server revision/individual deletion paths and all UI entry points. This change
does not satisfy complete attachment deletion until these are implemented and
verified. User-exported gallery/download originals must remain separate.
