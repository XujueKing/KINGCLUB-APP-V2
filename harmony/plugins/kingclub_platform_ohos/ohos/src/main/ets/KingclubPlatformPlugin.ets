import { FlutterPlugin, FlutterPluginBinding, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import bundleManager from '@ohos.bundle.bundleManager';
export default class KingclubPlatformPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  getUniqueClassName(): string { return 'KingclubPlatformPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/app-version');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null); this.channel = null;
  }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method !== 'read') { result.notImplemented(); return; }
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      const values = new Map<string, string>();
      values.set('version', info.versionName); values.set('build', info.versionCode.toString());
      result.success(values);
    } catch (error) { result.error('VERSION_UNAVAILABLE', 'Unable to read installed bundle metadata', null); }
  }
}
