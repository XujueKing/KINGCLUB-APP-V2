import { FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
import fs from '@ohos.file.fs';
export default class KingclubVideoThumbnailPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private queue: Promise<void> = Promise.resolve();
  private epoch: number = 0;
  getUniqueClassName(): string { return 'KingclubVideoThumbnailPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'video_thumbnail');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.epoch++; this.channel?.setMethodCallHandler(null); this.channel = null;
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    const epoch = this.epoch;
    this.queue = this.queue.catch((): void => {}).then(async (): Promise<void> => {
      try {
        if (epoch !== this.epoch) throw new Error('Thumbnail request detached');
        if (call.method !== 'data') { result.notImplemented(); return; }
        const bytes = await this.decode(call);
        if (epoch !== this.epoch) throw new Error('Thumbnail request detached');
        result.success(new Uint8Array(bytes));
      } catch (error) { result.error('THUMBNAIL_FAILED', 'Unable to generate local video thumbnail', null); }
    });
  }
  private async decode(call: MethodCall): Promise<ArrayBuffer> {
    const path = call.argument('video') as string;
    const format = call.argument('format') as number;
    const quality = call.argument('quality') as number;
    const width = call.argument('maxw') as number;
    const height = call.argument('maxh') as number;
    const time = call.argument('timeMs') as number;
    if (!path || !path.startsWith('/') || (format !== 0 && format !== 1) ||
      !Number.isInteger(quality) || quality < 0 || quality > 100 ||
      !Number.isInteger(width) || width < 0 || !Number.isInteger(height) || height < 0 ||
      !Number.isSafeInteger(time) || time < 0 || time > Number.MAX_SAFE_INTEGER / 1000) {
      throw new Error('Unsupported thumbnail request');
    }
    let file: fs.File | null = null;
    let generator: media.AVImageGenerator | null = null;
    let pixel: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      file = await fs.open(path, fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(file.fd);
      if (!stat.isFile() || stat.size === 0) throw new Error('Empty source');
      generator = await media.createAVImageGenerator();
      generator.fdSrc = { fd: file.fd, offset: 0, length: stat.size };
      pixel = await generator.fetchFrameByTime(time * 1000, media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST_SYNC, {});
      const info = await pixel.getImageInfo();
      const ratio = Math.min(1, width > 0 ? width / info.size.width : 1,
        height > 0 ? height / info.size.height : 1);
      if (ratio < 1) await pixel.scale(ratio, ratio);
      packer = image.createImagePacker();
      return await packer.packing(pixel, { format: format === 0 ? 'image/jpeg' : 'image/png', quality: quality });
    } finally {
      try { if (packer) await packer.release(); }
      finally {
        try { if (pixel) await pixel.release(); }
        finally {
          try { if (generator) await generator.release(); }
          finally { if (file) await fs.close(file); }
        }
      }
    }
  }
}
