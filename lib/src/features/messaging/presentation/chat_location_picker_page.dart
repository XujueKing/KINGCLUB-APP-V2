import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/session/secure_session_store.dart';
import '../data/chat_location.dart';
import '../data/chat_location_lookup.dart';
import '../data/chat_current_position.dart';

/// Selecting a candidate never sends it; the explicit confirm returns it.
class ChatLocationPickerPage extends StatefulWidget {
  const ChatLocationPickerPage({
    super.key,
    this.lookup,
    this.onConfirm,
    this.initialSelection,
    this.onSelectionChanged,
  });
  final ChatLocationLookup? lookup;
  final ChatLocation? initialSelection;
  final Future<void> Function(ChatLocation)? onSelectionChanged;
  final Future<void> Function(ChatLocation)? onConfirm;
  @override
  State<ChatLocationPickerPage> createState() => _ChatLocationPickerPageState();
}

class _ChatLocationPickerPageState extends State<ChatLocationPickerPage> {
  static const _maps = MethodChannel('kingclub/chat-map');
  late final ChatLocationLookup _lookup =
      widget.lookup ?? NativeChatLocationLookup();
  final _query = TextEditingController();
  StreamSubscription<void>? _session;
  List<ChatLocation> _results = [];
  ChatLocation? _selected;
  String? _error;
  String? _accuracyLabel;
  MethodChannel? _map;
  Timer? _mapDebounce;
  ChatLocation? _current;
  Offset? _markerAnchor;
  String _mapStatus = 'loading';
  bool get _nativeMap => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool _openingMap = false;
  bool _busy = false, _invalid = false, _sending = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
    if (_selected != null) _results = [_selected!];
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      _generation++;
      _mapDebounce?.cancel();
      unawaited(_map?.invokeMethod<void>('cancel').catchError((_) {}));
      setState(() {
        _invalid = true;
        _busy = false;
        _results = [];
        _selected = null;
        _error = '登录状态已变化，请重新进入';
        _accuracyLabel = null;
      });
    });
  }

  void _attachMap(int id) {
    if (!mounted || _invalid) return;
    final channel = MethodChannel('kingclub/location-picker-map/$id');
    _map = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted || _invalid || _sending || _map != channel) return;
      if (call.method == 'status') {
        setState(() => _mapStatus = call.arguments as String? ?? 'failed');
      } else if (call.method == 'selectionAnchor') {
        final args = call.arguments;
        if (args is! Map || args['x'] is! num || args['y'] is! num) return;
        final x = (args['x'] as num).toDouble();
        final y = (args['y'] as num).toDouble();
        if (x.isFinite && y.isFinite) {
          setState(() => _markerAnchor = Offset(x, y));
        }
      } else if (call.method == 'moving') {
        _generation++;
        _mapDebounce?.cancel();
        setState(() {
          _busy = true;
          _selected = null;
          _results = [];
        });
      } else if (call.method == 'centerChanged') {
        final center = ChatLocation.tryParse(call.arguments);
        if (center == null) return;
        _mapDebounce?.cancel();
        _mapDebounce = Timer(
          const Duration(milliseconds: 350),
          () => _nearby(center),
        );
      }
    });
    final initial = _selected;
    if (initial != null && initial.name != '当前位置') {
      unawaited(_restoreSelection(initial));
    } else {
      // A saved GPS fix is a draft, never evidence of the current position.
      unawaited(_load(true));
    }
  }

  Future<void> _restoreSelection(ChatLocation initial) async {
    await _center(initial);
    if (!mounted || _invalid) return;
    await _nearby(initial, preserveSelection: true);
  }

  Future<void> _center(
    ChatLocation location, {
    bool userLocation = false,
  }) async {
    if (_invalid || !_nativeMap || location.coordinateSystem != 'wgs84') return;
    try {
      await _map
          ?.invokeMethod<void>('center', {
            ...location.toJson(),
            'userLocation': userLocation,
          })
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (mounted && !_invalid) setState(() => _mapStatus = 'failed');
    }
  }

  Future<List<ChatLocation>> _mapPlaces(
    String method,
    Map<String, dynamic> args,
  ) async {
    final channel = _map;
    if (channel == null) throw StateError('地图尚未准备好，请稍后重试');
    final data = await channel
        .invokeListMethod<dynamic>(method, args)
        .timeout(const Duration(seconds: 15));
    return (data ?? [])
        .map(ChatLocation.tryParse)
        .whereType<ChatLocation>()
        .toList();
  }

  Future<ChatLocation> _currentLocation() async {
    if (!_nativeMap || _lookup is! NativeChatLocationLookup) {
      return _lookup.current();
    }
    await ChatCurrentPosition.ensurePermission();
    final data = await _map
        ?.invokeMapMethod<String, dynamic>('locate', {})
        .timeout(const Duration(seconds: 22));
    final location = ChatLocation.tryParse(data?['location']);
    final accuracy = data?['accuracyMeters'];
    if (location == null ||
        accuracy is! num ||
        !accuracy.isFinite ||
        accuracy <= 0 ||
        accuracy > 100) {
      throw StateError('地图尚未获取精确位置，请重新定位');
    }
    _lookup.currentAccuracyMeters = accuracy.ceil();
    return location;
  }

  Future<void> _nearby(
    ChatLocation center, {
    bool preserveSelection = false,
  }) async {
    if (_invalid || _sending) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _selected = null;
      _error = null;
      _results = [];
    });
    var results = [center];
    try {
      results = await _mapPlaces('nearby', center.toJson());
    } catch (_) {
      // The actual map-center coordinate remains selectable without POI service.
    }
    if (!mounted || _invalid || generation != _generation) return;
    setState(() {
      _results = preserveSelection
          ? [
              center,
              ...results.where(
                (item) =>
                    item.latitudeE6 != center.latitudeE6 ||
                    item.longitudeE6 != center.longitudeE6 ||
                    item.name != center.name,
              ),
            ]
          : results.isEmpty
          ? [center]
          : results;
      _busy = false;
      if (preserveSelection) _selected = center;
    });
    // Keep the original durable draft ID until a manual selection changes.
    if (preserveSelection) return;
    await _select(_results.first, moveMap: false);
  }

  Future<void> _load(bool current) async {
    if (_invalid || _sending) return;
    final generation = ++_generation;
    _mapDebounce?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _accuracyLabel = null;
      _selected = null;
      _results = [];
    });
    try {
      var results = current
          ? [await _currentLocation()]
          : _nativeMap
          ? await _mapPlaces('search', {'query': _query.text.trim()})
          : await _lookup.search(_query.text);
      if (!mounted || generation != _generation || _invalid) return;
      if (current) {
        _current = results.first;
        // Native current location is centered by MapKit's tracking camera.
        // Do not replace it with an independent raw GPS center afterwards.
        if (!_nativeMap || _lookup is! NativeChatLocationLookup) {
          await _center(results.first, userLocation: true);
        }
        if (_nativeMap) {
          try {
            final nearby = await _mapPlaces('nearby', results.first.toJson());
            if (nearby.isNotEmpty) results = nearby;
          } catch (_) {
            /* Keep the accurate GPS candidate, never fabricate POIs. */
          }
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        if (current && _lookup is NativeChatLocationLookup) {
          final accuracy = _lookup.currentAccuracyMeters;
          if (accuracy != null) {
            _accuracyLabel = '定位精度约 $accuracy 米';
          }
        }
        if (results.isEmpty) _error = '没有找到地点，请输入更完整的地址';
      });
      if (_nativeMap && current && results.isNotEmpty) {
        setState(() => _busy = false);
        await _select(results.first, moveMap: false);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : error is PlatformException && error.message != null
              ? error.message
              : '无法获取地点，请重试',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _select(ChatLocation location, {bool moveMap = true}) async {
    if (_invalid || _busy || _sending) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _selected = null;
      _error = null;
    });
    try {
      await widget.onSelectionChanged?.call(location);
      if (mounted && generation == _generation && !_invalid && moveMap) {
        await _center(location);
      }
      if (mounted && generation == _generation && !_invalid) {
        setState(() => _selected = location);
      }
    } catch (_) {
      if (mounted && generation == _generation && !_invalid) {
        setState(() => _error = '地点未能保存，请重新选择');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _preview(ChatLocation location) async {
    if (_invalid || _busy || _sending || _openingMap) return;
    final generation = _generation;
    setState(() => _openingMap = true);
    try {
      final data = location.toJson()..remove('address');
      data['mode'] = 'view';
      final opened = await _maps
          .invokeMethod<bool>('open', data)
          .timeout(const Duration(seconds: 10));
      if (opened != true) throw StateError('无法打开系统地图');
    } catch (_) {
      if (mounted && !_invalid && generation == _generation) {
        setState(() => _error = '无法打开系统地图，请安装地图应用后重试');
      }
    } finally {
      if (mounted) setState(() => _openingMap = false);
    }
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null || _invalid || _busy || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onConfirm?.call(selected);
      if (mounted && !_invalid) Navigator.of(context).pop(selected);
    } catch (_) {
      if (mounted && !_invalid) setState(() => _error = '发送未完成，请重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _mapDebounce?.cancel();
    _map?.setMethodCallHandler(null);
    unawaited(_map?.invokeMethod<void>('cancel').catchError((_) {}));
    _session?.cancel();
    _query.dispose();
    super.dispose();
  }

  String _subtitle(ChatLocation location) {
    final current = _current;
    String distance = '';
    if (current != null &&
        current.coordinateSystem == 'wgs84' &&
        location.coordinateSystem == 'wgs84') {
      final meters = Geolocator.distanceBetween(
        current.latitudeE6 / 1e6,
        current.longitudeE6 / 1e6,
        location.latitudeE6 / 1e6,
        location.longitudeE6 / 1e6,
      );
      distance = meters < 1000
          ? '${meters.round()}m'
          : '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return [distance, location.address].where((s) => s.isNotEmpty).join(' | ');
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF07C160),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final panelHeight = (MediaQuery.sizeOf(context).height * .36).clamp(
              0.0,
              constraints.maxHeight * .72,
            );
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_nativeMap && !_invalid)
                        UiKitView(
                          viewType: 'kingclub/location-picker-map',
                          creationParamsCodec: const StandardMessageCodec(),
                          gestureRecognizers: {
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                          onPlatformViewCreated: _attachMap,
                        )
                      else
                        ColoredBox(
                          color: const Color(0xFFF4F4F4),
                          child: constraints.maxHeight - panelHeight < 160
                              ? const SizedBox.shrink()
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.map_outlined,
                                          size: 36,
                                          color: Color(0xFF888888),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _invalid ? '登录状态已变化' : '此设备暂未接入内嵌地图',
                                          style: const TextStyle(
                                            color: Color(0xFF777777),
                                          ),
                                        ),
                                        if (_results.isNotEmpty)
                                          TextButton(
                                            onPressed:
                                                _invalid ||
                                                    _busy ||
                                                    _sending ||
                                                    _openingMap
                                                ? null
                                                : () => _preview(
                                                    _selected ?? _results.first,
                                                  ),
                                            child: const Text('在系统地图中查看'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      if (_nativeMap &&
                          !_invalid &&
                          constraints.maxHeight - panelHeight >= 160)
                        Positioned(
                          left:
                              (_markerAnchor?.dx ?? constraints.maxWidth / 2) -
                              27,
                          top:
                              (_markerAnchor?.dy ??
                                  (constraints.maxHeight - panelHeight) / 2) -
                              49.5,
                          child: const IgnorePointer(
                            child: Icon(
                              Icons.location_on,
                              size: 54,
                              color: Color(0xFF07C160),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: MediaQuery.paddingOf(context).top + 74,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        left: 8,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _sending
                                  ? null
                                  : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF222222),
                                minimumSize: const Size(64, 44),
                              ),
                              child: const Text(
                                '取消',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            FilledButton(
                              onPressed:
                                  _selected == null ||
                                      _invalid ||
                                      _busy ||
                                      _sending
                                  ? null
                                  : _confirm,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF07C160),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                minimumSize: const Size(64, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                _sending ? '发送中' : '发送',
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (constraints.maxHeight - panelHeight >= 160)
                        Positioned(
                          bottom: 30,
                          left: 16,
                          child: Material(
                            color: Colors.white,
                            elevation: 1,
                            borderRadius: BorderRadius.circular(8),
                            child: IconButton(
                              tooltip: '使用当前位置',
                              onPressed: _invalid || _busy || _sending
                                  ? null
                                  : () => _load(true),
                              color: const Color(0xFF222222),
                              icon: const Icon(Icons.my_location, size: 25),
                            ),
                          ),
                        ),
                      if (_nativeMap && _mapStatus == 'failed')
                        Positioned(
                          left: 74,
                          right: 16,
                          bottom: 32,
                          child: const Text(
                            '地图加载失败，请检查网络后重新进入',
                            style: TextStyle(color: Color(0xFF555555)),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: panelHeight,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: TextField(
                            controller: _query,
                            enabled: !_invalid && !_sending,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _load(false),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF222222),
                            ),
                            decoration: InputDecoration(
                              hintText: '搜索地点',
                              hintStyle: const TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 16,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFEDEDED),
                              isDense: true,
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF999999),
                                size: 22,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        if (_busy)
                          const SizedBox(
                            height: 2,
                            child: LinearProgressIndicator(
                              color: Color(0xFF07C160),
                            ),
                          ),
                        if (_accuracyLabel != null && _error == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _accuracyLabel!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFF777777),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '定位权限设置',
                                  onPressed: _invalid
                                      ? null
                                      : Geolocator.openAppSettings,
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: _results.isEmpty && !_busy && _error == null
                              ? const Center(
                                  child: Text(
                                    '移动地图或搜索地点',
                                    style: TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _results.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    thickness: .5,
                                    color: Color(0xFFEDEDED),
                                  ),
                                  itemBuilder: (context, index) {
                                    final location = _results[index];
                                    final selected =
                                        _selected?.sameAs(location) ?? false;
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 2,
                                          ),
                                      onTap: _sending || _busy || _invalid
                                          ? null
                                          : () => _select(location),
                                      title: Text(
                                        location.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF222222),
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _subtitle(location),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF999999),
                                          fontSize: 12,
                                          height: 1.7,
                                        ),
                                      ),
                                      trailing: selected
                                          ? const Icon(
                                              Icons.check,
                                              color: Color(0xFF07C160),
                                              size: 26,
                                            )
                                          : null,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
