import { AbilityAware, AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import notificationManager from '@ohos.notificationManager';

// Permission bridge only: deliberately does not claim a vendor push token.
export default class KingclubNotificationPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private epoch: number = 0;
  private busy: boolean = false;
  getUniqueClassName(): string { return 'KingclubNotificationPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/push-registration');
    this.channel.setMethodCallHandler(this);
  }
  onAttachedToAbility(binding: AbilityPluginBinding): void { this.context = binding.getAbility().context; }
  onDetachedFromAbility(): void { this.epoch++; this.context = null; }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.epoch++; this.context = null;
    this.channel?.setMethodCallHandler(null); this.channel = null;
  }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
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
