import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:integration_test/integration_test.dart';

// 默认跳过，只有显式传入测试 AppId 和广告位才请求真实广告。
const _enabled = bool.fromEnvironment('GM_RUN_REAL_ADS');
const _appId = String.fromEnvironment('GM_APP_ID');
const _rewardId = String.fromEnvironment('GM_REWARD_ID');
const _bannerId = String.fromEnvironment('GM_BANNER_ID');
const _feedId = String.fromEnvironment('GM_FEED_ID');
const _drawId = String.fromEnvironment('GM_DRAW_ID');
const _splashId = String.fromEnvironment('GM_SPLASH_ID');
const _interstitialId = String.fromEnvironment('GM_INTERSTITIAL_ID');
const _fullscreenId = String.fromEnvironment('GM_FULLSCREEN_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!_enabled) return;
    expect(_appId, isNotEmpty,
        reason: '请通过 --dart-define=GM_APP_ID 提供测试 AppId');
    final result = await GromoreFlutter.instance.initialize(
      androidAppId: _appId,
      iosAppId: _appId,
      privacy: const GromorePrivacyConfig.disableAll(),
    );
    expect(result.android.success || result.ios.success, isTrue);
  });

  final configs = <GromoreAdType, GromoreAdConfig>{
    GromoreAdType.rewardVideo: const GromoreRewardConfig(
      placementId: _rewardId,
      userId: 'integration_test',
      customData: {'source': 'integration_test', 'orderId': 'test-order'},
    ),
    GromoreAdType.banner: const GromoreBannerConfig(
        placementId: _bannerId, width: 320, height: 100),
    GromoreAdType.native: const GromoreFeedConfig(
        placementId: _feedId, width: 320, height: 400, adCount: 1),
    GromoreAdType.drawNative: const GromoreDrawConfig(
        placementId: _drawId, width: 320, height: 400, adCount: 1),
    GromoreAdType.splash: const GromoreSplashConfig(placementId: _splashId),
    GromoreAdType.interstitial:
        const GromoreInterstitialConfig(placementId: _interstitialId),
    GromoreAdType.fullscreenVideo:
        const GromoreFullscreenVideoConfig(placementId: _fullscreenId),
  };
  for (final entry in configs.entries) {
    testWidgets('${entry.key.value}: real load, show, detach and dispose',
        (tester) async {
      var shown = false;
      var closed = false;
      GromoreAdErrorEvent? failure;
      GromoreAdRewardEvent? reward;
      final controller = GromoreAdController(
          adType: entry.key,
          callback: GromoreAdCallback(
            onShown: (_) => shown = true,
            onClosed: (_) => closed = true,
            onFailed: (event) => failure = event,
            onRewarded: (event) => reward = event,
          ));
      addTearDown(controller.dispose);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await controller.load(entry.value, timeout: const Duration(seconds: 30));
      final id = controller.adId!;
      Widget? view;
      if (entry.key == GromoreAdType.banner) view = GromoreBannerView(adId: id);
      if (entry.key == GromoreAdType.native) view = GromoreFeedView(adId: id);
      if (entry.key == GromoreAdType.drawNative) {
        view = GromoreDrawView(adId: id);
      }
      if (view != null) {
        await tester
            .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: view))));
      } else {
        await controller.show();
      }
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (!(view != null ? shown : closed) &&
          failure == null &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(failure, isNull);
      expect(shown, isTrue, reason: '未收到真实展示回调');
      if (view == null) expect(closed, isTrue, reason: '请在设备上完成播放并关闭广告');
      if (entry.key == GromoreAdType.rewardVideo) {
        expect(reward, isNotNull, reason: '激励需完整播放后再关闭');
        expect(reward!.rewardVerify, isTrue);
        // 客户端回调不作为服务端 extra 已到达的证据，见真机验证文档。
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.dispose();
      await controller.dispose();
      await expectLater(
          GromoreFlutter.instance.getAdState(id),
          throwsA(isA<PlatformException>()
              .having((error) => error.code, 'code', 'ad_not_found')));
    }, skip: !_enabled || entry.value.placementId.isEmpty);
  }
}
