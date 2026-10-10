import { AbilityAware, AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import notificationManager from '@ohos.notificationManager';

import { LocalNotifications } from './LocalNotifications';
import { NotificationLifecycle } from './NotificationLifecycle';
// Native local notifications do not register a vendor push token.
export default class KingclubNotificationPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private local: LocalNotifications = new LocalNotifications();
  private localChannel: MethodChannel | null = null;
  private openChannel: MethodChannel | null = null;
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private epoch: number = 0;
  private busy: boolean = false;
  getUniqueClassName(): string { return 'KingclubNotificationPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/push-registration');
    this.channel.setMethodCallHandler(this);
    this.localChannel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/local-notifications');
    this.localChannel.setMethodCallHandler(this.local);
    this.openChannel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/push-open');
    this.openChannel.setMethodCallHandler(this);
    NotificationLifecycle.changed = () => { this.openChannel?.invokeMethod('changed', null); };
  }
  onAttachedToAbility(binding: AbilityPluginBinding): void { this.context = binding.getAbility().context; this.local.context = this.context; }
  onDetachedFromAbility(): void { this.epoch++; this.context = null; this.local.detach(); }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.epoch++; this.context = null; this.local.detach();
    NotificationLifecycle.changed = null;
    this.localChannel?.setMethodCallHandler(null); this.localChannel = null;
    this.openChannel?.setMethodCallHandler(null); this.openChannel = null;
    this.channel?.setMethodCallHandler(null); this.channel = null;
  }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'takePending' || call.method === 'ackPending') {
      const context = this.context;
      if (!context) { result.error('NO_ACTIVITY', 'Notification opening requires an active page', null); return; }
      try {
        const raw = call.method === 'ackPending' ? call.args as string : null;
        const pending = await NotificationLifecycle.pending(context, raw);
        result.success(call.method === 'takePending' ? pending : null);
      } catch (error) { result.error('PENDING_UNAVAILABLE', 'Unable to read notification opening', null); }
      return;
    }
    if (call.method === 'notificationStatus') {
      try { result.success(await notificationManager.isNotificationEnabled()); }
      catch (error) { result.error('NOTIFICATION_STATUS_UNAVAILABLE', 'Unable to read notification permission', null); }
      return;
    }
    if (call.method !== 'requestNotificationPermission' && call.method !== 'openNotificationSettings') {
      result.notImplemented(); return;
    }
    const context = this.context;
    if (!context) { result.error('NO_ACTIVITY', 'Notification settings require an active page', null); return; }
    if (this.busy) { result.error('BUSY', 'Notification settings are already opening', null); return; }
    this.busy = true;
    const epoch = this.epoch;
    try {
      if (call.method === 'requestNotificationPermission') {
        await notificationManager.requestEnableNotification(context);
      } else {
        await notificationManager.openNotificationSettings(context);
      }
      if (epoch !== this.epoch) { result.error('CANCELLED', 'Page detached', null); return; }
      // A completed request is not proof of permission: Dart must read status.
      result.success(null);
    } catch (error) { result.error('NOTIFICATION_SETTINGS_UNAVAILABLE', 'Notification permission request did not complete', null); }
    finally { this.busy = false; }
  }
}
