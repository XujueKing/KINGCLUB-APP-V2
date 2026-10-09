import pathlib, sys, shutil
root = pathlib.Path(sys.argv[1]).resolve()
repo = pathlib.Path(__file__).resolve().parent.parent
if root == repo: raise RuntimeError('Use isolated probe')
base = root/'lib/src/features/messaging'
def edit(relative, changes):
    path = base/relative
    text = path.read_text(encoding='utf-8')
    for old,new in changes:
        if old not in text: raise RuntimeError('Changed source: '+relative+' '+old[:60])
        text = text.replace(old,new)
    return path,text
prefix = "import '../data/harmony_map_consent.dart';\n"
cond = 'defaultTargetPlatform == TargetPlatform.ohos'
restore = f'({cond} ? HarmonyMapConsent.restore() : ChatMapPreviewCache.restoreConsent())'
request = f'({cond} ? HarmonyMapConsent.request(context) : requestTencentChatMapConsent(context))'
changes=[]
changes.append(edit('presentation/chat_location_picker_page.dart',[
("import 'chat_map_consent.dart';", "import 'chat_map_consent.dart';\n"+prefix),
('defaultTargetPlatform == TargetPlatform.android &&\n      TencentChatPlaceSearch.configuredKey.isNotEmpty', '(defaultTargetPlatform == TargetPlatform.ohos || (defaultTargetPlatform == TargetPlatform.android &&\n      TencentChatPlaceSearch.configuredKey.isNotEmpty))'),
('widget.lookup == null && TencentChatPlaceSearch.configuredKey.isNotEmpty', 'defaultTargetPlatform != TargetPlatform.ohos && widget.lookup == null && TencentChatPlaceSearch.configuredKey.isNotEmpty'),
('ChatMapPreviewCache.restoreConsent()',restore),
('requestTencentChatMapConsent(context)',request),
('if (defaultTargetPlatform == TargetPlatform.android &&', 'if ((defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.ohos) &&'),
('defaultTargetPlatform == TargetPlatform.android) {\n          await _center', '(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.ohos)) {\n          await _center'),
(': _nativeMap\n          ? await _mapPlaces', ': _nativeMap && defaultTargetPlatform != TargetPlatform.ohos\n          ? await _mapPlaces'),
("map: defaultTargetPlatform == TargetPlatform.android", """map: defaultTargetPlatform == TargetPlatform.ohos
                              ? OhosView(
                                  viewType: 'kingclub/location-picker-map',
                                  creationParams: {'privacyAccepted': _androidMapAllowed},
                                  creationParamsCodec: const StandardMessageCodec(),
                                  gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
                                  onPlatformViewCreated: _attachMap,
                                )
                              : defaultTargetPlatform == TargetPlatform.android"""),
]))
changes.append(edit('data/chat_map_preview_cache.dart',[
("import 'chat_location.dart';", "import 'chat_location.dart';\nimport 'harmony_map_consent.dart';"),
('platform != TargetPlatform.android)', 'platform != TargetPlatform.android && platform != TargetPlatform.ohos)'),
('if (platform == TargetPlatform.iOS) {', """if (platform == TargetPlatform.ohos) {
        if (!await HarmonyMapConsent.restore()) return null;
        return await const MethodChannel('kingclub/chat-map-preview').invokeMethod<Uint8List>('snapshot', {
          'latitudeE6': location.latitudeE6, 'longitudeE6': location.longitudeE6,
          'coordinateSystem': location.coordinateSystem, 'privacyAccepted': true,
        }).timeout(const Duration(seconds: 12));
      }
      if (platform == TargetPlatform.iOS) {"""),
]))
changes.append(edit('presentation/chat_location_message.dart',[
("import 'dart:async';", "import 'dart:async';\n"+prefix),
('defaultTargetPlatform == TargetPlatform.android)', '(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.ohos))'),
('defaultTargetPlatform == TargetPlatform.android &&\n      TencentChatPlaceSearch.configuredKey.isNotEmpty', '(defaultTargetPlatform == TargetPlatform.ohos || (defaultTargetPlatform == TargetPlatform.android &&\n      TencentChatPlaceSearch.configuredKey.isNotEmpty))'),
('ChatMapPreviewCache.restoreConsent()',restore),
('requestTencentChatMapConsent(context)',request),
("? '腾讯地图'\n                      : 'Apple Maps'", "? '腾讯地图'\n                      : defaultTargetPlatform == TargetPlatform.ohos ? '华为地图' : 'Apple Maps'"),
('ChatMapPreviewCache.androidConsent.addListener(_consentChanged);', 'ChatMapPreviewCache.androidConsent.addListener(_consentChanged);\n    HarmonyMapConsent.accepted.addListener(_consentChanged);'),
('ChatMapPreviewCache.androidConsent.removeListener(_consentChanged);', 'ChatMapPreviewCache.androidConsent.removeListener(_consentChanged);\n    HarmonyMapConsent.accepted.removeListener(_consentChanged);'),
]))
for path,text in changes: path.write_text(text,encoding='utf-8')
shutil.copyfile(repo/'harmony/verification/harmony_map_consent.dart.template',base/'data/harmony_map_consent.dart')
plugin=root/'native_plugins/kingclub_map_ohos'
if not plugin.exists(): raise RuntimeError('Stage system map plugin first')
for src in (repo/'harmony/plugins/kingclub_map_ohos/ohos/src/main/ets').glob('*.ets'):
    shutil.copyfile(src,plugin/'ohos/src/main/ets'/src.name)
print('Embedded map staged in probe only')

