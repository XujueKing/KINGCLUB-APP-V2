import 'novorudp_frame.dart';
import 'novorudp_secure_session.dart';

/// Authenticated peer frames, independent of direct or relay carriage.
abstract interface class NovoRudpFrameLink {
  NovoRudpSecureChannel get channel;
  Stream<NovoRudpFrame> get frames;
  Future<void> send(NovoRudpFrame frame);
  Future<void> close();
}

/// Optional route feedback; missing application receipts are not delivery proof.
abstract interface class NovoRudpRouteRecovery {
  void reportDeliveryStall();
}
