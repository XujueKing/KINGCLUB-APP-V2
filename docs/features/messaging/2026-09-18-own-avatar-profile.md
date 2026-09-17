# Own avatar profile from conversation

A actual-device follow-up found the own-avatar route calling visitor profile 612,
which creates/validates a direct pair and rejects self. Keep the approved profile
layout but load the authenticated own snapshot through 501. Content stays on 614,
whose access gate explicitly allows viewer == owner and retains media MIME types.
Own signed attachment images are accepted only on the own-account path. Other
members continue to use visitor media authorization. Disable self remark controls
as well as already-hidden relationship actions. No relationship mutation occurs.

Validate own vs peer API selection, real content category requests, self action
absence, delayed session invalidation and existing visitor privacy behavior.

Five profile-content/avatar-navigation tests passed; three Dart files analyzed without issues. Device follow-up follows the corrected build.
