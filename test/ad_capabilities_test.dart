import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:gromore_flutter/gromore_flutter_platform_interface.dart';

class CapabilityPlatform extends GromoreFlutterPlatform {
  final events = StreamController<dynamic>.broadcast(sync: true);
  final disposed = <String>[];
  final shown = <String>[];
  bool ready = false;
  bool reject = false;
  bool empty = false;
  bool rejectShow = false;
  bool rejectCleanup = false;
  int next = 0;
  @override
  Stream<dynamic> get adEvents => events.stream;
  @override
  Stream<dynamic> get logEvents => const Stream.empty();
  @override
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    final id = 'ad-${next++}';
    if (!empty) {
      events.add({
        'adId': id,
        'adType': type.value,
        'eventType': reject ? 'failed' : 'loaded',
        'errorCode': reject ? 'no_fill' : null,
        'data': {
          'adIds': [id, if (type == GromoreAdType.native) '$id-child']
        },
      });
    }
    // Deliberately deliver the event before the method result.
    await Future<void>.delayed(Duration.zero);
    return id;
  }

  @override
  Future<void> disposeAd(String adId) async {
    disposed.add(adId);
    if (rejectCleanup) throw PlatformException(code: 'cleanup_failed');
  }

  @override
  Future<void> showAd(String adId) async {
    if (rejectShow) throw PlatformException(code: 'show_failed');
    shown.add(adId);
  }

  @override
  Future<dynamic> invokeNative(
      String method, Map<String, dynamic>? args) async {
    if (method == 'getAdState') return {'isReady': ready, 'isLoading': !ready};
    if (method == 'getAdIds') return [args!['adId']];
    if (method == 'getAdDiagnostics') return {'loadInfo': [], 'bestEcpm': null};
    throw PlatformException(code: 'unsupported');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = CapabilityPlatform();
  setUpAll(() {
    GromoreFlutterPlatform.instance = platform;
  });
  setUp(() {
    platform.ready = false;
    platform.reject = false;
    platform.empty = false;
    platform.rejectShow = false;
    platform.rejectCleanup = false;
    platform.disposed.clear();
    platform.shown.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('reward payloads from Android and iOS retain structured and raw fields',
      () {
    for (final fields in [
      {
        'isRewardValid': true,
        'reward_name': '金币',
        'reward_amount': '2',
        'user_id': 'u',
        'trans_id': 't'
      },
      {
        'verify': 1,
        'rewardName': '金币',
        'rewardAmount': 2,
        'userId': 'u',
        'tradeId': 't',
        'verifyByGroMoreS2S': true
      },
    ]) {
      final event = GromoreAdEvent.fromMap({
        'adId': 'id',
        'adType': 'rewardVideo',
        'eventType': 'rewarded',
        'data': fields
      }) as GromoreAdRewardEvent;
      expect(event.rewardVerify, true);
      expect(event.rewardName, '金币');
      expect(event.rewardAmount, 2);
      expect(event.userId, 'u');
      expect(event.tradeId, 't');
      expect(event.data, fields);
    }
  });
  test(
      'legacy top-level reward fields take precedence including false and zero',
      () {
    final event = GromoreAdEvent.fromMap({
      'eventType': 'rewarded',
      'rewardVerify': false,
      'rewardAmount': 0,
      'data': {'verify': true, 'rewardAmount': 4}
    }) as GromoreAdRewardEvent;
    expect(event.rewardVerify, false);
    expect(event.rewardAmount, 0);
  });
  test('ecpm permissions and unknown SDK fields are preserved', () {
    final value = GromoreEcpmInfo({'ecpm': '-3', 'futureField': 'raw'});
    expect(value.ecpmValue, null);
    expect(value.raw['futureField'], 'raw');
    expect(GromoreEcpmInfo({'ecpm': '0'}).ecpmValue, 0);
  });
  test('loadAll returns every ad when loaded precedes method response',
      () async {
    final ids = await GromoreFeed.loadAll(
        const GromoreFeedConfig(placementId: 'feed', adCount: 2));
    expect(ids.length, 2);
    expect(ids.last, '${ids.first}-child');
    for (final id in ids) {
      await GromoreFeed.dispose(id);
    }
    expect(platform.disposed, ids);
  });
  test('loadAndShow waits for actual readiness after loaded', () async {
    final future = GromoreSplash.loadAndShow(
        const GromoreSplashConfig(placementId: 'splash'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(platform.shown, isEmpty);
    platform.ready = true;
    final id = await future;
    expect(platform.shown, [id]);
  });
  test('load errors before method response propagate and dispose', () async {
    platform.reject = true;
    await expectLater(
        GromoreSplash.loadAndShow(
            const GromoreSplashConfig(placementId: 'splash')),
        throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'no_fill')));
    expect(platform.shown, isEmpty);
    expect(platform.disposed.length, 1);
  });
  test('timeout disposes pending loads', () async {
    platform.empty = true;
    await expectLater(
        GromoreFlutter.instance.loadAds(
            GromoreAdType.native, const GromoreAdRequest(placementId: 'feed'),
            timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()));
    expect(platform.disposed.length, 1);
  });
  test('interstitial listener receives its own native events', () async {
    final received = <GromoreAdEvent>[];
    final sub = GromoreInterstitial.listen(
        callback: GromoreAdCallback(onEvent: received.add));
    platform.events
        .add({'adId': 'i', 'adType': 'interstitial', 'eventType': 'cached'});
    platform.events
        .add({'adId': 'f', 'adType': 'fullscreenVideo', 'eventType': 'cached'});
    await Future<void>.delayed(Duration.zero);
    expect(received.map((e) => e.adId), ['i']);
    await sub.cancel();
  });
  test('Android SDK reward aliases and nested extraInfo are parsed', () {
    final event = GromoreAdEvent.fromMap({
      'eventType': 'rewarded',
      'adType': 'rewardVideo',
      'data': {
        'isRewardValid': true,
        'transId': 'trade',
        'isGroMoreServerSideVerify': true,
        'extraInfo': {
          'reward_verify': true,
          'reward_amount': 7,
          'reward_custom_data': 'order'
        }
      }
    }) as GromoreAdRewardEvent;
    expect(event.rewardAmount, 7);
    expect(event.customData, 'order');
    expect(event.tradeId, 'trade');
    expect(event.verifyByGroMoreS2S, true);
  });
  test('show rejection disposes the loaded splash and preserves error',
      () async {
    platform.ready = true;
    platform.rejectShow = true;
    platform.rejectCleanup = true;
    await expectLater(
        GromoreSplash.loadAndShow(const GromoreSplashConfig(placementId: 's')),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'show_failed')));
    expect(platform.disposed.length, 1);
  });
  test('readiness timeout disposes an ad that loaded but never became ready',
      () async {
    await expectLater(
        GromoreFlutter.instance.loadReady(
            GromoreAdType.splash, const GromoreAdRequest(placementId: 's'),
            timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()));
    expect(platform.disposed.length, 1);
  });
  test('cleanup errors do not replace the original load error', () async {
    platform.reject = true;
    platform.rejectCleanup = true;
    await expectLater(
        GromoreFlutter.instance.loadAds(
            GromoreAdType.native, const GromoreAdRequest(placementId: 'f')),
        throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'no_fill')));
  });
  test('diagnostics preserve missing permissions and error phase', () async {
    final diagnostics = await GromoreFlutter.instance.getAdDiagnostics('id');
    expect(diagnostics.bestEcpm, null);
    expect(diagnostics.multiBiddingEcpm, null);
    final error = GromoreAdEvent.fromMap({
      'eventType': 'failed',
      'data': {'phase': 'show'}
    }) as GromoreAdErrorEvent;
    expect(error.phase, 'show');
  });
  test('request options preserve zero, false and platform maps', () {
    final map = const GromoreBannerConfig(
        placementId: 'b',
        options: GromoreRequestOptions(
            scenarioId: 'scene',
            volume: 0,
            bidNotify: false,
            addParams: {'adnKey': 'value'})).toRequest().toMap();
    expect(map['scenarioId'], 'scene');
    expect(map['volume'], 0);
    expect(map['bidNotify'], false);
    expect(map['addParams'], {'adnKey': 'value'});
  });
}
