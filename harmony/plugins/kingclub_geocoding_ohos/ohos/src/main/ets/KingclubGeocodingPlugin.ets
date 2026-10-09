import { FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { geoLocationManager } from '@kit.LocationKit';

export default class KingclubGeocodingPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  getUniqueClassName(): string { return 'KingclubGeocodingPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.lingmei.kingclub/geocoding');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (call.method === 'isPresent') {
        result.success(geoLocationManager.isGeocoderAvailable());
        return;
      }
      if (call.method !== 'placemarkFromCoordinates' && call.method !== 'placemarkFromAddress' && call.method !== 'locationFromAddress') {
        result.notImplemented(); return;
      }
      if (!geoLocationManager.isGeocoderAvailable()) {
        result.error('GEOCODER_UNAVAILABLE', 'System geocoding is unavailable', null); return;
      }
      const locale: string | null = call.argument('locale');
      let addresses: Array<geoLocationManager.GeoAddress>;
      if (call.method === 'placemarkFromCoordinates') {
        const latitude: number | null = call.argument('latitude');
        const longitude: number | null = call.argument('longitude');
        if (latitude === null || longitude === null || !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
          latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
          result.error('INVALID_ARGUMENT', 'Invalid coordinates', null); return;
        }
        const request: geoLocationManager.ReverseGeoCodeRequest = { latitude: latitude, longitude: longitude, maxItems: 5 };
        if (locale) request.locale = locale;
        addresses = await geoLocationManager.getAddressesFromLocation(request);
      } else {
        const address: string | null = call.argument('address');
        if (!address || address.trim().length === 0) {
          result.error('INVALID_ARGUMENT', 'Empty address', null); return;
        }
        const request: geoLocationManager.GeoCodeRequest = { description: address, maxItems: 5 };
        if (locale) request.locale = locale;
        addresses = await geoLocationManager.getAddressesFromLocationName(request);
      }
      const values: Array<Map<string, Object>> = [];
      for (const a of addresses) {
        const value = new Map<string, Object>();
        if (call.method === 'locationFromAddress') {
          if (a.latitude === undefined || a.longitude === undefined) continue;
          value.set('latitude', a.latitude); value.set('longitude', a.longitude);
        } else {
          value.set('name', a.placeName ?? '');
          value.set('street', a.roadName ?? '');
          value.set('isoCountryCode', a.countryCode ?? '');
          value.set('country', a.countryName ?? '');
          value.set('postalCode', a.postalCode ?? '');
          value.set('administrativeArea', a.administrativeArea ?? '');
          value.set('subAdministrativeArea', a.subAdministrativeArea ?? '');
          value.set('locality', a.locality ?? '');
          value.set('subLocality', a.subLocality ?? '');
          value.set('thoroughfare', a.roadName ?? '');
          value.set('subThoroughfare', a.subRoadName ?? '');
        }
        values.push(value);
      }
      result.success(values);
    } catch (_) {
      // Do not expose coordinates or detailed addresses in logs or exceptions.
      result.error('GEOCODING_FAILED', 'System geocoding failed', null);
    }
  }
}
