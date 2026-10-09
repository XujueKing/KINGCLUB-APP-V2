import { MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { map, mapCommon, staticMap } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
export class KingMapSnapshot implements MethodCallHandler {
  context: common.UIAbilityContext | null = null;
  private epoch: number = 0;
  private queue: Promise<void> = Promise.resolve();
  detach(): void { this.epoch++; this.context = null; }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    const epoch = this.epoch;
    this.queue = this.queue.catch((): void => {}).then(async (): Promise<void> => {
      let pixel: image.PixelMap | null = null;
      let packer: image.ImagePacker | null = null;
      try {
        if (call.method !== 'snapshot') { result.notImplemented(); return; }
        const context = this.context;
        if (!context || epoch !== this.epoch || call.argument('privacyAccepted') !== true) throw new Error('Map consent required');
        const lat = call.argument('latitudeE6') as number;
        const lon = call.argument('longitudeE6') as number;
        const system = call.argument('coordinateSystem') as string;
        if (!Number.isInteger(lat) || !Number.isInteger(lon) || Math.abs(lat) > 85200000 || lon < -180000000 || lon >= 180000000 ||
          (system !== 'wgs84' && system !== 'gcj02')) throw new Error('Invalid coordinate');
        const points = await map.rectifyCoordinate(context, [{
          coordinateType: system === 'wgs84' ? mapCommon.CoordinateType.WGS84 : mapCommon.CoordinateType.GCJ02,
          location: { latitude: lat / 1000000, longitude: lon / 1000000 }
        }]);
        if (epoch !== this.epoch || points.length !== 1) throw new Error('Snapshot cancelled');
        pixel = await staticMap.getMapImage(context, { location: points[0].location, zoom: 15, imageWidth: 640, imageHeight: 320, scale: 1 });
        packer = image.createImagePacker();
        const bytes = await packer.packing(pixel, { format: 'image/jpeg', quality: 80 });
        if (epoch !== this.epoch) throw new Error('Snapshot cancelled');
        result.success(new Uint8Array(bytes));
      } catch (error) { result.error('MAP_UNAVAILABLE', '地图预览暂不可用', null); }
      finally { try { if (packer) await packer.release(); } finally { if (pixel) await pixel.release(); } }
    });
  }
}
