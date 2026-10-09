import { AbilityAware, AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { petalMaps, mapCommon } from '@kit.MapKit';
import deviceInfo from '@ohos.deviceInfo';

export default class KingclubMapPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private epoch: number = 0;
  private busy: boolean = false;
  getUniqueClassName(): string { return 'KingclubMapPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/chat-map');
    this.channel.setMethodCallHandler(this);
  }
  onAttachedToAbility(binding: AbilityPluginBinding): void { this.context = binding.getAbility().context; }
  onDetachedFromAbility(): void { this.epoch++; this.context = null; }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.epoch++; this.context = null; this.channel?.setMethodCallHandler(null); this.channel = null;
  }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method !== 'open') { result.notImplemented(); return; }
    const context = this.context;
    if (!context) { result.error('NO_ACTIVITY', 'Map requires an active page', null); return; }
    if (this.busy) { result.error('BUSY', 'Map is already opening', null); return; }
    const lat = call.argument('latitudeE6') as number;
    const lon = call.argument('longitudeE6') as number;
    const system = call.argument('coordinateSystem') as string;
    const name = call.argument('name') as string;
    const mode = call.argument('mode') as string | null;
    if (!Number.isInteger(lat) || !Number.isInteger(lon) || lat < -85200000 || lat > 85200000 ||
      lon < -180000000 || lon >= 180000000 || (system !== 'wgs84' && system !== 'gcj02') ||
      (mode !== null && mode !== undefined && mode !== 'view' && mode !== 'walking' && mode !== 'driving')) {
      result.error('INVALID', 'Invalid map destination', null); return;
    }
    if (deviceInfo.sdkApiVersion < 21 && system !== 'gcj02') {
      result.error('UNSUPPORTED_COORDINATES', 'This system cannot explicitly specify WGS84', null); return;
    }
    this.busy = true;
    const epoch = this.epoch;
    try {
      const position: mapCommon.LatLng = { latitude: lat / 1000000, longitude: lon / 1000000 };
      const title = typeof name === 'string' ? name.substring(0, 100) : '';
      if (mode !== 'view') {
        const options: petalMaps.RoutePlanParams = {
          destinationPosition: position, destinationName: title,
          vehicleType: mode === 'walking' ? petalMaps.VehicleType.WALKING : petalMaps.VehicleType.DRIVING
        };
        if (deviceInfo.sdkApiVersion >= 21) options.coordinateType = system === 'wgs84' ? mapCommon.CoordinateType.WGS84 : mapCommon.CoordinateType.GCJ02;
        await petalMaps.openMapRoutePlan(context, options);
      } else {
        const options: petalMaps.PoiDetailParams = { destinationPosition: position, destinationName: title };
        if (deviceInfo.sdkApiVersion >= 21) options.coordinateType = system === 'wgs84' ? mapCommon.CoordinateType.WGS84 : mapCommon.CoordinateType.GCJ02;
        await petalMaps.openMapPoiDetail(context, options);
      }
      result.success(epoch === this.epoch);
    } catch (error) { result.error('MAP_UNAVAILABLE', 'Unable to open system map', null); }
    finally { this.busy = false; }
  }
}
