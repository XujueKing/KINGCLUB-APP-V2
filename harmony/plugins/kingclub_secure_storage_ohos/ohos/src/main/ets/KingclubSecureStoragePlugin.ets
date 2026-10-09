import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler, MethodChannel,
  MethodResult } from '@ohos/flutter_ohos';
import { asset } from '@kit.AssetStoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

// The root key is managed by the OS. Preferences contain authenticated ciphertext only.
export default class KingclubSecureStoragePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private store: preferences.Preferences | null = null;
  private queue: Promise<void> = Promise.resolve();
  private encoder = new util.TextEncoder();
  private decoder = util.TextDecoder.create('utf-8', { fatal: true });
  private base64 = new util.Base64Helper();
  private readonly alias = 'kingclub.secure-storage.root.v1';

  getUniqueClassName(): string { return 'KingclubSecureStoragePlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.store = preferences.getPreferencesSync(binding.getApplicationContext(), { name: 'kingclub_secure_v1' });
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'plugins.it_nomads.com/flutter_secure_storage');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    this.queue = this.queue.then(async () => {
      try {
        await this.handle(call, result);
      } catch (error) {
        // Never expose credentials, key names, encrypted data or native error messages.
        const code = (error as BusinessError).code;
        result.error('secure_storage_unavailable', 'System secure storage operation failed.', code ?? null);
      }
    });
  }

  private prefs(): preferences.Preferences {
    if (this.store === null) { throw new Error('Storage not attached'); }
    return this.store;
  }

  private queryRoot(): asset.AssetMap {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.encoder.encodeInto(this.alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    return query;
  }

  private async rootKey(create: boolean): Promise<cryptoFramework.SymKey> {
    const generator = cryptoFramework.createSymKeyGenerator('AES256');
    try {
      const records = await asset.query(this.queryRoot());
      if (records.length !== 1) { throw new Error('Invalid root key record'); }
      return generator.convertKeySync({ data: records[0].get(asset.Tag.SECRET) as Uint8Array });
    } catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND || !create) { throw error as Error; }
    }
    // Missing key with existing ciphertext is a recovery condition, not a new installation.
    if (Object.keys(this.prefs().getAllSync()).length > 0) { throw new Error('Root key missing'); }
    const key = generator.generateSymKeySync();
    const entry: asset.AssetMap = new Map();
    entry.set(asset.Tag.ALIAS, this.encoder.encodeInto(this.alias));
    entry.set(asset.Tag.SECRET, key.getEncoded().data);
    entry.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    entry.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    entry.set(asset.Tag.IS_PERSISTENT, false);
    entry.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.THROW_ERROR);
    try {
      await asset.add(entry);
      return key;
    } catch (error) {
      // Another engine may have initialized the key. Never overwrite its key.
      if ((error as BusinessError).code !== asset.ErrorCode.DUPLICATED) { throw error as Error; }
      return this.rootKey(false);
    }
  }

  private params(key: string, iv: Uint8Array, tag: Uint8Array): cryptoFramework.GcmParamsSpec {
    return { algName: 'GcmParamsSpec', iv: { data: iv }, authTag: { data: tag },
      aad: { data: this.encoder.encodeInto('kingclub.secure.v1:' + key) } };
  }

  private async write(key: string, value: string): Promise<void> {
    const root = await this.rootKey(true);
    const iv = cryptoFramework.createRandom().generateRandomSync(12).data;
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, root, this.params(key, iv, new Uint8Array(16)));
    // JSON encoding preserves empty strings and arbitrary Unicode without zero-length cipher input.
    const encrypted = cipher.updateSync({ data: this.encoder.encodeInto(JSON.stringify(value)) }).data;
    const tag = cipher.doFinalSync(null).data;
    if (tag.length !== 16) { throw new Error('Invalid GCM tag'); }
    const envelope = new Uint8Array(28 + encrypted.length);
    envelope.set(iv, 0);
    envelope.set(tag, 12);
    envelope.set(encrypted, 28);
    this.prefs().putSync(key, 'v1:' + this.base64.encodeToStringSync(envelope));
    await this.prefs().flush();
  }

  private async read(key: string): Promise<string | null> {
    const prefs = this.prefs();
    if (!prefs.hasSync(key)) { return null; }
    const value = prefs.getSync(key, '');
    if (typeof value !== 'string' || !value.startsWith('v1:')) { throw new Error('Invalid encrypted record'); }
    const bytes = this.base64.decodeSync(value.substring(3));
    if (bytes.length <= 28) { throw new Error('Truncated encrypted record'); }
    const root = await this.rootKey(false);
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, root,
      this.params(key, bytes.slice(0, 12), bytes.slice(12, 28)));
    const plaintext = cipher.updateSync({ data: bytes.slice(28) }).data;
    cipher.doFinalSync(null); // Authenticate before decoding or returning any plaintext.
    const decoded = JSON.parse(this.decoder.decodeToString(plaintext)) as string;
    if (typeof decoded !== 'string') { throw new Error('Invalid stored value'); }
    return decoded;
  }

  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    const prefs = this.prefs();
    if (call.method === 'deleteAll') {
      prefs.clearSync();
      await prefs.flush();
      result.success(null);
      return;
    }
    if (call.method === 'readAll') {
      const values = new Map<string, string>();
      for (const key of Object.keys(prefs.getAllSync())) {
        const value = await this.read(key);
        if (value !== null) { values.set(key, value); }
      }
      result.success(values);
      return;
    }
    if (call.method === 'checkUpgradeStatus') { result.notImplemented(); return; }
    if (!['write', 'read', 'delete', 'containsKey'].includes(call.method)) { result.notImplemented(); return; }
    const args = call.args as Map<string, Object>;
    const key = args.get('key');
    if (typeof key !== 'string' || key.length === 0) {
      result.error('invalid_argument', 'A nonempty storage key is required.', null);
      return;
    }
    switch (call.method) {
      case 'write': {
        const value = args.get('value');
        if (typeof value !== 'string') { result.error('invalid_argument', 'A string value is required.', null); return; }
        await this.write(key, value);
        result.success(null);
        return;
      }
      case 'read': result.success(await this.read(key)); return;
      case 'containsKey': result.success((await this.read(key)) !== null); return;
      case 'delete': prefs.deleteSync(key); await prefs.flush(); result.success(null); return;
    }
  }
}
