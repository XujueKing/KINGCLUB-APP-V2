import { MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import notification from '@ohos.notification';
import notificationManager from '@ohos.notificationManager';
import wantAgent from '@ohos.app.ability.wantAgent';
import { normalizeEnvelope, NotificationEnvelope } from './NotificationEnvelope';
import { NotificationLifecycle } from './NotificationLifecycle';

export class LocalNotifications implements MethodCallHandler {
  context: common.UIAbilityContext | null = null;
  private session: string | null = null;
  private epoch: number = 0;
  private queue: Promise<void> = Promise.resolve();
  detach(): void { this.epoch++; this.session = null; this.context = null; }
  private async clear(): Promise<void> {
    const active = await notificationManager.getActiveNotifications();
    for (const item of active) {
      if (item.id === 4280 && item.label?.startsWith('kingclub-local:')) {
        await notificationManager.cancel(4280, item.label);
      }
    }
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'bind' || call.method === 'clear') this.epoch++;
    this.queue = this.queue.then(async () => {
      try { await this.handle(call, result); }
      catch (error) { result.error('LOCAL_NOTIFICATION_FAILED', 'Local notification unavailable', null); }
    });
  }
  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'bind') {
      const next = call.argument('session') as string | null;
      if (next !== this.session || next === null) {
        const resetBadge = this.session !== null || next === null;
        this.session = null;
        await this.clear();
        if (resetBadge) await notificationManager.setBadgeNumber(0);
        this.session = typeof next === 'string' && next.length > 0 && next.length <= 256 ? next : null;
      }
      result.success(null); return;
    }
    if (call.method === 'clear') { await this.clear(); result.success(null); return; }
    // Calls remain unsupported until the native calling stack is ready.
    if (call.method === 'clearCalls' || call.method === 'reconcileCalls') { result.success(null); return; }
    if (call.method === 'badge') {
      const count = call.argument('count') as number;
      if (!Number.isInteger(count)) { result.success(false); return; }
      await notificationManager.setBadgeNumber(Math.max(0, Math.min(count, 9999)));
      result.success(true); return;
    }
    if (call.method !== 'show') { result.notImplemented(); return; }
    const context = this.context;
    const raw = normalizeEnvelope(call.argument('destination') as string);
    if (!context || !raw || NotificationLifecycle.foreground || !this.session || this.session !== call.argument('session')) {
      result.success(false); return;
    }
    const value = JSON.parse(raw) as NotificationEnvelope;
    if (value.kind !== 'message') { result.success(false); return; }
    const revision = this.epoch;
    const lifecycle = NotificationLifecycle.epoch;
    if (!await notificationManager.isNotificationEnabled()) { result.success(false); return; }
    await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
    const slot = await notificationManager.getSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
    if (slot.enabled === false) { result.success(false); return; }
    const label = `kingclub-local:${value.scope}:${value.target}`;
    const agent = await wantAgent.getWantAgent({
      wants: [{ bundleName: context.abilityInfo.bundleName, abilityName: context.abilityInfo.name,
        action: `kingclub.notification.${value.eventId}`, parameters: { kingclub_push: raw } }],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 4280,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
    if (revision !== this.epoch || lifecycle !== NotificationLifecycle.epoch || value.expiresAt <= Date.now()) {
      result.success(false); return;
    }
    await notificationManager.publish({ id: 4280, label: label,
      slotType: notification.SlotType.SOCIAL_COMMUNICATION,
      content: { notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: 'KINGCLUB', text: '你收到了一条新消息' } },
      wantAgent: agent, tapDismissed: true, badgeNumber: 0,
      autoDeletedTime: value.expiresAt
    });
    if (revision !== this.epoch || lifecycle !== NotificationLifecycle.epoch) {
      await notificationManager.cancel(4280, label);
      result.success(false); return;
    }
    result.success(true);
  }
}
