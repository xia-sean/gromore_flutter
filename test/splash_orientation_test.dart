import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:gromore_flutter/gromore_flutter_platform_interface.dart';

class OrientationPlatform extends GromoreFlutterPlatform {
  final events = StreamController<dynamic>.broadcast(sync: true);
  final shown = <String>[];
  final disposed = <String>[];
  bool rejectShow = false;
  int next = 0;

  @override
  Stream<dynamic> get adEvents => events.stream;
  @override
  Stream<dynamic> get logEvents => const Stream.empty();
  @override
  Future<PlatformInitResult> init(GromoreConfig config) async =>
      const PlatformInitResult.success();
  @override
  Future<void> setLogEnabled(bool enabled) async {}
  @override
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async =>
      'orientation-${next++}';
  @override
  Future<void> showAd(String adId) async {
    if (rejectShow) throw PlatformException(code: 'show_failed');
    shown.add(adId);
  }

  @override
  Future<void> disposeAd(String adId) async => disposed.add(adId);

  void emit(String id, String event) => events.add({
        'adId': id,
        'adType': 'splash',
        'eventType': event,
      });
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final platform = OrientationPlatform();
  final plugin = GromoreFlutter.instance;
  final changes = <List<String>>[];
  final ids = <String>[];
  Completer<void>? lockGate;

  Future<String> load() async {
    final id = await GromoreSplash.load(
        const GromoreSplashConfig(placementId: 'splash'));
    ids.add(id);
    return id;
  }

  setUpAll(() => GromoreFlutterPlatform.instance = platform);
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    changes.clear();
    platform.shown.clear();
    platform.disposed.clear();
    platform.rejectShow = false;
    lockGate = null;
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        final values = (call.arguments as List).cast<String>();
        changes.add(values);
        if (values.contains('DeviceOrientation.portraitUp')) {
          await lockGate?.future;
        }
      }
      return null;
    });
    await plugin.init(const GromoreConfig(
      iosAppId: 'test',
      iosSplashRestoreOrientations: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ));
  });
  tearDown(() async {
    lockGate?.complete();
    lockGate = null;
    for (final id in ids) {
      await plugin.disposeAd(id);
    }
    ids.clear();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('preloading and disposing an unshown splash preserve host orientation',
      () async {
    final id = await load();
    await plugin.disposeAd(id);
    expect(changes, isEmpty);
  });

  test('close restores the configured host orientations once', () async {
    final id = await load();
    await plugin.showAd(id);
    expect(changes, [
      ['DeviceOrientation.portraitUp']
    ]);
    platform.emit(id, 'completed');
    await Future<void>.delayed(Duration.zero);
    expect(changes, hasLength(1));
    platform.emit(id, 'closed');
    platform.emit(id, 'closed');
    await Future<void>.delayed(Duration.zero);
    expect(changes.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(changes, hasLength(2));
  });

  test('show rejection restores host policy and preserves the original error',
      () async {
    final id = await load();
    platform.rejectShow = true;
    await expectLater(
        plugin.showAd(id),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'show_failed')));
    expect(changes.last, contains('DeviceOrientation.landscapeLeft'));
  });

  test('another or duplicate show cannot unlock an active splash', () async {
    final first = await load();
    final second = await load();
    await plugin.showAd(first);
    for (final id in [first, second]) {
      await expectLater(
          plugin.showAd(id),
          throwsA(isA<PlatformException>()
              .having((e) => e.code, 'code', 'splash_show_in_progress')));
    }
    platform.emit(second, 'failed');
    await plugin.disposeAd(second);
    expect(changes, hasLength(1));
    expect(platform.shown, [first]);
    await plugin.disposeAd(first);
    expect(changes, hasLength(2));
  });

  test('dispose during orientation change cancels native presentation',
      () async {
    final id = await load();
    lockGate = Completer<void>();
    final showing = plugin.showAd(id);
    final expectation = expectLater(
        showing,
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'show_cancelled')));
    await Future<void>.delayed(Duration.zero);
    final disposing = plugin.disposeAd(id);
    lockGate!.complete();
    lockGate = null;
    await disposing;
    await expectation;
    expect(platform.shown, isEmpty);
    expect(platform.disposed, contains(id));
    expect(changes.last, contains('DeviceOrientation.landscapeLeft'));
  });
}
