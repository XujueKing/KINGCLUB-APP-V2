import { AbilityAware, AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import util from '@ohos.util';

export default class KingclubFilePickerPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private busy: boolean = false;
  private epoch: number = 0;
  getUniqueClassName(): string { return 'KingclubFilePickerPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.lingmei.kingclub/file_picker');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.epoch++; this.channel?.setMethodCallHandler(null); this.channel = null; this.context = null;
  }
  onAttachedToAbility(binding: AbilityPluginBinding): void { this.context = binding.getAbility().context; }
  onDetachedFromAbility(): void { this.epoch++; this.context = null; }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method !== 'pickFile') { result.notImplemented(); return; }
    if (this.busy) { result.error('PICKER_BUSY', 'A file picker is already open', null); return; }
    const context = this.context;
    if (!context) { result.error('NO_ACTIVITY', 'File picker requires an active page', null); return; }
    this.busy = true;
    const epoch = this.epoch;
    let source: fs.File | null = null;
    let target: fs.File | null = null;
    let output = '';
    let completed = false;
    try {
      const uris = await new picker.DocumentViewPicker(context).select({ maxSelectNumber: 1 });
      if (epoch !== this.epoch) throw new Error('File selection interrupted');
      if (uris.length === 0) { result.success(null); completed = true; return; }
      if (uris.length !== 1) throw new Error('Expected one document');
      const name = new fileUri.FileUri(uris[0]).name;
      if (!name || name.length > 180) throw new Error('Invalid file name');
      source = await fs.open(uris[0], fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(source.fd);
      if (!stat.isFile() || stat.size > 268435456) throw new Error('File must be at most 256 MiB');
      const directory = context.cacheDir + '/kingclub-picked-documents';
      if (!fs.accessSync(directory)) fs.mkdirSync(directory);
      const candidate = directory + '/' + util.generateRandomUUID();
      if (fs.accessSync(candidate)) throw new Error('Cache path already exists');
      output = candidate;
      target = await fs.open(output, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      const buffer = new ArrayBuffer(65536);
      let total = 0;
      while (true) {
        if (epoch !== this.epoch) throw new Error('File selection interrupted');
        const count = await fs.read(source.fd, buffer);
        if (count === 0) break;
        total += count;
        if (total > 268435456 || total > stat.size) throw new Error('File changed or is too large');
        const written = await fs.write(target.fd, buffer, { length: count });
        if (written !== count) throw new Error('Incomplete file copy');
      }
      if (total !== stat.size || epoch !== this.epoch) throw new Error('File changed or selection interrupted');
      await fs.close(target); target = null;
      await fs.close(source); source = null;
      const file = new Map<string, Object>();
      file.set('path', output); file.set('name', name); file.set('size', total);
      result.success(file); completed = true;
    } catch (error) {
      result.error('FILE_PICK_FAILED', (error as Error).message, null);
    } finally {
      try { if (source) await fs.close(source); }
      finally {
        try { if (target) await fs.close(target); }
        finally {
          try { if (!completed && output && fs.accessSync(output)) fs.unlinkSync(output); }
          finally { this.busy = false; }
        }
      }
    }
  }
}
