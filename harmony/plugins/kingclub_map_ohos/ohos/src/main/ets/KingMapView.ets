import { PlatformView, PlatformViewFactory, StandardMessageCodec, BinaryMessenger, MethodChannel, MethodCall, MethodCallHandler, MethodResult, Any } from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { common } from '@kit.AbilityKit';
import { MapComponent, map, mapCommon } from '@kit.MapKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class KingMapFactory extends PlatformViewFactory {
  private messenger: BinaryMessenger;
  constructor(messenger: BinaryMessenger) { super(StandardMessageCodec.INSTANCE); this.messenger = messenger; }
  create(context: common.Context, id: number, args: Any): PlatformView {
    const values = args as Map<string, Object>;
    return new KingMapView(context, this.messenger, id, values?.get('privacyAccepted') === true);
  }
}
export class KingMapView extends PlatformView implements MethodCallHandler {
  readonly allowed: boolean;
  private context: common.Context;
  private channel: MethodChannel;
  private controller: map.MapComponentController | null = null;
  private resolveReady: ((value: map.MapComponentController) => void) | null = null;
  private rejectReady: ((error: Error) => void) | null = null;
  private timer: number = -1;
  private disposed: boolean = false;
  private serial: number = 0;
  private centered: boolean = false;
  private moved: boolean = false;
  private loaded: boolean = false;
  constructor(context: common.Context, messenger: BinaryMessenger, id: number, allowed: boolean) {
    super(); this.context = context; this.allowed = allowed;
    this.channel = new MethodChannel(messenger, 'kingclub/location-picker-map/' + id);
    this.channel.setMethodCallHandler(this);
  }
  getView(): WrappedBuilder<[Params]> { return new WrappedBuilder(mapBuilder); }
  private status(value: string): void { if (!this.disposed) this.channel.invokeMethod('status', value); }
  ready(error: BusinessError, controller: map.MapComponentController): void {
    if (this.disposed) return;
    if (error || !this.allowed) { this.status('failed'); this.rejectReady?.(new Error('Map unavailable')); return; }
    this.controller = controller;
    const events = controller.getEventManager();
    events.on('mapLoad', (): void => { this.loaded = true; if (this.centered) this.status('ready'); });
    events.on('cameraMoveStart', (reason: number): void => {
      if (reason === 1 && this.centered && !this.disposed) {
        this.moved = true; this.serial++; this.channel.invokeMethod('moving', null);
      }
    });
    events.on('cameraIdle', (): void => {
      if (this.disposed || !this.moved || !this.centered) return;
      this.moved = false;
      this.reportCenter().catch((): void => { this.status('failed'); });
    });
    this.resolveReady?.(controller); this.resolveReady = null; this.rejectReady = null;
    if (this.timer >= 0) clearTimeout(this.timer);
  }
  private async reportCenter(): Promise<void> {
    const controller = this.controller; if (!controller) return;
    const generation = this.serial;
    const actual = controller.getCameraPosition().target;
    const corrected = await map.rectifyCoordinate(this.context, [{ coordinateType: mapCommon.CoordinateType.GCJ02, location: actual }]);
    if (this.disposed || generation !== this.serial || corrected.length !== 1) return;
    const location = corrected[0];
    const data = new Map<string, Object>();
    data.set('latitudeE6', Math.round(location.location.latitude * 1000000));
    data.set('longitudeE6', Math.round(location.location.longitude * 1000000));
    data.set('coordinateSystem', location.coordinateType === mapCommon.CoordinateType.GCJ02 ? 'gcj02' : 'wgs84');
    data.set('name', '地图选点'); data.set('address', '');
    this.channel.invokeMethod('centerChanged', data);
  }
  private waitReady(): Promise<map.MapComponentController> {
    if (this.controller) return Promise.resolve(this.controller);
    if (this.resolveReady || this.disposed || !this.allowed) return Promise.reject(new Error('Map unavailable'));
    return new Promise((resolve, reject): void => {
      this.resolveReady = resolve; this.rejectReady = reject;
      this.timer = setTimeout((): void => {
        this.resolveReady = null; this.rejectReady = null; reject(new Error('Map initialization timed out')); this.status('failed');
      }, 8000);
    });
  }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'cancel') { this.dispose(); result.success(null); return; }
    if (this.disposed || !this.allowed) { result.error('MAP_UNAVAILABLE', '地图不可用', null); return; }
    if (call.method === 'nearby') { result.success([]); return; }
    if (call.method !== 'center') { result.notImplemented(); return; }
    const generation = ++this.serial;
    try {
      const lat = call.argument('latitudeE6') as number;
      const lon = call.argument('longitudeE6') as number;
      const system = call.argument('coordinateSystem') as string;
      if (!Number.isInteger(lat) || !Number.isInteger(lon) || Math.abs(lat) > 85200000 || lon < -180000000 || lon >= 180000000 ||
        (system !== 'wgs84' && system !== 'gcj02')) throw new Error('Invalid location');
      const controller = await this.waitReady();
      const corrected = await map.rectifyCoordinate(this.context, [{
        coordinateType: system === 'wgs84' ? mapCommon.CoordinateType.WGS84 : mapCommon.CoordinateType.GCJ02,
        location: { latitude: lat / 1000000, longitude: lon / 1000000 }
      }]);
      if (this.disposed || generation !== this.serial || corrected.length !== 1) throw new Error('Map request cancelled');
      this.moved = false; this.centered = true;
      controller.moveCamera(map.newLatLng(corrected[0].location, 16));
      if (this.loaded) this.status('ready');
      result.success(corrected[0].coordinateType === mapCommon.CoordinateType.GCJ02 ? 'gcj02' : 'wgs84');
    } catch (error) { this.status('failed'); result.error('MAP_UNAVAILABLE', '地图未能加载，请重试或搜索地点', null); }
  }
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true; this.serial++;
    if (this.timer >= 0) clearTimeout(this.timer);
    this.rejectReady?.(new Error('Map disposed')); this.resolveReady = null; this.rejectReady = null;
    const events = this.controller?.getEventManager();
    events?.off('mapLoad'); events?.off('cameraMoveStart'); events?.off('cameraIdle');
    this.controller = null; this.channel.setMethodCallHandler(null);
  }
}
@Builder
function mapBuilder(params: Params) {
  KingMapComponent({ view: params.platformView as KingMapView })
}
@Component
struct KingMapComponent {
  view: KingMapView | null = null;
  build() {
    if (this.view?.allowed) {
      MapComponent({
        mapOptions: { position: { target: { latitude: 0, longitude: 0 }, zoom: 2 }, rotateGesturesEnabled: false },
        mapCallback: (error: BusinessError, controller: map.MapComponentController): void => { this.view?.ready(error, controller); }
      }).width('100%').height('100%')
    } else {
      Column().width('100%').height('100%')
    }
  }
}
