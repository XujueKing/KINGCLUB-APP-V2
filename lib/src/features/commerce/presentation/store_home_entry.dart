import 'package:flutter/material.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../../club/data/secure_together_play_repository.dart';
import '../../club/presentation/together_activity_page.dart';
import '../../club/presentation/together_booking_page.dart';
import '../../club/presentation/together_ticket_page.dart';
import 'store_home_page.dart';

/// Saved stores share the same store and activity flows as recommendation cards.
Future<void> openMemberStore(BuildContext context, String storeRef) {
  final repository = SecureTogetherPlayRepository.secure(kingclubApiBaseUrl);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => StoreHomePage(
        storeRef: storeRef,
        onActivity: (storeContext, ref) async {
          final party = await repository.detail(ref);
          if (!storeContext.mounted) return;
          await Navigator.of(storeContext).push<void>(
            MaterialPageRoute(
              builder: (_) => TogetherActivityPage(
                party: party,
                repository: repository,
                initialReadComplete: true,
                onViewed: () {},
                onJoin: (value) => Navigator.of(storeContext).push<void>(
                  MaterialPageRoute(
                    builder: (_) => TogetherBookingPage(
                      party: value,
                      repository: repository,
                    ),
                  ),
                ),
                onAdmission: (value) async {
                  final admission = await repository.admission(value.ref);
                  if (!storeContext.mounted) return;
                  await Navigator.of(storeContext).push<void>(
                    MaterialPageRoute(
                      builder: (_) => TogetherTicketPage(
                        party: admission,
                        removalRepository: repository,
                        reload: () => repository.admission(value.ref),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}
