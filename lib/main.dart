import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/features/auth/data/auth_repository_provider.dart';
import 'src/features/messaging/data/background_connection.dart';

@pragma('vm:entry-point')
Future<void> backgroundMessageReceiver() => runBackgroundMessageReceiver();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final container = ProviderContainer();
  final repository = container.read(authRepositoryProvider);
  if (repository is RealAuthRepository) {
    try {
      await repository.restoreCachedForStartup();
    } catch (_) {
      // Locked/unavailable storage goes through the normal bootstrap retry.
    }
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const KingClubApp()),
  );
}
