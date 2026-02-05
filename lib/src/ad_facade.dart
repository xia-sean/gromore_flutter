import 'dart:async';

import 'ad_callbacks.dart';
import 'ad_configs.dart';
import 'ad_event.dart';
import 'ad_types.dart';
import 'gromore_flutter.dart';

/// 开屏广告 Facade
class GromoreSplash {
  static Future<String> load(GromoreSplashConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.splash,
      config.toRequest(),
    );
  }

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static Future<String> loadAndShow(GromoreSplashConfig config) async {
    final adId = await load(config);
    await show(adId);
    return adId;
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.splash,
      adId: adId,
      callback: callback,
    );
  }
}

/// 插屏广告 Facade
class GromoreInterstitial {
  static Future<String> load(GromoreInterstitialConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.interstitial,
      config.toRequest(),
    );
  }

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.interstitial,
      adId: adId,
      callback: callback,
    );
  }
}

/// 全屏视频广告 Facade
class GromoreFullscreenVideo {
  static Future<String> load(GromoreFullscreenVideoConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.fullscreenVideo,
      config.toRequest(),
    );
  }

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.fullscreenVideo,
      adId: adId,
      callback: callback,
    );
  }
}

/// 激励视频广告 Facade
class GromoreReward {
  static Future<String> load(GromoreRewardConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.rewardVideo,
      config.toRequest(),
    );
  }

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.rewardVideo,
      adId: adId,
      callback: callback,
    );
  }
}

/// Banner 广告 Facade
class GromoreBanner {
  static Future<String> load(GromoreBannerConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.banner,
      config.toRequest(),
    );
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.banner,
      adId: adId,
      callback: callback,
    );
  }
}

/// 信息流广告 Facade
class GromoreFeed {
  static Future<String> load(GromoreFeedConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.native,
      config.toRequest(),
    );
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.native,
      adId: adId,
      callback: callback,
    );
  }
}

/// Draw 信息流广告 Facade
class GromoreDraw {
  static Future<String> load(GromoreDrawConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.drawNative,
      config.toRequest(),
    );
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.drawNative,
      adId: adId,
      callback: callback,
    );
  }
}
