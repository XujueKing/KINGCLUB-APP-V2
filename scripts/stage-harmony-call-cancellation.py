from pathlib import Path
import sys
def replace_once(source, old, new):
    if source.count(old) != 1: raise SystemExit('Unexpected staging source: '+old[:80])
    return source.replace(old,new,1)
repo=Path(__file__).resolve().parent.parent
root=Path(sys.argv[1]).resolve()
if root==repo or repo in root.parents: raise SystemExit('Use isolated Harmony application')
p=root/'native_plugins/kingclub_notification_ohos/ohos/src/main/ets/KingclubNotificationPlugin.ets'
s=p.read_text(encoding='utf-8')
if 'this.callLease.lost' in s: raise SystemExit('Already staged')
s=replace_once(s,'    this.callChannel.setMethodCallHandler(this.callLease);', "    this.callChannel.setMethodCallHandler(this.callLease);\n    this.callLease.lost = (id: string) => { this.callChannel?.invokeMethod('lost', id); };")
s=replace_once(s,'    this.callChannel?.setMethodCallHandler(null);', '    this.callLease.lost = null;\n    this.callChannel?.setMethodCallHandler(null);')
p.write_text(s,encoding='utf-8')
p=root/'lib/src/features/messaging/data/call_foreground_lease.dart'
s=p.read_text(encoding='utf-8')
s=replace_once(s,"  static const _channel =", '''  void Function()? onLost;
  static final Map<String, CallForegroundLease> _leases = {};
  static bool _listening = false;
  void _listen() {
    if (Platform.operatingSystem != 'ohos') return;
    if (!_listening) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'lost' || call.arguments is! String) return;
        final lease = _leases.remove(call.arguments);
        if (lease == null || lease._closed) return;
        lease._started = false;
        lease._lost = true;
        lease.onLost?.call();
      });
      _listening = true;
    }
    _leases[_id] = this;
  }
  static const _channel =''')
s=replace_once(s,'  bool _started = false;', '  bool _started = false;\n  bool _lost = false;')
s=replace_once(s,"      if (_closed) throw StateError('Call capture closed');", "      if (_closed || _lost) throw StateError('Call capture closed');")
s=replace_once(s,'    _requested = true;', '    _requested = true;\n    _listen();')
s=replace_once(s,'    } catch (_) {', '    } catch (_) {\n      _leases.remove(_id);')
s=replace_once(s,'    _closed = true;', '    _closed = true;\n    _leases.remove(_id);')
p.write_text(s,encoding='utf-8')
for name in ['native_call_media.dart','native_group_call_media.dart']:
    p=root/'lib/src/features/messaging/data'/name
    s=p.read_text(encoding='utf-8')
    callback="_fail(StateError('系统已停止通话后台服务'));" if name.startswith('native_group') else "if (!_closed) { onConnection?.call(RTCPeerConnectionState.RTCPeerConnectionStateFailed); unawaited(close()); }"
    s=replace_once(s,'      await _foregroundLease.start(', '      _foregroundLease.onLost = () { '+callback+' };\n      await _foregroundLease.start(')
    p.write_text(s,encoding='utf-8')
(root/'native_plugins/kingclub_notification_ohos/ohos/src/main/ets/CallBackgroundLease.ets').write_text((repo/'harmony/verification/CallBackgroundLease.ets.template').read_text(encoding='utf-8'),encoding='utf-8')
print('System task cancellation wired to existing call failure paths.')
