import { AbilityAware, AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import crypto from '@ohos.security.cryptoFramework';
import utd from '@ohos.data.uniformTypeDescriptor';

class ExportOperation {
  id: string;
  uri: string = '';
  mime: string = 'application/octet-stream';
  cancelled: boolean = false;
  ownsEmpty: boolean = false;
  constructor(id: string) { this.id = id; }
}
export default class KingclubFileExportPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private active: ExportOperation | null = null;
  private saved: ExportOperation | null = null;
  private busy: boolean = false;
  getUniqueClassName(): string { return 'KingclubFileExportPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/chat-file-export');
    this.channel.setMethodCallHandler(this);
  }
  onAttachedToAbility(binding: AbilityPluginBinding): void { this.context = binding.getAbility().context; }
  onDetachedFromAbility(): void { this.invalidate(); this.context = null; }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.invalidate(); this.context = null;
    this.channel?.setMethodCallHandler(null); this.channel = null;
  }
  private invalidate(): void {
    this.saved = null;
    const op = this.active;
    if (op) { op.cancelled = true; if (!this.busy) { this.active = null; this.cleanup(op); } }
  }
  private cleanup(op: ExportOperation): void {
    if (!op.ownsEmpty || !op.uri) return;
    const uri = op.uri; op.ownsEmpty = false;
    fs.unlink(uri).catch((): void => {});
  }
  private check(op: ExportOperation): void {
    if (op.cancelled || this.active !== op || !this.context) throw new Error('Export interrupted');
  }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    const id = call.argument('operationId') as string;
    if (!id || !/^[0-9a-fA-F-]{36}$/.test(id)) { result.error('INVALID', 'Invalid export operation', null); return; }
    if (call.method === 'cancel') {
      if (this.saved?.id === id) this.saved = null;
      const op = this.active;
      if (op?.id === id) {
        op.cancelled = true;
        if (!this.busy) { this.active = null; this.cleanup(op); }
      }
      result.success(null); return;
    }
    const context = this.context;
    if (!context) { result.error('NO_ACTIVITY', 'An active page is required', null); return; }
    if (this.busy) { result.error('BUSY', 'Another export is active', null); return; }
    this.busy = true;
    try {
      if (call.method === 'choose') {
        if (this.active) throw new Error('Another export is active');
        const name = call.argument('name') as string;
        if (!name || name.length > 180 || /[\\/\x00-\x1f]/.test(name)) throw new Error('Invalid file name');
        const op = new ExportOperation(id); this.active = op;
        const dot = name.lastIndexOf('.');
        if (dot >= 0) {
          try {
            const type = utd.getUniformDataTypeByFilenameExtension(name.substring(dot).toLowerCase());
            const types = utd.getTypeDescriptor(type).mimeTypes;
            if (types.length > 0) op.mime = types[0];
          } catch (error) { /* Unknown extensions use generic file viewer. */ }
        }
        try {
          const uris = await new picker.DocumentViewPicker(context).save({ newFileNames: [name] });
          if (uris.length === 0) { this.active = null; result.success(false); return; }
          if (uris.length !== 1 || !uris[0].startsWith('file://')) throw new Error('Invalid target');
          op.uri = uris[0];
          const stat = await fs.stat(op.uri);
          if (!stat.isFile() || stat.size !== 0) throw new Error('Target must be a new empty document');
          op.ownsEmpty = true; this.check(op);
          result.success(true);
        } catch (error) { this.cleanup(op); this.active = null; throw new Error('Export operation failed'); }
      } else if (call.method === 'copy') {
        const op = this.active;
        if (!op || op.id !== id || !op.uri || !op.ownsEmpty) throw new Error('No active document');
        try {
          await this.copy(call, op, context);
          this.check(op); op.ownsEmpty = false;
          this.saved = op; this.active = null; result.success(true);
        } catch (error) { this.cleanup(op); this.active = null; throw new Error('Export operation failed'); }
      } else if (call.method === 'openSaved') {
        const op = this.saved;
        if (!op || op.id !== id) throw new Error('No saved document');
        await context.startAbility({ action: 'ohos.want.action.viewData', uri: op.uri, type: op.mime, flags: 1 });
        result.success(true);
      } else { result.notImplemented(); }
    } catch (error) { result.error('EXPORT_FAILED', 'Unable to export or open document', null); }
    finally { this.busy = false; }
  }
  private async copy(call: MethodCall, op: ExportOperation, context: common.UIAbilityContext): Promise<void> {
    const path = call.argument('path') as string;
    const size = call.argument('size') as number;
    const expected = call.argument('sha256') as string;
    const prefix = context.cacheDir + '/';
    if (!path || !path.startsWith(prefix) || !Number.isInteger(size) || size < 0 || size > 268435456 ||
      !expected || !/^[0-9a-f]{64}$/.test(expected)) throw new Error('Invalid private source');
    const suffix = path.substring(prefix.length);
    if (!/^kingclub-chat-download-[A-Za-z0-9_-]+\/content\.bin$/.test(suffix)) throw new Error('Invalid private source');
    const parent = path.substring(0, path.lastIndexOf('/'));
    const parentStat = await fs.lstat(parent);
    const sourceStat = await fs.lstat(path);
    if (!parentStat.isDirectory() || parentStat.isSymbolicLink() || !sourceStat.isFile() || sourceStat.isSymbolicLink() || sourceStat.size !== size) throw new Error('Invalid source');
    let source: fs.File | null = null;
    let target: fs.File | null = null;
    try {
      source = await fs.open(path, fs.OpenMode.READ_ONLY);
      await this.transfer(source.fd, null, size, expected, op);
      this.check(op);
      const destinationStat = await fs.stat(op.uri);
      if (destinationStat.size !== 0) { op.ownsEmpty = false; throw new Error('Target changed'); }
      target = await fs.open(op.uri, fs.OpenMode.WRITE_ONLY);
      await this.transfer(source.fd, target.fd, size, expected, op);
      await fs.fsync(target.fd); this.check(op);
    } finally {
      try { if (target) await fs.close(target); }
      finally { if (source) await fs.close(source); }
    }
  }
  private async transfer(source: number, target: number | null, size: number, expected: string, op: ExportOperation): Promise<void> {
    fs.lseek(source, 0);
    const digest = crypto.createMd('SHA256');
    const buffer = new ArrayBuffer(65536);
    let total = 0;
    while (true) {
      this.check(op);
      const count = await fs.read(source, buffer);
      if (count === 0) break;
      if (total + count > size) throw new Error('Source size changed');
      await digest.update({ data: new Uint8Array(buffer, 0, count) });
      this.check(op);
      if (target !== null) {
        const written = await fs.write(target, buffer, { length: count });
        if (written !== count) throw new Error('Incomplete write');
      }
      total += count;
    }
    const hash = (await digest.digest()).data;
    let hex = '';
    for (let i = 0; i < hash.length; i++) hex += hash[i].toString(16).padStart(2, '0');
    if (total !== size || hex !== expected) throw new Error('Integrity check failed');
    this.check(op);
  }
}
