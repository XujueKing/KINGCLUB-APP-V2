# 当前新服务建表脚本清单

2026-09-18 只读扫描 database/mysql8 的 126 个 SQL 文件，识别 86 个不同 CREATE TABLE 名称。此表是本地源码证据，不是现网 SHOW TABLES；ALTER 列出脚本候选，未模拟执行整套迁移。源码引用可能是字符串/注释，不能仅凭命中证明已上线。

| 表名 | 建表脚本 | 后续 ALTER 脚本 | src 引用文件（最多三处） |
|---|---|---|---|
| `authSession` | 006_user_foundation.sql | 008_auth_session_unification.sql, 016_bilingual_table_comments.sql, 019_kingclub_login_session_foundation.sql, 020_kingclub_auth_super_interfaces.sql | src/kingclub/messaging/call-service.ts<br>src/kingclub/messaging/chat-file-assets.ts<br>src/kingclub/messaging/chat-video-assets.ts 等 14 处 |
| `auth_session` | 001_core_schema.sql | 未检出 | 未检出直接引用 |
| `databaseCatalogCategory` | 007_database_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `databaseCatalogDocument` | 007_database_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `databaseCatalogTable` | 007_database_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `databaseChangeExecution` | 007_database_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `databaseChangeRequest` | 007_database_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `databaseDocumentCategory` | 007_database_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `databaseRoutineCatalog` | 011_database_routine_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `databaseRoutineCategory` | 011_database_routine_catalog_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `idSequence` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `identityProvisioningAttempt` | 018_kingclub_identity_projection.sql | 未检出 | 未检出直接引用 |
| `interface` | 001_core_schema.sql | 004_interface_enum_comments.sql, 005_interface_bilingual_comments.sql, 016_bilingual_table_comments.sql | src/app.ts<br>src/adapters/adapter-registry.ts<br>src/business-lines/business-line-registry.ts 等 76 处 |
| `interface_type` | 001_core_schema.sql | 005_interface_bilingual_comments.sql, 016_bilingual_table_comments.sql | 未检出直接引用 |
| `interface_type_relation` | 001_core_schema.sql | 005_interface_bilingual_comments.sql, 016_bilingual_table_comments.sql | 未检出直接引用 |
| `kingclubAdmissionDecisionLog` | 030_kingclub_admission_decisions.sql | 未检出 | src/kingclub/admission/admission-service.ts |
| `kingclubAgreementDocument` | 019_kingclub_login_session_foundation.sql | 022_kingclub_current_agreement_catalog.sql | src/security/login/kingclub-auth-repository.ts |
| `kingclubAppearanceApplication` | 028_kingclub_appearance.sql | 029_kingclub_preferences_before_admission.sql | src/kingclub/admission/admission-service.ts<br>src/kingclub/appearance/appearance-service.ts<br>src/kingclub/messaging/messaging-service.ts 等 5 处 |
| `kingclubAppearanceAttempt` | 028_kingclub_appearance.sql | 未检出 | src/kingclub/appearance/appearance-service.ts<br>src/kingclub/messaging/messaging-service.ts<br>src/kingclub/profile/profile-service.ts |
| `kingclubAppearancePhoto` | 028_kingclub_appearance.sql | 未检出 | src/kingclub/appearance/appearance-service.ts<br>src/kingclub/messaging/messaging-service.ts<br>src/kingclub/profile/profile-service.ts 等 4 处 |
| `kingclubChatCall` | 066_kingclub_call_storage.sql | 068_kingclub_call_signals.sql, 072_kingclub_call_liveness.sql, 112_kingclub_call_history.sql | src/kingclub/messaging/call-history.ts<br>src/kingclub/messaging/call-service.ts<br>src/kingclub/messaging/recall-message.ts |
| `kingclubChatCallOccupancy` | 066_kingclub_call_storage.sql | 106_kingclub_group_call_storage.sql | src/kingclub/messaging/call-service.ts<br>src/kingclub/messaging/group-call-service.ts |
| `kingclubChatCallRequest` | 066_kingclub_call_storage.sql | 未检出 | src/kingclub/messaging/call-service.ts |
| `kingclubChatCallSignal` | 068_kingclub_call_signals.sql | 未检出 | src/kingclub/messaging/call-service.ts |
| `kingclubChatFileAsset` | 074_kingclub_chat_file_assets.sql | 未检出 | src/kingclub/messaging/chat-file-access.ts<br>src/kingclub/messaging/chat-file-assets.ts |
| `kingclubChatFileChunk` | 074_kingclub_chat_file_assets.sql | 未检出 | src/kingclub/messaging/chat-file-access.ts<br>src/kingclub/messaging/chat-file-assets.ts<br>src/kingclub/messaging/direct-file-media.ts 等 5 处 |
| `kingclubChatGroup` | 042_kingclub_chat_groups.sql | 043_kingclub_group_messages.sql, 045_kingclub_group_name.sql, 047_kingclub_group_creator_identity.sql, 081_kingclub_group_announcement.sql, 089_kingclub_message_recall_state.sql | src/kingclub/messaging/chat-groups.ts<br>src/kingclub/messaging/group-call-history.ts<br>src/kingclub/messaging/group-call-service.ts 等 15 处 |
| `kingclubChatGroupCall` | 106_kingclub_group_call_storage.sql | 123_kingclub_group_call_history.sql | src/kingclub/messaging/group-call-history.ts<br>src/kingclub/messaging/group-call-service.ts<br>src/kingclub/messaging/group-messages.ts |
| `kingclubChatGroupCallParticipant` | 106_kingclub_group_call_storage.sql | 未检出 | src/kingclub/messaging/group-call-service.ts<br>src/kingclub/messaging/group-messages.ts |
| `kingclubChatGroupCallRequest` | 107_kingclub_group_call_requests.sql | 未检出 | src/kingclub/messaging/group-call-requests.ts |
| `kingclubChatGroupInvitation` | 050_kingclub_group_invitations.sql | 未检出 | src/kingclub/messaging/group-invitations.ts<br>src/kingclub/messaging/group-join-requests.ts<br>src/kingclub/messaging/group-messages.ts |
| `kingclubChatGroupJoinRequest` | 085_kingclub_group_join_requests.sql | 086_kingclub_group_join_review_list.sql | src/kingclub/messaging/group-join-requests.ts |
| `kingclubChatGroupMember` | 042_kingclub_chat_groups.sql | 043_kingclub_group_messages.sql, 044_kingclub_group_conversation_settings.sql, 046_kingclub_group_departure.sql, 122_kingclub_group_member_silence.sql | src/kingclub/messaging/chat-groups.ts<br>src/kingclub/messaging/group-admission.ts<br>src/kingclub/messaging/group-call-history.ts 等 14 处 |
| `kingclubChatGroupMessage` | 043_kingclub_group_messages.sql | 057_kingclub_group_image_messages.sql, 063_kingclub_group_voice_messages.sql, 065_kingclub_chat_location_messages.sql, 079_kingclub_group_file_messages.sql, 089_kingclub_message_recall_state.sql, 093_kingclub_message_reply.sql, 095_kingclub_video_messages.sql | src/kingclub/messaging/group-call-history.ts<br>src/kingclub/messaging/group-file-media.ts<br>src/kingclub/messaging/group-image-media.ts 等 11 处 |
| `kingclubChatGroupTransfer` | 048_kingclub_group_transfer.sql | 未检出 | src/kingclub/messaging/group-messages.ts |
| `kingclubChatImageAsset` | 053_kingclub_chat_image_assets.sql | 未检出 | src/kingclub/messaging/chat-image-access.ts<br>src/kingclub/messaging/chat-image-assets.ts<br>src/kingclub/messaging/direct-image-media.ts 等 5 处 |
| `kingclubChatMemberState` | 036_kingclub_direct_messaging.sql | 未检出 | src/kingclub/messaging/direct-file-media.ts<br>src/kingclub/messaging/direct-image-media.ts<br>src/kingclub/messaging/direct-video-media.ts 等 8 处 |
| `kingclubChatMessage` | 036_kingclub_direct_messaging.sql | 055_kingclub_direct_image_messages.sql, 061_kingclub_direct_voice_messages.sql, 065_kingclub_chat_location_messages.sql, 077_kingclub_direct_file_messages.sql, 089_kingclub_message_recall_state.sql, 093_kingclub_message_reply.sql, 095_kingclub_video_messages.sql | src/kingclub/messaging/call-history.ts<br>src/kingclub/messaging/direct-file-media.ts<br>src/kingclub/messaging/direct-file-messages.ts 等 16 处 |
| `kingclubChatMessageHidden` | 091_kingclub_message_hidden.sql | 未检出 | src/kingclub/messaging/direct-file-media.ts<br>src/kingclub/messaging/direct-file-messages.ts<br>src/kingclub/messaging/direct-image-media.ts 等 19 处 |
| `kingclubChatOutbox` | 036_kingclub_direct_messaging.sql | 041_kingclub_group_notifications.sql, 042_kingclub_chat_groups.sql, 043_kingclub_group_messages.sql, 105_kingclub_sticker_notification_scope.sql, 108_kingclub_group_call_notification_scope.sql, 120_kingclub_sticker_scoped_release.sql | src/kingclub/messaging/chat-groups.ts<br>src/kingclub/messaging/chat-outbox-worker.ts<br>src/kingclub/messaging/contact-groups.ts 等 11 处 |
| `kingclubChatVideoAsset` | 094_kingclub_chat_video_assets.sql | 098_kingclub_video_hevc_variant.sql | src/kingclub/messaging/chat-video-access.ts<br>src/kingclub/messaging/chat-video-assets.ts<br>src/kingclub/messaging/direct-video-media.ts 等 4 处 |
| `kingclubChatVoiceAsset` | 059_kingclub_chat_voice_assets.sql | 未检出 | src/kingclub/messaging/chat-voice-access.ts<br>src/kingclub/messaging/chat-voice-assets.ts<br>src/kingclub/messaging/direct-voice-media.ts 等 5 处 |
| `kingclubConsentRecord` | 019_kingclub_login_session_foundation.sql | 027_kingclub_independent_mobile_members.sql | 未检出直接引用 |
| `kingclubContactGroups` | 040_kingclub_contact_groups.sql | 未检出 | src/kingclub/messaging/contact-groups.ts |
| `kingclubDeviceRegistration` | 019_kingclub_login_session_foundation.sql | 027_kingclub_independent_mobile_members.sql | 未检出直接引用 |
| `kingclubDirectPair` | 036_kingclub_direct_messaging.sql | 089_kingclub_message_recall_state.sql | src/kingclub/messaging/call-history.ts<br>src/kingclub/messaging/call-service.ts<br>src/kingclub/messaging/chat-groups.ts 等 20 处 |
| `kingclubFriendRequest` | 036_kingclub_direct_messaging.sql | 未检出 | src/kingclub/messaging/messaging-service.ts |
| `kingclubIdentityApplication` | 026_kingclub_photo_identity.sql | 028_kingclub_appearance.sql, 030_kingclub_admission_decisions.sql | src/kingclub/admission/admission-service.ts<br>src/kingclub/appearance/appearance-service.ts<br>src/kingclub/appearance/selfie-assessment.ts 等 5 处 |
| `kingclubIdentityAttempt` | 026_kingclub_photo_identity.sql | 未检出 | src/kingclub/admission/admission-service.ts<br>src/kingclub/identity/identity-service.ts<br>src/kingclub/profile/profile-service.ts |
| `kingclubIdentityPhoto` | 026_kingclub_photo_identity.sql | 未检出 | src/kingclub/appearance/selfie-assessment.ts<br>src/kingclub/identity/identity-service.ts |
| `kingclubIdentityRestriction` | 030_kingclub_admission_decisions.sql | 未检出 | src/kingclub/admission/admission-service.ts |
| `kingclubLoginIdentityProjection` | 019_kingclub_login_session_foundation.sql | 027_kingclub_independent_mobile_members.sql | src/security/login/kingclub-auth-repository.ts |
| `kingclubMember` | 018_kingclub_identity_projection.sql | 024_kingclub_registration_state.sql, 027_kingclub_independent_mobile_members.sql, 029_kingclub_preferences_before_admission.sql, 030_kingclub_admission_decisions.sql | src/kingclub/admission/admission-service.ts<br>src/kingclub/appearance/appearance-service.ts<br>src/kingclub/identity/identity-service.ts 等 26 处 |
| `kingclubNetworkDeviceKey` | 099_kingclub_network_device_keys.sql | 未检出 | src/kingclub/messaging/network-device-keys.ts |
| `kingclubNetworkKeyChallenge` | 099_kingclub_network_device_keys.sql | 未检出 | src/kingclub/messaging/network-device-keys.ts |
| `kingclubProfile` | 033_kingclub_profile.sql | 未检出 | src/kingclub/messaging/chat-groups.ts<br>src/kingclub/messaging/messaging-service.ts<br>src/kingclub/profile/profile-service.ts 等 4 处 |
| `kingclubProfileAssets` | 033_kingclub_profile.sql | 未检出 | src/kingclub/messaging/messaging-service.ts<br>src/kingclub/profile/profile-service.ts |
| `kingclubProfileContent` | 033_kingclub_profile.sql | 未检出 | src/kingclub/messaging/messaging-service.ts<br>src/kingclub/profile/profile-service.ts<br>src/kingclub/profile/visitor-media.ts |
| `kingclubRegistrationReward` | 034_kingclub_registration_reward.sql | 未检出 | src/kingclub/profile/profile-service.ts |
| `kingclubStickerLibrary` | 103_kingclub_sticker_library.sql, 120_kingclub_sticker_scoped_release.sql | 未检出 | src/kingclub/messaging/sticker-library.ts |
| `kingclubStorageEvent` | 031_kingclub_private_storage.sql | 未检出 | src/kingclub/storage/storage-service.ts |
| `kingclubStorageHolding` | 031_kingclub_private_storage.sql | 032_kingclub_storage_member_delete.sql | src/kingclub/storage/storage-service.ts |
| `kingclubStoragePickup` | 031_kingclub_private_storage.sql | 未检出 | src/kingclub/storage/storage-service.ts |
| `kingclubStorageProduct` | 031_kingclub_private_storage.sql | 未检出 | src/kingclub/storage/storage-service.ts |
| `platform_audit_log` | 001_core_schema.sql | 016_bilingual_table_comments.sql | src/platform/audit/audit-repository.ts |
| `platform_external_callback_log` | 001_core_schema.sql | 016_bilingual_table_comments.sql | src/platform/callback/external-callback-repository.ts |
| `platform_file_object` | 001_core_schema.sql | 016_bilingual_table_comments.sql, 075_kingclub_empty_file_chunk.sql | src/kingclub/messaging/chat-file-access.ts<br>src/kingclub/messaging/chat-file-assets.ts<br>src/kingclub/messaging/chat-image-access.ts 等 19 处 |
| `platform_notification_log` | 001_core_schema.sql | 016_bilingual_table_comments.sql | src/platform/notification/notification-repository.ts |
| `smsProvider` | 019_kingclub_login_session_foundation.sql | 未检出 | src/adapters/sms/router/sms-repository.ts |
| `smsSceneRoute` | 019_kingclub_login_session_foundation.sql | 未检出 | src/adapters/sms/router/sms-repository.ts |
| `smsSendAudit` | 019_kingclub_login_session_foundation.sql | 未检出 | src/adapters/sms/router/sms-repository.ts |
| `smsVerificationChallenge` | 019_kingclub_login_session_foundation.sql | 未检出 | src/adapters/sms/router/sms-repository.ts |
| `userAccount` | 006_user_foundation.sql | 016_bilingual_table_comments.sql, 018_kingclub_identity_projection.sql, 027_kingclub_independent_mobile_members.sql | src/super-interface/routes.ts<br>src/super-interface/super-interface-service.ts<br>src/super-interface/types.ts 等 90 处 |
| `userAccountMerge` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userApiKey` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | src/kingclub/messaging/group-call-service.ts<br>src/kingclub/messaging/network-device-keys.ts<br>src/kingclub/messaging/sticker-library.ts 等 5 处 |
| `userBiometric` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userBiometricEvidence` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userBiometricVerification` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userKyc` | 006_user_foundation.sql | 016_bilingual_table_comments.sql, 017_user_identity_provider_expansion.sql | 未检出直接引用 |
| `userKycDocument` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userLoginIdentity` | 006_user_foundation.sql | 016_bilingual_table_comments.sql, 017_user_identity_provider_expansion.sql | 未检出直接引用 |
| `userPasswordCredential` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userProfile` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userProfileAttribute` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userRelation` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
| `userSearchIndex` | 006_user_foundation.sql | 016_bilingual_table_comments.sql | 未检出直接引用 |
