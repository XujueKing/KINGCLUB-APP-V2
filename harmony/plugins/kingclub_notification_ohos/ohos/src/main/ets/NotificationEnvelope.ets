export interface NotificationEnvelope {
  version: number;
  eventId: string;
  recipient: string;
  target: string;
  scope: string;
  kind: string;
  expiresAt: number;
}

export function normalizeEnvelope(raw: string): string | null {
  if (typeof raw !== 'string' || raw.length > 2048) return null;
  try {
    const data = JSON.parse(raw) as NotificationEnvelope;
    const account = /^[A-Za-z0-9_-]{1,64}$/;
    const uuid = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
    if (!data || data.version !== 1 || (data.kind !== 'message' && data.kind !== 'call') ||
      (data.scope !== 'direct' && data.scope !== 'group') ||
      typeof data.eventId !== 'string' || !uuid.test(data.eventId) ||
      typeof data.recipient !== 'string' || !account.test(data.recipient) ||
      typeof data.target !== 'string' || !(data.scope === 'group' ? uuid : account).test(data.target) ||
      !Number.isInteger(data.expiresAt) || data.expiresAt <= Date.now() || data.expiresAt > Date.now() + 86400000) return null;
    const clean: NotificationEnvelope = { version: 1, eventId: data.eventId, recipient: data.recipient,
      target: data.target, scope: data.scope, kind: data.kind, expiresAt: data.expiresAt };
    return JSON.stringify(clean);
  } catch (error) { return null; }
}
