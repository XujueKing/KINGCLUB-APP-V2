import '../../auth/domain/auth_repository.dart';

/// Safe UI copy for a failed refresh, without exposing server/internal errors.
String chatSyncFailureMessage(Object error) {
  if (error is AuthFailure) {
    if ({
      'SESSION_EXPIRED',
      'AUTH_SESSION_REVOKED',
      'AUTH_REFRESH_TOKEN_INVALID',
      'AUTH_REFRESH_REUSE_DETECTED',
    }.contains(error.code)) {
      return '登录已失效，请重新登录';
    }
    if (error.code == 'SESSION_CHANGED') return '登录状态已变化，请重新进入';
    if (error.code == 'NETWORK_ERROR') return '网络不可用，请稍后重试';
    if (error.code.contains('DENIED') || error.code.contains('FORBIDDEN')) {
      return '当前无法访问，请检查账号权限';
    }
  }
  return '暂时无法更新，请稍后重试';
}
