import '../../../core/session/secure_session_store.dart';
import '../../../core/networking/kingclub_realtime.dart';
import 'call_media_session.dart';
import 'call_repository.dart';
import 'call_relay_configuration.dart';
import 'call_state_controller.dart';
import 'native_call_media.dart';

CallStateController createNativeCallController({
  required CallRepository repository,
  required CallSnapshot initial,
  required CallRelayConfiguration relay,
  bool outgoingAttempt = false,
}) {
  relay.requireUsable(initial.id);
  return CallStateController(
    repository: repository,
    initial: initial,
    outgoingAttempt: outgoingAttempt,
    sessionChanges: SecureSessionStore.changes.stream,
    events: KingclubRealtime.shared.events,
    sessionFactory: (call, onConnection) {
      relay.requireUsable(call.id);
      return CallMediaSession(
        repository: repository,
        call: call,
        initialRelayExpiresAtMs: relay.expiresAtMs,
        mediaFactory: (onCandidate) => NativeCallMedia(
          video: call.media == CallMedia.video,
          iceServers: relay.iceServers,
          onCandidate: onCandidate,
          onConnection: onConnection,
        ),
      );
    },
  );
}
