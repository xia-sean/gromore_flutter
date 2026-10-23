import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:gromore_flutter/gromore_flutter_platform_interface.dart';

class OptimizationPlatform extends GromoreFlutterPlatform {
  final events = StreamController<dynamic>.broadcast(sync: true);
  final disposed = <String>[];
  final shown = <String>[];
  final calls = <String>[];
  Map<String, dynamic>? lastArgs;
  Completer<void>? responseGate;
  bool waitForReady = false;
  bool waitForCleanup = false;
  bool reject = false;
  int nextId = 0;
  @override
  Stream<dynamic> get adEvents => events.stream;
  @override
  Stream<dynamic> get logEvents => const Stream.empty();
  @override
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    calls.add('loadAd');
    final id = 'optimized-${nextId++}';
    events.add({
      'adId': id,
      'adType': type.value,
      'eventType': reject ? 'failed' : 'loaded',
      if (reject) 'errorCode': 'no_fill',
      'data': {
        'adIds': [
          id,
          if (type == GromoreAdType.native || type == GromoreAdType.drawNative)
            '$id-child'
        ]
      },
    });
    await responseGate?.future;
    return id;
  }

  @override
  Future<void> showAd(String adId) async => shown.add(adId);
  @override
  Future<void> disposeAd(String adId) async {
    disposed.add(adId);
    if (waitForCleanup) await Completer<void>().future;
  }

  @override
  Future<dynamic> invokeNative(
      String method, Map<String, dynamic>? args) async {
    calls.add(method);
    lastArgs = args;
    if (method == 'getAdState') {
      if (waitForReady) return Completer<dynamic>().future;
      return {'isReady': true};
    }
    if (method == 'getAdIds') return [args!['adId'], '${args['adId']}-child'];
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = OptimizationPlatform();
  final plugin = GromoreFlutter.instance;
  setUpAll(() async {
    GromoreFlutterPlatform.instance = platform;
    final sub = plugin.listenAdEvents(callback: const GromoreAdCallback());
    await sub.cancel();
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    platform.disposed.clear();
    platform.calls.clear();
    platform.shown.clear();
    platform.responseGate = null;
    platform.waitForReady = false;
    platform.waitForCleanup = false;
    platform.reject = false;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('timeout covers a hung method response and cleans all late IDs',
      () async {
    platform.responseGate = Completer<void>();
    await expectLater(
        plugin.loadAds(GromoreAdType.native,
            const GromoreFeedConfig(placementId: 'f').toRequest(),
            timeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()));
    expect(platform.disposed, isEmpty);
    platform.responseGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(platform.disposed, hasLength(2));
  });
  test('late method errors after timeout are handled', () async {
    platform.responseGate = Completer<void>();
    await expectLater(
        GromoreBanner.loadReady(const GromoreBannerConfig(placementId: 'b'),
            timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()));
    platform.responseGate!
        .completeError(PlatformException(code: 'late_failure'));
    await Future<void>.delayed(Duration.zero);
  });
  test('readiness query cannot hang beyond the loading deadline', () async {
    platform.waitForReady = true;
    await expectLater(
        GromoreReward.loadReady(const GromoreRewardConfig(placementId: 'r'),
            timeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()));
    expect(platform.disposed, hasLength(1));
  });
  test('hung native cleanup does not block timeout completion', () async {
    platform.waitForReady = true;
    platform.waitForCleanup = true;
    await expectLater(
        GromoreInterstitial.loadReady(
                const GromoreInterstitialConfig(placementId: 'i'),
                timeout: const Duration(milliseconds: 10))
            .timeout(const Duration(seconds: 1)),
        throwsA(isA<TimeoutException>()));
    expect(platform.disposed, hasLength(1));
  });
  test('zero timeout and invalid final params are rejected before native calls',
      () async {
    await expectLater(
        GromoreFullscreenVideo.loadReady(
            const GromoreFullscreenVideoConfig(placementId: 'v'),
            timeout: Duration.zero),
        throwsArgumentError);
    await expectLater(
        plugin.loadAd(
            GromoreAdType.rewardVideo,
            const GromoreRewardConfig(placementId: 'r', rewardAmount: -1)
                .toRequest()),
        throwsArgumentError);
    expect(platform.calls, isEmpty);
  });
  test('video enum and old strings use identical native actions', () async {
    await plugin.controlVideo('f', GromoreVideoAction.pause);
    expect(platform.lastArgs, {'adId': 'f', 'action': 'pause'});
    await plugin.controlVideo('f', 'resume');
    expect(platform.lastArgs!['action'], 'resume');
    final count = platform.calls.length;
    await expectLater(plugin.controlVideo('f', 'pasue'), throwsArgumentError);
    expect(platform.calls, hasLength(count));
  });
  test(
      'typed preload infers type, serializes customData and keeps logical sizes',
      () async {
    await plugin.preloadAds(const [
      GromorePreloadRequest(
          config: GromoreRewardConfig(
              placementId: 'r', customData: {'order': '123'})),
      GromorePreloadRequest(
          config:
              GromoreBannerConfig(placementId: 'b', width: 320, height: 100)),
    ]);
    final items = platform.lastArgs!['requests'] as List;
    expect(items[0]['adType'], 'rewardVideo');
    expect(items[0]['request']['customData'], '{"order":"123"}');
    expect(items[1]['request']['sizeUnit'], 'logicalPixels');
    expect(items[1]['request']['width'], 320);
    await plugin.preloadAds([
      {
        'adType': 'banner',
        'request': {'placementId': 'legacy', 'width': 960}
      }
    ]);
    expect(platform.lastArgs!['requests'][0]['request']['sizeUnit'],
        'nativePixels');
  });
  test('iOS typed preload requires factory and forwards its parameters',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await expectLater(
        plugin.preloadAds(const [
          GromorePreloadRequest(config: GromoreBannerConfig(placementId: 'b'))
        ]),
        throwsArgumentError);
    expect(platform.calls, isEmpty);
    await plugin.preloadAds(const [
      GromorePreloadRequest(
          config: GromoreBannerConfig(placementId: 'b'),
          iosFactoryId: 'factory',
          iosFactoryParams: {'count': 1})
    ]);
    expect(platform.lastArgs!['requests'][0]['iosFactoryId'], 'factory');
    expect(platform.lastArgs!['requests'][0]['factoryParams'], {'count': 1});
  });
  test('controller owns all IDs and filters events, disposal is idempotent',
      () async {
    final received = <String>[];
    final controller = GromoreAdController(
        adType: GromoreAdType.native,
        callback:
            GromoreAdCallback(onEvent: (event) => received.add(event.adId)));
    final ids = await controller
        .load(const GromoreFeedConfig(placementId: 'f', adCount: 2));
    expect(controller.adId, ids.first);
    expect(received, [ids.first]);
    platform.events
        .add({'adId': 'unrelated', 'adType': 'native', 'eventType': 'clicked'});
    platform.events
        .add({'adId': ids.last, 'adType': 'native', 'eventType': 'clicked'});
    await Future<void>.delayed(Duration.zero);
    expect(received, [ids.first, ids.last]);
    await controller.dispose();
    await controller.dispose();
    expect(platform.disposed, ids);
    platform.events
        .add({'adId': ids.first, 'adType': 'native', 'eventType': 'clicked'});
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(2));
    expect(controller.adId, isNull);
    await expectLater(
        controller.load(const GromoreFeedConfig(placementId: 'f')),
        throwsStateError);
  });
  test('dispose during loading releases late results and cannot show',
      () async {
    platform.responseGate = Completer<void>();
    final controller = GromoreAdController(adType: GromoreAdType.rewardVideo);
    final loading =
        controller.load(const GromoreRewardConfig(placementId: 'r'));
    final assertion = expectLater(loading, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await controller.dispose();
    platform.responseGate!.complete();
    await assertion;
    expect(platform.disposed, hasLength(1));
    await expectLater(controller.show(), throwsStateError);
    expect(platform.shown, isEmpty);
  });
  test('controller reload releases old IDs, validates config and forwards show',
      () async {
    final controller = GromoreAdController(adType: GromoreAdType.rewardVideo);
    await expectLater(
        controller.load(const GromoreBannerConfig(placementId: 'b')),
        throwsArgumentError);
    final first =
        await controller.load(const GromoreRewardConfig(placementId: 'r'));
    final second =
        await controller.load(const GromoreRewardConfig(placementId: 'r'));
    expect(platform.disposed, first);
    await controller.show();
    expect(platform.shown, second);
    await controller.dispose();
  });
  test(
      'controller disposed by early callbacks does not return an empty success',
      () async {
    late GromoreAdController controller;
    controller = GromoreAdController(
        adType: GromoreAdType.banner,
        callback: GromoreAdCallback(onLoaded: (_) => controller.dispose()));
    await expectLater(
        controller.load(const GromoreBannerConfig(placementId: 'b')),
        throwsStateError);
    expect(controller.isDisposed, isTrue);
    expect(platform.disposed, hasLength(1));
  });
  test('controller rejects concurrent loads and releases the earlier batch',
      () async {
    platform.responseGate = Completer<void>();
    final controller = GromoreAdController(adType: GromoreAdType.banner);
    final loading =
        controller.load(const GromoreBannerConfig(placementId: 'b'));
    await Future<void>.delayed(Duration.zero);
    await expectLater(
        controller.load(const GromoreBannerConfig(placementId: 'b')),
        throwsStateError);
    platform.responseGate!.complete();
    final ids = await loading;
    await controller.dispose();
    expect(platform.disposed, ids);
  });
  test('controller cleans loading failures without calling show', () async {
    platform.reject = true;
    final controller = GromoreAdController(adType: GromoreAdType.banner);
    await expectLater(
        controller.load(const GromoreBannerConfig(placementId: 'b')),
        throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'no_fill')));
    expect(controller.adIds, isEmpty);
    expect(platform.disposed, isNotEmpty);
    await controller.dispose();
  });
  testWidgets('dedicated Feed and Draw views expose manual video management',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      for (final view in [
        const GromoreFeedView(
            adId: 'f',
            width: 320,
            height: 100,
            autoManageVideo: false,
            enableVisibility: false),
        const GromoreDrawView(
            adId: 'd',
            width: 320,
            height: 100,
            autoManageVideo: false,
            enableVisibility: false),
      ]) {
        await tester.pumpWidget(
            Directionality(textDirection: TextDirection.ltr, child: view));
        expect(
            tester
                .widget<GromoreAdView>(find.byType(GromoreAdView))
                .autoManageVideo,
            isFalse);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
