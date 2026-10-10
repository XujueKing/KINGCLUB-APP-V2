import { common, Want } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';
import { normalizeEnvelope } from './NotificationEnvelope';

// App-private routing metadata only; never an authentication credential.
export class NotificationLifecycle {
  static foreground: boolean = false;
  static epoch: number = 0;
  static changed: (() => void) | null = null;
  private static queue: Promise<void> = Promise.resolve();

  static setForeground(value: boolean): void { NotificationLifecycle.foreground = value; NotificationLifecycle.epoch++; }
  static accept(context: common.UIAbilityContext, want: Want): void {
    const raw = want.parameters?.['kingclub_push'] as string;
    const clean = normalizeEnvelope(raw);
    if (!clean) return;
    NotificationLifecycle.queue = NotificationLifecycle.queue.then(async () => {
      const store = await preferences.getPreferences(context, { name: 'kingclub_notification_opens_v1' });
      const pending = NotificationLifecycle.decode(await store.get('pending', '[]') as string);
      if (!pending.includes(clean)) pending.push(clean);
      await store.put('pending', JSON.stringify(pending.slice(-8)));
      await store.flush();
      NotificationLifecycle.changed?.();
    }).catch(() => { /* Do not consume the system Want on storage failure. */ });
  }
  private static decode(raw: string): string[] {
    if (raw.length > 20000) return [];
    try {
      const list = JSON.parse(raw) as string[];
      if (!Array.isArray(list)) return [];
      const valid: string[] = [];
      for (const item of list.slice(-8)) {
        const clean = normalizeEnvelope(item);
        if (clean && !valid.includes(clean)) valid.push(clean);
      }
      return valid;
    } catch (error) { return []; }
  }
  static async pending(context: common.UIAbilityContext, ack: string | null = null): Promise<string | null> {
    let value: string | null = null;
    const task = NotificationLifecycle.queue.then(async () => {
      const store = await preferences.getPreferences(context, { name: 'kingclub_notification_opens_v1' });
      const list = NotificationLifecycle.decode(await store.get('pending', '[]') as string);
      if (ack !== null && list.length > 0 && list[0] === ack) list.shift();
      await store.put('pending', JSON.stringify(list));
      await store.flush();
      value = list.length > 0 ? list[0] : null;
    });
    NotificationLifecycle.queue = task.catch(() => {});
    await task;
    return value;
  }
}
